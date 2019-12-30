#!/bin/bash

cd $(dirname "${0}")
cd ..

echo "this has run at $(date)"
#exit
#use the .env file to upload to blipmaps.nl ...

#areas="netherlands0 netherlands1 netherlands2 netherlands3 netherlands4 nl1km0"
areas="nl1km1"

export offset=6
export uploadXblFiles="true"

for area in ${areas} ; do
    /usr/local/bin/docker-compose -f docker-compose.yml run ${area}
    /usr/local/bin/docker-compose rm -fv
done

