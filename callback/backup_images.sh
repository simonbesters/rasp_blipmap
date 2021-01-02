#!/bin/bash

. ./parse_directory.sh ${1}

# Goals is to upload all data to a local NAS
if [ ! -z "${backupUrl}" ] ; then
    echo "Backing up images and data to ${backupUrl}"
    
    #Upload files
    echo "uploading images to ${backupUrl} for ${region}"

    rsync -av -e "ssh -i /run/secrets/host_ssh_key" ${basedirectory}/* ${backupUrl}
    #rsync -av -e ssh ${basedirectory}/* ${backupUrl} # used for testing
else
    echo "NOT backing up data, backupRul not set"
fi
