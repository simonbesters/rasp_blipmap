#!/bin/bash

. ./rasp.site.runenvironment

########################################################
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

########################################################
# cleanup of images that may be mounted
echo "Removing previous images so current run cannot be contaminated"
rm -rf /root/rasp/${region}/OUT/*.data
rm -rf /root/rasp/${region}/OUT/*.png
rm -rf /root/rasp/${region}/wrfout_d0*

########################################################
#Generate the region
startDate=$(date +%Y%m%d);
startTime=$(date +%H%M);
startDateTime=$(date);

echo "Running runGM on area ${region}, startDay = ${START_DAY} and hour offset = ${OFFSET_HOUR}"
runGM ${region}

########################################################
#Generate the meteogram images
if [ "${region}" == "NETHERLANDS" ] ; then
    echo "Running meteogram on $(date)"
    cp bin/logo.png ${region}/OUT/logo.png
    ncl bin/meteogram.ncl DOMAIN=\"${region}\" SITEDATA=\"/root/rasp/bin/sitedata.ncl\"
fi
# TODO: rename files in order to correct winter time / summer time ?

########################################################
# Move images for later processing (moving, transforming, ... anything not RASP related)
targetDir="/root/rasp/${region}/OUT/${startDate}/${startTime}/${region}/${START_DAY}"
mkdir -p ${targetDir}
chmod -R uga+rwX /root/rasp/${region}/OUT/*

mv /root/rasp/${region}/OUT/*.data ${targetDir}
mv /root/rasp/${region}/OUT/*.png ${targetDir}
mv /root/rasp/${region}/wrfout_d02_* ${targetDir}
chmod 666 ${targetDir}/*
chmod 666 /root/rasp/${region}/LOG/GM.printout

# signal I'm done:
mv /root/rasp/${region}/LOG/GM.printout ${targetDir}

########################################################
# Move log files for further analysis
mv /root/rasp/${region}/wrf.out /root/rasp/${region}/LOG/
mv /root/rasp/${region}/metgrid.log /root/rasp/${region}/LOG/
mv /root/rasp/${region}/ungrib.log /root/rasp/${region}/LOG/

echo "Started running rasp at ${startDate} ${startTime}, ended at $(date)";
