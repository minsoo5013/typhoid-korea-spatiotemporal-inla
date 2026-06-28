#!/usr/bin/env Rscript

# Reproduces: per-district-year data feeding the supplementary videos
#   (S1 observed vs fitted incidence; S2 Pearson residual), 2011-2024.
#   The actual frame/GIF/MP4 rendering is done by the Python scripts in python/.
# Input: outputs/generated/INLA_M1_M6_final_contiguity.rds (from R/03_model_fit.R)
#   and outputs/generated/panel_inla_6var_contiguity.csv (from 01-02).
#   This .rds MUST reproduce the locked M6 (DIC 4196.36 / WAIC 4198.66); verify the
#   extracted fitted/residual values match the published frames before release.
# Output: outputs/generated/district_year_final_contiguity_M6_for_gifs.csv.
# Ported from tables/gifs/extract_final_m6_for_gifs.R (no automated selection).

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

rds_path <- path("outputs", "generated", "INLA_M1_M6_final_contiguity.rds")
panel_path <- path("outputs", "generated", "panel_inla_6var_contiguity.csv")
if (!file.exists(rds_path)) stop("Run R/03_model_fit.R first (missing generated M6 fit).")
if (!file.exists(panel_path)) stop("Run R/01_data_prep.R and R/02_adjacency.R first.")

fits <- readRDS(rds_path)
m6 <- fits[["M6"]]
if (!inherits(m6, "inla")) stop("M6 object is not an INLA fit.")

panel <- read_csv_utf8(panel_path)
if (nrow(panel) != nrow(m6$summary.fitted.values)) {
  stop(sprintf("Panel/model row mismatch: panel=%d fitted=%d", nrow(panel), nrow(m6$summary.fitted.values)))
}

fitted_cases <- as.numeric(m6$summary.fitted.values$mean)
pearson_resid <- (panel$cases - fitted_cases) / sqrt(pmax(fitted_cases, 1e-9))
fitted_incidence <- fitted_cases / panel$population * 1e5
observed_incidence <- panel$cases / panel$population * 1e5

district_year <- data.frame(
  region = panel$region,
  year = panel$year,
  cases = panel$cases,
  population = panel$population,
  observed_incidence = observed_incidence,
  fitted_cases = fitted_cases,
  fitted_incidence = fitted_incidence,
  pearson_resid = pearson_resid,
  idarea = panel$idarea,
  idtime = panel$idtime,
  stringsAsFactors = FALSE
)

out_path <- path("outputs", "generated", "district_year_final_contiguity_M6_for_gifs.csv")
write_csv_utf8(district_year, out_path)

validation <- data.frame(
  check = c("model", "district_years", "districts", "years", "total_cases"),
  value = c(
    "NB + BYM + RW1 + IID (M6)",
    nrow(district_year),
    length(unique(district_year$region)),
    paste0(min(district_year$year), "-", max(district_year$year)),
    sum(district_year$cases)
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(validation, path("outputs", "generated", "district_year_for_gifs_validation.csv"))
capture.output(sessionInfo(), file = path("outputs", "generated", "session_info_video_frames.txt"))
message("Video frame data written to ", out_path)
