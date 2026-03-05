#!/bin/bash

# If you call docker run with a target url, e.g. like the one below, it wil upload them in a subdirectory of this location
#targetUrl="user@host:/home/user/domains/domainname/public_html/images/"

########################################################
#Upload images
if [ ! -z "${targetUrl}" ] ; then
    
    # see if we need to offset START_DAY (because calculations took us over the day):
    # ensure "date" is a date and does not contain time!!
    currentDate=$(date +"%Y%m%d")
    offset=$(( ($(date --date="${currentDate}" +%s) - $(date --date="${startDate}" +%s) )/(60*60*24) ))
    if [ ${offset} -le ${START_DAY}  ] ; then
	ACTUAL_START_DAY=$(( ${START_DAY} - ${offset} ));
    fi
    finalTargetUrl="${targetUrl}/${region}/NL+${ACTUAL_START_DAY}"

    #Upload files
    echo "uploading images to ${finalTargetUrl} for ${region}"
    scp -q -i /run/secrets/host_ssh_key ${dataDirectory}/OUT/* ${finalTargetUrl}

    # Create file to let the server know I'm done (so it can unpack the gz file for XBL)
    echo "Transferred files at $(date)" > ${dataDirectory}/LOG/xfer.log
    scp -q -i /run/secrets/host_ssh_key ${dataDirectory}/LOG/xfer.log ${finalTargetUrl}
else
    echo "NOT uploading, targetUrl not set"
fi
