#!/bin/bash
export offset=6
export uploadXblFiles="true"
areas="nl1km1"

echo "Running NL1KM image $(date)"
cd $(dirname "${0}")
cd ..
mkdir -p /tmp/OUT && mkdir -p /tmp/LOG

#use the .env file to upload to blipmaps.nl ...

for area in ${areas} ; do
    /usr/local/bin/docker-compose -f docker-compose.yml run ${area}
    /usr/local/bin/docker-compose rm -fv
done

