#!/usr/bin/env Rscript

# Reproduces: S5 window sensitivity (W1-W5, start years 2011-2015 to 2024).
#   SUPPLEMENTARY SENSITIVITY ONLY — the FINAL model is the full 2011-2024 window
#   on queen contiguity. Fixed six _T covariates; no automated selection.
# Input: outputs/generated/panel_inla_6var_contiguity.csv (from 01-02) and
#   data/spatial/final.{gpkg,shp}; queen contiguity rebuilt per window.
# Output: outputs/generated/window_sensitivity_comparison.csv (+ per-window files)
#   corresponding to outputs/reference/window_sensitivity_comparison_recovered_final.csv.
# Ported from professor_pipeline_run05_FINAL_v2/R/01_refit_FINAL_v2.R window loop.

set.seed(20260626)
options(scipen = 999)

get_repo_root <- function() {
  cmd <- commandArgs(FALSE)
  script_arg <- grep("^--file=", cmd, value = TRUE)
  if (length(script_arg) > 0) {
    return(normalizePath(file.path(dirname(sub("^--file=", "", script_arg[1])), ".."), mustWork = TRUE))
  }
  normalizePath(getwd(), mustWork = TRUE)
}

repo_root <- get_repo_root()
path <- function(...) file.path(repo_root, ...)
read_csv_utf8 <- function(x) read.csv(x, check.names = FALSE, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
write_csv_utf8 <- function(x, y) write.csv(x, y, row.names = FALSE, fileEncoding = "UTF-8")
source(path("R", "_sensitivity_common.R"))

panel_path <- path("outputs", "generated", "panel_inla_6var_contiguity.csv")
if (!file.exists(panel_path)) stop("Run R/01_data_prep.R and R/02_adjacency.R first.")
spatial_path <- if (file.exists(path("data", "spatial", "final.gpkg"))) path("data", "spatial", "final.gpkg") else path("data", "spatial", "final.shp")
if (!file.exists(spatial_path)) stop("Missing spatial file under data/spatial/.")

panel_all <- read_csv_utf8(panel_path)
if (!all(SENS_MODEL_COVARIATES %in% names(panel_all))) stop("Panel is missing the six _T covariates.")
if (!"log_pop" %in% names(panel_all)) panel_all$log_pop <- log(panel_all$population + 1)

out_dir <- path("outputs", "generated", "sensitivity", "window")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

window_one <- function(start_year) {
  wid <- paste0("W", start_year - 2010L)
  w_out <- file.path(out_dir, wid)
  dir.create(w_out, recursive = TRUE, showWarnings = FALSE)
  panel_w <- panel_all[panel_all$year >= start_year & panel_all$year <= 2024, , drop = FALSE]
  inputs <- sens_build_queen(panel_w, spatial_path, file.path(w_out, paste0("spatial_graph_", wid, ".inla")))
  forms <- sens_formula_set(SENS_MODEL_COVARIATES)
  fits <- lapply(forms, function(fs) sens_fit_inla(fs, inputs$panel, inputs$g))
  names(fits) <- names(forms)

  comparison <- do.call(rbind, lapply(names(fits), function(m) data.frame(
    model = m, DIC = as.numeric(fits[[m]]$dic$dic), WAIC = as.numeric(fits[[m]]$waic$waic), stringsAsFactors = FALSE
  )))
  comparison$DeltaDIC <- comparison$DIC - min(comparison$DIC, na.rm = TRUE)
  write_csv_utf8(comparison, file.path(w_out, paste0("model_comparison_M1_M6_", wid, ".csv")))

  fixed <- sens_extract_fixed(fits[["M6"]])
  write_csv_utf8(fixed, file.path(w_out, paste0("Table2_fixed_effects_6var_", wid, ".csv")))
  residual <- sens_area_moran(fits[["M6"]], inputs$panel, inputs$listw, "M6")
  write_csv_utf8(residual, file.path(w_out, paste0("residual_moran_", wid, ".csv")))

  data.frame(
    window_id = wid,
    start_year = start_year,
    end_year = 2024L,
    years = 2024L - start_year + 1L,
    N = nrow(inputs$panel),
    districts = length(unique(inputs$panel$region)),
    cases = sum(inputs$panel$cases),
    M6_DIC = comparison$DIC[comparison$model == "M6"],
    M6_WAIC = comparison$WAIC[comparison$model == "M6"],
    sewerage_IRR = sens_irr(fixed, "하수도보급률", "IRR"),
    sewerage_CrI_lower = sens_irr(fixed, "하수도보급률", "IRR_CrI_lower"),
    sewerage_CrI_upper = sens_irr(fixed, "하수도보급률", "IRR_CrI_upper"),
    foreign_IRR = sens_irr(fixed, "인구천명당외국인수", "IRR"),
    foreign_CrI_lower = sens_irr(fixed, "인구천명당외국인수", "IRR_CrI_lower"),
    foreign_CrI_upper = sens_irr(fixed, "인구천명당외국인수", "IRR_CrI_upper"),
    stringsAsFactors = FALSE
  )
}

window_cmp <- do.call(rbind, lapply(2011:2015, window_one))
write_csv_utf8(window_cmp, path("outputs", "generated", "window_sensitivity_comparison.csv"))
capture.output(sessionInfo(), file = path("outputs", "generated", "session_info_sensitivity_window.txt"))
message("Window sensitivity written to outputs/generated/window_sensitivity_comparison.csv")
