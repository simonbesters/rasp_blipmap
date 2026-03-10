#!/bin/bash
# Update symlinks in RASPViewer to latest results for all 4 forecast systems

VIEWER_DIR="/root/RASPViewer"
RESULTS_DIR="/tmp/results"

# 1. GFS WRF symlinks: NL+0 through NL+4
for day in 0 1 2 3 4; do
    latest=$(ls -dt "${RESULTS_DIR}/"*_NL4KMGFS_${day} 2>/dev/null | head -1)
    if [ -n "$latest" ] && [ -d "$latest/OUT" ]; then
        ln -sfn "$latest/OUT" "${VIEWER_DIR}/NL+${day}"
        echo "NL+${day} -> $latest/OUT"
    fi
done

# 2. ICON-EU WRF symlinks: NL+0-ICON through NL+4-ICON
for day in 0 1 2 3 4; do
    latest=$(ls -dt "${RESULTS_DIR}/"*_NL4KMICON_${day} 2>/dev/null | head -1)
    if [ -n "$latest" ] && [ -d "$latest/OUT" ]; then
        ln -sfn "$latest/OUT" "${VIEWER_DIR}/NL+${day}-ICON"
        echo "NL+${day}-ICON -> $latest/OUT"
    fi
done

# 3. ICON-D2 NCL symlinks: NL+0-ICOND2NCL through NL+1-ICOND2NCL (max 48h forecast)
#    Also matches old prefix NL2KMICOND2 for backwards compatibility
for day in 0 1; do
    latest=$(ls -dt "${RESULTS_DIR}/"*_NL2KMICOND2NCL_${day} "${RESULTS_DIR}/"*_NL2KMICOND2_${day} 2>/dev/null | head -1)
    if [ -n "$latest" ] && [ -d "$latest/OUT" ]; then
        ln -sfn "$latest/OUT" "${VIEWER_DIR}/NL+${day}-ICOND2NCL"
        echo "NL+${day}-ICOND2NCL -> $latest/OUT"
    fi
done

# 4. ICON-D2 Pipeline symlinks: NL+0-ICOND2 through NL+1-ICOND2 (max 48h forecast)
for day in 0 1; do
    latest=$(ls -dt "${RESULTS_DIR}/"*_NL2KMICOND2_${day} 2>/dev/null | head -1)
    if [ -n "$latest" ] && [ -d "$latest/OUT" ]; then
        ln -sfn "$latest/OUT" "${VIEWER_DIR}/NL+${day}-ICOND2"
        echo "NL+${day}-ICOND2 -> $latest/OUT"
    fi
done
