#!/bin/bash
# run_icon_d2.sh - ICON-D2 direct pipeline (bypasses WRF)
# Downloads ICON-D2 2.2km data, converts to wrfout format, runs NCL plotting
#
# Usage:
#   run_icon_d2.sh [--date YYYYMMDD] [--run HH] [--hours H1-H2] [--day DAY]
#
# Examples:
#   run_icon_d2.sh                              # today, run 00, hours 6-18, day 0
#   run_icon_d2.sh --day 1                      # tomorrow (hours 30-42 from today's 00Z)
#   run_icon_d2.sh --date 20260310 --hours 6-18 # specific date/hours

set -euo pipefail

# Defaults
RUN_DATE=$(date -u +%Y%m%d)  # model run date
RUN_HOUR=0
HOUR_START=6
HOUR_END=18
START_DAY=0
WORKERS=10

# Docker image (reuse NL4KMGFS for NCL scripts)
DOCKER_IMAGE="blipmaps.nl.docker/blipmaps.nl/rasp/rasp:fedora42_WRFv4.7.1-native_NL4KMGFS"
NCL_REGION="NL4KMGFS"

RESULTS_DIR="/tmp/results"
CACHE_DIR="/tmp/icon-d2-cache"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# NCL parameters (same as NL4KMGFS minus pfd_tot which needs multi-file processing)
NCL_PARAMS="sfctemp:sfcsunpct:hbl:experimental1:hglider:bltopvariab:wstar175:bsratio:sfcwind0:blwind:bltopwind:blwindshear:wblmaxmin:zwblmaxmin:zsfclcldif:zsfclclmask:zblcl:zblcldif:zblclmask:sfcdewpt:cape:rain1:cfracl:cfracm:cfrach:press955:press899:press846:press795:press701:press616:press540:wstar:blcloudpct:wrf=slp:wrf=HGT:pfd_tot:pfd_tot2:pfd_tot3"
NCL_SOUNDINGS="sounding1:sounding2:sounding3:sounding4:sounding5:sounding6:sounding7:sounding8:sounding9:sounding10:sounding11:sounding12:sounding13:sounding14:sounding15:sounding18:sounding23"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --date) RUN_DATE="$2"; shift 2 ;;
        --run) RUN_HOUR="$2"; shift 2 ;;
        --hours) IFS='-' read -r HOUR_START HOUR_END <<< "$2"; shift 2 ;;
        --day) START_DAY="$2"; shift 2 ;;
        --workers) WORKERS="$2"; shift 2 ;;
        --no-soundings) NCL_SOUNDINGS=""; shift ;;
        --no-download) SKIP_DOWNLOAD=1; shift ;;
        --no-convert) SKIP_CONVERT=1; shift ;;
        --no-plot) SKIP_PLOT=1; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# For day > 0, shift forecast hours forward
if [[ $START_DAY -gt 0 ]]; then
    HOUR_START=$((HOUR_START + 24 * START_DAY))
    HOUR_END=$((HOUR_END + 24 * START_DAY))
fi

# ICON-D2 00Z run goes to 48h, check bounds
if [[ $HOUR_END -gt 48 ]]; then
    echo "ERROR: ICON-D2 00Z forecast only goes to 48h, requested hour $HOUR_END"
    echo "  Day 0: hours 6-18, Day 1: hours 30-42, Day 2: not available from single run"
    exit 1
fi

# Setup directories
FORECAST_DATE=$(date -u -d "$RUN_DATE + $START_DAY days" +%Y%m%d)
RUN_PREFIX="${FORECAST_DATE}_NL2KMICOND2NCL_${START_DAY}"
RUN_DIR="$RESULTS_DIR/$RUN_PREFIX"
OUT_DIR="$RUN_DIR/OUT"
LOG_DIR="$RUN_DIR/LOG"
WRFOUT_DIR="$RUN_DIR/wrfout"
DATA_DIR="$CACHE_DIR/${RUN_DATE}_$(printf '%02d' "$RUN_HOUR")"

mkdir -p "$OUT_DIR" "$LOG_DIR" "$WRFOUT_DIR" "$DATA_DIR"

STARTED=$(date +%s)
echo "=== ICON-D2 Pipeline ==="
echo "  Model run: ${RUN_DATE} ${RUN_HOUR}Z"
echo "  Forecast date: $FORECAST_DATE (day +${START_DAY})"
echo "  Hours: ${HOUR_START}-${HOUR_END} ($(( HOUR_END - HOUR_START + 1 )) steps)"
echo "  Data cache: $DATA_DIR"
echo "  Output: $OUT_DIR"
echo "  Log: $LOG_DIR"
echo ""

# Step 1: Download
if [[ -z "${SKIP_DOWNLOAD:-}" ]]; then
    echo "=== Step 1: Download ICON-D2 data ==="
    t0=$(date +%s)
    source "$SCRIPT_DIR/venv/bin/activate"
    python "$SCRIPT_DIR/download_icon_d2.py" \
        --date "$RUN_DATE" --run "$RUN_HOUR" \
        --hours "${HOUR_START}-${HOUR_END}" \
        --outdir "$DATA_DIR" --workers "$WORKERS" \
        2>&1 | tee "$LOG_DIR/download.log"
    t1=$(date +%s)
    echo "  Download took $((t1 - t0))s"
    echo ""
else
    echo "=== Step 1: Download SKIPPED ==="
    source "$SCRIPT_DIR/venv/bin/activate"
fi

# Step 2: Convert to wrfout
if [[ -z "${SKIP_CONVERT:-}" ]]; then
    echo "=== Step 2: Convert to wrfout ==="
    t0=$(date +%s)
    python "$SCRIPT_DIR/icon_d2_to_wrfout.py" \
        --datadir "$DATA_DIR" --outdir "$WRFOUT_DIR" \
        --date "$RUN_DATE" --run "$RUN_HOUR" \
        --hours "${HOUR_START}-${HOUR_END}" \
        2>&1 | tee "$LOG_DIR/convert.log"
    deactivate
    t1=$(date +%s)
    echo "  Conversion took $((t1 - t0))s"
    echo ""
else
    echo "=== Step 2: Convert SKIPPED ==="
    deactivate 2>/dev/null || true
fi

# Step 3: NCL plotting
if [[ -z "${SKIP_PLOT:-}" ]]; then
    echo "=== Step 3: NCL plotting ==="
    NFILES=$(ls "$WRFOUT_DIR"/wrfout_d02_* 2>/dev/null | wc -l)
    if [[ $NFILES -eq 0 ]]; then
        echo "ERROR: No wrfout files found in $WRFOUT_DIR"
        exit 1
    fi
    echo "  Processing $NFILES wrfout files"

    # Build full parameter list
    PARAMS="$NCL_PARAMS"
    if [[ -n "$NCL_SOUNDINGS" ]]; then
        PARAMS="${PARAMS}:${NCL_SOUNDINGS}"
    fi

    t0=$(date +%s)
    docker run --rm \
        -v "$WRFOUT_DIR:/tmp/wrfdata:ro" \
        -v "$OUT_DIR:/root/rasp/${NCL_REGION}/OUT" \
        -e "ENV_NCL_REGIONNAME=${NCL_REGION}" \
        -e "ENV_NCL_OUTDIR=/root/rasp/${NCL_REGION}/OUT" \
        -e "ENV_NCL_PARAMS=${PARAMS}" \
        -e BASEDIR=/root/rasp \
        -e GMIMAGESIZE=1600 \
        -e PROJECTION=mercator \
        "$DOCKER_IMAGE" \
        bash -c "
            source /root/rasp/${NCL_REGION}/rasp.site.runenvironment
            # Symlink wrfout files into region dir so NCL finds them via ls
            for f in /tmp/wrfdata/wrfout_d02_*; do
                ln -s \"\$f\" /root/rasp/${NCL_REGION}/
            done
            cd /root/rasp/GM && ncl -n -p < wrf2gm.ncl
        " 2>&1 | tee "$LOG_DIR/ncl.log"
    t1=$(date +%s)
    echo "  NCL plotting took $((t1 - t0))s"
    echo ""
else
    echo "=== Step 3: NCL plotting SKIPPED ==="
fi

# Summary
ENDED=$(date +%s)
NPNG=$(ls "$OUT_DIR"/*.png 2>/dev/null | wc -l)
echo "=== Done ==="
echo "  Total time: $((ENDED - STARTED))s"
echo "  Output: $OUT_DIR"
echo "  Images: $NPNG PNG files"
echo "  Wrfout: $(ls "$WRFOUT_DIR"/wrfout_d02_* 2>/dev/null | wc -l) files"
