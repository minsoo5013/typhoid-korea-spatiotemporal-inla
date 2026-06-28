# Public Release Preparation Report

## Status

This folder has been prepared as a future GitHub/Zenodo code-release package for the fixed six-covariate typhoid fever INLA analysis.

No GitHub push was performed.
No Zenodo DOI was generated.
DOI insertion should occur only after final model choice, output freeze, and professor approval.

## Public Pipeline

The main public pipeline is fixed to the final manuscript model:

- `R/01_data_prep.R`: prepare the derived panel and raw-copy `_T` covariates.
- `R/02_adjacency.R`: build queen contiguity adjacency with `poly2nb(snap = 0.01, queen = TRUE)`.
- `R/03_model_fit.R`: fit M1-M6, with M6 defined as NB + BYM + RW1 + IID.
- `R/04_diagnostics.R`: generate diagnostic tables from fitted objects or validate locked reference values without refitting.
- `R/05_figures.R`: generate deterministic figure outputs from available reference/generated inputs.

The final model uses the six prespecified raw-scale covariates: sewerage coverage, foreign residents per 1,000 population, physicians per 1,000 population, fiscal self-reliance, older population share, and sex ratio.

## Exploratory Scripts

Exploratory variable-selection procedures are isolated under `R/exploratory/`.

Forward selection, backward elimination, stepwise selection, VIF pruning, and AIC-driven screening are documented as preliminary exploratory work only. They are not called by the public final-model pipeline.

## Reference Validation

The no-refit reference validation command was run:

```bash
Rscript R/04_diagnostics.R --validate-reference
```

The validation output is `outputs/generated/reference_validation.csv`. All locked headline values passed:

- 223 districts
- 3,122 district-years
- 1,202 cases
- DIC 4196.36
- WAIC 4198.66
- raw incidence Moran's I 0.333
- M6 raw residual Moran's I -0.019, p = 0.6341
- M6 Pearson residual Moran's I -0.060, p = 0.8998
- 14 districts with elevated posterior spatial relative risk
- 9 of those districts in Gyeongnam

## Data Policy

Restricted raw data and locally derived analytic panels are not included. Public source documentation and expected local file placement are described in `data/README.md`.

The release package should be checked again before publication to ensure no restricted data, personal paths, temporary logs, or real DOI-like placeholders are present.
