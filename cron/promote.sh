#!/bin/bash
# Usage: promote.sh <model> <run_id>
# Example: promote.sh gfs 20260313T00Z
#          promote.sh icon-d2 20260313T03Z
set -euo pipefail

MODEL="$1"
RUN_ID="$2"
BASE="/data/rasp"
RUN_DIR="$BASE/$MODEL/$RUN_ID"

if [ ! -d "$RUN_DIR" ]; then
    echo "ERROR: Run directory not found: $RUN_DIR"
    exit 1
fi

LATEST_DIR="$BASE/latest/$MODEL"
mkdir -p "$LATEST_DIR"

count=0
for FORECAST_DIR in "$RUN_DIR"/*/; do
    [ -d "$FORECAST_DIR" ] || continue
    FORECAST_DATE=$(basename "$FORECAST_DIR")

    # Validate forecast_date is YYYYMMDD
    [[ "$FORECAST_DATE" =~ ^[0-9]{8}$ ]] || continue

    LATEST_LINK="$LATEST_DIR/$FORECAST_DATE"

    # Atomic symlink swap
    ln -sfn "../../$MODEL/$RUN_ID/$FORECAST_DATE" "${LATEST_LINK}.tmp"
    mv -Tf "${LATEST_LINK}.tmp" "$LATEST_LINK"

    logger -t rasp-promote "$MODEL $FORECAST_DATE -> $RUN_ID"
    count=$((count + 1))
done

# Update manifest
"$BASE/scripts/update_manifest.sh"

echo "Promoted $MODEL $RUN_ID ($count forecast dates)"
