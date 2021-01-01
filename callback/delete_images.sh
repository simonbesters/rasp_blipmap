#!/bin/bash

. ./parse_directory.sh ${1}

# This script removes all data from the directory after we are done
rm -rf ${basedirectory}/${startDate}/${startTime}

