#!/bin/bash

CONFIG_PATH="./scripts/config.yml"
YAML="./scripts/yq"

BASE_DIR=$($YAML eval ".BASE_DIR" "${CONFIG_PATH}")
TIMESTAMP=$(date '+%Y-%m-%dT%H:%MZ')

parse_yaml() {
    echo $($YAML eval ".$1" "${CONFIG_PATH}")
}

sync_repo() {

    local repo=$1
    local type=$(parse_yaml "repos.${repo}.type")
    local url=$(parse_yaml "repos.${repo}.url")
    local path=$(parse_yaml "repos.${repo}.path")
    local log=$(parse_yaml "repos.${repo}.log")

    if [[ "$type" == "null" ]]; then
        type=$(parse_yaml "global.type")
    fi

    if [[ "$log" == "null" ]]; then
        log="$(parse_yaml "global.log_dir")$path"
    fi

    log=$(realpath $log)
    path="${BASE_DIR}/$path/"
    echo -e "----\n|  Repo: $repo\n|  Type: $type\n|  Upstream: $url\n|  Path: $path\n|  Log: $log\n----"
    
    rotate_log $log

    case $type in
        "rsync")
            local rsync_options=$(parse_yaml 'global.rsync.options')
            local exclude_list=($(parse_yaml 'global.rsync.exclude[]'))
            local exclude=""
            for ex in "${exclude_list[@]}"; do
                exclude="${exclude} --exclude='${ex}'"
            done
            echo rsync ${rsync_options} ${exclude} $url $path >> $log
            rsync ${rsync_options} ${exclude} $url $path >> $log 2>> ${log}-error
            ;;
        "ftpsync")
            cd ${BASE_DIR}/scripts
            export BASE_DIR=${BASE_DIR}
            ./ftpsync >> $log 2>> ${log}-error
            cd ${BASE_DIR}
            ;;
        "http")
            echo ${repo} Fetch >> $log 2>> ${log}-error
            python3 -u $BASE_DIR/scripts/getFetch.py "${url}" $path $BASE_DIR/scripts/${path}.fetch >> $log 2>> ${log}-error
            echo ${repo} Download >> $log 2>> ${log}-error
            python3 -u $BASE_DIR/scripts/getFile.py $BASE_DIR/scripts/${path}.fetch >> $log 2>> ${log}-error
            ;;
        *)
            echo "Unknown type $type for $repo." | tee ${log}-error
            ;;
    esac

    clean_log $log
}

rotate_log() {
    local log_file=$1
    if [[ -f $log_file ]]; then
        PREV_LOG=$(cat "$log_file" | head -n 1)    
        old_log_file="$(dirname $log_file)/old/$(basename $log_file)-$PREV_LOG"
        mkdir -p "$(dirname $old_log_file)"
        mv "$log_file" "$old_log_file"
    fi

    local error_file=$1-error
    if [[ -f $error_file ]]; then
        PREV_LOG=$(cat "$error_file" | head -n 1)    
        old_error_file="$(dirname $error_file)/old/$(basename $error_file)-$PREV_LOG"
        mkdir -p "$(dirname $old_error_file)"
        mv "$error_file" "$old_error_file"
    fi

    echo $TIMESTAMP >> $log_file
    echo $TIMESTAMP >> $error_file
}

clean_log() {
    local error_file=$1-error
    nl=$(cat "$error_file" | wc -l)
    if [ $nl -eq 1 ]; then
        rm "$error_file"
    fi
}

##########
#  Main  # 
##########

echo Started job $TIMESTAMP..

global_pre_scripts=($(parse_yaml 'global.scripts.pre[]'))
for script in "${global_pre_scripts[@]}"; do
    $script
done

repos=($(parse_yaml 'global.sync[]'))

if [[ "${repos[0]}" == "ALL" ]]; then
    repos=($($YAML eval '.repos | keys| .[]' "${CONFIG_PATH}"))
fi
for repo in "${repos[@]}"; do
    echo Checking $repo...
    duration=$(parse_yaml "repos.${repo}.duration")
    last_sync_timestamp=$(date -d "$(parse_yaml "repos.${repo}.last_sync")" +%s)
    next_sync_timestamp=$(( last_sync_timestamp + duration * 3600 ))
    next_sync_timestamp=1
    if [ $next_sync_timestamp -le $(date +%s) ]; then
        echo "Lastsync $last_sync_timestamp"
        echo "Syncing $repo..."

        sync_repo $repo

        if [ $? -ne 0 ]; then
            global_fail_scripts=($(parse_yaml 'global.scripts.fail[]'))
            for script in "${global_fail_scripts[@]}"; do
                $script
            done
            echo "Error syncing $repo"
        else
            $YAML eval ".repos.${repo}.last_sync = \"$TIMESTAMP\"" -i "${CONFIG_PATH}"
            echo "Successfully synced $repo."
        fi
    fi
done

global_post_scripts=($(parse_yaml 'global.scripts.post[]'))
for script in "${global_post_scripts[@]}"; do
    $script
done

echo Ended job $TIMESTAMP..
