#!/bin/bash

function runAreas() {
    for area in ${areas} ; do
      region=$(echo "${area}" | cut -d "_" -f 1)
      start_day=$(echo "${area}" | cut -d "_" -f 2)

      if [[ ${area} =~ NL1KM?? ]] ; then
          uploadXblFiles="true";
      else
          uploadXblFiles="false";
      fi

      export REGION="${region}"
      export START_DAY="${start_day}"
      # shellcheck disable=SC2154
      export OFFSET_HOUR="${offset}"
      echo "running area ${REGION} @ $(date), start_day = ${START_DAY}, offset = ${OFFSET_HOUR}, uploadingXblFiles = ${uploadXblFiles}"
      docker-compose --env-file ./docker_env --env-file ./docker_env_"${region}" run --remove-orphans rasp
    done
}



