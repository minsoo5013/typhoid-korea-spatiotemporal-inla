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

final_covariates <- c(
  "하수도보급률",
  "인구천명당외국인수",
  "인구천명당의료기관종사의사수",
  "재정자립도",
  "고령인구비율",
  "성비"
)
model_covariates <- paste0(final_covariates, "_T")

clean_region <- function(x) {
  x <- gsub("[[:space:]]+", "", as.character(x))
  x <- gsub("광역시", "시", x)
  x[x %in% c("경상북도군위군", "경북군위군", "대구광역시군위군", "대구시군위군", "대구군위군")] <- "대구시군위군"
  x[x == "인천시미추홀구"] <- "인천시남구"
  x
}

input_panel <- path("data", "derived", "panel_inla_6var_contiguity.csv")
if (!file.exists(input_panel)) {
  stop(
    "Missing input panel: data/derived/panel_inla_6var_contiguity.csv\n",
    "Do not commit restricted data. Place a permitted local derived panel there before running."
  )
}

panel <- read_csv_utf8(input_panel)
required <- c("region", "year", "cases", "population", final_covariates)
missing_required <- setdiff(required, names(panel))
if (length(missing_required)) stop("Panel is missing required columns: ", paste(missing_required, collapse = ", "))

panel$region <- clean_region(panel$region)
panel$year <- as.integer(panel$year)
panel$cases <- as.numeric(panel$cases)
panel$population <- as.numeric(panel$population)
panel$log_pop <- log(panel$population + 1)

for (i in seq_along(final_covariates)) {
  raw_name <- final_covariates[i]
  model_name <- model_covariates[i]
  panel[[model_name]] <- as.numeric(panel[[raw_name]])
}

raw_copy_check <- data.frame(
  variable = final_covariates,
  model_column = model_covariates,
  is_raw_copy = vapply(
    final_covariates,
    function(v) isTRUE(all.equal(panel[[v]], panel[[paste0(v, "_T")]], check.attributes = FALSE)),
    logical(1)
  ),
  stringsAsFactors = FALSE
)
if (!all(raw_copy_check$is_raw_copy)) stop("At least one _T column is not a raw-copy column.")

summary_out <- data.frame(
  metric = c("rows", "districts", "years", "total_cases", "year_min", "year_max"),
  value = c(
    nrow(panel),
    length(unique(panel$region)),
    length(unique(panel$year)),
    sum(panel$cases, na.rm = TRUE),
    min(panel$year, na.rm = TRUE),
    max(panel$year, na.rm = TRUE)
  ),
  stringsAsFactors = FALSE
)

dir.create(path("outputs", "generated"), recursive = TRUE, showWarnings = FALSE)
write_csv_utf8(panel, path("outputs", "generated", "panel_inla_6var_contiguity.csv"))
write_csv_utf8(raw_copy_check, path("outputs", "generated", "raw_T_equivalence_check.csv"))
write_csv_utf8(summary_out, path("outputs", "generated", "panel_summary.csv"))

capture.output(sessionInfo(), file = path("outputs", "generated", "session_info_data_prep.txt"))
message("Prepared panel written to outputs/generated/panel_inla_6var_contiguity.csv")
