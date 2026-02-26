#!/bin/bash

files=("geog1.tar.xz" "geog2.tar.xz" "rangs.tgz")

BASE_URL="https://docker.blipmaps.nl/downloads"

for f in "${files[@]}" ; do
    echo "Downloading ${BASE_URL}/${f}"
    wget ${BASE_URL}/"${f}" ./rasp/"${f}"
done
