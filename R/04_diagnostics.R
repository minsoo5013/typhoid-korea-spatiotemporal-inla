#!/usr/bin/env Rscript

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

make_generated_tables <- function() {
  rds_path <- path("outputs", "generated", "INLA_M1_M6_final_contiguity.rds")
  panel_path <- path("outputs", "generated", "panel_inla_6var_contiguity.csv")
  if (!file.exists(rds_path)) {
    stop("Missing generated INLA fit. Run R/03_model_fit.R or use --validate-reference for no-refit validation.")
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

  if (!is.null(m6$summary.random$idarea)) {
    n_area <- length(unique(panel$idarea))
    re <- m6$summary.random$idarea[seq_len(n_area), , drop = FALSE]
    regions <- unique(panel[order(panel$idarea), c("idarea", "region")])
    spatial <- data.frame(
      idarea = regions$idarea,
      region = regions$region,
      spatial_RE = re$mean,
      spatial_RE_CrI_lower = re$`0.025quant`,
      spatial_RE_CrI_upper = re$`0.975quant`,
      spatial_RR = exp(re$mean),
      spatial_RR_CrI_lower = exp(re$`0.025quant`),
      spatial_RR_CrI_upper = exp(re$`0.975quant`),
      elevated_posterior_spatial_RR = re$`0.025quant` > 0,
      stringsAsFactors = FALSE
    )
    write_csv_utf8(spatial, path("outputs", "generated", "spatial_RE_all_6var.csv"))
  }

  capture.output(sessionInfo(), file = path("outputs", "generated", "session_info_diagnostics.txt"))
  message("Generated diagnostic tables written to outputs/generated/.")
}

if ("--validate-reference" %in% args) {
  validate_reference()
} else {
  make_generated_tables()
}
