#!/usr/bin/env Rscript

# Reproduces: S3 (M1-M6 DIC/WAIC), Table 2 fixed-effect IRRs, residual Moran's I
#   (raw incidence pre-model, M6 raw + Pearson), per-district spatial RE/RR, and
#   the S4 elevated posterior spatial-RR ranking. Fixed 6 _T covariates only.
# Reference-of-record input: copy outputs/reference/INLA_M1_M6_final_contiguity_archived_reference.rds
#   to outputs/generated/INLA_M1_M6_final_contiguity.rds, then use the panel from
#   R/01-R/02 and queen-contiguity adjacency rebuilt from data/spatial/final.{gpkg,shp}.
# Output: outputs/generated/{Table_S_model_comparison_M1_M6_diagnostics, Table2_fixed_effects_6var_diagnostics,
#   residual_moran, spatial_RE_all_6var, Table_S_elevated_spatial_RR_districts}.csv
#   (reference equivalents under outputs/reference/; --validate-reference checks
#   the archived-fit/reference-CSV locked values with no refit).
# A full R/03 re-fit is an approximate reproduction check and may differ at the
# second to third decimal place because of INLA numerical non-determinism.
# Ported from professor_pipeline_run05_FINAL_v2/R/01_refit_FINAL_v2.R (no automated selection).

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
args <- commandArgs(trailingOnly = TRUE)

dir.create(path("outputs", "generated"), recursive = TRUE, showWarnings = FALSE)

validate_reference <- function() {
  final_path <- path("outputs", "reference", "FINAL_all_values_for_manuscript.csv")
  if (!file.exists(final_path)) stop("Missing outputs/reference/FINAL_all_values_for_manuscript.csv")
  values <- read_csv_utf8(final_path)

  get_value <- function(section, item) {
    hit <- values$value[values$section == section & values$item == item]
    if (length(hit) != 1) return(NA_character_)
    hit
  }

  checks <- data.frame(
    check = c(
      "districts",
      "district-years",
      "total cases",
      "final model",
      "DIC",
      "WAIC",
      "raw incidence Moran I",
      "M6 raw residual Moran I",
      "M6 Pearson residual Moran I",
      "elevated posterior spatial relative-risk districts",
      "Gyeongnam among elevated districts"
    ),
    expected = c(
      "223",
      "3122",
      "1202",
      "NB + BYM + RW1 + IID",
      "4196.36",
      "4198.66",
      "0.333",
      "-0.019, p=0.6341",
      "-0.060, p=0.8998",
      "14",
      "9"
    ),
    actual = c(
      get_value("main_headline", "districts"),
      get_value("main_headline", "district-years"),
      get_value("main_headline", "total cases"),
      get_value("main_headline", "final model"),
      get_value("main_headline", "DIC"),
      get_value("main_headline", "WAIC"),
      get_value("main_headline", "raw incidence Moran I"),
      get_value("main_headline", "M6 raw residual Moran I"),
      get_value("main_headline", "M6 Pearson residual Moran I"),
      get_value("main_headline", "elevated posterior spatial relative-risk districts"),
      get_value("main_headline", "Gyeongnam among elevated districts")
    ),
    stringsAsFactors = FALSE
  )

  checks$status <- ifelse(
    mapply(function(expected, actual) grepl(expected, actual, fixed = TRUE), checks$expected, checks$actual),
    "PASS",
    "FAIL"
  )

  out <- path("outputs", "generated", "reference_validation.csv")
  write_csv_utf8(checks, out)
  if (any(checks$status != "PASS")) {
    print(checks)
    stop("Reference validation failed. See outputs/generated/reference_validation.csv")
  }
  message("Reference validation passed: ", out)
}

# Region key cleaning, identical to R/01_data_prep.R and R/02_adjacency.R.
clean_region <- function(x) {
  x <- gsub("[[:space:]]+", "", as.character(x))
  x <- gsub("광역시", "시", x)
  x[x %in% c("경상북도군위군", "경북군위군", "대구광역시군위군", "대구시군위군", "대구군위군")] <- "대구시군위군"
  x[x == "인천시미추홀구"] <- "인천시남구"
  x
}

# District-level residual Moran's I for a fitted model, matching FINAL_v2:
# raw residual aggregated by sum, Pearson residual by mean, over district-years.
area_moran_rows <- function(fit, panel, listw, model_label) {
  fitted <- as.numeric(fit$summary.fitted.values$mean)
  residual_raw <- panel$cases - fitted
  residual_pearson <- residual_raw / sqrt(pmax(fitted, 1e-9))
  raw_by <- tapply(residual_raw, panel$idarea, sum, na.rm = TRUE)
  pear_by <- tapply(residual_pearson, panel$idarea, mean, na.rm = TRUE)
  ord <- order(as.integer(names(raw_by)))
  raw_vec <- as.numeric(raw_by[ord])
  pear_vec <- as.numeric(pear_by[ord])
  raw_m <- spdep::moran.test(raw_vec, listw, zero.policy = TRUE)
  pear_m <- spdep::moran.test(pear_vec, listw, zero.policy = TRUE)
  data.frame(
    model = model_label,
    diagnostic = c("raw residual Moran I", "Pearson residual Moran I"),
    Moran_I = c(as.numeric(raw_m$estimate[["Moran I statistic"]]), as.numeric(pear_m$estimate[["Moran I statistic"]])),
    expected_I = c(as.numeric(raw_m$estimate[["Expectation"]]), as.numeric(pear_m$estimate[["Expectation"]])),
    p_value = c(raw_m$p.value, pear_m$p.value),
    interpretation = ifelse(
      c(raw_m$p.value, pear_m$p.value) < 0.05,
      "Significant residual spatial autocorrelation",
      "Non-significant residual spatial autocorrelation"
    ),
    stringsAsFactors = FALSE
  )
}

# Pre-model raw incidence (crude rate) global Moran's I.
pre_moran_row <- function(panel, listw) {
  cases_by <- tapply(panel$cases, panel$idarea, sum, na.rm = TRUE)
  pop_by <- tapply(panel$population, panel$idarea, sum, na.rm = TRUE)
  ord <- order(as.integer(names(cases_by)))
  crude <- as.numeric(cases_by[ord]) / as.numeric(pop_by[ord]) * 100000
  m <- spdep::moran.test(crude, listw, zero.policy = TRUE)
  data.frame(
    model = "Pre-model",
    diagnostic = "raw incidence Global Moran I",
    Moran_I = as.numeric(m$estimate[["Moran I statistic"]]),
    expected_I = as.numeric(m$estimate[["Expectation"]]),
    p_value = m$p.value,
    interpretation = ifelse(m$p.value < 0.05, "Significant before adjustment", "Non-significant before adjustment"),
    stringsAsFactors = FALSE
  )
}

make_generated_tables <- function() {
  suppressPackageStartupMessages({
    library(sf)
    library(spdep)
    library(stringr)
  })
  rds_path <- path("outputs", "generated", "INLA_M1_M6_final_contiguity.rds")
  panel_path <- path("outputs", "generated", "panel_inla_6var_contiguity.csv")
  if (!file.exists(rds_path)) {
    stop("Missing INLA fit. Copy outputs/reference/INLA_M1_M6_final_contiguity_archived_reference.rds to outputs/generated/INLA_M1_M6_final_contiguity.rds for reference-of-record diagnostics, or use --validate-reference for no-refit validation. A fresh R/03 refit is approximate and may differ at the second to third decimal place.")
  }
  if (!file.exists(panel_path)) stop("Missing generated panel. Run R/01_data_prep.R and R/02_adjacency.R first.")

  fits <- readRDS(rds_path)
  panel <- read_csv_utf8(panel_path)
  m6 <- fits[["M6"]]
  if (is.null(m6)) stop("The generated RDS does not contain M6.")

  final_covariates <- paste0(c(
    "하수도보급률",
    "인구천명당외국인수",
    "인구천명당의료기관종사의사수",
    "재정자립도",
    "고령인구비율",
    "성비"
  ), "_T")

  # --- S3: M1-M6 DIC/WAIC comparison ---
  comparison <- do.call(rbind, lapply(names(fits), function(model_name) {
    fit <- fits[[model_name]]
    data.frame(
      model = model_name,
      DIC = as.numeric(fit$dic$dic),
      WAIC = as.numeric(fit$waic$waic),
      stringsAsFactors = FALSE
    )
  }))
  comparison$DeltaDIC <- comparison$DIC - min(comparison$DIC, na.rm = TRUE)
  comparison <- comparison[, c("model", "DIC", "DeltaDIC", "WAIC")]
  write_csv_utf8(comparison, path("outputs", "generated", "Table_S_model_comparison_M1_M6_diagnostics.csv"))

  # --- Table 2: fixed-effect IRRs ---
  fe <- m6$summary.fixed[final_covariates, , drop = FALSE]
  fixed <- data.frame(
    model = "M6",
    variable = rownames(fe),
    beta_mean = fe$mean,
    beta_CrI_lower = fe$`0.025quant`,
    beta_CrI_upper = fe$`0.975quant`,
    IRR = exp(fe$mean),
    IRR_CrI_lower = exp(fe$`0.025quant`),
    IRR_CrI_upper = exp(fe$`0.975quant`),
    CrI_includes_1 = exp(fe$`0.025quant`) <= 1 & exp(fe$`0.975quant`) >= 1,
    stringsAsFactors = FALSE
  )
  write_csv_utf8(fixed, path("outputs", "generated", "Table2_fixed_effects_6var_diagnostics.csv"))

  # --- Queen-contiguity spatial weights, ordered by idarea, for residual Moran ---
  spatial_path <- if (file.exists(path("data", "spatial", "final.gpkg"))) {
    path("data", "spatial", "final.gpkg")
  } else {
    path("data", "spatial", "final.shp")
  }
  if (!file.exists(spatial_path)) stop("Missing spatial file under data/spatial/ (required for residual Moran's I).")

  panel$region <- clean_region(panel$region)
  lookup <- unique(panel[, c("region", "idarea")])
  lookup <- lookup[order(lookup$idarea), ]

  sf::sf_use_s2(FALSE)
  shape <- sf::st_read(spatial_path, quiet = TRUE)
  shape$region <- clean_region(shape$region)
  shape <- shape[shape$region %in% lookup$region, ]
  if (is.na(sf::st_crs(shape))) {
    sf::st_crs(shape) <- 5179
  } else if (sf::st_crs(shape)$epsg != 5179) {
    shape <- sf::st_transform(shape, 5179)
  }
  shape <- shape[match(lookup$region, shape$region), ]   # order rows by idarea
  shape$idarea <- lookup$idarea
  nb <- spdep::poly2nb(shape, snap = 0.01, queen = TRUE)
  listw <- spdep::nb2listw(nb, style = "W", zero.policy = TRUE)

  # --- Residual Moran's I: pre-model crude incidence, M1, M6 ---
  residual <- rbind(
    pre_moran_row(panel, listw),
    area_moran_rows(fits[["M1"]], panel, listw, "M1"),
    area_moran_rows(m6, panel, listw, "M6")
  )
  write_csv_utf8(residual, path("outputs", "generated", "residual_moran.csv"))

  # --- Spatial RE / RR per district (FINAL_v2 schema, consumed by python/figure2) ---
  n_area <- nrow(lookup)
  re <- m6$summary.random$idarea[seq_len(n_area), , drop = FALSE]
  spatial <- data.frame(
    district = lookup$region,
    province = str_extract(lookup$region, "^(.*?[도시])"),
    idarea = lookup$idarea,
    model = "M6",
    spatial_RE = re$mean,
    spatial_RE_sd = re$sd,
    spatial_RE_CrI_lower = re$`0.025quant`,
    spatial_RE_CrI_upper = re$`0.975quant`,
    posterior_spatial_RR = exp(re$mean),
    posterior_spatial_RR_CrI_lower = exp(re$`0.025quant`),
    posterior_spatial_RR_CrI_upper = exp(re$`0.975quant`),
    elevated_posterior_spatial_rr = re$`0.025quant` > 0,
    stringsAsFactors = FALSE
  )
  spatial <- spatial[order(-spatial$spatial_RE), ]
  write_csv_utf8(spatial, path("outputs", "generated", "spatial_RE_all_6var.csv"))

  # --- S4: elevated posterior spatial RR ranking ---
  elevated <- spatial[spatial$elevated_posterior_spatial_rr, ]
  elevated <- data.frame(
    rank = seq_len(nrow(elevated)),
    district = elevated$district,
    province = elevated$province,
    idarea = elevated$idarea,
    spatial_RE_log_scale = elevated$spatial_RE,
    spatial_RE_CrI_lower_log_scale = elevated$spatial_RE_CrI_lower,
    spatial_RE_CrI_upper_log_scale = elevated$spatial_RE_CrI_upper,
    posterior_spatial_RR = elevated$posterior_spatial_RR,
    posterior_spatial_RR_CrI_lower = elevated$posterior_spatial_RR_CrI_lower,
    posterior_spatial_RR_CrI_upper = elevated$posterior_spatial_RR_CrI_upper,
    label_for_outputs = "elevated_posterior_spatial_relative_risk",
    extraction_rule = "spatial random effect 95% CrI lower bound on log scale > 0",
    stringsAsFactors = FALSE
  )
  write_csv_utf8(elevated, path("outputs", "generated", "Table_S_elevated_spatial_RR_districts.csv"))

  capture.output(sessionInfo(), file = path("outputs", "generated", "session_info_diagnostics.txt"))
  message("Generated diagnostic tables written to outputs/generated/.")
}

if ("--validate-reference" %in% args) {
  validate_reference()
} else {
  make_generated_tables()
}
