#!/usr/bin/env python3
"""
Download ICON-D2 regular-lat-lon data from DWD open data server.
Downloads only the variables needed for RASP/wrfout conversion.

Usage: download_icon_d2.py --date 20260309 --run 00 --hours 6-18 --outdir /tmp/icon-d2-data
"""

import argparse
import bz2
import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests

BASE_URL = "https://opendata.dwd.de/weather/nwp/icon-d2/grib"

# Variables needed for wrfout conversion
# Single-level (2D) variables
SINGLE_LEVEL_VARS = [
    "t_2m",       # T2 - 2m temperature
    "td_2m",      # for Q2 derivation (2m dewpoint)
    "u_10m",      # U10
    "v_10m",      # V10
    "ps",          # PSFC - surface pressure
    "mh",          # PBLH - mixing layer height
    "ashfl_s",     # HFX - sensible heat flux
    "alhfl_s",     # LH - latent heat flux
    "asob_s",      # SWDOWN approximation (net SW, close enough)
    "aswdir_s",    # direct SW radiation
    "aswdifd_s",   # diffuse SW radiation
    "tot_prec",    # RAINC + RAINNC combined
    "clcl",        # low cloud cover
    "clcm",        # mid cloud cover
    "clch",        # high cloud cover
    "cape_ml",     # CAPE
    "pmsl",        # sea level pressure (for slp)
]

# Model-level (3D) variables - all 65 levels
MODEL_LEVEL_VARS = [
    "t",    # temperature -> T (perturbation potential temperature)
    "u",    # u-wind
    "v",    # v-wind
    "w",    # w-wind (vertical velocity)
    "p",    # pressure -> P, PB
    "qv",   # specific humidity -> QVAPOR
    "qc",   # cloud water -> QCLOUD
    "clc",  # cloud fraction -> CLDFRA
    "tke",  # TKE
]

# Time-invariant
TIME_INVARIANT_VARS = [
    "hhl",   # half-level heights (66 levels) - for vertical coordinate
    "hsurf", # terrain height (single level, time-invariant)
]

# Model levels (1=top, 65=surface)
MODEL_LEVELS = list(range(1, 66))
HHL_LEVELS = list(range(1, 67))  # 66 half-levels


def build_url(run_hour, param, date_run, step, level=None, level_type="single-level"):
    """Build download URL for a single ICON-D2 GRIB2 file."""
    step_str = f"{step:03d}"
    if level_type == "single-level":
        fname = f"icon-d2_germany_regular-lat-lon_single-level_{date_run}_{step_str}_2d_{param}.grib2.bz2"
    elif level_type == "model-level":
        fname = f"icon-d2_germany_regular-lat-lon_model-level_{date_run}_{step_str}_{level}_{param}.grib2.bz2"
    elif level_type == "time-invariant":
        fname = f"icon-d2_germany_regular-lat-lon_time-invariant_{date_run}_{step_str}_{level}_{param}.grib2.bz2"
    else:
        raise ValueError(f"Unknown level_type: {level_type}")
    return f"{BASE_URL}/{run_hour:02d}/{param}/{fname}"


def download_file(url, outpath, session):
    """Download and decompress a single bz2 GRIB2 file."""
    if outpath.exists():
        return outpath, True, "cached"

    try:
        resp = session.get(url, timeout=30)
        if resp.status_code == 404:
            return outpath, False, "404"
        resp.raise_for_status()

        # Decompress bz2
        data = bz2.decompress(resp.content)
        outpath.parent.mkdir(parents=True, exist_ok=True)
        outpath.write_bytes(data)
        return outpath, True, f"{len(resp.content)/1024:.0f}KB"
    except Exception as e:
        return outpath, False, str(e)


def download_all(date, run_hour, hour_start, hour_end, outdir, max_workers=10):
    """Download all needed ICON-D2 data for a time range."""
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    date_run = f"{date}{run_hour:02d}"
    steps = list(range(hour_start, hour_end + 1))

    tasks = []

    # Single-level variables (one file per step per variable)
    for step in steps:
        for var in SINGLE_LEVEL_VARS:
            url = build_url(run_hour, var, date_run, step, level_type="single-level")
            outpath = outdir / f"sl_{var}_{step:03d}.grib2"
            tasks.append((url, outpath))

    # Model-level variables (one file per step per level per variable)
    for step in steps:
        for var in MODEL_LEVEL_VARS:
            for level in MODEL_LEVELS:
                url = build_url(run_hour, var, date_run, step, level=level, level_type="model-level")
                outpath = outdir / f"ml_{var}_{step:03d}_L{level:03d}.grib2"
                tasks.append((url, outpath))

    # Time-invariant fields - only step 000
    for level in HHL_LEVELS:
        url = build_url(run_hour, "hhl", date_run, 0, level=level, level_type="time-invariant")
        outpath = outdir / f"ti_hhl_L{level:03d}.grib2"
        tasks.append((url, outpath))
    # hsurf - single level, time-invariant (level=0)
    url = build_url(run_hour, "hsurf", date_run, 0, level=0, level_type="time-invariant")
    outpath = outdir / f"ti_hsurf.grib2"
    tasks.append((url, outpath))

    total = len(tasks)
    print(f"Downloading {total} files ({len(steps)} steps, "
          f"{len(SINGLE_LEVEL_VARS)} SL vars, "
          f"{len(MODEL_LEVEL_VARS)} ML vars x {len(MODEL_LEVELS)} levels, "
          f"{len(HHL_LEVELS)} HHL levels)")

    success = 0
    failed = 0
    cached = 0

    session = requests.Session()
    adapter = requests.adapters.HTTPAdapter(
        pool_connections=max_workers,
        pool_maxsize=max_workers,
        max_retries=3
    )
    session.mount("https://", adapter)

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(download_file, url, outpath, session): (url, outpath)
            for url, outpath in tasks
        }

        for i, future in enumerate(as_completed(futures), 1):
            outpath, ok, msg = future.result()
            if ok:
                if msg == "cached":
                    cached += 1
                else:
                    success += 1
            else:
                failed += 1
                if msg != "404":
                    print(f"  FAIL: {outpath.name}: {msg}")

            if i % 200 == 0 or i == total:
                print(f"  Progress: {i}/{total} "
                      f"(ok={success}, cached={cached}, fail={failed})")

    print(f"\nDone: {success} downloaded, {cached} cached, {failed} failed")
    return failed == 0


def main():
    parser = argparse.ArgumentParser(description="Download ICON-D2 data from DWD")
    parser.add_argument("--date", required=True, help="Date YYYYMMDD")
    parser.add_argument("--run", type=int, default=0, help="Run hour (0,3,6,...)")
    parser.add_argument("--hours", default="6-18",
                        help="Forecast hour range, e.g. 6-18")
    parser.add_argument("--outdir", required=True, help="Output directory")
    parser.add_argument("--workers", type=int, default=10,
                        help="Parallel download threads")
    args = parser.parse_args()

    hour_start, hour_end = map(int, args.hours.split("-"))

    ok = download_all(args.date, args.run, hour_start, hour_end,
                      args.outdir, args.workers)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
