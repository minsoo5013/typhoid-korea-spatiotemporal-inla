#!/usr/bin/env Rscript

# Final manuscript model. The six covariates below are FIXED and pre-specified.
# No automated variable selection (forward/backward/stepwise/VIF/AIC) is called
# here; any such procedure lives in R/exploratory/ and is exploratory only.
# Spatial: NB + BYM + RW1 + IID, offset log(population + 1), queen contiguity.
# Running this unchanged on the locked panel reproduces M6 DIC 4196.36 / WAIC 4198.66.

set.seed(20260626)
options(scipen = 999)

suppressPackageStartupMessages({
  library(INLA)
})

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
bt <- function(x) paste0("`", x, "`")

panel_path <- path("outputs", "generated", "panel_inla_6var_contiguity.csv")
graph_path <- path("outputs", "generated", "spatial_graph_contiguity_queen_snap001.inla")
if (!file.exists(panel_path)) stop("Run R/01_data_prep.R and R/02_adjacency.R first.")
if (!file.exists(graph_path)) stop("Run R/02_adjacency.R first.")

panel <- read_csv_utf8(panel_path)
g <- INLA::inla.read.graph(graph_path)

final_covariates <- paste0(c(
  "하수도보급률",
  "인구천명당외국인수",
  "인구천명당의료기관종사의사수",
  "재정자립도",
  "고령인구비율",
  "성비"
), "_T")

if (!all(final_covariates %in% names(panel))) stop("Panel is missing final six _T covariates.")
if (!"log_pop" %in% names(panel)) panel$log_pop <- log(panel$population + 1)

pc_bym <- list(
  prec.unstruct = list(prior = "pc.prec", param = c(0.5, 0.01)),
  prec.spatial = list(prior = "pc.prec", param = c(0.5, 0.01))
)
pc_prec <- list(prec = list(prior = "pc.prec", param = c(0.5, 0.01)))

fixed <- paste(bt(final_covariates), collapse = " + ")
base_formula <- paste0("cases ~ 1 + ", fixed, " + offset(log_pop)")
formula_text <- list(
  M1 = base_formula,
  M2 = paste(base_formula, "+ f(idarea, model='besag', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_prec)"),
  M3 = paste(base_formula, "+ f(idarea, model='bym', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_bym)"),
  M4 = paste(base_formula, "+ f(idarea, model='bym', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_bym)", "+ f(idarea_time, model='iid', hyper=pc_prec)"),
  M5 = paste(base_formula, "+ f(idarea, model='bym', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_bym)", "+ f(idtime, model='rw1', constr=TRUE, hyper=pc_prec)"),
  M6 = paste(base_formula, "+ f(idarea, model='bym', graph=g, scale.model=TRUE, constr=TRUE, hyper=pc_bym)", "+ f(idtime, model='rw1', constr=TRUE, hyper=pc_prec)", "+ f(idarea_time, model='iid', hyper=pc_prec)")
)

num_threads <- Sys.getenv("TYPHOID_INLA_NUM_THREADS", unset = "1:1")
fits <- list()
comparison <- data.frame(model = character(), DIC = numeric(), WAIC = numeric(), stringsAsFactors = FALSE)

for (model_name in names(formula_text)) {
  fml <- as.formula(formula_text[[model_name]])
  environment(fml) <- environment()
  message("Fitting ", model_name, " with num.threads=", num_threads)
  fit <- INLA::inla(
    formula = fml,
    family = "nbinomial",
    data = panel,
    control.compute = list(dic = TRUE, waic = TRUE, cpo = TRUE, return.marginals.predictor = TRUE),
    control.predictor = list(compute = TRUE, link = 1),
    control.inla = list(strategy = "adaptive"),
    verbose = FALSE,
    num.threads = num_threads
  )
  fits[[model_name]] <- fit
  comparison <- rbind(
    comparison,
    data.frame(model = model_name, DIC = as.numeric(fit$dic$dic), WAIC = as.numeric(fit$waic$waic))
  )
}

comparison$DeltaDIC <- comparison$DIC - min(comparison$DIC, na.rm = TRUE)
comparison <- comparison[, c("model", "DIC", "DeltaDIC", "WAIC")]

saveRDS(fits, path("outputs", "generated", "INLA_M1_M6_final_contiguity.rds"))
write_csv_utf8(comparison, path("outputs", "generated", "Table_S_model_comparison_M1_M6.csv"))
writeLines(unlist(formula_text), con = path("outputs", "generated", "model_formulas.txt"), useBytes = TRUE)
message("Saved outputs/generated/INLA_M1_M6_final_contiguity.rds")
