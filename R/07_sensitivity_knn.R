#!/usr/bin/env Rscript

# Reproduces: S6 KNN adjacency sensitivity (K=2-7) on the SAME locked 223-district
#   panel. SUPPLEMENTARY SENSITIVITY ONLY — the FINAL adjacency is queen contiguity.
#   Fixed six _T covariates; M6 (NB + BYM + RW1 + IID) only; no automated selection.
# Input: outputs/generated/panel_inla_6var_contiguity.csv (from 01-02) and
#   data/spatial/final.{gpkg,shp}; centroids drive symmetric KNN graphs.
# Output: outputs/generated/S6_KNN_adjacency_sensitivity.csv (+ per-K files)
#   corresponding to outputs/reference/S6_KNN_adjacency_sensitivity_recovered_final.csv.
# Ported from professor_pipeline_run05_FINAL_v2/R/01_refit_FINAL_v2.R KNN loop.

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

out_dir <- path("outputs", "generated", "sensitivity", "knn")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Reuse the queen-retained 223-district panel and shape (idarea-consistent).
main <- sens_build_queen(panel_all, spatial_path, file.path(out_dir, "spatial_graph_main_contiguity.inla"))
m6_form <- sens_formula_set(SENS_MODEL_COVARIATES)[["M6"]]

knn_one <- function(K) {
  k_out <- file.path(out_dir, paste0("K", K))
  dir.create(k_out, recursive = TRUE, showWarnings = FALSE)
  adj <- sens_build_knn(main$shape, K, file.path(k_out, paste0("spatial_graph_K", K, ".inla")))
  fit <- sens_fit_inla(m6_form, main$panel, adj$g)

  fixed <- sens_extract_fixed(fit, paste0("K", K))
  residual <- sens_area_moran(fit, main$panel, adj$listw, paste0("K", K))
  spatial <- sens_extract_spatial_re(fit, main$shape, paste0("K", K))
  elevated <- spatial[spatial$elevated_posterior_spatial_rr, ]
  write_csv_utf8(fixed, file.path(k_out, paste0("Table2_fixed_effects_6var_K", K, ".csv")))
  write_csv_utf8(residual, file.path(k_out, paste0("residual_moran_K", K, ".csv")))
  write_csv_utf8(spatial, file.path(k_out, paste0("spatial_RE_all_6var_K", K, ".csv")))

  raw_idx <- residual$diagnostic == "raw residual Moran I"
  pear_idx <- residual$diagnostic == "Pearson residual Moran I"
  data.frame(
    K = K,
    N = nrow(main$panel),
    districts = length(unique(main$panel$region)),
    cases = sum(main$panel$cases),
    DIC = as.numeric(fit$dic$dic),
    WAIC = as.numeric(fit$waic$waic),
    raw_residual_Morans_I = residual$Moran_I[raw_idx],
    raw_residual_Morans_p = residual$p_value[raw_idx],
    pearson_residual_Morans_I = residual$Moran_I[pear_idx],
    pearson_residual_Morans_p = residual$p_value[pear_idx],
    sewerage_IRR = sens_irr(fixed, "하수도보급률", "IRR"),
    sewerage_CrI_lower = sens_irr(fixed, "하수도보급률", "IRR_CrI_lower"),
    sewerage_CrI_upper = sens_irr(fixed, "하수도보급률", "IRR_CrI_upper"),
    foreign_IRR = sens_irr(fixed, "인구천명당외국인수", "IRR"),
    foreign_CrI_lower = sens_irr(fixed, "인구천명당외국인수", "IRR_CrI_lower"),
    foreign_CrI_upper = sens_irr(fixed, "인구천명당외국인수", "IRR_CrI_upper"),
    elevated_posterior_spatial_RR_n = nrow(elevated),
    gyeongnam_count = sum(grepl("경상남도", elevated$district)),
    note = "KNN sensitivity on the locked 223-district queen-retained panel.",
    stringsAsFactors = FALSE
  )
}

knn_cmp <- do.call(rbind, lapply(2:7, knn_one))
write_csv_utf8(knn_cmp, path("outputs", "generated", "S6_KNN_adjacency_sensitivity.csv"))
capture.output(sessionInfo(), file = path("outputs", "generated", "session_info_sensitivity_knn.txt"))
message("KNN sensitivity written to outputs/generated/S6_KNN_adjacency_sensitivity.csv")
