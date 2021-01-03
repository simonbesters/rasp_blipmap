#!/bin/bash

params=("bltopvariab" "bltopwind" "blwind" "blwindshear" "cape" "experimental1" "hbl" "hglider" "press540" "press616" "press701" "press795" "press846" "press899" "press955" "rain1" "sfcdewpt" "sfcsunpct" "sfctemp" "sfcwind0" "sounding1" "sounding10" "sounding11" "sounding12" "sounding13" "sounding14" "sounding15" "sounding18" "sounding2" "sounding23" "sounding3" "sounding4" "sounding5" "sounding6" "sounding7" "sounding8" "sounding9" "wblmaxmin" "wrf=CFRACH" "wrf=CFRACL" "wrf=CFRACM" "wstar" "bsratio" "zblclmask" "zsfclclmask" "zwblmaxmin");

paramsConvertable=("bltopvariab" "bltopwind" "blwind" "blwindshear" "cape" "experimental1" "hbl" "hglider" "press540" "press616" "press701" "press795" "press846" "press899" "press955" "rain1" "sfcdewpt" "sfcsunpct" "sfctemp" "sfcwind0" "wblmaxmin" "wrf=CFRACH" "wrf=CFRACL" "wrf=CFRACM" "wstar" "bsratio" "zblclmask" "zsfclclmask" "zwblmaxmin");

times=("0830" "0900" "0930" "1000" "1030" "1100" "1130" "1200" "1230" "1300" "1330" "1400" "1430" "1500" "1530" "1600" "1630" "1700" "1730" "1800" "1830" );

usage="$0 <source region> - converts images in /rasp/root/<source region>/OUT> to animated gifs"

parallel=$(lscpu | grep '^CPU(s):' | awk '{print $2}')

if [ $# -ne 1 ] ; then
    echo "ERROR - not enough arguments";
    echo $usage;
    exit 0;
fi

cd ${dataDirectory}

echo "Stitching images to one"
startDate=$(date);
for p in ${paramsConvertable[@]} ; do
    echo "param = $p"
    for t in ${times[@]} ; do
	outputfile="${p}.curr.${t}lst.d2.png"
	hfile="${p}.curr.${t}lst.d2.head.png"
	bfile="${p}.curr.${t}lst.d2.body.png"
	ffile="${p}.curr.${t}lst.d2.foot.png"
	((i=i%parallel)); ((i++==0)) && wait
	if [ -f ${hfile} -a -f ${bfile} -a -f ${ffile} ] ; then
	    convert $hfile $bfile $ffile -append $outputfile &
	else
	    echo "Not converting ${outputfile}. Missing input file(s)"
	fi
    done
done
echo "waiting for processes to finish" 
wait
convert pfd_tot.head.png pfd_tot.body.png pfd_tot.foot.png -append pfd_tot.png

echo "proceeding to creating animated gif" 
for p in ${params[@]} ; do
    ((i=i%parallel)); ((i++==0)) && wait
    convert -delay 100 -loop 0 ${p}.curr.*.d2.png ${p}.curr.loop.d2.gif &
done
echo "waiting for processes to finish" 
wait
echo "Started converting images at ${startDate}, ended at $(date)"
