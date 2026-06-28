# Reproducibility Checklist

- R version: record with `sessionInfo()` after the final local run.
- Required R packages: `INLA`, `sf`, `spdep`, `dplyr`, `ggplot2`.
- Input panel: `data/derived/panel_inla_6var_contiguity.csv`.
- Spatial boundary: `data/spatial/final.gpkg` or `data/spatial/final.shp`.
- Expected retained districts: 223.
- Expected analytic panel: 3,122 district-years.
- Expected total cases: 1,202.
- Offset: `log(population + 1)`.
- Adjacency: queen contiguity, `poly2nb(snap = 0.01, queen = TRUE)`, no-neighbour districts removed.
- Final model: negative binomial + BYM + RW1 + district-year IID.
- Final covariates: sewerage coverage, foreign residents per 1,000 population, physicians per 1,000 population, fiscal self-reliance, older population share, sex ratio.
- Thread setting for rerun: `TYPHOID_INLA_NUM_THREADS=1:1`.
- Reference validation command: `Rscript R/04_diagnostics.R --validate-reference`.
- Before public release: confirm no restricted raw data, personal paths, temporary debug output, or DOI placeholders treated as real DOI values.
