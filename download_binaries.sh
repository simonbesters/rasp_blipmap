#!/bin/bash

files="NETHERLANDS.tar.gz  rasp-gm-NETHERLANDS.tar.gz geog.tar.gz rasp-gm-stable.tar.gz rangs.tgz"
BASE_URL="https://docker.blipmaps.nl/downloads"

for f in $files ; do
    echo "Downloading ${BASE_URL}/${f}"
    wget ${BASE_URL}/${f}
done
