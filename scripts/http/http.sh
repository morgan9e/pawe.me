#!/bin/bash

TIMENOW=$(date '+%Y%m%d_%H%M')
BASE_DIR="/srv/mirror"

DIST_ARR=('archlinuxarm' 'asahilinux')

in=0
for di in "${DIST_ARR[@]}"
do 
	if [ "$di" == "$1" ]; then in=1; fi 
done

if [ "$in" -ne 1 ]; then
	echo Not declared;exit;
fi

dist=$1

echo HTTP Mirroring ${dist} started at ${TIMENOW}.
echo "${TIMENOW} STARTED ${dist}" >> ${BASE_DIR}/logs/all.log
cd $BASE_DIR/scripts/http

echo ${dist} Fetch >> $BASE_DIR/logs/http.log
python3 -u $BASE_DIR/scripts/http/fetchFile.py ${dist} $BASE_DIR/${dist}/ >> $BASE_DIR/logs/${dist}.log 2>&1
echo ${dist} Download >> $BASE_DIR/logs/http.log
python3 -u $BASE_DIR/scripts/http/getFile.py $BASE_DIR/scripts/http/${dist}.fetch >> $BASE_DIR/logs/${dist}.log 2>&1
if [ $? -eq 0 ];
then
	echo Sync ${dist} Success
	echo "${TIMENOW} DONE ${dist}" >> ${BASE_DIR}/logs/all.log
	cd $BASE_DIR
	echo "Updating Index"
	python3 -u ./scripts/index.py ${BASE_DIR}
fi