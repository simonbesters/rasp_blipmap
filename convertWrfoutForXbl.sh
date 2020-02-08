#!/bin/bash
region=${1}
cd /root/rasp/${region}


# convert wrf files (lower number of parameters) with ncks
echo "converting wrf files: removing unnecessary parameters for XBL ($(date))"
find ./ \
     -maxdepth 1 \
     -type f \
     -name "wrfout_d02_??????????_1*" \
     -exec ncks -v CLDFRA,PH,PHB,XLAT,XLONG,HGT,U,V,P,PB,T,QVAPOR,W,QCLOUD {} OUT/{} \;


echo "converting wrf files: zipping files for XBL ($(date))"
pigz --best
find ./OUT \
     -maxdepth 1 \
     -type f \
     -name "wrfout_d02_??????????_1*" \
     -exec pigz --best {} \;

echo "converting wrf files: done ($(date))"
