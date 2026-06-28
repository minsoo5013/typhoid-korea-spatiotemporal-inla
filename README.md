# Typhoid Fever Spatiotemporal INLA Analysis, South Korea, 2011-2024

This repository contains release-ready analysis code for the manuscript:

**Long-term spatiotemporal distribution and area-level factors associated with typhoid fever in South Korea: a nationwide district-level ecological study, 2011-2024**

The public pipeline is intentionally restricted to the final prespecified six-covariate model. Historical automatic variable-selection scripts are not used by the release pipeline.

## Final Model

- Outcome: annual district-level typhoid fever cases
- Population offset: `log(population + 1)`
- Likelihood: negative binomial
- Spatial structure: queen contiguity adjacency using `poly2nb(snap = 0.01, queen = TRUE)`
- Retained analysis geography: 223 districts after removing no-neighbour island districts
- Time period: 2011-2024
- Final model: NB + BYM + RW1 + IID
- Final covariates, fixed and pre-specified, modelled on raw measurement scale:

| Covariate | Unit |
|---|---|
| Sewerage coverage | % |
| Foreign residents | per 1,000 population |
| Physicians | per 1,000 population |
| Fiscal self-reliance | % |
| Older-population share | % |
| Sex ratio | males per 100 females |

The covariates are fixed inputs to `R/03_model_fit.R`; the public pipeline performs no automated variable selection. IRRs in Table 2 are interpreted per 1-unit increase on each covariate's original scale (e.g. per 1 percentage point, per 1 person per 1,000 population, per 1 male per 100 females).

The foreign-residents variable is interpreted only as a district-level mobility/importation/connectivity proxy; it is not an estimate of individual or group-specific risk.

The `_T` covariate suffix used in the analysis data denotes analysis-ready raw-copy columns. It does not denote z-standardisation, log transformation, or categorical transformation.

## Locked Manuscript Values

The current locked manuscript values are:

- Districts: 223
- District-years: 3,122
- Total cases: 1,202
- Final model DIC: 4196.36
- Final model WAIC: 4198.66
- Raw incidence Moran's I: 0.333
- M6 raw residual Moran's I: -0.019, p = 0.6341
- M6 Pearson residual Moran's I: -0.060, p = 0.8998
- Districts with elevated posterior spatial relative risk: 14
- Gyeongnam among elevated districts: 9

Reference output tables are stored in `outputs/reference/`. Generated outputs from a local rerun should be written to `outputs/generated/`.

## Repository Structure

```text
repo/
├─ README.md
├─ LICENSE
├─ CITATION.cff
├─ data/
│  └─ README.md
├─ R/
│  ├─ 01_data_prep.R
│  ├─ 02_adjacency.R
│  ├─ 03_model_fit.R                # final model (queen contiguity)
│  ├─ 04_diagnostics.R              # S3, Table 2, residual Moran, S4 elevated
│  ├─ 05_figures.R                  # Figure 1 (annual cases)
│  ├─ 06_sensitivity_window.R       # S5 window sensitivity (supplementary)
│  ├─ 07_sensitivity_knn.R          # S6 KNN adjacency sensitivity (supplementary)
│  ├─ 08_video_frames.R             # district-year data for the videos
│  ├─ _sensitivity_common.R         # shared helpers for 06–07
│  └─ exploratory/                  # variable selection — exploratory only, not used for final analysis
├─ python/                          # Figure 2 + supplementary video renderers (matplotlib/geopandas)
│  ├─ figure2_contiguity.py
│  ├─ make_video_frames.py
│  ├─ convert_videos.py
│  ├─ north_arrow.py
│  └─ requirements.txt
└─ outputs/
   ├─ reference/
   └─ generated/
```

## How to Run

Place permitted input files under `data/` according to `data/README.md` (including the
SGIS boundary shapefile under `data/spatial/`, which is required and not redistributed here).

```bash
# Final model + diagnostics
Rscript R/01_data_prep.R
Rscript R/02_adjacency.R
TYPHOID_INLA_NUM_THREADS=1:1 Rscript R/03_model_fit.R
Rscript R/04_diagnostics.R
Rscript R/05_figures.R

# Supplementary sensitivity analyses (queen is the main model; these are sensitivity only)
TYPHOID_INLA_NUM_THREADS=1:1 Rscript R/06_sensitivity_window.R
TYPHOID_INLA_NUM_THREADS=1:1 Rscript R/07_sensitivity_knn.R

# Figure 2 + supplementary videos (Python; needs the SGIS boundary)
Rscript R/08_video_frames.R
pip install -r python/requirements.txt
python python/figure2_contiguity.py
python python/make_video_frames.py
python python/convert_videos.py
```

`R/04_diagnostics.R` can also validate the reference locked manuscript values without refitting:

```bash
Rscript R/04_diagnostics.R --validate-reference
```

## Reproduction Scope

| Manuscript output | Code | Reproduced |
|---|---|---|
| Figure 1 (annual cases) | `R/05_figures.R` | Yes |
| Figure 2 (crude incidence + posterior spatial RR maps) | `python/figure2_contiguity.py` | Yes — requires SGIS boundary shapefile |
| S1 video (observed vs fitted) | `R/08_video_frames.R` → `python/make_video_frames.py` → `python/convert_videos.py` | Yes — requires SGIS boundary shapefile |
| S2 video (Pearson residual) | `R/08_video_frames.R` → `python/make_video_frames.py` → `python/convert_videos.py` | Yes — requires SGIS boundary shapefile |
| S3 (M1–M6 DIC/WAIC) | `R/03_model_fit.R`, `R/04_diagnostics.R` | Yes |
| S4 (elevated posterior spatial RR ranking) | `R/04_diagnostics.R` | Yes |
| S5 (window sensitivity W1–W5) | `R/06_sensitivity_window.R` | Yes |
| S6 (KNN adjacency sensitivity K=2–7) | `R/07_sensitivity_knn.R` | Yes |
| Residual Moran's I (raw + Pearson) | `R/04_diagnostics.R` | Yes |
| Table 1 / Table 2 | `R/01_data_prep.R`, `R/04_diagnostics.R` | Yes |

Items 06–08 and the `python/` renderers are supplementary; the **final manuscript model
is the full 2011–2024 queen-contiguity M6** fitted in `R/03_model_fit.R`. KNN and window
analyses are sensitivity checks only.

## Two-Tier Analysis Policy

Earlier forward, backward, stepwise, VIF-based, or AIC-driven scripts were exploratory only. They are not part of the final manuscript strategy and are not called by the public release pipeline.

The public release pipeline uses a prespecified six-covariate final model selected based on epidemiological relevance, data availability, data quality, interpretability, and parsimony. Automatic variable selection is not used to define the final manuscript model.

Exploratory scripts, if retained for audit purposes, must stay under `R/exploratory/` and must not be sourced by the release pipeline (`R/01`–`R/08` and `python/`). Every model fit in the release pipeline — including the window and KNN sensitivity analyses — uses the same fixed six covariates.

## Data Availability

This repository should not include personal information, non-public raw data, or restricted source files. See `data/README.md` for public-source documentation and expected local file placement.

## Reproducibility Notes

- Set `TYPHOID_INLA_NUM_THREADS=1:1` for deterministic INLA reruns where possible.
- Minor numerical differences may occur across R/INLA versions and numerical environments.
- Manuscript values should not be replaced unless discrepancies are documented and approved before manuscript revision.
- Figure generation is deterministic and does not use AI-generated images.

## Public Release Status

This folder is prepared for future GitHub and Zenodo release. No GitHub push has been performed from this workspace, and no Zenodo DOI has been generated here.
