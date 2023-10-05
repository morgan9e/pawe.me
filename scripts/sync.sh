#!/bin/bash
TIMENOW=$(date '+%Y%m%d_%H%M')
BASE_DIR="/srv/mirror"
ALERT=""

option="-rtlHpv --chmod=D0755,F0644 --partial --hard-links --safe-links --stats --delete --delete-after --delay-updates --max-delete=70000"

exclude="--exclude=.*.?????? --exclude='.~tmp~/' --exclude='Packages*' --exclude='Sources*' --exclude='Release*' --exclude='*.links.tar.gz*' --exclude='/other' --exclude='/sources'"

ubuntu="rsync://rsync.archive.ubuntu.com/ubuntu/"
ubuntu_cd="rsync://releases.ubuntu.com/releases/"
ubuntu_cd_old="rsync://old-releases.ubuntu.com/releases/"
debian="rsync://mirrors.xtom.jp/debian/"
debian_cd="rsync://ftp.lanet.kr/debian-cd/"
fedora="rsync://dl.fedoraproject.org/fedora-enchilada/linux/"
epel="rsync://dl.fedoraproject.org/fedora-epel/"
fedora_cd=""
archlinux="rsync://mirror.rackspace.com/archlinux/"
raspbian="rsync://archive.raspbian.org/archive/"
manjaro="rsync://ftp.riken.jp/manjaro/"

DIST_ARR=('archlinux' 'debian' 'debian_cd' 'ubuntu' 'ubuntu_cd' 'ubuntu_cd_old' 'raspbian' 'epel' 'fedora' 'fedora_cd' 'manjaro')

in=0
for di in "${DIST_ARR[@]}"
do 
	if [ "$di" == "$1" ]; then in=1; fi 
done

if [ "$in" -ne 1 ]; then
	echo Not declared;exit;
fi

dist=$1
echo Syncing $1...

LASTLOG=`head -1 ${BASE_DIR}/logs/${dist}.log`

mv ${BASE_DIR}/logs/${dist}.log ${BASE_DIR}/logs/previous/${dist}-${LASTLOG}.log
mv ${BASE_DIR}/logs/${dist}-error.log ${BASE_DIR}/logs/previous/${dist}-error-${LASTLOG}.log

echo ${TIMENOW} >> ${BASE_DIR}/logs/${dist}.log
echo ${TIMENOW} >> ${BASE_DIR}/logs/${dist}-error.log
echo "${TIMENOW}: Mirroring ${dist} from ${!dist} to ${BASE_DIR}/${dist}"
echo "${TIMENOW} STARTED ${dist}" >> ${BASE_DIR}/logs/all.log

if [ "$dist" == "debian" ];
then
	cd ${BASE_DIR}/scripts
	export BASE_DIR=${BASE_DIR}
	./ftpsync
else
	echo "rsync ${option} ${exclude} ${!dist} ${BASE_DIR}/${dist}" >> ${BASE_DIR}/logs/${dist}.log 
	rsync ${option} ${exclude} ${!dist} ${BASE_DIR}/${dist} >> ${BASE_DIR}/logs/${dist}.log 2>> ${BASE_DIR}/logs/${dist}-error.log
fi

if [ $? -ne 0 ];
then
	cd ${ALERT}
	MSG="${dist} failed at ${TIMENOW}"
	if [ -n "$ALERT" ];
	then
		${ALERT}/alert alert "${MSG}"
	fi
	
	echo Sync ${dist} Error
	echo "${TIMENOW} ERROR ${dist}" >> ${BASE_DIR}/logs/all.log
	echo curl -X POST -d 'email=DEVPG.NET' -d "title=${dist}" -d "content=${MSG}" https://one.devpg.net/send
else
	echo Sync ${dist} Success
	if [ `echo ${BASE_DIR}/logs/${dist}-error.log | wc -l` -eq 1 ]; 
	then
		rm ${BASE_DIR}/logs/${dist}-error.log
	fi
	echo "${TIMENOW} DONE ${dist}" >> ${BASE_DIR}/logs/all.log
	cd $BASE_DIR
	echo "Updating Index"
	python3 -u ./scripts/index.py ${BASE_DIR}
fi
