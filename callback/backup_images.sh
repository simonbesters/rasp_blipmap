#!/bin/bash

. ./parse_directory.sh ${1}

# Goals is to upload all data to a local NAS
if [ ! -z "${backupUrl}" ] ; then
    echo "Backing up images and data to ${backupUrl}"
    
    #Upload files
    echo "uploading images to ${backupUrl} for ${region}"
    scp -q -i /run/secrets/host_ssh_key ${dataDirectory}/* ${backupUrl}
else
    echo "NOT backing up data, backupRul not set"
fi
