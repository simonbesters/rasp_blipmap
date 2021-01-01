#!/bin/bash

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
ncl ${BASEDIR}/bin/meteogram.ncl DOMAIN=\"${region}\"

########################################################
# Move images for later processing (moving, transforming, ... anything not RASP related)
targetDir="/root/rasp/${region}/OUT/${startDate}/${startTime}/${region}/${START_DAY}"
mkdir -p ${targetDir}
mv /root/rasp/${region}/OUT/*.data ${targetDir}
mv /root/rasp/${region}/OUT/*.png ${targetDir}
mv /root/rasp/${region}/wrfout_d02_* ${targetDir}
mv /root/rasp/${region}/LOG/GM.printout ${targetDir}

echo "Started running rasp at ${startDate} ${startTime}, ended at $(date)";
