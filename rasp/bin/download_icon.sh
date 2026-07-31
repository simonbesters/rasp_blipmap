#!/bin/bash

#Split comma-delimited arguments
IFS=',' read -ra args <<< "$1"

targetfile="${args[0]}"
ifile="${args[1]}"
GRIBFTPSTDOUT="${args[2]}"
GRIBFTPSTDERR="${args[3]}"
outdir="${args[4]}"
printoutfilename="${args[5]}"

STDOUTFILE="${GRIBFTPSTDOUT}.${ifile}"
STDERRFILE="${GRIBFTPSTDERR}.${ifile}"

process() {
	(curl --retry 10 --fail-with-body -sS --write-out "%output{>>${STDOUTFILE}}%{url}\n%{http_code}, %{size_download} bytes in %{time_total} seconds (%{speed_download} bytes per second).\n" "$1" | bzcat >> "${outdir}/${targetfile}") 2>> "${STDERRFILE}"
}

logprintout() {
	echo "$1" >> "$printoutfilename"
}

logstdout() {
	echo "$1" >> "${STDOUTFILE}"
}

truncate -s0 "${outdir}/${targetfile}"
truncate -s0 "${STDOUTFILE}"
truncate -s0 "${STDERRFILE}"

RUN_DATE="$(date -u +%Y%m%d)"

regex="t([0-9][0-9])z.f([0-9][0-9][0-9])"
if [[ $targetfile =~ $regex ]]; then
	INIT_HOUR="${BASH_REMATCH[1]}"
	FCST_HOUR="${BASH_REMATCH[2]}"
else
	logprintout "ERROR: wrong targetfile format"
	exit 1
fi

mkdir -p "${outdir}"

logprintout "Start download_icon.sh with RUN_DATE=${RUN_DATE} INIT_HOUR=${INIT_HOUR} FCST_HOUR=${FCST_HOUR} STDOUTFILE=${STDOUTFILE} STDERRFILE=${STDERRFILE} outdir=${outdir} targetfile=${targetfile}"

logstdout "Doing model-level fields"
for VARIABLE in "T" "QV" "P" "U" "V"; do
	logstdout "VARIABLE: $VARIABLE"
	variable="$(echo $VARIABLE | tr '[:upper:]' '[:lower:]')"
	for LEVEL in {1..74}; do # ICON-EU has 74 model levels
		process https://opendata.dwd.de/weather/nwp/icon-eu/grib/"${INIT_HOUR}"/"${variable}"/icon-eu_europe_regular-lat-lon_model-level_"${RUN_DATE}""${INIT_HOUR}"_"${FCST_HOUR}"_"${LEVEL}"_${VARIABLE}.grib2.bz2
	done
done

logstdout "Doing single-level fields"
for VARIABLE in "T_2M" "RELHUM_2M" "QV_2M" "PS" "PMSL" "U_10M" "V_10M" "H_SNOW" "W_SNOW" "T_G"; do
	logstdout "VARIABLE: $VARIABLE"
	variable="$(echo $VARIABLE | tr '[:upper:]' '[:lower:]')"
	process https://opendata.dwd.de/weather/nwp/icon-eu/grib/"${INIT_HOUR}"/"${variable}"/icon-eu_europe_regular-lat-lon_single-level_"${RUN_DATE}""${INIT_HOUR}"_"${FCST_HOUR}"_${VARIABLE}.grib2.bz2
done

logstdout "Doing time-invariant single-level fields"
for VARIABLE in "FR_LAND" "HSURF"; do
	logstdout "VARIABLE: $VARIABLE"
	variable="$(echo $VARIABLE | tr '[:upper:]' '[:lower:]')"
	process https://opendata.dwd.de/weather/nwp/icon-eu/grib/"${INIT_HOUR}"/"${variable}"/icon-eu_europe_regular-lat-lon_time-invariant_"${RUN_DATE}""${INIT_HOUR}"_${VARIABLE}.grib2.bz2
done

logstdout "Doing time-invariant model-level fields"
for VARIABLE in "HHL"; do
	logstdout "VARIABLE: $VARIABLE"
	variable="$(echo $VARIABLE | tr '[:upper:]' '[:lower:]')"
	for LEVEL in {1..74}; do # ICON-EU has 74 model levels
		process https://opendata.dwd.de/weather/nwp/icon-eu/grib/"${INIT_HOUR}"/"${variable}"/icon-eu_europe_regular-lat-lon_time-invariant_"${RUN_DATE}""${INIT_HOUR}"_"${LEVEL}"_${VARIABLE}.grib2.bz2
	done
done

logstdout "Doing soil temperature"
for VARIABLE in "T_SO"; do
	logstdout "VARIABLE: $VARIABLE"
	variable="$(echo $VARIABLE | tr '[:upper:]' '[:lower:]')"
	for LEVEL in 5 2 6 18 54 162 486; do # See Vtable.ICONm for soil temperature levels
		process https://opendata.dwd.de/weather/nwp/icon-eu/grib/"${INIT_HOUR}"/"${variable}"/icon-eu_europe_regular-lat-lon_soil-level_"${RUN_DATE}""${INIT_HOUR}"_"${FCST_HOUR}"_${LEVEL}_${VARIABLE}.grib2.bz2
	done
done

logstdout "Doing soil water content"
for VARIABLE in "W_SO"; do
	logstdout "VARIABLE: $VARIABLE"
	variable="$(echo $VARIABLE | tr '[:upper:]' '[:lower:]')"
	for LEVEL in 0 1 3 9 27 81 243 729; do # See Vtable.ICONm for soil water content levels
		process https://opendata.dwd.de/weather/nwp/icon-eu/grib/"${INIT_HOUR}"/"${variable}"/icon-eu_europe_regular-lat-lon_soil-level_"${RUN_DATE}""${INIT_HOUR}"_"${FCST_HOUR}"_${LEVEL}_${VARIABLE}.grib2.bz2
	done
done

# DWD switched ICON-EU opendata to CCSDS/AEC compression (GRIB2 data template
# 5.42) around 2026-06-17. WPS ungrib's bundled g2lib cannot unpack that
# (gf_getfld error 12 -> empty UNGRIB files -> metgrid "TT not found").
# Repack the concatenated file to grid_simple so ungrib can read it again.
logstdout "Repacking to grid_simple for WPS ungrib (DWD CCSDS since 2026-06-17)"
if command -v grib_set >/dev/null 2>&1; then
	if grib_set -r -s packingType=grid_simple "${outdir}/${targetfile}" "${outdir}/${targetfile}.simple" 2>> "${STDERRFILE}"; then
		mv -f "${outdir}/${targetfile}.simple" "${outdir}/${targetfile}"
	else
		logprintout "WARNING: grib_set repack failed; leaving ${targetfile} as downloaded (ungrib will likely extract 0 fields)"
		rm -f "${outdir}/${targetfile}.simple"
	fi
else
	logprintout "WARNING: grib_set not found in image; ungrib cannot unpack CCSDS records"
fi
