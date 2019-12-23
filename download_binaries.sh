#!/bin/bash

files="\
NETHERLANDS.tar.gz \
NL1KM-1.tar.gz \
NL1KM-2.tar.gz \
rasp-gm-NETHERLANDS.tar.gz \
geog.tar.gz \
geog.fine.tar.gz \
rasp-gm-stable.tar.gz \
rangs.tgz"

BASE_URL="https://docker.blipmaps.nl/downloads"

for f in $files ; do
    echo "Downloading ${BASE_URL}/${f}"
    wget ${BASE_URL}/${f}
done
