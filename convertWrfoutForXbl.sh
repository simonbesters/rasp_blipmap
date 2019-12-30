#!/bin/bash
region=${1}
cd /root/rasp/${region}

# convert wrf files (lower number of parameters) with ncks
find ./ \
     -maxdepth 1 \
     -type f \
     -name "wrfout_d02_??????????_1[2345]*" \
     -exec ncks -v CLDFRA,PH,PHB,XLAT,XLONG,HGT,U,V,P,PB,T,QVAPOR,W,QCLOUD {} OUT/{} \;
