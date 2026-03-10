#!/bin/bash
# ICON-EU WRF runs - triggered after ICON-EU 0Z data is available (~06 UTC)
echo "starting to run ${0} @ $(date)"
exec 100>/var/tmp/rasp.lock || (echo "could not acquire lock for ${0}" && exit 1)
flock -w 7200 100 || exit 1
echo "lock acquired @ $(date)"
cd "$(dirname "${0}")" || exit
cd ..

export offset=0;
export uploadXblFiles="false";
export areas="NL4KMICON_0 NL4KMICON_1 NL4KMICON_2 NL4KMICON_3 NL4KMICON_4"

. ./cron/runArea.sh
runAreas
./cron/update-symlinks.sh
./cron/cleanup-results.sh
