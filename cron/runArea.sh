#!/bin/bash

function runAreas() {
    for area in ${areas} ; do
	
	if [[ ${area} =~ nl1km?? ]] ; then
	    uploadXblFiles="true";
	else
	    uploadXblFiles="false";
	fi	
	echo "running area ${area} @ $(date), offset = ${offset}, uploadingXblFiles = ${uploadXblFiles}"
	/usr/local/bin/docker-compose -f docker-compose.yml run ${area}
	/usr/local/bin/docker-compose rm -fv
    done
}



