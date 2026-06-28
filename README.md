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
│  ├─ 03_model_fit.R
│  ├─ 04_diagnostics.R
│  ├─ 05_figures.R
│  └─ exploratory/                 # variable selection — exploratory only, not used for final analysis
└─ outputs/
   ├─ reference/
   └─ generated/
```

## How to Run

Place permitted input files under `data/` according to `data/README.md`.

```bash
Rscript R/01_data_prep.R
Rscript R/02_adjacency.R
TYPHOID_INLA_NUM_THREADS=1:1 Rscript R/03_model_fit.R
Rscript R/04_diagnostics.R
Rscript R/05_figures.R
```

`R/04_diagnostics.R` can also validate the reference locked manuscript values without refitting:

```bash
Rscript R/04_diagnostics.R --validate-reference
```

## Two-Tier Analysis Policy

Earlier forward, backward, stepwise, VIF-based, or AIC-driven scripts were exploratory only. They are not part of the final manuscript strategy and are not called by the public release pipeline.

The public release pipeline uses a prespecified six-covariate final model selected based on epidemiological relevance, data availability, data quality, interpretability, and parsimony. Automatic variable selection is not used to define the final manuscript model.

Exploratory scripts, if retained for audit purposes, must stay under `R/exploratory/` and must not be sourced by `R/01_data_prep.R` through `R/05_figures.R`.

## Data Availability

This repository should not include personal information, non-public raw data, or restricted source files. See `data/README.md` for public-source documentation and expected local file placement.

## Reproducibility Notes

- Set `TYPHOID_INLA_NUM_THREADS=1:1` for deterministic INLA reruns where possible.
- Minor numerical differences may occur across R/INLA versions and numerical environments.
- Manuscript values should not be replaced unless discrepancies are documented and approved before manuscript revision.
- Figure generation is deterministic and does not use AI-generated images.

## Public Release Status

This folder is prepared for future GitHub and Zenodo release. No GitHub push has been performed from this workspace, and no Zenodo DOI has been generated here.
