#!/bin/bash

# Default locations.
CONFIG="./scripts/config.yml"
YAML="./scripts/yq"

function usage() {
    cat <<EOF
Usage: $0 [-c config_path] [-y yq_path]

Flags:
    -c, --config_path:      config file path
    -y, --yq:               yq binary path (>v4.35.2)
    -v, --verbose
      -> -b, --base-dir:         overrides base_dir
      -> -d, --dry-run:          dry run
EOF
    exit 1
}

function error() {
    echo $0: "$1"
    exit
}

function debug() {
    if [[ -v DEBUG ]]; then
        echo debug: "$1"
    fi
}

function execute() {
    debug "Executing script: \"$@\""
    if [[ ! -v DRY_RUN ]]; then
        $@
    fi
}

parse_yaml() {
    echo $($YAML eval ".$1" "${CONFIG}")
}

get_repo_config() {
    local LOCAL_CFG=$($YAML eval ".repos.$1.$2" "${CONFIG}")
    if [[ "$LOCAL_CFG" == "null" || "$LOCAL_CFG" == "" ]]; then
        echo $($YAML eval ".defaults.$2" "${CONFIG}");
        return 1
    fi
    echo $LOCAL_CFG
    return 0

    # 1 if global 0 if local
}

sync_repo() {
    local repo=$1
    local name=$(get_repo_config ${repo} name)
    local type=$(get_repo_config ${repo} type)
    local url=$(get_repo_config ${repo} url)
    local path=$(get_repo_config ${repo} path)
    local log; log=$(get_repo_config ${repo} log) || log=${log/\${path\}/$path};

    if [[ "$type" == "null" || "$url" == "null" || "$path" == "null" || "$log" == "null" ]]; then
        echo "Error config wrong."
        return
    fi

    path="${BASE_DIR}/$path/"
    log="${BASE_DIR}/$log"

    echo -e "--------\nRepo:      $name\nType:      $type\nUpstream:  $url\nPath:      $path\nLog:       $log\n--------"

    if [[ ! -v DRY_RUN ]]; then

        rotate_log $log

        case $type in
            "rsync")
                local rsync_options=$(get_repo_config $repo 'rsync.options')
                local exclude_list=($(get_repo_config $repo 'rsync.exclude[]'))
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
    fi
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

function global_log() {
    GLOBAL_LOG_FILE="$(parse_yaml 'global.log')"
    echo "$1 $TIMESTAMP SUCCESS" >> $GLOBAL_LOG_FILE
}

function global_log_error() {
    GLOBAL_LOG_FILE="$(parse_yaml 'global.log')"
    echo "$1 $TIMESTAMP ERROR" >> $GLOBAL_LOG_FILE
}

##########
#  Main  # 
##########

while [ "$1" != "" ]; do
    case $1 in
    -c | --config)
        shift
        if [[ -z $1 ]]; then
            error "option '-c' requires argument 'config_path'"
        fi
        CONFIG=$1
        ;;
    -y | --yq)
        shift
        if [[ -z $1 ]]; then
            error "option '-y' requires argument 'yq_path'"
        fi
        YAML=$1
        ;;
    -b | --base-dir)
        shift
        if [[ -z $1 ]]; then
            error "option '-b' requires argument 'base_dir'"
        fi
        BASE_DIR_OVERRIDE=$1
        ;;
    -h | --help)
        usage
        ;;
    -v | --verbose)
        DEBUG=1
        ;;
    -d | --dry-run)
        DRY_RUN=1
        ;;
    *)
        usage
        exit 1
        ;;
    esac
    shift
done

if [[ -v DEBUG ]]; then
    debug "DEBUG=1"
fi
if [[ -v DRY_RUN ]]; then
    debug "DRY_RUN=1"
fi
debug CONFIG="\"${CONFIG}\""
debug YQ="\"${YAML}\""

if [[ ! -f ${CONFIG} ]]; then
    error "config not found."
fi

if [[ ! -f ${YAML} ]]; then
    error "yq not found."
fi

BASE_DIR=$($YAML eval ".BASE_DIR" "${CONFIG}")

if [[ -v DEBUG && -v BASE_DIR_OVERRIDE ]]; then
    debug "Overriding $BASE_DIR to $BASE_DIR_OVERRIDE"
    BASE_DIR="$BASE_DIR_OVERRIDE"
fi

TIMESTAMP=$(date '+%Y-%m-%dT%H:%MZ')

debug BASE_DIR="\"${BASE_DIR}\""
debug TIMESTAMP="\"${TIMESTAMP}\""

echo Started job $TIMESTAMP..

cd $BASE_DIR
# PRE
global_pre_scripts=($(parse_yaml 'global.scripts.pre[]'))
for script in "${global_pre_scripts[@]}"; do
    execute $BASE_DIR/$script
done
#
repos=($(parse_yaml 'global.sync[]'))

if [[ "${repos[0]}" == "ALL" ]]; then
    repos=($($YAML eval '.repos | keys | .[]' "${CONFIG}"))
fi
for repo in "${repos[@]}"; do
    cd $BASE_DIR
    debug "Checking $repo..."
    
    duration=$(get_repo_config ${repo} "duration")
    last_sync_timestamp=$(date -d "$(get_repo_config ${repo} "last_sync")" +%s)
    next_sync_timestamp=$(( last_sync_timestamp + duration * 3600 ))
    
    if [[ -v DEBUG ]]; then
        next_sync_timestamp=1
        # read -p "Continue? " choice
        # case "$choice" in
        #     y) next_sync_timestamp=1;;
        #     *) continue;;
        # esac
    fi

    if [ $next_sync_timestamp -le $(date +%s) ]; then
        debug "Lastsync was $last_sync_timestamp."
        echo "Syncing $repo..."

        repo_pre_scripts=($(get_repo_config ${repo} "scripts.pre[]"))
        for script in "${repo_pre_scripts[@]}"; do
            execute $BASE_DIR/$script $repo
        done

        sync_repo $repo

        if [ $? -ne 0 ]; then
            repo_fail_scripts=($(get_repo_config ${repo} "scripts.fail[]"))
            for script in "${repo_fail_scripts[@]}"; do
                execute $BASE_DIR/$script $repo
            done

            global_log_error $repo
            echo "Error during syncing $repo."
        else

            global_log $repo
            $YAML eval ".repos.${repo}.last_sync = \"$TIMESTAMP\"" -i "${CONFIG}"
            echo "Successfully synced $repo."
        fi

        repo_post_scripts=($(get_repo_config ${repo} "scripts.post[]"))
        for script in "${repo_post_scripts[@]}"; do
            execute $BASE_DIR/$script $repo
        done
    fi
done

# POST
global_post_scripts=($(parse_yaml 'global.scripts.post[]'))
for script in "${global_post_scripts[@]}"; do
    execute $BASE_DIR/$script
done
#

echo Ended job $TIMESTAMP..