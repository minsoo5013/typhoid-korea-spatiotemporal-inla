# Exploratory Scripts

This directory is reserved for historical or internal exploratory scripts only.

Forward selection, backward elimination, stepwise selection, VIF pruning, and AIC-driven screening were used only as preliminary exploratory work. They are not part of the final manuscript analysis strategy and are not sourced by the public pipeline.

The release pipeline in `R/01_data_prep.R` through `R/05_figures.R` uses the fixed six-covariate final model. Any script retained here must be labelled exploratory and must not overwrite manuscript reference outputs.

## Files

- `variable_selection_exploratory.R` — preserved verbatim for transparency: automated candidate screening, forward selection, and VIF-based pruning over a wide candidate pool. **Exploratory only; not used for the final analysis.** The manuscript's six covariates were pre-specified on epidemiological grounds, not chosen by this procedure. Its historical input paths are not guaranteed to resolve in this public layout.
- `00_exploratory_only_do_not_source.R` — guard that errors out if the directory is sourced as part of the pipeline.
