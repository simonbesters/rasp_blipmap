# Server Changes — blipmaps.nl (pre-rebuild snapshot)

Documented 2026-03-13. These are uncommitted local changes on the server that can be
rolled back. Preserved here so the fixes can be re-applied if needed after the rebuild.

---

## 1. Cron scripts: blank line before update-symlinks

**Files**: `cron/run.0Z.cron.sh`, `cron/run.6Z.cron.sh`, `cron/run.12Z.cron.sh`, `cron/run.18Z.cron.sh`

Cosmetic only — added a blank line before `./cron/update-symlinks.sh` call.

---

## 2. update-symlinks.sh: removed ICON-D2 NCL, renamed ICON-D2 pipeline symlinks

**File**: `cron/update-symlinks.sh`

### Removed
ICON-D2 NCL symlink section (`NL+X-ICOND2NCL`) — the NCL-based ICON-D2 pipeline was
replaced by the Python pipeline, so these symlinks are no longer needed.

```bash
# Was: section 3, scanning for *_NL2KMICOND2NCL_${day} and *_NL2KMICOND2_${day}
# Created symlinks: NL+0-ICOND2NCL, NL+1-ICOND2NCL
```

### Changed
Renamed ICON-D2 Python pipeline symlinks from `NL+X-ICOND2` to `NL+X-ICOND2PY` to
match the viewer's model selector naming.

```bash
# Was:  ln -sfn "$latest/OUT" "${VIEWER_DIR}/NL+${day}-ICOND2"
# Now:  ln -sfn "$latest/OUT" "${VIEWER_DIR}/NL+${day}-ICOND2PY"
```

---

## 3. run_icon_d2.sh: two-pass NCL + reprojection

**File**: `icon-d2/run_icon_d2.sh`

Major rework of the NCL plotting step. Three key changes:

### 3a. Split NCL parameters into two passes

Single `NCL_PARAMS` variable split into `NCL_PARAMS_MAIN` and `NCL_PARAMS_PFD`:

```bash
# Main params (writes .data files):
NCL_PARAMS_MAIN="sfctemp:sfcsunpct:hbl:experimental1:hglider:bltopvariab:wstar175:bsratio:sfcwind0:blwind:bltopwind:blwindshear:wblmaxmin:zwblmaxmin:zsfclcldif:zsfclclmask:zblcl:zblcldif:zblclmask:sfcdewpt:cape:rain1:cfracl:cfracm:cfrach:press955:press899:press846:press795:press701:press616:press540:wstar:blcloudpct:wrf=slp:wrf=HGT"

# PFD params (reads .data files from pass 1):
NCL_PARAMS_PFD="pfd_tot:pfd_tot2:pfd_tot3"
```

**Why**: PFD calculation requires `ENV_NCL_FILENAME` to extract the forecast date, but
setting `ENV_NCL_FILENAME` changes how `wrf2gm.ncl` discovers wrfout files (single file
vs all). Pass 1 uses `ENV_NCL_DATIME` to enable `.data` file writing. Pass 2 uses
`ENV_NCL_FILENAME` so `pfd()` in `calc_funcs.ncl` can parse the date and read the
wstar `.data` files.

### 3b. NCL projection patch for correct map alignment

Both NCL passes include an in-container sed patch:

```bash
sed -i 's/opts_bg@mpProjection        = "Mercator"/opts_bg@mpProjection        = "CylindricalEquidistant"/' /root/rasp/GM/plot_funcs.ncl
```

**Why**: NCL's Mercator rendering introduces non-linear distortion that can't be cleanly
georeferenced for GDAL reprojection. CylindricalEquidistant (plate carrée / EPSG:4326)
has a linear lat/lon-to-pixel mapping, making reprojection straightforward.

### 3c. New environment variables added to docker run

```bash
-e "ENV_NCL_DATIME=Day= 0 0 0 X ValidLST= 0 CET ValidZ= 0 Fcst= 0 Init= 0 "  # enables .data file writing
-e "ENV_NCL_INITMODE=ICON-D2"  # header line 3 shows "ICON-D2-initiated"
-e CONVERT=convert             # imagemagick path
```

Pass 2 additionally sets:
```bash
-e "ENV_NCL_FILENAME=/root/rasp/${NCL_REGION}/${LAST_WRFOUT_NAME}"  # date extraction for PFD
```

### 3d. Step 4: EPSG:4326 → EPSG:3857 reprojection

After NCL plotting, a new step warps all `*.body.png` files from plate carrée to Web
Mercator using `reproject_body.py` (see section 4). This corrects the vertical stretch
needed for Leaflet overlay at latitudes above ~50°N.

```bash
docker run --rm \
    -v "$WRFOUT_DIR:/tmp/wrfdata:ro" \
    -v "$OUT_DIR:/tmp/out" \
    -v "$SCRIPT_DIR/reproject_body.py:/tmp/reproject_body.py:ro" \
    "$DOCKER_IMAGE" \
    python3 /tmp/reproject_body.py /tmp/wrfdata /tmp/out
```

---

## 4. reproject_body.py (new file)

**File**: `icon-d2/reproject_body.py`

Python script that runs inside the RASP Docker container (which has GDAL). Steps:

1. Reads lat/lon bounds from the first `wrfout_d02_*` file (XLAT/XLONG variables)
2. For each `*.body.png` in the output directory:
   - Detects non-transparent content bounds (NCL adds transparent padding)
   - Crops to content area
   - Georeferences with EPSG:4326 bounds
   - Warps to EPSG:3857 (Web Mercator) using bilinear resampling
   - Overwrites the original PNG

Dependencies: `numpy`, `osgeo` (GDAL Python bindings) — both available in the RASP
Docker image.

---

## 5. run.icond2py.cron.sh (new file)

**File**: `cron/run.icond2py.cron.sh`

Standalone cron helper for running the ICON-D2 Python pipeline independently of WRF.

```bash
Usage: ./cron/run.icond2py.cron.sh <offset_hour> <start_day> [start_day...]
```

- Uses its own lock file (`/var/tmp/icond2py.lock`) so it doesn't block WRF runs
- Auto-detects CET/CEST timezone offset
- Loops over requested days, calling `/root/icon-d2-pipeline/run.sh` for each
- Calls `update-symlinks.sh` after each day and `cleanup-results.sh` at the end

---

## 6. tasks/ directory (untracked)

Contains `todo.md` tracking ICON-D2 NCL pipeline work items. The open item:

- Per-file NCL invocation with `ENV_NCL_ID` for correct time display in headers
  (currently shows "missing" because all wrfout files are processed in one NCL run
  instead of per-timestep like GM-master.pl does)
