# blipmaps.nl

This project is to manage and develop the weather forecasts on https://blipmaps.nl which are done via RASP

Howto run a forecast:

Clone/download files to the repository:
```
git clone git@gitlab.com:DavidRasp/blipmaps.nl.git
cd blipmaps.nl
./download_binaries.sh
```

Create ssh keys for uploading results to webserver:
```
./create_ssh_keys.sh
```

Run:
```
docker-compose docker-compose.yml
```

After that, the images can be served by https://github.com/dingetje/RASPViewer

Goals:
  - Ensure that everyone can have a running local setup in a few minutes, including webserver (good setup instructions)
  - Put binary files / non-used config files in docker.blipmaps.nl
    - Create OSM sync script (download OSM & put that on docker.blipmaps.nl)
  - Put config files in Gitlab 
  - Webserver should have region defined in subdirectories
  - Ensure the NCL scripts are copied / stripped of superfluous data
  
Extra goals:
  - Have dinner together

