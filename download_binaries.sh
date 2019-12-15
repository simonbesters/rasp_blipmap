#!/bin/bash

files="rasp.tar.gz stable.tar.gz rangs.tgz geog.tar.gz"
BASE_URL="https://blipmaps.nl/dockerdownloads"

for f in $files ; do
    echo "Downloading ${BASE_URL}/${f}"
    #wget ${BASE_URL}/${f}
done
