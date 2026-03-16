#!/bin/bash
set -euo pipefail

BASE="/data/rasp"
MANIFEST="$BASE/latest/manifest.json"

python3 << 'PYEOF'
import json, os, pathlib, datetime, re

base = pathlib.Path("/data/rasp/latest")
manifest = {}

for model_dir in sorted(base.iterdir()):
    if not model_dir.is_dir() or model_dir.name in ("scripts",):
        continue
    model = model_dir.name
    dates = []
    run_id = None
    for entry in sorted(model_dir.iterdir()):
        name = entry.name
        if len(name) == 8 and name.isdigit():
            dates.append(name)
            if entry.is_symlink():
                target = os.readlink(str(entry))
                parts = target.split("/")
                for p in parts:
                    # Match run_id pattern: YYYYMMDDTHHZ
                    if re.match(r"^\d{8}T\d{2}Z$", p):
                        run_id = p
                if run_id is None:
                    # Bridge symlinks: /tmp/results/YYYYMMDD_HHMM_REGION_DAY/OUT
                    for p in parts:
                        m = re.match(r"^(\d{8})_(\d{2})\d{2}_(NL4KM\w+)_\d+$", p)
                        if m:
                            run_id = f"{m.group(1)}T{m.group(2)}Z"
    if dates:
        manifest[model] = {
            "dates": dates,
            "run": run_id,
            "updated": datetime.datetime.now(datetime.UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        }

with open("/data/rasp/latest/manifest.json", "w") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")

print(f"Manifest updated: {list(manifest.keys())}")
PYEOF
