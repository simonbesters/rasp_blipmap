#!/bin/bash

function runAreas() {
    local total=${#areas}
    local run_start=$(date '+%Y-%m-%d %H:%M:%S')
    echo "========================================"
    echo "RASP run batch started at ${run_start}"
    echo "Areas: ${areas}"
    echo "Offset: ${offset}"
    echo "========================================"

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

      RUN_PREFIX="$(date '+%Y%m%d')_$(date '+%H%M')_${REGION}_${START_DAY}"
      mkdir -p /tmp/results/"${RUN_PREFIX}"/OUT
      mkdir -p /tmp/results/"${RUN_PREFIX}"/LOG
      echo "RUN_PREFIX=${RUN_PREFIX}" > /tmp/results/${RUN_PREFIX}/run_prefix_env

      local area_start=$(date +%s)
      local area_start_fmt=$(date '+%H:%M:%S')
      echo "----------------------------------------"
      echo "[${area_start_fmt}] START ${area} (region=${REGION}, day=${START_DAY}, offset=${OFFSET_HOUR})"

      docker compose --env-file ./docker_env --env-file ./docker_env_"${REGION}" --env-file /tmp/results/"${RUN_PREFIX}"/run_prefix_env run --remove-orphans rasp
      local exit_code=$?

      local area_end=$(date +%s)
      local area_end_fmt=$(date '+%H:%M:%S')
      local duration=$(( area_end - area_start ))
      local mins=$(( duration / 60 ))
      local secs=$(( duration % 60 ))
      local file_count=$(ls /tmp/results/"${RUN_PREFIX}"/OUT/ 2>/dev/null | wc -l)

      if [ $exit_code -eq 0 ]; then
          echo "[${area_end_fmt}] DONE  ${area} - ${mins}m${secs}s - ${file_count} output files"
      else
          echo "[${area_end_fmt}] FAIL  ${area} - ${mins}m${secs}s - exit code ${exit_code} - ${file_count} output files"
      fi

      # Update symlinks after each area so results are live immediately
      ./cron/update-symlinks.sh
    done

    local batch_end=$(date '+%Y-%m-%d %H:%M:%S')
    local batch_start_epoch=$(date -d "${run_start}" +%s)
    local batch_end_epoch=$(date +%s)
    local batch_duration=$(( batch_end_epoch - batch_start_epoch ))
    local batch_mins=$(( batch_duration / 60 ))
    local batch_secs=$(( batch_duration % 60 ))
    echo "========================================"
    echo "RASP run batch finished at ${batch_end}"
    echo "Total runtime: ${batch_mins}m${batch_secs}s"
    echo "========================================"
}
