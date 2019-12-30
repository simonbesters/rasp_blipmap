# blipmaps.nl

This project is to manage and develop the weather forecasts on https://blipmaps.nl which are done using RASP

Howto run a forecast:

Clone/download files to the repository:
```
git clone https://gitlab.com/DavidRasp/blipmaps.nl.git
cd blipmaps.nl
./download_binaries.sh
```
Build image and create two directories to see the results:
```
docker-compose -f docker-compose.yml build netherlands0  #only need to do this once
mkdir /tmp/OUT && mkdir /tmp/LOG
```

Run e.g. Netherlands today (see netherlands0 in docker-compose file):
```
docker-compose -f docker-compose.yml run netherlands0
```

After that, 
- You can find the images in the /tmp/OUT folder
- The images can be served by https://github.com/dingetje/RASPViewer:
  - The corners.js file must be adjusted to match the logfiles which are named ncl.out.02.xxx
  - Ensure you adjust the server name in index.html
- If you make a .env file, and add a line "targetUrl=user@host:/home/user/domain/public_html/images", the script will upload the images there (in a subdirectory ./${region}.N)

Some things to do:
Goals:
  - Split binaries / files which are never adjusted and put them on docker.blipmaps.nl
    - Put config files in Gitlab 
  - Create OSM sync script (download OSM & put that on docker.blipmaps.nl)
  - Webserver should have region defined in subdirectories
  
Extra goals:
  - Have dinner together
  - Add XCSoar support
  - Get XBL plots working
    - XBL: Ensure the NCL scripts are copied / stripped of superfluous data
