#!/usr/bin/env Rscript

set.seed(20260626)
options(scipen = 999)

suppressPackageStartupMessages({
  library(ggplot2)
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

fig_dir <- path("outputs", "generated", "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

annual_path <- path("outputs", "reference", "Table1_annual_cases_recovered_final.csv")
if (!file.exists(annual_path)) stop("Missing reference annual case table.")
annual <- read_csv_utf8(annual_path)

year_col <- names(annual)[grepl("^year$|연도", names(annual), ignore.case = TRUE)][1]
case_col <- names(annual)[grepl("case|cases|발생", names(annual), ignore.case = TRUE)][1]
if (is.na(year_col) || is.na(case_col)) {
  stop("Could not identify year/case columns in Table1_annual_cases_recovered_final.csv")
}

annual$plot_year <- as.integer(annual[[year_col]])
annual$plot_cases <- as.numeric(annual[[case_col]])

p <- ggplot(annual, aes(x = plot_year, y = plot_cases)) +
  geom_col(fill = "#4C78A8", width = 0.72) +
  scale_x_continuous(breaks = sort(unique(annual$plot_year))) +
  labs(x = "Year", y = "Typhoid fever cases") +
  theme_classic(base_size = 10) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(fig_dir, "Figure1_annual_cases.png"), p, width = 7.0, height = 3.8, dpi = 600)
ggsave(file.path(fig_dir, "Figure1_annual_cases.tiff"), p, width = 7.0, height = 3.8, dpi = 600, compression = "lzw")

note <- c(
  "Figure generation note",
  "",
  "Figure 1 was generated from the locked reference annual case table.",
  "Figure 2 and supplementary video frames require local spatial boundary data and generated model outputs.",
  "Those restricted/local inputs are intentionally not committed to the public release package.",
  "No AI-generated images are used by this script."
)
writeLines(note, con = file.path(fig_dir, "FIGURE_GENERATION_NOTE.md"), useBytes = TRUE)
capture.output(sessionInfo(), file = path("outputs", "generated", "session_info_figures.txt"))
message("Figure outputs written to outputs/generated/figures/.")
