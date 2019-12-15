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
docker run -f Dockerfile TODO: set environment variables such as upload host, keyfile for  etc. 
```

Current know issues:
- not sure where to put the binaries
- cannot download the rasp-gm binaries (gives 404)