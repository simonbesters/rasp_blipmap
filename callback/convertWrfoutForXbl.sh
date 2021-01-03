#!/bin/bash

cd ${dataDirectory}

# convert wrf files (lower number of parameters) with ncks
echo "converting wrf files: removing unnecessary parameters for XBL ($(date))"
mkdir tmp
find ./ \
     -maxdepth 1 \
     -type f \
     -name "wrfout_d02_??????????_*" \
     -exec ncks -v PH,PHB,XLAT,XLONG,HGT,U,V,P,PB,T,QVAPOR,W,QCLOUD {} tmp/{} \;
rm wrfout_d02*
mv tmp/wrfout_d02* . 
rmdir tmp

echo "converting wrf files: zipping files for XBL ($(date))"
find ./ \
     -maxdepth 1 \
     -type f \
     -name "wrfout_d02_??????????_*" \
     -exec pigz --best {} \;

echo "converting wrf files: done ($(date))"
