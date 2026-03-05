#!/bin/bash

# This script expects the following variables to be set. E.g. with:
# CALLBACK_NETHERLANDS="deleteWrfFiles.sh convertImages.sh upload_images.sh delete_images.sh"

# Optionally you can set the variables below for the scripts upload_images.sh
# targetUrl=

callbackDone=callback_done.txt

function processRunDirectory {
    rundir=${1}
    . ./parse_directory.sh ${rundir}
    # length = 7
    # dataDirectory = /tmp/results/OUT/20210101_2106_NL4KMGFS_0
    # basedirectory = /tmp/results/OUT/0210101_2106_NL4KMGFS_0
    # startDate = 20210101
    # startTime = 2106
    # region = NL4KMGFS
    # START_DAY = 0
    variableName="CALLBACK_${region}"
    eval scripts=\$$variableName
    for st in ${scripts} ; do
	echo "Running script ${st} @ $(date)"
	./${st} ${rundir}
    done
    echo "callback functions called: ${scripts}" > ${rundir}/${callbackDone}
    # it may not be there anymore due to scripts removing it
    find ${rundir} -type f -name GM.printout -delete
}

dataDir=${1}
while true ; do
    runDirectory=$(find ${dataDir} -type f -name "GM.printout" |head -n 1|sed "s|/LOG.*$||")
    if [ -d "${runDirectory}/LOG" ] && [ ! -f "${runDirectory}"/LOG/${callbackDone} ]; then
      echo "Processing directory ${dataDir} and found file ${runDirectory} @ $(date)"
	    processRunDirectory "${runDirectory}"
    fi
    sleep 10
done
