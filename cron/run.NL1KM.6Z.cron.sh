#!/bin/bash
export uploadXblFiles="true"

echo "Running NL1KM image $(date)"
cd $(dirname "${0}")
cd ..
mkdir -p /tmp/OUT && mkdir -p /tmp/LOG

#use the .env file to upload to blipmaps.nl ...

export offset=6
areas="nl1km1"
for area in ${areas} ; do
    /usr/local/bin/docker-compose -f docker-compose.yml run ${area}
    /usr/local/bin/docker-compose rm -fv
done

# by the time we are done, fresher data can be gotten.
secondsToWait=$(($(date -f - +%s- <<< $'today 17:45\nnow')0))
if [ ${secondsToWait} -gt 0 ] ; then
    echo "sleeping ${secondsToWait} to be on time"
    sleep ${secondsToWait};
fi

uploadXblFiles="false"
offset=12
areas="netherlands0 netherlands1 netherlands2 netherlands3 netherlands4"
for area in ${areas} ; do
    /usr/local/bin/docker-compose -f docker-compose.yml run ${area}
    /usr/local/bin/docker-compose rm -fv
done

