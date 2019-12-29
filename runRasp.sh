#!/bin/bash

########################################################3
# check parameters
usage="$0 <region> - will execute runGM on region, convert files that can be used in classic environment and upload them"
if [ $# -ne 1 ] ; then
    echo "ERROR: require region to run, not no/too many arguments provided"
    echo $usage;
    exit 1;
fi
region=${1}
if [ -z "${START_DAY}" ] ; then
    START_DAY=0;
fi

# If you call docker run with a target url, e.g. like the one below, it wil upload them in a subdirectory of this location
#targetUrl="user@host:/home/user/domains/domainname/public_html/images/"

startDate=$(date);

########################################################3
# cleanup of images that may be mounted
echo "Removing previous images so current run is not contaminated"
rm -rf /root/rasp/${region}/OUT/*
rm -rf /root/rasp/${region}/wrfout_d0*

########################################################3
#Generate the region
echo "Running runGM on area ${region}, startDay = ${START_DAY} and hour offset = ${OFFSET_HOUR}"
runGM ${region}

########################################################3
#convert images
# NOTE: This is only necessary if you want single images with everything stitched together AND animated gifs of that
convertImages.sh ${region}

########################################################3
#Upload images
if [ ! -z "${targetUrl}" ] ; then
    finalTargetUrl="${targetUrl}/${region}.${START_DAY}"

    #Upload files
    echo "uploading images to ${finalTargetUrl} for ${region}"
    scp -q -C -i /run/secrets/host_ssh_key /root/rasp/${region}/OUT/*.data ${finalTargetUrl}
    scp -q -C -i /run/secrets/host_ssh_key /root/rasp/${region}/OUT/*.png ${finalTargetUrl}
    scp -q -C -i /run/secrets/host_ssh_key /root/rasp/${region}/OUT/*.gif ${finalTargetUrl}

    if [ ! -z "${uploadXblFiles}" ] ; then
	echo "uploading wrfout files for XBL"
	scp -q -C -i /run/secrets/host_ssh_key /root/rasp/${region}/wrfout_d02* ${finalTargetUrl}
    fi
else
    echo "NOT uploading, targetUrl not set"
fi

echo "Started running rasp at ${startDate}, ended at $(date)";
