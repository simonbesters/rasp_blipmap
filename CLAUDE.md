# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RASP (Regional Atmospheric Soaring Predictions) weather simulation for the Netherlands. Runs the WRF (Weather Research and Forecasting) model inside Docker, then generates soaring-specific weather plots using NCL and Perl scripts originally written by Dr. Jack Glendening.

## Build Commands

All builds from repo root (`/root/blipmaps.nl`). Always use `--progress=plain` for full logging.

```bash
# Download binaries first (one-time)
cd rasp && curl -L -O https://blipmaps.nl/docker/geog1.tar.xz \
  && curl -L -O https://blipmaps.nl/docker/geog2.tar.xz \
  && curl -L -O https://blipmaps.nl/docker/rangs.tgz && cd ..

# Build all images (strict order required)
docker compose --env-file ./docker_env --env-file ./docker_env_NL4KMGFS build --progress=plain base
docker compose --env-file ./docker_env --env-file ./docker_env_NL4KMGFS build --progress=plain wrf_build
docker compose --env-file ./docker_env --env-file ./docker_env_NL4KMGFS build --progress=plain wrf_prod
docker compose --env-file ./docker_env --env-file ./docker_env_NL4KMGFS build --progress=plain rasp
```

Swap `docker_env_NL4KMGFS` for another region env file as needed.

## Run Commands

```bash
# Test run
mkdir -p /tmp/results/test/OUT /tmp/results/test/LOG
RUN_PREFIX=test docker compose --env-file ./docker_env --env-file ./docker_env_NL4KMGFS run rasp

# Production run (used by cron scripts)
# See cron/runArea.sh - creates timestamped RUN_PREFIX, runs docker compose
```

## Architecture

### Docker Image Chain

```
base (Fedora 42 + runtime libs: netcdf, libpng, jasper)
  └─ wrf_build (gcc/gfortran + WRF v4.7.1 + WPS v4.6.0, compiled for build arch)
  └─ wrf_prod  (same, compiled for production arch)
       └─ rasp (multi-stage: combines both WRF builds, runs geogrid, installs RASP scripts)
```

- `wrf_build` and `wrf_prod` use identical Dockerfile (`wrf/Dockerfile`) with different `-march` flags
- When build and prod run on same machine, both use `-march=native` (identical output, but Docker builds twice due to different image tags)
- WRF configure: option 33 (smpar GNU), WPS configure: option 1 (serial GNU)
- LTO (`-flto=auto`) is enabled, making the link phase very slow (~10min per executable)

### RASP Runtime Pipeline (inside container)

`runRasp.sh <REGION>` orchestrates the full run:
1. **runGM** → copies `GM-master.pl` to region dir as `GM.pl`, runs it with `-M 0`
2. **GM-master.pl** (giant Perl script, ~85K tokens) → the core orchestrator:
   - Downloads GFS/ICON GRIB data
   - Runs `ungrib.exe` → `metgrid.exe` → `real.exe` → `wrf.exe`
   - Runs NCL plotting scripts (`wrf2gm.ncl`, `wrf_plot.ncl`) via `ncl` for each parameter
3. **meteogram.ncl** → generates sounding/meteogram plots
4. **title2json.pl** → extracts metadata from output files
5. **rasp2geotiff.py** → converts output to GeoTIFF format

### Key Directories (inside container at `/root/rasp/`)

- `bin/` — executables and wrapper scripts (runGM, runRasp.sh, WRF binaries)
- `GM/` — NCL plotting scripts, calc functions, colour levels, site data
- `<REGION>/` — region-specific configs: `namelist.input`, `namelist.wps`, `rasp.run.parameters.*`, `rasp.site.parameters`, `rasp.site.runenvironment`
- `<REGION>/OUT/` — output images, GeoTIFFs, wrfout files (volume mount)
- `<REGION>/LOG/` — log files (volume mount)

### WRF Patching

Three patch scripts modify WRF/WPS after `./configure`:
- `patch_registry.sh` — adds `rh` (history) output flag to tke, RTHBLTEN, RQVBLTEN, RQCBLTEN in Registry
- `patch_configure_wrf.sh` — sets optimization flags (`-O3 -ftree-vectorize -funroll-loops -ffast-math -flto=auto -march=<arch>`), fixes netcdf library paths
- `patch_configure_wps.sh` — removes `-O`, adds gfortran module path and netcdf libs, patches jasper API calls for WPS

### Callback System (`callback/`)

Separate docker-compose service that monitors `/tmp/results/OUT` every 10 seconds. When it finds a `GM.printout` file, it runs configured callbacks per region (upload images, convert wrfout for XBL, delete files).

## Available Regions

| Region | Resolution | Input Model | Env File |
|--------|-----------|-------------|----------|
| NL4KMGFS | 4km | GFS | `docker_env_NL4KMGFS` |
| NL4KMICON | 4km | ICON | `docker_env_NL4KMICON` |
| NL1KMGFS | 1km | GFS | `docker_env_NL1KMGFS` |
| NL1KMICON | 1km | ICON | `docker_env_NL1KMICON` |

Each region has its own directory under `rasp/` with namelists, site data, and run parameters.

## Production Scheduling

Cron scripts in `cron/` run multiple regions sequentially with file locking (`/var/tmp/rasp.lock`):
- `run.0Z.cron.sh` — runs NL4KMGFS days 0-4, NL1KMGFS (offset=0, 03:30 UTC)
- `run.6Z.cron.sh` — NL4KMGFS_0 + NL1KMGFS_1 (offset=6, 09:30 UTC)
- `run.12Z.cron.sh` — NL4KMGFS_1 + NL1KMGFS_2 (offset=12, 15:30 UTC)
- `run.18Z.cron.sh` — NL4KMGFS_1 (offset=18, 21:30 UTC)
- Format: `<REGION>_<START_DAY>` (e.g., `NL4KMGFS_0` = today, `NL4KMGFS_1` = tomorrow)
- `START_DAY` and `OFFSET_HOUR` env vars control forecast timing
- All cron scripts call `cron/update-symlinks.sh` to update viewer symlinks after runs
- Log output: `/var/log/rasp.log`

## WRF Stability Settings

All regions have these stability settings in `namelist.input` (and baked into Docker images):
- `w_damping = 1` — damps extreme vertical velocities on convective days
- `diff_6th_opt = 2` — 6th order numerical diffusion (removes 2-gridpoint noise)
- `target_cfl = 0.8` / `target_hcfl = 0.56` — stricter CFL limits (default 1.2/0.84)
- `OMP_STACKSIZE=512M` in `rasp.site.runenvironment` (GNU OpenMP, not KMP_STACKSIZE)

**CRITICAL**: `namelist.input` changes require Docker image rebuild. GM-master.pl reads
`namelist.input.template` which is copied from `namelist.input` at `docker compose build` time.

## Web Frontend

- **URL**: https://rasp.besters.digital (Let's Encrypt, auto-renew via certbot)
- **Server**: Nginx + fcgiwrap on ports 80/443
- **Viewer**: `/root/RASPViewer/` with symlinks `NL+0` through `NL+4`
- **CGI**: Perl BlipSpot scripts in `/root/RASPViewer/cgi-bin/`
- **Symlink updater**: `cron/update-symlinks.sh` finds latest result per day

## Binary Dependencies (in `rasp/`, not in git)

- `geog1.tar.xz` (1.3GB) + `geog2.tar.xz` (1.4GB) — WPS geographic data (extracted during build, then deleted)
- `rangs.tgz` (83MB) — high-resolution coastline/lake data
- `ncl_jack/libncl_drjack.avx.nocuda.so` — custom NCL Fortran library for RASP calculations

## Workflow Orchestration

### 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately – don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes – don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Write a test to reproduce the bug first
- Point at logs, errors, failing tests – then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management

1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.
- **NEVER COMMIT**: You will never commit to this repository. No PR's, nothing. Keep everything in the user's hands and locally.
