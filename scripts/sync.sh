#!/bin/bash

TIMENOW=$(date '+%Y%m%d_%H%M')
BASE_DIR="/srv/mirror"
ALERT="$BASE_DIR/scripts/alert.sh"
DATA_DIR="$BASE_DIR/pub"

echo $TIMENOW $BASE_DIR $DATA_DIR $USER

if [[ "$USER" == "root" ]]; then
	echo "Dont run as root."
	su user $0 $@
	exit
fi

option="-rtlHpvi --chmod=D0755,F0644 --partial --hard-links --safe-links --stats --delete --delete-after --delay-updates --max-delete=70000"
exclude="--exclude=.*.?????? --exclude='.~tmp~/' --exclude='Packages*' --exclude='Sources*' --exclude='Release*' --exclude='*.links.tar.gz*' --exclude='/other' --exclude='/sources'"

ubuntu="rsync://rsync.archive.ubuntu.com/ubuntu/"
ubuntu_cd="rsync://releases.ubuntu.com/releases/"
ubuntu_cd_old="rsync://old-releases.ubuntu.com/releases/"
debian="rsync://mirrors.xtom.jp/debian/"
debian_cd="rsync://ftp.lanet.kr/debian-cd/"
fedora="rsync://dl.fedoraproject.org/fedora-enchilada/linux/"
epel="rsync://dl.fedoraproject.org/fedora-epel/"
fedora_cd=""
archlinux="rsync://mirrors.xtom.de/archlinux/"
raspbian="rsync://archive.raspbian.org/archive/"
manjaro="rsync://ftp.riken.jp/manjaro/"
gnu="rsync://ftp.gnu.org/gnu/"
kali_images="rsync://repo.jing.rocks/kali-images"
kali="rsync://repo.jing.rocks/kali"
linux="rsync://rsync.kernel.org/pub/"
failtest="rsync://aa"
if [[ ! -v $1 ]]; then
	echo Not found.
	exit
fi

ubuntu_cd_name="ubuntu-cd"
debian_cd_name="debian-cd"
ubuntu_cd_old_name="ubuntu-old"
kali_images_name="kali-images"

dist=$1
echo Syncing $1...
set -o pipefail
LASTLOG=`head -1 ${BASE_DIR}/logs/${dist}.log`

mv ${BASE_DIR}/logs/${dist}.log ${BASE_DIR}/logs/previous/${dist}-${LASTLOG}.log
mv ${BASE_DIR}/logs/${dist}-error.log ${BASE_DIR}/logs/previous/${dist}-error-${LASTLOG}.log

if [[ -v ${dist}_name ]]; then
	dist_name_var="${dist}_name"
	dist_dir=${!dist_name_var}
else
	dist_dir=$dist
fi

echo ${TIMENOW} >> ${BASE_DIR}/logs/${dist}.log
echo ${TIMENOW} >> ${BASE_DIR}/logs/${dist}-error.log
echo "${TIMENOW}: Mirroring ${dist} from ${!dist} to ${DATA_DIR}/${dist}"
echo "${TIMENOW} STARTED ${dist}" >> ${BASE_DIR}/logs/all.log

TRY=3
while [ $TRY -ne 0 ]; do
  echo Try $TRY...
  if [ "$dist" == "debian" ];
  then
  	cd ${BASE_DIR}/scripts
  	export BASE_DIR=${BASE_DIR}
  	export DATA_DIR=${DATA_DIR}
  	./ftpsync
  else
	unset RSYNC_CONNECT_PROG
	if [ "$dist" == "kali_images" ];
	then
 		# export RSYNC_CONNECT_PROG='ssh zhr0 nc %H 873'
		echo Connecting to RSYNC PROG
	fi
	echo "rsync ${option} ${exclude} ${!dist} ${DATA_DIR}/${dist_dir}" | tee -a ${BASE_DIR}/logs/${dist}.log 
	rsync ${option} ${exclude} ${!dist} ${DATA_DIR}/${dist_dir} 2> >(tee -a ${BASE_DIR}/logs/${dist}-error.log) | tee -a ${BASE_DIR}/logs/${dist}.log
	EXIT=$?
  fi
  if [[ $EXIT == 0 ]]; then break; fi
  TRY=$(($TRY-1))
done

if [ $EXIT -ne 0 ];
then
	MSG="${dist} failed at ${TIMENOW}"
	if [ -f "$ALERT" ];
	then
	        ${ALERT} "${MSG}"
	fi
	
	echo Sync ${dist} Error
	echo "${TIMENOW} ERROR ${dist}" >> ${BASE_DIR}/logs/all.log
else
	echo Sync ${dist} Success
	if [ `echo ${BASE_DIR}/logs/${dist}-error.log | wc -l` -eq 1 ]; 
	then
		rm ${BASE_DIR}/logs/${dist}-error.log
	fi
	echo "${TIMENOW} DONE ${dist}" >> ${BASE_DIR}/logs/all.log
	cd $BASE_DIR
	echo "Updating Index"
	python3 -u ./scripts/index.py ${BASE_DIR} ${DATA_DIR}
fi

