#!/bin/bash
export offset=0;

echo "Running NL images $(date)"
cd $(dirname "${0}")


#use the .env file to upload to blipmaps.nl ...

areas="netherlands0 netherlands1 netherlands2 netherlands3 netherlands4"
#areas="nl1km0"

for area in ${areas} ; do
    /usr/local/bin/docker-compose -f docker-compose.yml run ${area}
    /usr/local/bin/docker-compose rm -fv
done

