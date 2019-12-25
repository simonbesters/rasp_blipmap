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

# If you call docker run with a target url, e.g. like the one below, it wil upload them in a subdirectory of this location
#targetUrl="user@host:/home/user/domains/domainname/public_html/images/"

startDate=$(date);

########################################################3
#Generate the region
echo "Running runGM on area ${region}"
runGM ${region}

########################################################3
#convert images
# NOTE: This is only necessary if you want single images with everything stitched together AND animated gifs of that
convertImages.sh ${region}

########################################################3
#Upload images
if [ ! -z "${targetUrl}" ] ; then
    #Determine final upload location
    if [ -z "${START_DAY}" ] ; then
	START_DAY=0;
    fi
    finalTargetUrl="${targetUrl}/${region}.${START_DAY}"

    #Upload files
    echo "uploading images to ${finalTargetUrl} for ${region}"
    scp /root/rasp/${region}/OUT/*.data ${finalTargetUrl}
    scp /root/rasp/${region}/OUT/*.png ${finalTargetUrl}
else
    echo "NOT uploading, targetUrl not set"
fi

echo "Started running rasp at ${startDate}, ended at $(date)";
