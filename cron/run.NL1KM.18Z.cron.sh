#!/bin/bash
export uploadXblFiles="true"

echo "Running 18Z cron job on $(date)"
cd $(dirname "${0}")
cd ..
mkdir -p /tmp/OUT && mkdir -p /tmp/LOG

#use the .env file to upload to blipmaps.nl ...

export offset=18
areas="nl1km1"
for area in ${areas} ; do
    echo "running area ${area} on $(date) with offset ${offset}"
    /usr/local/bin/docker-compose -f docker-compose.yml run ${area}
    /usr/local/bin/docker-compose rm -fv
done

# by the time we are done, fresher data can be gotten. But "sleep" if not true:
secondsToWait=$(($(date -f - +%s- <<< $'today 05:45\nnow')0))
if [ ${secondsToWait} -lt -60000 ] ; then
    # it got caught off guard before tomorrow even. Sleep until tomorrow and recalculate.
    echo "sleeping 7200 to cross days"
    sleep 7200;
    secondsToWait=$(($(date -f - +%s- <<< $'today 05:45\nnow')0))
    secondsToWait=20
fi
if [ ${secondsToWait} -gt 0 ] ; then
    echo "sleeping ${secondsToWait} to be on time"
    sleep ${secondsToWait};
fi

offset=0
areas="netherlands0 netherlands1 netherlands2 netherlands3 netherlands4"
for area in ${areas} ; do
    echo "running area ${area} on $(date) with offset ${offset}"
   /usr/local/bin/docker-compose -f docker-compose.yml run ${area}
   /usr/local/bin/docker-compose rm -fv
done

