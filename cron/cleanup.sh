#\!/bin/bash
# Remove old run directories from /data/rasp/, keeping recent ones.
# Cron: 0 4 * * * /data/rasp/scripts/cleanup.sh
set -euo pipefail

BASE="/data/rasp"
KEEP_DAYS="${1:-3}"

for MODEL in gfs icon-eu icon-d2; do
    MODEL_DIR="$BASE/$MODEL"
    [ -d "$MODEL_DIR" ] || continue

    find "$MODEL_DIR" -maxdepth 1 -mindepth 1 -type d \
        -name "????????T??Z" \
        -mtime +"$KEEP_DAYS" \
        -exec rm -rf {} +
done

# Clean stale symlinks in latest/
find "$BASE/latest" -type l \! -exec test -e {} \; -delete

# Rebuild manifest after cleanup
"$BASE/scripts/update_manifest.sh"

logger -t rasp-cleanup "Cleaned runs older than $KEEP_DAYS days"
