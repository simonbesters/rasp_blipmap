#!/usr/bin/env python3
"""
Convert ICON-D2 regular-lat-lon GRIB2 data to WRF-compatible wrfout netCDF files.

This creates "fake" wrfout files that the existing RASP NCL plotting scripts
can process. One wrfout file per timestep.

Usage: icon_d2_to_wrfout.py --datadir /tmp/icon-d2-data --outdir /tmp/results/.../OUT
                             --date 2026-03-09 --run 00 --hours 6-18
"""

import argparse
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path

import cfgrib
import numpy as np
from netCDF4 import Dataset

# ICON-D2 grid: 746 x 1215, 0.02 deg spacing
# We crop to Netherlands region to match the ~4km WRF domain
# WRF domain: lat ~49.6-54.0, lon ~2.0-10.5 (approximate from CEN_LAT/CEN_LON)
# Use slightly generous bounds
NL_LAT_MIN = 49.5
NL_LAT_MAX = 54.5
NL_LON_MIN = 1.5
NL_LON_MAX = 11.0

# WRF constants
P0 = 100000.0  # reference pressure (Pa)
T0 = 300.0     # base state temperature for potential temp perturbation
G = 9.81       # gravity


def read_grib(filepath):
    """Read a single GRIB2 file, return data as numpy array and metadata.
    If multi-step, returns only the first timestep.
    Always returns a 2D array for single-level, or the raw array for model-level.
    """
    ds = cfgrib.open_datasets(str(filepath))
    d = ds[0]
    varnames = [v for v in d.data_vars]
    data = d[varnames[0]].values
    # If 3D (step x lat x lon), take first timestep
    if data.ndim == 3 and "step" in d[varnames[0]].dims:
        data = data[0, :, :]
    return data, d.coords


def get_nl_crop_indices(lats, lons):
    """Get indices to crop ICON-D2 grid to Netherlands region."""
    lat_mask = (lats >= NL_LAT_MIN) & (lats <= NL_LAT_MAX)
    lon_mask = (lons >= NL_LON_MIN) & (lons <= NL_LON_MAX)
    lat_idx = np.where(lat_mask)[0]
    lon_idx = np.where(lon_mask)[0]
    return lat_idx[0], lat_idx[-1] + 1, lon_idx[0], lon_idx[-1] + 1


def load_single_level(datadir, var, step):
    """Load a single-level variable for a given forecast step."""
    path = datadir / f"sl_{var}_{step:03d}.grib2"
    if not path.exists():
        return None
    data, coords = read_grib(path)
    return data


def load_model_level(datadir, var, step, level):
    """Load a model-level variable for a given step and level."""
    path = datadir / f"ml_{var}_{step:03d}_L{level:03d}.grib2"
    if not path.exists():
        return None
    data, coords = read_grib(path)
    return data


def load_hhl(datadir, level):
    """Load HHL (half-level height) for a given level."""
    path = datadir / f"ti_hhl_L{level:03d}.grib2"
    if not path.exists():
        return None
    data, coords = read_grib(path)
    return data


def get_grid_info(datadir):
    """Get lat/lon grid from a sample file."""
    # Use hsurf or t_2m step 0 to get grid
    for var in ["t_2m", "hsurf"]:
        for step in range(0, 49):
            path = datadir / f"sl_{var}_{step:03d}.grib2"
            if path.exists():
                ds = cfgrib.open_datasets(str(path))
                d = ds[0]
                lats = d.coords["latitude"].values
                lons = d.coords["longitude"].values
                return lats, lons
    raise FileNotFoundError("No GRIB files found to determine grid")


def dewpoint_to_mixing_ratio(td, p):
    """Convert dewpoint temperature (K) and pressure (Pa) to mixing ratio (kg/kg)."""
    td_c = td - 273.15
    # Saturation vapor pressure at dewpoint = actual vapor pressure
    e = 611.2 * np.exp(17.67 * td_c / (td_c + 243.5))
    # Mixing ratio
    q = 0.622 * e / (p - e)
    return np.maximum(q, 0.0)


def temperature_to_theta_perturbation(t, p):
    """Convert temperature (K) and pressure (Pa) to potential temperature perturbation.
    WRF T = theta - T0, where theta = T * (P0/p)^(R/cp)
    """
    theta = t * (P0 / p) ** 0.2854
    return theta - T0


# WRF variable metadata (units, description) needed by NCL
WRF_VAR_META = {
    "T2":      ("K", "TEMP at 2 M"),
    "PSFC":    ("Pa", "SFC PRESSURE"),
    "U10":     ("m s-1", "U at 10 M"),
    "V10":     ("m s-1", "V at 10 M"),
    "HGT":     ("m", "Terrain Height"),
    "PBLH":    ("m", "PBL HEIGHT"),
    "HFX":     ("W m-2", "UPWARD HEAT FLUX AT THE SURFACE"),
    "LH":      ("W m-2", "LATENT HEAT FLUX AT THE SURFACE"),
    "SWDOWN":  ("W m-2", "DOWNWARD SHORT WAVE FLUX AT GROUND SURFACE"),
    "Q2":      ("kg kg-1", "QV at 2 M"),
    "RAINC":   ("mm", "ACCUMULATED TOTAL CUMULUS PRECIPITATION"),
    "RAINNC":  ("mm", "ACCUMULATED TOTAL GRID SCALE PRECIPITATION"),
    "MU":      ("Pa", "perturbation dry air mass in column"),
    "MUB":     ("Pa", "base state dry air mass in column"),
    "T":       ("K", "perturbation potential temperature (theta-t0)"),
    "P":       ("Pa", "perturbation pressure"),
    "PB":      ("Pa", "BASE STATE PRESSURE"),
    "P_HYD":   ("Pa", "hydrostatic pressure"),
    "U":       ("m s-1", "x-wind component"),
    "V":       ("m s-1", "y-wind component"),
    "W":       ("m s-1", "z-wind component"),
    "QVAPOR":  ("kg kg-1", "Water vapor mixing ratio"),
    "QCLOUD":  ("kg kg-1", "Cloud water mixing ratio"),
    "CLDFRA":  ("", "CLOUD FRACTION"),
    "TKE":     ("m2 s-2", "TURBULENCE KINETIC ENERGY"),
    "PH":      ("m2 s-2", "perturbation geopotential"),
    "PHB":     ("m2 s-2", "base-state geopotential"),
    "RQCBLTEN":("kg kg-1 s-1", "Coupled moisture tendency due to PBL"),
    "RQVBLTEN":("kg kg-1 s-1", "Coupled water vapor tendency due to PBL"),
    "RTHBLTEN":("K s-1", "Coupled potential temperature tendency due to PBL"),
    "XLAT":    ("degree_north", "LATITUDE, SOUTH IS NEGATIVE"),
    "XLONG":   ("degree_east", "LONGITUDE, WEST IS NEGATIVE"),
}


def create_wrfout(outpath, time_str, lats2d, lons2d,
                  data_2d, data_3d, hhl_3d, nz, attrs):
    """Create a wrfout-compatible netCDF file.

    data_2d: dict of 2D arrays {varname: array(ny, nx)}
    data_3d: dict of 3D arrays {varname: array(nz, ny, nx)}
    hhl_3d: half-level heights array(nz+1, ny, nx)
    """
    ny, nx = lats2d.shape

    nc = Dataset(outpath, "w", format="NETCDF4")

    # Dimensions
    nc.createDimension("Time", 1)
    nc.createDimension("DateStrLen", 19)
    nc.createDimension("south_north", ny)
    nc.createDimension("west_east", nx)
    nc.createDimension("south_north_stag", ny + 1)
    nc.createDimension("west_east_stag", nx + 1)
    nc.createDimension("bottom_top", nz)
    nc.createDimension("bottom_top_stag", nz + 1)
    nc.createDimension("soil_layers_stag", 4)

    # Global attributes (WRF projection info)
    nc.DX = attrs["dx"]
    nc.DY = attrs["dy"]
    nc.CEN_LAT = np.float32(attrs["cen_lat"])
    nc.CEN_LON = np.float32(attrs["cen_lon"])
    nc.TRUELAT1 = np.float32(attrs["cen_lat"])
    nc.TRUELAT2 = np.float32(attrs["cen_lat"])
    nc.STAND_LON = np.float32(attrs["cen_lon"])
    nc.MAP_PROJ = np.int32(1)  # Lambert Conformal
    nc.MOAD_CEN_LAT = np.float32(attrs["cen_lat"])
    nc.setncattr("WEST-EAST_GRID_DIMENSION", np.int32(nx + 1))
    nc.setncattr("SOUTH-NORTH_GRID_DIMENSION", np.int32(ny + 1))
    nc.setncattr("BOTTOM-TOP_GRID_DIMENSION", np.int32(nz + 1))
    nc.GRIDTYPE = "C"
    nc.DIFF_OPT = np.int32(1)
    nc.KM_OPT = np.int32(4)
    nc.DAMP_OPT = np.int32(0)
    nc.KHDIF = np.float32(0.0)
    nc.KVDIF = np.float32(0.0)
    nc.MP_PHYSICS = np.int32(8)
    nc.RA_LW_PHYSICS = np.int32(4)
    nc.RA_SW_PHYSICS = np.int32(4)
    nc.SF_SFCLAY_PHYSICS = np.int32(1)
    nc.SF_SURFACE_PHYSICS = np.int32(2)
    nc.BL_PBL_PHYSICS = np.int32(1)
    nc.CU_PHYSICS = np.int32(0)
    nc.SURFACE_INPUT_SOURCE = np.int32(1)
    nc.SST_UPDATE = np.int32(0)
    nc.GRID_FDDA = np.int32(0)
    nc.GFDDA_INTERVAL_M = np.int32(0)
    nc.GFDDA_END_H = np.int32(0)
    nc.GRID_SFDDA = np.int32(0)
    nc.SGFDDA_INTERVAL_M = np.int32(0)
    nc.SGFDDA_END_H = np.int32(0)
    nc.HYPSOMETRIC_OPT = np.int32(2)
    nc.TITLE = "ICON-D2 data converted to WRF format for RASP"
    nc.START_DATE = time_str
    nc.SIMULATION_START_DATE = time_str
    nc.JULYR = np.int32(int(time_str[:4]))
    nc.JULDAY = np.int32(datetime.strptime(time_str[:10], "%Y-%m-%d").timetuple().tm_yday)
    nc.GMT = np.float32(float(time_str[11:13]))
    nc.DT = np.float32(12.0)
    nc.ISWATER = np.int32(17)
    nc.ISICE = np.int32(15)
    nc.ISURBAN = np.int32(13)
    nc.ISOILWATER = np.int32(14)

    # Times
    times = nc.createVariable("Times", "S1", ("Time", "DateStrLen"))
    times[0, :] = list(time_str)

    # Coordinates
    def _set_meta(v, name, stagger, mem_order):
        v.stagger = stagger
        v.MemoryOrder = mem_order
        if name in WRF_VAR_META:
            v.units = WRF_VAR_META[name][0]
            v.description = WRF_VAR_META[name][1]

    def write_2d(name, data, dims=("Time", "south_north", "west_east")):
        v = nc.createVariable(name, "f4", dims)
        _set_meta(v, name, "", "XY ")
        v[0, :, :] = data

    def write_3d(name, data, dims=("Time", "bottom_top", "south_north", "west_east")):
        v = nc.createVariable(name, "f4", dims)
        _set_meta(v, name, "", "XYZ")
        v[0, :, :, :] = data

    def write_3d_stag_z(name, data):
        v = nc.createVariable(name, "f4",
                              ("Time", "bottom_top_stag", "south_north", "west_east"))
        _set_meta(v, name, "Z", "XYZ")
        v[0, :, :, :] = data

    def write_3d_stag_x(name, data):
        v = nc.createVariable(name, "f4",
                              ("Time", "bottom_top", "south_north", "west_east_stag"))
        _set_meta(v, name, "X", "XYZ")
        v[0, :, :, :] = data

    def write_3d_stag_y(name, data):
        v = nc.createVariable(name, "f4",
                              ("Time", "bottom_top", "south_north_stag", "west_east"))
        _set_meta(v, name, "Y", "XYZ")
        v[0, :, :, :] = data

    def write_scalar(name, val):
        v = nc.createVariable(name, "f4", ("Time",))
        v.stagger = ""
        v.MemoryOrder = "0  "
        v[0] = val

    # XLAT, XLONG
    write_2d("XLAT", lats2d)
    write_2d("XLONG", lons2d)

    # Staggered coordinate grids (approximate)
    dlat = (lats2d[-1, 0] - lats2d[0, 0]) / (ny - 1)
    dlon = (lons2d[0, -1] - lons2d[0, 0]) / (nx - 1)

    # XLAT_U (same lat, staggered lon)
    lons_stag_x = np.zeros((ny, nx + 1), dtype=np.float32)
    lons_stag_x[:, 0] = lons2d[:, 0] - dlon / 2
    lons_stag_x[:, 1:] = lons2d + dlon / 2
    lats_stag_x = np.zeros((ny, nx + 1), dtype=np.float32)
    lats_stag_x[:, :-1] = lats2d
    lats_stag_x[:, -1] = lats2d[:, -1]
    write_2d("XLAT_U", lats_stag_x, ("Time", "south_north", "west_east_stag"))
    write_2d("XLONG_U", lons_stag_x, ("Time", "south_north", "west_east_stag"))

    # XLAT_V (staggered lat, same lon)
    lats_stag_y = np.zeros((ny + 1, nx), dtype=np.float32)
    lats_stag_y[0, :] = lats2d[0, :] - dlat / 2
    lats_stag_y[1:, :] = lats2d + dlat / 2
    lons_stag_y = np.zeros((ny + 1, nx), dtype=np.float32)
    lons_stag_y[:-1, :] = lons2d
    lons_stag_y[-1, :] = lons2d[-1, :]
    write_2d("XLAT_V", lats_stag_y, ("Time", "south_north_stag", "west_east"))
    write_2d("XLONG_V", lons_stag_y, ("Time", "south_north_stag", "west_east"))

    # Map factors (1.0 for regular lat-lon, approximate)
    ones_2d = np.ones((ny, nx), dtype=np.float32)
    write_2d("MAPFAC_M", ones_2d)
    write_2d("MAPFAC_MX", ones_2d)
    write_2d("MAPFAC_MY", ones_2d)
    ones_u = np.ones((ny, nx + 1), dtype=np.float32)
    write_2d("MAPFAC_U", ones_u, ("Time", "south_north", "west_east_stag"))
    write_2d("MAPFAC_UX", ones_u, ("Time", "south_north", "west_east_stag"))
    write_2d("MAPFAC_UY", ones_u, ("Time", "south_north", "west_east_stag"))
    ones_v = np.ones((ny + 1, nx), dtype=np.float32)
    write_2d("MAPFAC_V", ones_v, ("Time", "south_north_stag", "west_east"))
    write_2d("MAPFAC_VX", ones_v, ("Time", "south_north_stag", "west_east"))
    write_2d("MAPFAC_VY", ones_v, ("Time", "south_north_stag", "west_east"))

    # COSALPHA, SINALPHA (grid rotation - 0 for regular lat-lon)
    write_2d("COSALPHA", ones_2d)
    write_2d("SINALPHA", np.zeros((ny, nx), dtype=np.float32))

    # RDX, RDY
    write_scalar("RDX", 1.0 / attrs["dx"])
    write_scalar("RDY", 1.0 / attrs["dy"])

    # P_TOP (model top pressure)
    write_scalar("P_TOP", 5000.0)  # 50 hPa

    # 2D surface variables
    for name, arr in data_2d.items():
        if arr is not None:
            write_2d(name, arr)

    # 3D variables on mass points
    for name in ["T", "P", "PB", "QVAPOR", "QCLOUD", "CLDFRA", "TKE", "P_HYD"]:
        if name in data_3d and data_3d[name] is not None:
            write_3d(name, data_3d[name])

    # 3D staggered variables
    if "U" in data_3d and data_3d["U"] is not None:
        write_3d_stag_x("U", data_3d["U"])
    if "V" in data_3d and data_3d["V"] is not None:
        write_3d_stag_y("V", data_3d["V"])
    if "W" in data_3d and data_3d["W"] is not None:
        write_3d_stag_z("W", data_3d["W"])

    # PH, PHB (geopotential height on staggered levels)
    if "PH" in data_3d and data_3d["PH"] is not None:
        write_3d_stag_z("PH", data_3d["PH"])
    if "PHB" in data_3d and data_3d["PHB"] is not None:
        write_3d_stag_z("PHB", data_3d["PHB"])

    # RQCBLTEN - not available from ICON-D2, fill with zeros
    write_3d("RQCBLTEN", np.zeros((nz, ny, nx), dtype=np.float32))
    write_3d("RQVBLTEN", np.zeros((nz, ny, nx), dtype=np.float32))
    write_3d("RTHBLTEN", np.zeros((nz, ny, nx), dtype=np.float32))

    # MU, MUB (dry air mass) - approximate from surface pressure and model top
    if "PSFC" in data_2d and data_2d["PSFC"] is not None:
        psfc = data_2d["PSFC"]
        p_top = 5000.0
        mu_total = psfc - p_top
        # Split roughly 90% base, 10% perturbation
        mub = mu_total * 0.9
        mu = mu_total * 0.1
        write_2d("MU", mu)
        write_2d("MUB", mub)

    # Eta levels (ZNU, ZNW) - approximate uniform spacing
    znu = np.linspace(1.0, 0.0, nz + 2)[1:-1].astype(np.float32)  # mass levels
    znw = np.linspace(1.0, 0.0, nz + 1).astype(np.float32)        # stag levels
    v_znu = nc.createVariable("ZNU", "f4", ("Time", "bottom_top"))
    v_znu.stagger = ""
    v_znu[0, :] = znu
    v_znw = nc.createVariable("ZNW", "f4", ("Time", "bottom_top_stag"))
    v_znw.stagger = "Z"
    v_znw[0, :] = znw

    # DN, DNW
    dn = np.diff(znw).astype(np.float32)
    v_dn = nc.createVariable("DN", "f4", ("Time", "bottom_top"))
    v_dn.stagger = ""
    v_dn[0, :] = dn
    v_dnw = nc.createVariable("DNW", "f4", ("Time", "bottom_top"))
    v_dnw.stagger = ""
    v_dnw[0, :] = dn

    # FNM, FNP
    fnm = np.ones(nz, dtype=np.float32) * 0.5
    fnp = np.ones(nz, dtype=np.float32) * 0.5
    v_fnm = nc.createVariable("FNM", "f4", ("Time", "bottom_top"))
    v_fnm.stagger = ""
    v_fnm[0, :] = fnm
    v_fnp = nc.createVariable("FNP", "f4", ("Time", "bottom_top"))
    v_fnp.stagger = ""
    v_fnp[0, :] = fnp

    # XTIME
    write_scalar("XTIME", 0.0)

    # Soil layers (dummy)
    dzs = nc.createVariable("DZS", "f4", ("Time", "soil_layers_stag"))
    dzs.stagger = "Z"
    dzs[0, :] = [0.1, 0.3, 0.6, 1.0]
    zs = nc.createVariable("ZS", "f4", ("Time", "soil_layers_stag"))
    zs.stagger = "Z"
    zs[0, :] = [0.05, 0.25, 0.7, 1.5]

    nc.close()


def process_timestep(datadir, outdir, date_str, run_hour, step,
                     lats, lons, lat_s, lat_e, lon_s, lon_e,
                     hhl_cropped, hsurf_cropped, nz):
    """Process a single timestep: load ICON-D2 data, convert, write wrfout."""

    # Calculate valid time
    base_time = datetime.strptime(f"{date_str}{run_hour:02d}", "%Y%m%d%H")
    valid_time = base_time + timedelta(hours=step)
    time_str = valid_time.strftime("%Y-%m-%d_%H:%M:%S")

    outpath = outdir / f"wrfout_d02_{time_str}"
    if outpath.exists():
        print(f"  {time_str} - cached")
        return True

    print(f"  {time_str} - converting...", end="", flush=True)

    ny = lat_e - lat_s
    nx = lon_e - lon_s

    # Build 2D lat/lon grids
    lats_crop = lats[lat_s:lat_e]
    lons_crop = lons[lon_s:lon_e]
    lons2d, lats2d = np.meshgrid(lons_crop, lats_crop)

    # Grid spacing in meters (approximate)
    dx = 0.02 * 111000.0 * np.cos(np.radians(np.mean(lats_crop)))  # ~1500m at 52N
    dy = 0.02 * 111000.0  # ~2220m

    attrs = {
        "dx": np.float32(dx),
        "dy": np.float32(dy),
        "cen_lat": float(np.mean(lats_crop)),
        "cen_lon": float(np.mean(lons_crop)),
    }

    # Load 2D fields
    def load_sl_crop(var):
        data = load_single_level(datadir, var, step)
        if data is None:
            return None
        return data[lat_s:lat_e, lon_s:lon_e].astype(np.float32)

    t2m = load_sl_crop("t_2m")
    td2m = load_sl_crop("td_2m")
    u10 = load_sl_crop("u_10m")
    v10 = load_sl_crop("v_10m")
    psfc = load_sl_crop("ps")
    hgt = hsurf_cropped  # time-invariant terrain height
    pblh = load_sl_crop("mh")
    hfx = load_sl_crop("ashfl_s")
    lh = load_sl_crop("alhfl_s")
    aswdir = load_sl_crop("aswdir_s")
    aswdifd = load_sl_crop("aswdifd_s")
    tot_prec = load_sl_crop("tot_prec")
    clcl = load_sl_crop("clcl")
    clcm = load_sl_crop("clcm")
    clch = load_sl_crop("clch")
    cape = load_sl_crop("cape_ml")

    # SWDOWN = direct + diffuse
    swdown = None
    if aswdir is not None and aswdifd is not None:
        swdown = aswdir + aswdifd

    # Q2 from dewpoint and surface pressure
    q2 = None
    if td2m is not None and psfc is not None:
        q2 = dewpoint_to_mixing_ratio(td2m, psfc)

    data_2d = {
        "T2": t2m,
        "PSFC": psfc,
        "U10": u10,
        "V10": v10,
        "HGT": hgt,
        "PBLH": pblh,
        "HFX": hfx,
        "LH": lh,
        "SWDOWN": swdown,
        "Q2": q2,
        "RAINC": np.zeros((ny, nx), dtype=np.float32),  # split not available
        "RAINNC": tot_prec if tot_prec is not None else np.zeros((ny, nx), dtype=np.float32),
    }

    # Load 3D fields (model levels)
    # ICON levels: 1=top, 65=surface. WRF: bottom_top 0=surface, nz-1=top
    # So we need to reverse the level order
    def load_ml_3d(var):
        """Load all model levels for a variable, crop and reverse."""
        levels_data = []
        for level in range(1, 66):
            data = load_model_level(datadir, var, step, level)
            if data is None:
                return None
            levels_data.append(data[lat_s:lat_e, lon_s:lon_e])
        # Stack: shape (65, ny, nx), level 0=top, 64=surface
        arr = np.array(levels_data, dtype=np.float32)
        # Reverse so index 0=surface (WRF convention)
        return arr[::-1, :, :]

    print(" 3D...", end="", flush=True)

    t_3d = load_ml_3d("t")      # temperature (K)
    p_3d = load_ml_3d("p")      # pressure (Pa)
    u_3d = load_ml_3d("u")      # u-wind (m/s)
    v_3d = load_ml_3d("v")      # v-wind (m/s)
    w_3d = load_ml_3d("w")      # w-wind (m/s)
    qv_3d = load_ml_3d("qv")    # specific humidity (kg/kg)
    qc_3d = load_ml_3d("qc")    # cloud water (kg/kg)
    clc_3d = load_ml_3d("clc")  # cloud fraction (ICON: 0-100%, WRF: 0-1)
    if clc_3d is not None:
        clc_3d = np.nan_to_num(clc_3d, nan=0.0) / 100.0
    tke_3d = load_ml_3d("tke")  # TKE

    # Convert temperature to WRF potential temperature perturbation
    # WRF T = theta - T0
    t_wrf = None
    if t_3d is not None and p_3d is not None:
        t_wrf = temperature_to_theta_perturbation(t_3d, p_3d)

    # Split pressure into base state (PB) and perturbation (P)
    # Use hydrostatic approximation for base state
    p_pert = None
    pb = None
    if p_3d is not None:
        # Simple approach: base state = horizontal mean at each level
        pb = np.zeros_like(p_3d)
        for k in range(nz):
            pb[k, :, :] = np.mean(p_3d[k, :, :])
        p_pert = p_3d - pb

    # Convert specific humidity to mixing ratio
    # q = qv/(1+qv) -> qv_mix = q/(1-q)
    qvapor = None
    if qv_3d is not None:
        qvapor = qv_3d / (1.0 - np.maximum(qv_3d, 0.0))

    # Stagger U (nx -> nx+1)
    u_stag = None
    if u_3d is not None:
        u_stag = np.zeros((nz, ny, nx + 1), dtype=np.float32)
        u_stag[:, :, 1:-1] = 0.5 * (u_3d[:, :, :-1] + u_3d[:, :, 1:])
        u_stag[:, :, 0] = u_3d[:, :, 0]
        u_stag[:, :, -1] = u_3d[:, :, -1]

    # Stagger V (ny -> ny+1)
    v_stag = None
    if v_3d is not None:
        v_stag = np.zeros((nz, ny + 1, nx), dtype=np.float32)
        v_stag[:, 1:-1, :] = 0.5 * (v_3d[:, :-1, :] + v_3d[:, 1:, :])
        v_stag[:, 0, :] = v_3d[:, 0, :]
        v_stag[:, -1, :] = v_3d[:, -1, :]

    # Stagger W (nz -> nz+1)
    w_stag = None
    if w_3d is not None:
        w_stag = np.zeros((nz + 1, ny, nx), dtype=np.float32)
        w_stag[1:-1, :, :] = 0.5 * (w_3d[:-1, :, :] + w_3d[1:, :, :])
        w_stag[0, :, :] = w_3d[0, :, :]
        w_stag[-1, :, :] = w_3d[-1, :, :]

    # PH, PHB (geopotential on staggered levels)
    # Use HHL (half-level heights) from ICON-D2
    # hhl_cropped is already (66, ny, nx), reversed (0=surface, 65=top)
    ph = None
    phb = None
    if hhl_cropped is not None:
        geopotential = hhl_cropped * G  # convert height to geopotential
        # Base state = horizontal mean
        phb = np.zeros_like(geopotential)
        for k in range(nz + 1):
            phb[k, :, :] = np.mean(geopotential[k, :, :])
        ph = geopotential - phb

    data_3d = {
        "T": t_wrf,
        "P": p_pert,
        "PB": pb,
        "P_HYD": p_3d,
        "U": u_stag,
        "V": v_stag,
        "W": w_stag,
        "QVAPOR": qvapor,
        "QCLOUD": qc_3d,
        "CLDFRA": clc_3d,
        "TKE": tke_3d,
        "PH": ph,
        "PHB": phb,
    }

    print(" write...", end="", flush=True)
    create_wrfout(outpath, time_str, lats2d.astype(np.float32),
                  lons2d.astype(np.float32), data_2d, data_3d,
                  hhl_cropped, nz, attrs)
    print(" OK")
    return True


def main():
    parser = argparse.ArgumentParser(description="Convert ICON-D2 to wrfout")
    parser.add_argument("--datadir", required=True, help="ICON-D2 GRIB data directory")
    parser.add_argument("--outdir", required=True, help="Output directory for wrfout files")
    parser.add_argument("--date", required=True, help="Date YYYYMMDD")
    parser.add_argument("--run", type=int, default=0, help="Run hour")
    parser.add_argument("--hours", default="6-18", help="Forecast hour range")
    args = parser.parse_args()

    datadir = Path(args.datadir)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    hour_start, hour_end = map(int, args.hours.split("-"))

    # Get grid info
    print("Loading grid info...")
    lats, lons = get_grid_info(datadir)
    lat_s, lat_e, lon_s, lon_e = get_nl_crop_indices(lats, lons)
    ny = lat_e - lat_s
    nx = lon_e - lon_s
    nz = 65  # ICON-D2 model levels
    print(f"  ICON-D2 grid: {len(lats)}x{len(lons)}")
    print(f"  NL crop: [{lat_s}:{lat_e}, {lon_s}:{lon_e}] = {ny}x{nx}")
    print(f"  Lat: {lats[lat_s]:.2f} - {lats[lat_e-1]:.2f}")
    print(f"  Lon: {lons[lon_s]:.2f} - {lons[lon_e-1]:.2f}")

    # Load HHL (half-level heights) - time-invariant
    print("Loading HHL (half-level heights)...")
    hhl_levels = []
    for level in range(1, 67):
        data = load_hhl(datadir, level)
        if data is None:
            print(f"  WARNING: HHL level {level} not found")
            hhl_levels.append(np.zeros((ny, nx), dtype=np.float32))
        else:
            hhl_levels.append(data[lat_s:lat_e, lon_s:lon_e].astype(np.float32))
    # Stack: (66, ny, nx), level 0=top, 65=surface
    hhl_3d = np.array(hhl_levels, dtype=np.float32)
    # Reverse: 0=surface, 65=top (WRF convention)
    hhl_3d = hhl_3d[::-1, :, :]
    print(f"  HHL range: {hhl_3d.min():.0f} - {hhl_3d.max():.0f} m")

    # Load hsurf (time-invariant terrain height)
    print("Loading hsurf (terrain height)...")
    hsurf_path = datadir / "ti_hsurf.grib2"
    if hsurf_path.exists():
        hsurf_data, _ = read_grib(hsurf_path)
        hsurf_cropped = hsurf_data[lat_s:lat_e, lon_s:lon_e].astype(np.float32)
        print(f"  hsurf range: {hsurf_cropped.min():.0f} - {hsurf_cropped.max():.0f} m")
    else:
        print("  WARNING: hsurf not found, using HHL surface level")
        hsurf_cropped = hhl_3d[0, :, :]  # surface level

    # Process each timestep
    steps = list(range(hour_start, hour_end + 1))
    print(f"\nConverting {len(steps)} timesteps...")

    for step in steps:
        ok = process_timestep(datadir, outdir, args.date, args.run, step,
                              lats, lons, lat_s, lat_e, lon_s, lon_e,
                              hhl_3d, hsurf_cropped, nz)
        if not ok:
            print(f"  FAILED step {step}")

    print("\nDone!")


if __name__ == "__main__":
    main()
