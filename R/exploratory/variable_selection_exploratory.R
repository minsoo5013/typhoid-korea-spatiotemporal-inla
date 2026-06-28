# EXPLORATORY ONLY — used to inspect candidate predictors.
# NOT used for the final analysis. The final model uses a fixed, pre-specified
# set of six covariates (see R/03_model_fit.R).
#
# This script performs automated candidate screening, forward selection, and
# VIF-based pruning over a wide candidate pool. It is preserved verbatim for
# transparency and audit only. It is NOT sourced by the public release pipeline
# (R/01_data_prep.R through R/05_figures.R) and does NOT define the manuscript
# model. The six covariates reported in the manuscript were pre-specified on
# epidemiological grounds (relevance, data availability, data quality,
# interpretability, parsimony), not chosen by this procedure.
#
# Original path: professor_style_typhoid_selection_pipeline/R/01_professor_style_variable_selection.R
# Paths and inputs below are historical and are not guaranteed to resolve in this
# public repository layout.
# ---------------------------------------------------------------------------

PARAMS <- list(
  PVAL_SCREEN = 0.20,
  VIF_THRESHOLD = 10,
  MIN_OBS = 20,
  COV_RATIO = 0.85,
  TARGET_FWD = 8,
  MAX_ITER = 400,
  SNAP = 0.01,
  NUM_THREADS = "1:1"
)

get_root <- function() {
  cwd <- normalizePath(getwd(), mustWork = TRUE)
  if (basename(cwd) == "professor_style_typhoid_selection_pipeline") return(cwd)
  p <- file.path(cwd, "professor_style_typhoid_selection_pipeline")
  if (dir.exists(p)) return(normalizePath(p, mustWork = TRUE))
  stop("Run from project root or professor_style_typhoid_selection_pipeline.")
}

PIPELINE_ROOT <- get_root()
PROJECT_ROOT <- normalizePath(file.path(PIPELINE_ROOT, ".."), mustWork = TRUE)
p <- function(...) file.path(PIPELINE_ROOT, ...)
project_p <- function(...) file.path(PROJECT_ROOT, ...)

dir_create <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

read_csv_safe <- function(path) {
  for (enc in c("UTF-8", "UTF-8-BOM", "CP949", "EUC-KR")) {
    x <- tryCatch(
      utils::read.csv(path, fileEncoding = enc, check.names = FALSE, stringsAsFactors = FALSE),
      error = function(e) NULL
    )
    if (!is.null(x)) return(x)
  }
  stop("Could not read CSV: ", path)
}

write_csv_utf8 <- function(x, path) {
  dir_create(dirname(path))
  x[] <- lapply(x, function(col) if (is.character(col)) enc2utf8(col) else col)
  utils::write.csv(x, path, row.names = FALSE, fileEncoding = "UTF-8")
  invisible(path)
}

clean_region <- function(x) {
  x <- gsub("\\s+", "", as.character(x))
  ifelse(x == "인천시미추홀구", "인천시남구", x)
}

candidate_category <- function(v) {
  if (grepl("상수도|하수도|수도|식품안정", v)) return("water quality / sewerage")
  if (grepl("손씻|칫솔|위생", v)) return("hygiene / health behaviour")
  if (grepl("인구밀도|도시지역|도시", v)) return("land use / urbanisation")
  if (grepl("외국인|전입|전출|이동|통근|대중교통|다문화|순이동", v)) return("mobility / urbanisation")
  if (grepl("의료|의사|병상|보건소|응급실|요양기관", v)) return("healthcare access")
  if (grepl("재정|복지|사업체|종사자|고용|실업|수급", v)) return("socioeconomic")
  if (grepl("고령|노인|성비|1인가구|독거", v)) return("vulnerability / population structure")
  "other"
}

assign_theory_dir <- function(v) {
  protection <- c("하수도보급률", "상수도보급률", "식품안정성확보율_조율")
  risk <- c(
    "인구천명당외국인수", "인구밀도", "도시지역인구비율", "총전입", "총전출",
    "시도간전입", "시도간전출", "시도내이동_시군구간전입", "대중교통이용인원_전체",
    "다문화혼인비중", "다문화출생비율", "거주지내통근취업자", "순이동",
    "인구천명당의료기관종사의사수", "인구천명당의료기관병상수", "병상수_계",
    "의사수", "요양기관수_보건소", "기준시간내의료이용률_응급실", "실업률"
  )
  if (v %in% protection) return("protective")
  if (v %in% risk) return("risk")
  "neutral"
}

unit_for_variable <- function(v) {
  if (grepl("보급률|비율|비중|재정|고령|실업|고용|손씻|칫솔|식품안정|의료이용률|확보율", v)) return("%")
  if (v == "성비") return("males per 100 females")
  if (grepl("인구천명당외국인", v)) return("persons per 1,000 population")
  if (grepl("인구천명당의료기관종사의사", v)) return("physicians per 1,000 population")
  if (grepl("인구천명당의료기관병상", v)) return("beds per 1,000 population")
  if (grepl("인구천명당사업체", v)) return("businesses per 1,000 population")
  if (grepl("인구천명당종사자", v)) return("workers per 1,000 population")
  if (v == "인구밀도") return("persons per km2")
  if (grepl("전입|전출|이동|통근|대중교통|노인인구|병상수|의사수|요양기관", v)) return("count")
  "source unit"
}

is_percent_or_standard_rate <- function(v) {
  unit_for_variable(v) %in% c("%", "persons per 1,000 population", "physicians per 1,000 population", "beds per 1,000 population", "businesses per 1,000 population", "workers per 1,000 population", "males per 100 females")
}

is_forced_variable <- function(v) {
  v %in% c("성비", "고령인구비율", "도시지역인구비율", "순이동")
}

read_inputs <- function() {
  panel_path <- project_p("expanded_panel_typhoid_candidate_pool_pipeline", "outputs", "tables", "analysis_panel.csv")
  registry_path <- project_p("expanded_panel_typhoid_candidate_pool_pipeline", "expanded_panel_typhoid_candidate_registry_curated_v1.csv")
  panel <- read_csv_safe(panel_path)
  panel$region <- clean_region(panel$region)
  panel$log_pop <- log(panel$population + 1)
  if (all(c("총전입", "총전출") %in% names(panel))) {
    panel$순이동 <- panel$총전입 - panel$총전출
  }
  registry <- read_csv_safe(registry_path)
  list(panel = panel, registry = registry, panel_path = panel_path, registry_path = registry_path)
}

read_spatial <- function() {
  candidates <- c(
    project_p("reproducible_code_package", "data", "spatial", "final.gpkg"),
    # Historical exploratory path omitted from the public release.
    project_p("reproducible_code_package", "data", "spatial", "final.shp")
  )
  hit <- candidates[file.exists(candidates)][1]
  if (is.na(hit)) stop("Spatial input not found.")
  sf::st_read(hit, quiet = TRUE)
}

build_contiguity <- function(panel) {
  shape <- read_spatial()
  shape$region <- clean_region(shape$region)
  shape <- shape[shape$region %in% unique(panel$region), ]
  nb0 <- spdep::poly2nb(shape, snap = PARAMS$SNAP, queen = TRUE)
  isolated <- which(spdep::card(nb0) == 0)
  isolated_regions <- if (length(isolated)) shape$region[isolated] else character()
  if (length(isolated)) {
    shape <- shape[-isolated, ]
  }
  panel_keep <- panel[panel$region %in% shape$region, , drop = FALSE]
  nb <- spdep::poly2nb(shape, snap = PARAMS$SNAP, queen = TRUE)
  region_lookup <- data.frame(region = sort(unique(shape$region)), stringsAsFactors = FALSE)
  region_lookup$idarea <- seq_len(nrow(region_lookup))
  shape <- merge(shape, region_lookup, by = "region", all.x = TRUE, sort = FALSE)
  shape <- shape[order(shape$idarea), ]
  nb <- spdep::poly2nb(shape, snap = PARAMS$SNAP, queen = TRUE)
  listw <- spdep::nb2listw(nb, style = "W", zero.policy = TRUE)
  graph_file <- p("outputs", "tables", "contiguity_poly2nb_snap001_graph.inla")
  spdep::nb2INLA(graph_file, nb)
  graph <- INLA::inla.read.graph(graph_file)
  write_csv_utf8(
    data.frame(removed_isolated_region = isolated_regions, reason = "poly2nb contiguity no-neighbour region removed", stringsAsFactors = FALSE),
    p("outputs", "tables", "contiguity_isolated_removed.csv")
  )
  write_csv_utf8(
    data.frame(
      snap = PARAMS$SNAP,
      original_districts = length(unique(panel$region)),
      removed_isolated_districts = length(isolated_regions),
      retained_districts = length(unique(panel_keep$region)),
      retained_district_years = nrow(panel_keep),
      retained_cases = sum(panel_keep$cases),
      subgraph_count_after_island_removal = spdep::n.comp.nb(nb)$nc,
      graph_file = graph_file,
      stringsAsFactors = FALSE
    ),
    p("outputs", "tables", "contiguity_adjacency_summary.csv")
  )
  list(shape = shape, panel = panel_keep, nb = nb, listw = listw, graph = graph, isolated_regions = isolated_regions)
}

make_candidate_inventory <- function(panel, registry) {
  base_cols <- c("region", "year", "cases", "population", "crude_rate", "log_pop", "sido", "sigungu")
  vars <- setdiff(names(panel), base_cols)
  rows <- lapply(vars, function(v) {
    x <- panel[[v]]
    n_non_missing <- sum(!is.na(x))
    data.frame(
      variable_name = v,
      category = candidate_category(v),
      theory_dir = assign_theory_dir(v),
      unit = unit_for_variable(v),
      n_non_missing = n_non_missing,
      coverage_ratio = n_non_missing / nrow(panel),
      zero_percent = if (is.numeric(x)) mean(x == 0, na.rm = TRUE) * 100 else NA_real_,
      n_unique = length(unique(x[!is.na(x)])),
      forced = is_forced_variable(v),
      include_auto_pool = n_non_missing >= PARAMS$MIN_OBS &&
        (n_non_missing / nrow(panel)) >= PARAMS$COV_RATIO &&
        length(unique(x[!is.na(x)])) > 1,
      exclusion_reason = "",
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out$exclusion_reason <- ifelse(out$n_non_missing < PARAMS$MIN_OBS, "below_MIN_OBS",
    ifelse(out$coverage_ratio < PARAMS$COV_RATIO, "below_COV_RATIO",
      ifelse(out$n_unique <= 1, "constant_or_single_unique", "")
    )
  )
  out$registry_decision <- NA_character_
  if (!is.null(registry) && "canonical_variable" %in% names(registry)) {
    idx <- match(out$variable_name, registry$canonical_variable)
    out$registry_decision <- registry$decision[idx]
  }
  write_csv_utf8(out, p("outputs", "tables", "candidate_pool_auto_inventory.csv"))
  out
}

binary_form <- function(x) {
  x <- as.numeric(x)
  zp <- mean(x == 0, na.rm = TRUE) * 100
  if (is.finite(zp) && zp > 20) {
    return(factor(ifelse(x > 0, "present", "absent"), levels = c("absent", "present")))
  }
  med <- stats::median(x, na.rm = TRUE)
  factor(ifelse(x > med, "high", "low"), levels = c("low", "high"))
}

quantile_form <- function(x, probs, labels) {
  x <- as.numeric(x)
  qs <- unique(as.numeric(stats::quantile(x, probs = probs, na.rm = TRUE, type = 7)))
  if (length(qs) < length(labels) + 1L) return(NULL)
  cut(x, breaks = qs, include.lowest = TRUE, labels = labels)
}

make_form_value <- function(x, form, variable_name) {
  x <- as.numeric(x)
  if (form == "raw") return(x)
  if (form == "log1p") return(log1p(pmax(0, x)))
  if (form == "binary") return(binary_form(x))
  if (form == "T3") return(quantile_form(x, c(0, 1 / 3, 2 / 3, 1), c("T1", "T2", "T3")))
  if (form == "Q4") return(quantile_form(x, c(0, 0.25, 0.5, 0.75, 1), c("Q1", "Q2", "Q3", "Q4")))
  stop("Unknown form: ", form)
}

allowed_forms <- function(variable_name, x) {
  forms <- c("raw", "log1p", "binary", "T3", "Q4")
  if (variable_name == "성비") return("raw")
  if (is_percent_or_standard_rate(variable_name)) {
    forms <- setdiff(forms, "log1p")
  }
  forms
}

fit_univariate_form <- function(panel, variable_name, form) {
  skipped_row <- function(status, reason) {
    data.frame(
      variable_name = variable_name,
      form = form,
      status = status,
      skip_reason = reason,
      n = NA_integer_,
      AIC = NA_real_,
      p_value = NA_real_,
      representative_term = NA_character_,
      coefficient = NA_real_,
      CI_lower = NA_real_,
      CI_upper = NA_real_,
      IRR = NA_real_,
      IRR_CI_lower = NA_real_,
      IRR_CI_upper = NA_real_,
      observed_direction = NA_character_,
      stringsAsFactors = FALSE
    )
  }
  value <- make_form_value(panel[[variable_name]], form, variable_name)
  if (is.null(value)) {
    return(skipped_row("skipped", "duplicate_quantile_breaks"))
  }
  if (is.factor(value) && length(unique(value[!is.na(value)])) < 2) {
    return(skipped_row("skipped", "degenerate_factor"))
  }
  if (is.numeric(value) && stats::sd(value, na.rm = TRUE) == 0) {
    return(skipped_row("skipped", "zero_variance"))
  }
  d <- data.frame(cases = panel$cases, log_pop = panel$log_pop, x = value)
  d <- d[stats::complete.cases(d), , drop = FALSE]
  if (nrow(d) < PARAMS$MIN_OBS) {
    return(skipped_row("skipped", "below_MIN_OBS_after_form"))
  }
  fit <- tryCatch(MASS::glm.nb(cases ~ x + offset(log_pop), data = d, control = glm.control(maxit = PARAMS$MAX_ITER)), error = function(e) e)
  if (inherits(fit, "error")) {
    return(skipped_row("failed", conditionMessage(fit)))
  }
  null_fit <- tryCatch(MASS::glm.nb(cases ~ 1 + offset(log_pop), data = d, control = glm.control(maxit = PARAMS$MAX_ITER)), error = function(e) e)
  lrt_p <- NA_real_
  if (!inherits(null_fit, "error")) {
    lrt <- tryCatch(stats::anova(null_fit, fit, test = "Chisq"), error = function(e) NULL)
    if (!is.null(lrt)) lrt_p <- lrt$`Pr(Chi)`[2]
  }
  coef_tab <- summary(fit)$coefficients
  terms <- rownames(coef_tab)
  terms <- terms[terms != "(Intercept)"]
  rep_term <- terms[length(terms)]
  coef <- coef_tab[rep_term, "Estimate"]
  se <- coef_tab[rep_term, "Std. Error"]
  wald_p <- coef_tab[rep_term, "Pr(>|z|)"]
  data.frame(
    variable_name = variable_name,
    form = form,
    status = "fitted",
    skip_reason = "",
    n = nrow(d),
    AIC = stats::AIC(fit),
    p_value = ifelse(is.finite(lrt_p), lrt_p, wald_p),
    representative_term = rep_term,
    coefficient = coef,
    CI_lower = coef - 1.96 * se,
    CI_upper = coef + 1.96 * se,
    IRR = exp(coef),
    IRR_CI_lower = exp(coef - 1.96 * se),
    IRR_CI_upper = exp(coef + 1.96 * se),
    observed_direction = ifelse(coef > 0, "positive", ifelse(coef < 0, "negative", "null")),
    stringsAsFactors = FALSE
  )
}

run_form_screening <- function(panel, inventory) {
  pool <- inventory[inventory$include_auto_pool, ]
  rows <- list()
  k <- 1L
  for (v in pool$variable_name) {
    forms <- allowed_forms(v, panel[[v]])
    for (form in forms) {
      rows[[k]] <- fit_univariate_form(panel, v, form)
      k <- k + 1L
    }
  }
  screening <- do.call(rbind, rows)
  screening <- merge(
    screening,
    inventory[, c("variable_name", "category", "theory_dir", "unit", "forced", "zero_percent", "coverage_ratio")],
    by = "variable_name",
    all.x = TRUE,
    sort = FALSE
  )
  screening$selected_form <- FALSE
  form_rank <- c(raw = 1, log1p = 2, binary = 3, T3 = 4, Q4 = 5)
  selected <- lapply(split(screening[screening$status == "fitted", ], screening$variable_name[screening$status == "fitted"]), function(df) {
    df$form_rank <- form_rank[df$form]
    df <- df[order(df$p_value, df$form_rank, df$AIC), ]
    df[1, , drop = FALSE]
  })
  selected_df <- do.call(rbind, selected)
  selected_df$selected_form <- TRUE
  screening$selected_form <- paste(screening$variable_name, screening$form) %in% paste(selected_df$variable_name, selected_df$form)
  selected_df$passes_pval_screen <- selected_df$p_value < PARAMS$PVAL_SCREEN
  selected_df$direction_status <- ifelse(
    selected_df$theory_dir == "risk" & selected_df$observed_direction == "negative", "reverse",
    ifelse(selected_df$theory_dir == "protective" & selected_df$observed_direction == "positive", "reverse", "allowed")
  )
  selected_df$reverse_removed <- selected_df$direction_status == "reverse" & !selected_df$forced
  write_csv_utf8(screening, p("outputs", "tables", "Table1_candidate_univariate.csv"))
  write_csv_utf8(selected_df, p("outputs", "tables", "form_map.csv"))
  selected_df
}

model_matrix_selected <- function(panel, vars, form_map, z_numeric = FALSE) {
  d <- panel[, c("cases", "log_pop", "region", "year"), drop = FALSE]
  term_map <- data.frame()
  for (i in seq_along(vars)) {
    v <- vars[i]
    form <- form_map$form[match(v, form_map$variable_name)]
    x <- make_form_value(panel[[v]], form, v)
    if (is.numeric(x) && z_numeric) {
      s <- stats::sd(x, na.rm = TRUE)
      if (is.finite(s) && s > 0) x <- as.numeric((x - mean(x, na.rm = TRUE)) / s)
    }
    col <- paste0("X", sprintf("%03d", i))
    d[[col]] <- x
    term_map <- rbind(
      term_map,
      data.frame(
        variable_name = v,
        form = form,
        base_term = col,
        unit = unit_for_variable(v),
        category = candidate_category(v),
        theory_dir = assign_theory_dir(v),
        forced = is_forced_variable(v),
        stringsAsFactors = FALSE
      )
    )
  }
  d <- d[stats::complete.cases(d), , drop = FALSE]
  list(data = d, term_map = term_map)
}

nb_formula_for_vars <- function(vars, form_map) {
  terms <- paste(paste0("X", sprintf("%03d", seq_along(vars))), collapse = " + ")
  stats::as.formula(paste("cases ~", terms, "+ offset(log_pop)"))
}

forward_select <- function(panel, selected_map) {
  eligible <- selected_map[selected_map$passes_pval_screen & !selected_map$reverse_removed, ]
  forced <- eligible$variable_name[eligible$forced]
  candidates <- setdiff(eligible$variable_name, forced)
  chosen <- forced
  log <- data.frame()
  null_aic <- Inf
  if (length(chosen)) {
    mm <- model_matrix_selected(panel, chosen, selected_map, z_numeric = FALSE)
    fit0 <- MASS::glm.nb(nb_formula_for_vars(chosen, selected_map), data = mm$data, control = glm.control(maxit = PARAMS$MAX_ITER))
    null_aic <- stats::AIC(fit0)
  }
  iter <- 1L
  while (length(chosen) < PARAMS$TARGET_FWD && length(candidates) && iter <= PARAMS$MAX_ITER) {
    trial <- lapply(candidates, function(v) {
      vars <- c(chosen, v)
      out <- tryCatch({
        mm <- model_matrix_selected(panel, vars, selected_map, z_numeric = FALSE)
        fit <- MASS::glm.nb(nb_formula_for_vars(vars, selected_map), data = mm$data, control = glm.control(maxit = PARAMS$MAX_ITER))
        data.frame(candidate = v, AIC = stats::AIC(fit), n = nrow(mm$data), status = "fitted", error = "", stringsAsFactors = FALSE)
      }, error = function(e) {
        data.frame(candidate = v, AIC = Inf, n = NA_integer_, status = "failed", error = conditionMessage(e), stringsAsFactors = FALSE)
      })
      out
    })
    trial_df <- do.call(rbind, trial)
    trial_df <- trial_df[order(trial_df$AIC), ]
    best <- trial_df[1, ]
    add <- is.finite(best$AIC) && (length(chosen) < length(forced) || best$AIC < null_aic || length(chosen) < PARAMS$TARGET_FWD)
    log <- rbind(log, data.frame(iteration = iter, selected_before = paste(chosen, collapse = " | "), chosen_candidate = best$candidate, best_AIC = best$AIC, previous_AIC = null_aic, added = add, stringsAsFactors = FALSE))
    if (!add) break
    chosen <- c(chosen, best$candidate)
    candidates <- setdiff(candidates, best$candidate)
    null_aic <- best$AIC
    iter <- iter + 1L
  }
  write_csv_utf8(log, p("outputs", "tables", "forward_selection_log.csv"))
  list(vars = chosen, log = log, eligible = eligible)
}

calculate_vif_terms <- function(panel, vars, form_map) {
  mm <- model_matrix_selected(panel, vars, form_map, z_numeric = FALSE)
  x <- stats::model.matrix(nb_formula_for_vars(vars, form_map), data = mm$data)
  x <- x[, colnames(x) != "(Intercept)", drop = FALSE]
  keep <- apply(x, 2, function(z) stats::sd(z, na.rm = TRUE) > 0)
  x <- x[, keep, drop = FALSE]
  cmat <- stats::cor(x, use = "pairwise.complete.obs")
  inv <- tryCatch(solve(cmat), error = function(e) MASS::ginv(cmat))
  term_vif <- data.frame(term = colnames(x), VIF = as.numeric(diag(inv)), stringsAsFactors = FALSE)
  term_vif$base_term <- sub("^(X[0-9]+).*", "\\1", term_vif$term)
  out <- merge(term_vif, mm$term_map, by = "base_term", all.x = TRUE, sort = FALSE)
  stats::aggregate(VIF ~ variable_name + forced, out, max)
}

vif_reduce <- function(panel, vars, form_map) {
  log <- data.frame()
  current <- vars
  iter <- 1L
  repeat {
    vif <- calculate_vif_terms(panel, current, form_map)
    max_nonforced <- vif[!vif$forced, , drop = FALSE]
    if (!nrow(max_nonforced) || max(max_nonforced$VIF, na.rm = TRUE) < PARAMS$VIF_THRESHOLD) break
    remove <- max_nonforced$variable_name[which.max(max_nonforced$VIF)]
    log <- rbind(log, data.frame(iteration = iter, removed_variable = remove, removed_VIF = max(max_nonforced$VIF, na.rm = TRUE), remaining_before = paste(current, collapse = " | "), stringsAsFactors = FALSE))
    current <- setdiff(current, remove)
    iter <- iter + 1L
    if (iter > PARAMS$MAX_ITER) break
  }
  final_vif <- calculate_vif_terms(panel, current, form_map)
  write_csv_utf8(log, p("outputs", "tables", "vif_removal_log.csv"))
  write_csv_utf8(final_vif, p("outputs", "tables", "final_vif.csv"))
  list(vars = current, log = log, vif = final_vif)
}

prepare_inla_data <- function(panel, vars, form_map, shape) {
  mm <- model_matrix_selected(panel, vars, form_map, z_numeric = TRUE)
  d <- mm$data
  shape$region <- clean_region(shape$region)
  if (!"idarea" %in% names(shape)) {
    lookup <- data.frame(region = sort(unique(shape$region)), stringsAsFactors = FALSE)
    lookup$idarea <- seq_len(nrow(lookup))
    shape <- merge(shape, lookup, by = "region", all.x = TRUE, sort = FALSE)
  } else {
    lookup <- sf::st_drop_geometry(shape[, c("region", "idarea")])
  }
  shape <- shape[order(shape$idarea), ]
  d <- merge(d, lookup, by = "region", all.x = TRUE, sort = FALSE)
  d <- d[stats::complete.cases(d), , drop = FALSE]
  d <- d[order(d$idarea, d$year), , drop = FALSE]
  d$idtime <- as.integer(factor(d$year, levels = sort(unique(panel$year))))
  d$idarea_time <- seq_len(nrow(d))
  list(data = d, shape = shape, term_map = mm$term_map)
}

safe_moran <- function(x, listw) {
  out <- tryCatch(spdep::moran.test(x, listw, zero.policy = TRUE), error = function(e) e)
  if (inherits(out, "error")) return(data.frame(Moran_I = NA_real_, expected = NA_real_, p_value = NA_real_, error = conditionMessage(out)))
  data.frame(Moran_I = unname(out$estimate[["Moran I statistic"]]), expected = unname(out$estimate[["Expectation"]]), p_value = out$p.value, error = "", stringsAsFactors = FALSE)
}

residual_morans <- function(fit, data, listw) {
  mu <- as.numeric(fit$summary.fitted.values$mean)
  raw <- data$cases - mu
  pearson <- raw / sqrt(pmax(mu, 1e-8))
  area <- data.frame(idarea = data$idarea, raw = raw, pearson = pearson)
  area_raw <- stats::aggregate(raw ~ idarea, area, sum)
  area_pearson <- stats::aggregate(pearson ~ idarea, area, mean)
  area_raw <- area_raw[order(area_raw$idarea), ]
  area_pearson <- area_pearson[order(area_pearson$idarea), ]
  r1 <- safe_moran(area_raw$raw, listw)
  r2 <- safe_moran(area_pearson$pearson, listw)
  data.frame(
    diagnostic = c("raw_residual", "pearson_residual"),
    Moran_I = c(r1$Moran_I, r2$Moran_I),
    expected = c(r1$expected, r2$expected),
    p_value = c(r1$p_value, r2$p_value),
    error = c(r1$error, r2$error),
    stringsAsFactors = FALSE
  )
}

fit_inla_structure <- function(model_id, prep, graph) {
  g <- graph
  pc_bym <- list(
    prec.unstruct = list(prior = "pc.prec", param = c(0.5, 0.01)),
    prec.spatial = list(prior = "pc.prec", param = c(0.5, 0.01))
  )
  pc_prec <- list(prec = list(prior = "pc.prec", param = c(0.5, 0.01)))
  fixed <- paste(prep$term_map$base_term, collapse = " + ")
  random <- switch(
    model_id,
    M1 = "",
    M2 = "+ f(idarea, model='besag', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_prec)",
    M3 = "+ f(idarea, model='bym', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_bym)",
    M4 = "+ f(idarea, model='bym', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_bym) + f(idarea_time, model='iid', hyper=pc_prec)",
    M5 = "+ f(idarea, model='bym', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_bym) + f(idtime, model='rw1', constr=TRUE, hyper=pc_prec)",
    M6 = "+ f(idarea, model='bym', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_bym) + f(idtime, model='rw1', constr=TRUE, hyper=pc_prec) + f(idarea_time, model='iid', hyper=pc_prec)"
  )
  ftxt <- paste("cases ~ 1 +", fixed, "+ offset(log_pop)", random)
  fml <- stats::as.formula(ftxt)
  environment(fml) <- environment()
  warn <- character()
  start <- Sys.time()
  fit <- withCallingHandlers(
    tryCatch(
      INLA::inla(
        fml,
        family = "nbinomial",
        data = prep$data,
        control.compute = list(dic = TRUE, waic = TRUE, cpo = TRUE, return.marginals.predictor = TRUE),
        control.predictor = list(compute = TRUE, link = 1),
        control.inla = list(strategy = "adaptive"),
        num.threads = PARAMS$NUM_THREADS,
        verbose = FALSE
      ),
      error = function(e) e
    ),
    warning = function(w) {
      warn <<- c(warn, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  runtime <- as.numeric(difftime(Sys.time(), start, units = "secs"))
  if (inherits(fit, "error")) {
    return(list(model_id = model_id, status = "failed", error = conditionMessage(fit), runtime = runtime, warnings = warn, formula = ftxt))
  }
  saveRDS(fit, p("outputs", "tables", paste0("fit_", model_id, ".rds")))
  list(model_id = model_id, status = "fitted", fit = fit, runtime = runtime, warnings = warn, formula = ftxt)
}

extract_fixed <- function(fit_obj, prep, selected_model_id) {
  sf <- fit_obj$fit$summary.fixed
  sf <- sf[rownames(sf) != "(Intercept)", , drop = FALSE]
  rows <- data.frame(term = rownames(sf), coefficient = sf$mean, sd = sf$sd, CrI_lower = sf$`0.025quant`, CrI_upper = sf$`0.975quant`, stringsAsFactors = FALSE)
  rows$base_term <- sub("^(X[0-9]+).*", "\\1", rows$term)
  out <- merge(rows, prep$term_map, by = "base_term", all.x = TRUE, sort = FALSE)
  out$model_id <- selected_model_id
  out$IRR <- exp(out$coefficient)
  out$IRR_CrI_lower <- exp(out$CrI_lower)
  out$IRR_CrI_upper <- exp(out$CrI_upper)
  out$CrI_includes_1 <- out$IRR_CrI_lower <= 1 & out$IRR_CrI_upper >= 1
  out$observed_direction <- ifelse(out$coefficient > 0, "positive", ifelse(out$coefficient < 0, "negative", "null"))
  out$theory_direction_agreement <- ifelse(
    out$theory_dir == "risk" & out$observed_direction == "positive", "consistent",
    ifelse(out$theory_dir == "protective" & out$observed_direction == "negative", "consistent",
      ifelse(out$theory_dir == "neutral", "neutral", "opposite_or_unclear")
    )
  )
  out
}

run_inla_m1_m6 <- function(panel, selected_vars, form_map, adj) {
  prep <- prepare_inla_data(panel, selected_vars, form_map, adj$shape)
  ids <- paste0("M", 1:6)
  fits <- lapply(ids, fit_inla_structure, prep = prep, graph = adj$graph)
  comp <- do.call(rbind, lapply(fits, function(x) {
    if (!identical(x$status, "fitted")) {
      return(data.frame(model_id = x$model_id, status = x$status, DIC = NA_real_, WAIC = NA_real_, runtime_seconds = x$runtime, warning_count = length(x$warnings), error = x$error, formula = x$formula, stringsAsFactors = FALSE))
    }
    data.frame(model_id = x$model_id, status = x$status, DIC = as.numeric(x$fit$dic$dic), WAIC = as.numeric(x$fit$waic$waic), runtime_seconds = x$runtime, warning_count = length(x$warnings), error = "", formula = x$formula, stringsAsFactors = FALSE)
  }))
  comp$DeltaDIC <- comp$DIC - min(comp$DIC, na.rm = TRUE)
  comp$DeltaWAIC <- comp$WAIC - min(comp$WAIC, na.rm = TRUE)
  m6_dic <- comp$DIC[comp$model_id == "M6"]
  m4_dic <- comp$DIC[comp$model_id == "M4"]
  selected_model <- if (is.finite(m4_dic) && is.finite(m6_dic) && (m4_dic - m6_dic) <= 2) "M4" else "M6"
  comp$selected_model <- comp$model_id == selected_model
  write_csv_utf8(comp, p("outputs", "tables", "model_M1_M6.csv"))
  moran_rows <- lapply(fits, function(x) {
    if (!identical(x$status, "fitted")) return(NULL)
    m <- residual_morans(x$fit, prep$data, adj$listw)
    m$model_id <- x$model_id
    m
  })
  morans <- do.call(rbind, moran_rows)
  write_csv_utf8(morans, p("outputs", "tables", "residual_moran.csv"))
  selected_fit <- fits[[match(selected_model, ids)]]
  fx <- extract_fixed(selected_fit, prep, selected_model)
  write_csv_utf8(fx, p("outputs", "tables", "SectionB_M1_M6_adjusted_IRR.csv"))
  list(comp = comp, morans = morans, fixed = fx, selected_model = selected_model, prep = prep)
}

run_pipeline <- function() {
  suppressPackageStartupMessages({
    if (!requireNamespace("MASS", quietly = TRUE)) stop("MASS package is required.")
    if (!requireNamespace("INLA", quietly = TRUE)) stop("INLA package is required.")
    if (!requireNamespace("sf", quietly = TRUE) || !requireNamespace("spdep", quietly = TRUE)) stop("sf and spdep are required.")
  })
  inputs <- read_inputs()
  adj <- build_contiguity(inputs$panel)
  panel <- adj$panel
  inventory <- make_candidate_inventory(panel, inputs$registry)
  selected_map <- run_form_screening(panel, inventory)
  fwd <- forward_select(panel, selected_map)
  vif <- vif_reduce(panel, fwd$vars, selected_map)
  final_vars <- vif$vars
  inla <- run_inla_m1_m6(panel, final_vars, selected_map, adj)
  final_selection_base <- merge(
    data.frame(variable_name = final_vars, selection_order = seq_along(final_vars), stringsAsFactors = FALSE),
    selected_map[, c("variable_name", "form", "category", "theory_dir", "unit", "forced", "p_value", "AIC", "IRR", "IRR_CI_lower", "IRR_CI_upper", "observed_direction", "direction_status")],
    by = "variable_name",
    all.x = TRUE,
    sort = FALSE
  )
  fixed_summary <- do.call(rbind, lapply(split(inla$fixed, inla$fixed$variable_name), function(df) {
    data.frame(
      variable_name = df$variable_name[1],
      model_id = df$model_id[1],
      adjusted_term_count = nrow(df),
      adjusted_terms_excluding_1 = sum(!df$CrI_includes_1),
      adjusted_term_summary = paste0(
        df$term, ": IRR ", sprintf("%.4f", df$IRR),
        " (95% CrI ", sprintf("%.4f", df$IRR_CrI_lower), "-",
        sprintf("%.4f", df$IRR_CrI_upper), ")"
      ) |> paste(collapse = " | "),
      theory_direction_agreement_summary = paste(unique(df$theory_direction_agreement), collapse = " | "),
      stringsAsFactors = FALSE
    )
  }))
  final_selection <- merge(final_selection_base, fixed_summary, by = "variable_name", all.x = TRUE, sort = FALSE)
  write_csv_utf8(final_selection, p("outputs", "tables", "final_variable_selection.csv"))

  selected_lines <- paste0(
    "- ", final_selection$selection_order, ". ", final_selection$variable_name,
    " [", final_selection$form, ", ", final_selection$unit, "]",
    ": adjusted terms excluding 1=", final_selection$adjusted_terms_excluding_1,
    "/", final_selection$adjusted_term_count,
    "; ", final_selection$adjusted_term_summary,
    "; theory=", final_selection$theory_direction_agreement_summary
  )
  comp_lines <- paste0(
    "- ", inla$comp$model_id, ": DIC=", sprintf("%.2f", inla$comp$DIC),
    ", WAIC=", sprintf("%.2f", inla$comp$WAIC),
    ", DeltaDIC=", sprintf("%.2f", inla$comp$DeltaDIC),
    ifelse(inla$comp$selected_model, " [selected]", "")
  )
  isolated <- read_csv_safe(p("outputs", "tables", "contiguity_isolated_removed.csv"))
  summary_text <- c(
    "# Professor-Style Typhoid Variable Selection Summary",
    "",
    "## Analysis Scope",
    "",
    "This exploratory analysis searches candidate variables and functional forms in the style of earlier hepatitis A/EHEC workflows. It is not the fixed six-covariate manuscript model and is not used to reproduce the locked manuscript values. Results are retained only for audit and strategy review.",
    "",
    "## Parameters",
    "",
    paste0("- PVAL_SCREEN=", PARAMS$PVAL_SCREEN, ", VIF_THRESHOLD=", PARAMS$VIF_THRESHOLD, ", MIN_OBS=", PARAMS$MIN_OBS, ", COV_RATIO=", PARAMS$COV_RATIO, "."),
    paste0("- TARGET_FWD=", PARAMS$TARGET_FWD, ", MAX_ITER=", PARAMS$MAX_ITER, ", num.threads=", PARAMS$NUM_THREADS, "."),
    "- Form screening: raw/log1p/binary/T3/Q4 univariable negative-binomial GLM; selected by minimum p-value with parsimony tie-break.",
    "- Sex ratio was forced raw; log1p was excluded for percentage or standardized-rate variables; zero-heavy variables used binary presence.",
    "",
    "## Adjacency",
    "",
    "- KNN K=4 was not used in this pipeline.",
    paste0("- poly2nb contiguity with snap=", PARAMS$SNAP, " was used; no-neighbour regions were removed before INLA fitting."),
    paste0("- Removed isolated regions: ", ifelse(nrow(isolated), paste(isolated$removed_isolated_region, collapse = ", "), "none"), "."),
    paste0("- Retained panel: ", nrow(inla$prep$data), " district-years, ", length(unique(inla$prep$data$region)), " districts, ", sum(inla$prep$data$cases), " cases."),
    "",
    "## Final Exploratory Variable Set",
    "",
    selected_lines,
    "",
    "## M1-M6",
    "",
    comp_lines,
    "",
    "## Conclusion",
    "",
    paste0("The exploratory forward/VIF procedure retained ", length(final_vars), " variables, and the INLA structure comparison selected ", inla$selected_model, " according to the exploratory selection rule."),
    "Because these results come from automated exploratory screening, they are not used as the basis for the public final manuscript model. The final release uses a separate pre-specified reproduction script with no forward, backward, or stepwise selection."
  )
  writeLines(enc2utf8(summary_text), p("outputs", "summary", "SELECTION_SUMMARY.md"), useBytes = TRUE)
  message("Professor-style typhoid selection complete.")
  message("Selected variables: ", paste(final_vars, collapse = ", "))
  message("Selected INLA structure: ", inla$selected_model)
}

if (length(grep("01_professor_style_variable_selection.R$", commandArgs(FALSE)))) {
  run_pipeline()
}
