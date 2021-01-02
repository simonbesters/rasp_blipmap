#!/bin/bash

# This script expects the following variables to be set. E.g. with:
# CALLBACK_NETHERLANDS="deleteWrfFiles.sh convertImages.sh upload_images.sh backup_images.sh delete_images.sh"

# Optionally you can set the variables below for the scripts upload_images.sh and backup_images.sh
# targetUrl=
# backupUrl=

callbackDone=callback_done.txt

function processPrintoutFile {
    rundir=${1}
    . ./parse_directory.sh ${rundir}
    # length = 7
    # dataDirectory = /tmp/OUT/20210101/2106/NETHERLANDS/0/
    # basedirectory = /tmp/OUT
    # startDate = 20210101
    # startTime = 2106
    # region = NETHERLANDS
    # START_DAY = 0
    variableName="CALLBACK_${region}"
    eval scripts=\$$variableName
    for st in ${scripts} ; do
	echo "Running script ${st} @ $(date)"
	./${st} ${rundir}
    done
    echo "callback functions called: ${scripts}" > ${rundir}/${callbackDone}
}

dataDir=${1}
while true ; do
    printout=$(find ${dataDir} -type f -name "GM.printout" |head -n 1|sed "s|/[^/]*$||")
    if [ -d "${printout}" -a ! -f ${printout}/${callbackDone} ]; then
	echo "Processing directory ${dataDir} and found file ${printout} @ $(date)"
	processPrintoutFile "${printout}"
    fi
    sleep 10
done
