#!/bin/bash

# This script expects the following variables to be set. E.g. with:
# CALLBACK_<region>="deleteWrfFiles.sh convertImages.sh upload_images.sh backup_images.sh delete_images.sh"

# Optionally you can set the variables below for the scripts upload_images.sh and backup_images.sh
# targetUrl=
# backupUrl=

function processPrintoutFile {
    . ./parse_directory.sh ${1}
    # length = 7
    # basedirectory = /tmp/OUT
    # startDate = 20210101
    # startTime = 2106
    # region = NETHERLANDS
    # START_DAY = 0
    
}


while true ; do
    printout=$(find /data -type f -name "GM.printout" |head -n 1|sed "s/[^/]*$//")
    if [ -d "${printout}" ]; then
	processPrintoutFile "${printout}"
    fi
    sleep 10
done
