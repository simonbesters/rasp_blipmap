#!/bin/bash

# This script creates variables from the directory name

# E.g. from the directory /foo/bar/20210112/1745/NETHERLANDS/0/ it creates the variables
#
# basedirectory="/foo/bar"
# startDate="20210112"
# startTime="1745"
# region="NETHERLANDS"
# START_DAY="0"

# These variables can be used in scripts that do actual work. 

export dataDirectory=${1}

#determine base directory
IFS='/' 
read -ra parts <<< "${1}"
IFS=' '
length=${#parts[@]}
export basedirectory=""
for ((idx=1; idx < $(( ${length} - 4 )) ; idx++)) ; do
    basedirectory="${basedirectory}/${parts[$idx]}"
done

#and the rest
export startDate=${parts[$(( ${length} - 4 ))]}
export startTime=${parts[$(( ${length} - 3 ))]}
export region=${parts[$(( ${length} - 2 ))]}
export START_DAY=${parts[$(( ${length} -1 ))]}

echo "Parsed basedirectory = ${basedirectory}"
# echo "startDate = ${startDate}"
# echo "startTime = ${startTime}"
# echo "region = ${region}"
# echo "START_DAY = ${START_DAY}"
    
