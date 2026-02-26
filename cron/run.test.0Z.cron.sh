#!/bin/bash
echo "starting to run ${0} @ $(date)"
exec 100>/var/tmp/rasp.lock || (echo "could not acquire lock for ${0}" && exit 1)
flock -w 7200 100 || exit 1
echo "lock acquired @ $(date)"
cd $(dirname "${0}")
cd ..
mkdir -p /tmp/OUT && mkdir -p /tmp/LOG

export offset=0;
export uploadXblFiles="false";
export areas="NL4KMGFS_3"

. ./cron/runArea.sh
runAreas



