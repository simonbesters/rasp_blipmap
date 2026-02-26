#!/bin/bash

# check parameters
usage="$0 <region> - execute runGM on <region>, create meteograms and copy results to right location"
if [ $# -ne 1 ] ; then
    echo "ERROR: require one region to run, no/too many arguments provided"
    echo "$usage";
    exit 1;
fi
REGION=$1
if [ -z "${START_DAY}" ] ; then
    START_DAY=0;
fi

regionDir="/root/rasp/${REGION}"
outDir="${regionDir}/OUT"
logDir="${regionDir}/LOG"

. "${regionDir}"/rasp.site.runenvironment

# cleanup of images that may be mounted
echo "Removing previous results so current run is not contaminated"
rm -rf "${outDir:?}"/*
rm -rf "${logDir:?}"/*
rm -rf "${regionDir}"/wrfout_d0*

runDate="$(date +%Y-%m-%d)";
runTime="$(date +%H-%M)";

echo "Running runGM on area ${REGION}, startDay = ${START_DAY} and hour offset = ${OFFSET_HOUR}"
runGM "${REGION}"

#Generate the meteogram images
echo "Running meteogram on $(date)"
cp /root/rasp/logo.png "${regionDir}"/OUT/logo.png
ncl /root/rasp/GM/meteogram.ncl DOMAIN=\""${REGION}"\" SITEDATA=\"/root/rasp/GM/sitedata.ncl\" &> "${logDir}"/meteogram.out

# Generate title JSONs from data files
perl /root/rasp/bin/title2json.pl /root/rasp/"${REGION}"/OUT &> "${logDir}"/title2json.out

# Generate geotiffs from data files
python3 /root/rasp/bin/rasp2geotiff.py /root/rasp/"${REGION}" &> "${logDir}"/rasp2geotiff.out

# Move some additional log files
mv "${regionDir}"/wrf.out "${logDir}"
mv "${regionDir}"/metgrid.log "${logDir}"
mv "${regionDir}"/ungrib.log "${logDir}"
mv "${regionDir}"/wrfout_d02_* "${outDir}"
echo "Started running rasp at ${runDate}_${runTime}, ended at $(date +%Y-%m-%d_%H-%M)"
