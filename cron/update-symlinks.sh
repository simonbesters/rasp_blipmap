#\!/bin/bash
# Update symlinks in RASPViewer to latest results for all 4 forecast systems
# Also bridges data to the new /data/rasp/latest/ structure with manifest.json

VIEWER_DIR="/root/RASPViewer"
RESULTS_DIR="/tmp/results"
RASP_BASE="/data/rasp"

# 1. GFS WRF symlinks: NL+0 through NL+4 (legacy)
for day in 0 1 2 3 4; do
    latest=$(ls -dt "${RESULTS_DIR}/"*_NL4KMGFS_${day} 2>/dev/null | head -1)
    if [ -n "$latest" ] && [ -d "$latest/OUT" ]; then
        ln -sfn "$latest/OUT" "${VIEWER_DIR}/NL+${day}"
        echo "NL+${day} -> $latest/OUT"
    fi
done

# 2. ICON-EU WRF symlinks: NL+0-ICON through NL+4-ICON (legacy)
for day in 0 1 2 3 4; do
    latest=$(ls -dt "${RESULTS_DIR}/"*_NL4KMICON_${day} 2>/dev/null | head -1)
    if [ -n "$latest" ] && [ -d "$latest/OUT" ]; then
        ln -sfn "$latest/OUT" "${VIEWER_DIR}/NL+${day}-ICON"
        echo "NL+${day}-ICON -> $latest/OUT"
    fi
done

# 3. ICON-D2 Python pipeline symlinks (legacy compat)
latest_icond2=$(ls -dt "${RASP_BASE}/icon-d2/"????????T??Z 2>/dev/null | head -1)
if [ -n "$latest_icond2" ]; then
    for fdir in "$latest_icond2"/[0-9]*/; do
        [ -d "$fdir" ] || continue
        fdate=$(basename "$fdir")
        # Compute day offset from today
        today_epoch=$(date -d "$(date +%Y-%m-%d)" +%s)
        fdate_epoch=$(date -d "${fdate:0:4}-${fdate:4:2}-${fdate:6:2}" +%s)
        day_offset=$(( (fdate_epoch - today_epoch) / 86400 ))
        if [ "$day_offset" -ge 0 ] && [ "$day_offset" -le 4 ]; then
            ln -sfn "$fdir" "${VIEWER_DIR}/NL+${day_offset}-ICOND2PY"
            echo "NL+${day_offset}-ICOND2PY -> $fdir"
        fi
    done
fi

# --- New structure: bridge to /data/rasp/latest/ ---

# 4. GFS -> /data/rasp/latest/gfs/YYYYMMDD
for day in 0 1 2 3 4; do
    latest=$(ls -dt "${RESULTS_DIR}/"*_NL4KMGFS_${day} 2>/dev/null | head -1)
    if [ -n "$latest" ] && [ -d "$latest/OUT" ]; then
        forecast_date=$(date -d "+${day} days" +%Y%m%d)
        mkdir -p "${RASP_BASE}/latest/gfs"
        ln -sfn "$latest/OUT" "${RASP_BASE}/latest/gfs/${forecast_date}"
    fi
done

# 5. ICON-EU -> /data/rasp/latest/icon-eu/YYYYMMDD
for day in 0 1 2 3 4; do
    latest=$(ls -dt "${RESULTS_DIR}/"*_NL4KMICON_${day} 2>/dev/null | head -1)
    if [ -n "$latest" ] && [ -d "$latest/OUT" ]; then
        forecast_date=$(date -d "+${day} days" +%Y%m%d)
        mkdir -p "${RASP_BASE}/latest/icon-eu"
        ln -sfn "$latest/OUT" "${RASP_BASE}/latest/icon-eu/${forecast_date}"
    fi
done

# 6. ICON-D2 -> /data/rasp/latest/icon-d2/YYYYMMDD (via promote if data in /data/rasp/)
#    Already handled by promote.sh, but ensure stale symlinks are cleaned
if [ -d "${RASP_BASE}/latest/icon-d2" ]; then
    find "${RASP_BASE}/latest/icon-d2" -type l \! -exec test -e {} \; -delete 2>/dev/null || true
fi

# 7. Rebuild manifest.json
"${RASP_BASE}/scripts/update_manifest.sh"
