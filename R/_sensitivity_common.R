# Shared helpers for the supplementary adjacency/window sensitivity analyses.
# Sourced by R/06_sensitivity_window.R and R/07_sensitivity_knn.R only.
# Not part of the main locked pipeline; the FINAL model stays queen contiguity.
# All model fits use the FIXED six _T covariates (no automated selection).
# Ported from professor_pipeline_run05_FINAL_v2/R/01_refit_FINAL_v2.R.

suppressPackageStartupMessages({
  library(sf)
  library(spdep)
  library(INLA)
})

SENS_FINAL_COVARIATES <- c(
  "하수도보급률",
  "인구천명당외국인수",
  "인구천명당의료기관종사의사수",
  "재정자립도",
  "고령인구비율",
  "성비"
)
SENS_MODEL_COVARIATES <- paste0(SENS_FINAL_COVARIATES, "_T")

SENS_PC_BYM <- list(
  prec.unstruct = list(prior = "pc.prec", param = c(0.5, 0.01)),
  prec.spatial = list(prior = "pc.prec", param = c(0.5, 0.01))
)
SENS_PC_PREC <- list(prec = list(prior = "pc.prec", param = c(0.5, 0.01)))
sens_threads <- function() Sys.getenv("TYPHOID_INLA_NUM_THREADS", unset = "1:1")

sens_clean_region <- function(x) {
  x <- gsub("[[:space:]]+", "", as.character(x))
  x <- gsub("광역시", "시", x)
  x[x %in% c("경상북도군위군", "경북군위군", "대구광역시군위군", "대구시군위군", "대구군위군")] <- "대구시군위군"
  x[x == "인천시미추홀구"] <- "인천시남구"
  x
}

sens_read_spatial <- function(spatial_path) {
  sf::sf_use_s2(FALSE)
  shape <- sf::st_read(spatial_path, quiet = TRUE)
  shape$region <- sens_clean_region(shape$region)
  if (is.na(sf::st_crs(shape))) {
    sf::st_crs(shape) <- 5179
  } else if (sf::st_crs(shape)$epsg != 5179) {
    shape <- sf::st_transform(shape, 5179)
  }
  shape
}

# Identical to R/03_model_fit.R: M1-M6 with M6 = NB + BYM + RW1 + IID.
sens_formula_set <- function(model_covariates) {
  fixed <- paste(paste0("`", model_covariates, "`"), collapse = " + ")
  base_f <- paste0("cases ~ 1 + ", fixed, " + offset(log_pop)")
  list(
    M1 = base_f,
    M2 = paste(base_f, "+ f(idarea, model='besag', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_prec)"),
    M3 = paste(base_f, "+ f(idarea, model='bym', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_bym)"),
    M4 = paste(base_f, "+ f(idarea, model='bym', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_bym)", "+ f(idarea_time, model='iid', hyper=pc_prec)"),
    M5 = paste(base_f, "+ f(idarea, model='bym', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_bym)", "+ f(idtime, model='rw1', constr=TRUE, hyper=pc_prec)"),
    M6 = paste(base_f, "+ f(idarea, model='bym', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_bym)", "+ f(idtime, model='rw1', constr=TRUE, hyper=pc_prec)", "+ f(idarea_time, model='iid', hyper=pc_prec)")
  )
}

sens_fit_inla <- function(formula_string, panel, g) {
  pc_bym <- SENS_PC_BYM
  pc_prec <- SENS_PC_PREC
  fml <- as.formula(formula_string)
  environment(fml) <- environment()
  INLA::inla(
    formula = fml,
    family = "nbinomial",
    data = panel,
    control.compute = list(dic = TRUE, waic = TRUE, cpo = TRUE, return.marginals.predictor = TRUE),
    control.predictor = list(compute = TRUE, link = 1),
    control.inla = list(strategy = "adaptive"),
    verbose = FALSE,
    num.threads = sens_threads()
  )
}

# Build queen-contiguity inputs for an arbitrary panel subset; isolated
# (no-neighbour) districts are dropped and idarea re-derived from sorted region,
# identical to R/02_adjacency.R.
sens_build_queen <- function(panel, spatial_path, graph_out) {
  dir.create(dirname(graph_out), recursive = TRUE, showWarnings = FALSE)
  panel$region <- sens_clean_region(panel$region)
  shape <- sens_read_spatial(spatial_path)
  shape <- shape[shape$region %in% unique(panel$region), ]
  shape <- shape[order(shape$region), ]
  nb0 <- spdep::poly2nb(shape, snap = 0.01, queen = TRUE)
  isolated_idx <- which(spdep::card(nb0) == 0)
  isolated_regions <- if (length(isolated_idx)) shape$region[isolated_idx] else character()
  if (length(isolated_idx)) shape <- shape[-isolated_idx, ]
  shape <- shape[order(shape$region), ]
  shape$idarea <- seq_len(nrow(shape))
  lookup <- data.frame(region = shape$region, idarea = shape$idarea, stringsAsFactors = FALSE)

  nb <- spdep::poly2nb(shape, snap = 0.01, queen = TRUE)
  spdep::nb2INLA(graph_out, nb)
  listw <- spdep::nb2listw(nb, style = "W", zero.policy = TRUE)
  g <- INLA::inla.read.graph(graph_out)

  keep <- panel[panel$region %in% shape$region, setdiff(names(panel), c("idarea", "idtime", "idarea_time")), drop = FALSE]
  keep <- merge(keep, lookup, by = "region")
  keep <- keep[order(keep$idarea, keep$year), ]
  keep$idtime <- match(keep$year, sort(unique(keep$year)))
  keep$idarea_time <- seq_len(nrow(keep))
  rownames(keep) <- NULL

  summary <- data.frame(
    input_districts = length(unique(panel$region)),
    retained_districts = nrow(shape),
    removed_isolated_districts = length(isolated_regions),
    retained_district_years = nrow(keep),
    retained_total_cases = sum(keep$cases, na.rm = TRUE),
    year_min = min(keep$year),
    year_max = max(keep$year),
    subgraph_count = spdep::n.comp.nb(nb)$nc,
    min_neighbours = min(spdep::card(nb)),
    max_neighbours = max(spdep::card(nb)),
    stringsAsFactors = FALSE
  )
  list(panel = keep, shape = shape, nb = nb, listw = listw, g = g, summary = summary, isolated_regions = isolated_regions)
}

# Symmetric K-nearest-neighbour adjacency from district centroids (S6 only).
sens_build_knn <- function(shape, K, graph_out) {
  dir.create(dirname(graph_out), recursive = TRUE, showWarnings = FALSE)
  coords <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(shape)))
  nb <- spdep::knn2nb(spdep::knearneigh(coords, k = K), sym = TRUE)
  spdep::nb2INLA(graph_out, nb)
  listw <- spdep::nb2listw(nb, style = "W", zero.policy = TRUE)
  g <- INLA::inla.read.graph(graph_out)
  list(nb = nb, listw = listw, g = g)
}

sens_extract_fixed <- function(fit, model = "M6") {
  fx <- fit$summary.fixed
  fx <- fx[rownames(fx) != "(Intercept)", , drop = FALSE]
  data.frame(
    model = model,
    variable = rownames(fx),
    variable_clean = sub("_T$", "", rownames(fx)),
    IRR = exp(fx$mean),
    IRR_CrI_lower = exp(fx$`0.025quant`),
    IRR_CrI_upper = exp(fx$`0.975quant`),
    CrI_includes_1 = exp(fx$`0.025quant`) <= 1 & exp(fx$`0.975quant`) >= 1,
    stringsAsFactors = FALSE
  )
}

# District residual Moran's I (raw residual summed, Pearson residual averaged).
sens_area_moran <- function(fit, panel, listw, model_label) {
  fitted <- as.numeric(fit$summary.fitted.values$mean)
  residual_raw <- panel$cases - fitted
  residual_pearson <- residual_raw / sqrt(pmax(fitted, 1e-9))
  raw_by <- tapply(residual_raw, panel$idarea, sum, na.rm = TRUE)
  pear_by <- tapply(residual_pearson, panel$idarea, mean, na.rm = TRUE)
  ord <- order(as.integer(names(raw_by)))
  raw_m <- spdep::moran.test(as.numeric(raw_by[ord]), listw, zero.policy = TRUE)
  pear_m <- spdep::moran.test(as.numeric(pear_by[ord]), listw, zero.policy = TRUE)
  data.frame(
    model = model_label,
    diagnostic = c("raw residual Moran I", "Pearson residual Moran I"),
    Moran_I = c(as.numeric(raw_m$estimate[["Moran I statistic"]]), as.numeric(pear_m$estimate[["Moran I statistic"]])),
    expected_I = c(as.numeric(raw_m$estimate[["Expectation"]]), as.numeric(pear_m$estimate[["Expectation"]])),
    p_value = c(raw_m$p.value, pear_m$p.value),
    stringsAsFactors = FALSE
  )
}

# Per-district spatial RE/RR with elevated flag (CrI lower on log scale > 0).
sens_extract_spatial_re <- function(fit, shape, model = "M6") {
  re <- fit$summary.random$idarea[seq_len(nrow(shape)), , drop = FALSE]
  out <- data.frame(
    district = shape$region,
    province = sub("^(.*?[도시]).*", "\\1", shape$region, perl = TRUE),
    idarea = shape$idarea,
    model = model,
    spatial_RE = re$mean,
    spatial_RE_CrI_lower = re$`0.025quant`,
    spatial_RE_CrI_upper = re$`0.975quant`,
    posterior_spatial_RR = exp(re$mean),
    posterior_spatial_RR_CrI_lower = exp(re$`0.025quant`),
    posterior_spatial_RR_CrI_upper = exp(re$`0.975quant`),
    elevated_posterior_spatial_rr = re$`0.025quant` > 0,
    stringsAsFactors = FALSE
  )
  out[order(-out$spatial_RE), ]
}

sens_irr <- function(fixed, clean_name, field) fixed[[field]][fixed$variable_clean == clean_name]
