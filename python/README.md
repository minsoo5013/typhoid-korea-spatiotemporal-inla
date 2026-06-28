# Python rendering (Figure 2 and supplementary videos)

These scripts render the manuscript Figure 2 and the supplementary videos from the
locked contiguity M6 outputs produced by the R pipeline. They perform **no model
refitting and no value changes** — they only draw deterministic matplotlib/geopandas
maps. No AI-generated images are used.

## Boundary data required

Figure 2 and the video frames need the district boundary shapefile from
**Statistics Korea SGIS** at `data/spatial/final.{gpkg,shp}`. This boundary file is
**not redistributed** in this repository (see `data/README.md`); obtain it from SGIS
and place it under `data/spatial/` before running.

## Inputs (produced by the R pipeline)

- `outputs/generated/panel_inla_6var_contiguity.csv` (R/01–02)
- `outputs/generated/spatial_RE_all_6var.csv` (R/04_diagnostics.R)
- `outputs/generated/Table_S_elevated_spatial_RR_districts.csv` (R/04_diagnostics.R)
- `outputs/generated/district_year_final_contiguity_M6_for_gifs.csv` (R/08_video_frames.R)

These must reproduce the locked M6 (DIC 4196.36 / WAIC 4198.66, 223 districts,
14 elevated, 9 in Gyeongnam). `figure2_contiguity.py` asserts these locked values
and fails fast if they drift.

## Install

```bash
pip install -r python/requirements.txt
```

`imageio-ffmpeg` bundles an ffmpeg binary used by `convert_videos.py`.

## Run order

```bash
python python/figure2_contiguity.py     # Figure 2 (A) crude incidence, (B) posterior spatial RR
python python/make_video_frames.py      # per-year PNG frames + GIFs (needs 08_video_frames.R output)
python python/convert_videos.py         # S1 / S2 MP4s from the frames
```

Outputs are written under `outputs/generated/figures/` (git-ignored).
