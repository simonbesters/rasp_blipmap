#!/bin/bash
# Remove old result directories, keeping those currently symlinked by RASPViewer
# Called after update-symlinks.sh in cron scripts

VIEWER_DIR="/root/RASPViewer"
RESULTS_DIR="/tmp/results"

# Collect all symlink targets (resolve to real paths)
declare -A keep
for link in "${VIEWER_DIR}"/NL+*; do
    [ -L "$link" ] || continue
    # Symlink points to .../OUT, we want the parent dir
    target=$(readlink -f "$link" 2>/dev/null)
    parent=$(dirname "$target")
    if [ -d "$parent" ]; then
        keep["$parent"]=1
    fi
done

# Skip dirs used by running containers
for cid in $(docker ps -q 2>/dev/null); do
    prefix=$(docker inspect "$cid" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep ^RUN_PREFIX= | cut -d= -f2)
    if [ -n "$prefix" ] && [ -d "${RESULTS_DIR}/${prefix}" ]; then
        keep["${RESULTS_DIR}/${prefix}"]=1
    fi
done

# Remove result dirs that are not symlinked and not in use by running containers
removed=0
freed=0
for dir in "${RESULTS_DIR}"/*/; do
    dir="${dir%/}"  # strip trailing slash
    [ -d "$dir" ] || continue
    if [ -z "${keep[$dir]}" ]; then
        size=$(du -sm "$dir" 2>/dev/null | cut -f1)
        echo "Removing: $(basename "$dir") (${size}MB)"
        rm -rf "$dir"
        removed=$((removed + 1))
        freed=$((freed + size))
    else
        echo "Keeping:  $(basename "$dir") (symlinked)"
    fi
done

echo "Cleaned up ${removed} directories, freed ~${freed}MB"
