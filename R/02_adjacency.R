#!/usr/bin/env Rscript

set.seed(20260626)
options(scipen = 999)

suppressPackageStartupMessages({
  library(dplyr)
  library(sf)
  library(spdep)
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

clean_region <- function(x) {
  x <- gsub("[[:space:]]+", "", as.character(x))
  x <- gsub("광역시", "시", x)
  x[x %in% c("경상북도군위군", "경북군위군", "대구광역시군위군", "대구시군위군", "대구군위군")] <- "대구시군위군"
  x[x == "인천시미추홀구"] <- "인천시남구"
  x
}

panel_path <- path("outputs", "generated", "panel_inla_6var_contiguity.csv")
if (!file.exists(panel_path)) stop("Run R/01_data_prep.R first.")
panel <- read_csv_utf8(panel_path)

spatial_path <- if (file.exists(path("data", "spatial", "final.gpkg"))) {
  path("data", "spatial", "final.gpkg")
} else {
  path("data", "spatial", "final.shp")
}
if (!file.exists(spatial_path)) stop("Missing spatial file under data/spatial/.")

sf::sf_use_s2(FALSE)
shape0 <- sf::st_read(spatial_path, quiet = TRUE) %>%
  mutate(region = clean_region(region)) %>%
  filter(region %in% unique(panel$region))

if (is.na(sf::st_crs(shape0))) {
  sf::st_crs(shape0) <- 5179
} else if (sf::st_crs(shape0)$epsg != 5179) {
  shape0 <- sf::st_transform(shape0, 5179)
}

nb0 <- spdep::poly2nb(shape0, snap = 0.01, queen = TRUE)
isolated_idx <- which(spdep::card(nb0) == 0)
isolated_regions <- if (length(isolated_idx)) shape0$region[isolated_idx] else character()
shape <- if (length(isolated_idx)) shape0[-isolated_idx, ] else shape0

lookup <- shape %>%
  sf::st_drop_geometry() %>%
  transmute(region) %>%
  distinct() %>%
  arrange(region) %>%
  mutate(idarea = row_number())

shape <- shape %>%
  select(-any_of("idarea")) %>%
  left_join(lookup, by = "region") %>%
  arrange(idarea)

nb <- spdep::poly2nb(shape, snap = 0.01, queen = TRUE)
graph_path <- path("outputs", "generated", "spatial_graph_contiguity_queen_snap001.inla")
spdep::nb2INLA(graph_path, nb)

panel_inla <- panel %>%
  filter(region %in% shape$region) %>%
  select(-any_of(c("idarea", "idtime", "idarea_time"))) %>%
  left_join(lookup, by = "region") %>%
  arrange(idarea, year) %>%
  mutate(
    idtime = match(year, sort(unique(year))),
    idarea_time = row_number()
  )

summary <- data.frame(
  adjacency = "queen_contiguity_poly2nb_snap001",
  input_districts = length(unique(panel$region)),
  retained_districts = length(unique(panel_inla$region)),
  removed_isolated_districts = length(isolated_regions),
  retained_district_years = nrow(panel_inla),
  retained_total_cases = sum(panel_inla$cases, na.rm = TRUE),
  year_min = min(panel_inla$year),
  year_max = max(panel_inla$year),
  subgraph_count = spdep::n.comp.nb(nb)$nc,
  min_neighbours = min(spdep::card(nb)),
  max_neighbours = max(spdep::card(nb)),
  graph_file = graph_path,
  stringsAsFactors = FALSE
)

write_csv_utf8(panel_inla, panel_path)
write_csv_utf8(summary, path("outputs", "generated", "contiguity_adjacency_summary.csv"))
write_csv_utf8(data.frame(removed_isolated_region = isolated_regions), path("outputs", "generated", "contiguity_isolated_removed.csv"))
message("Adjacency graph written to outputs/generated/spatial_graph_contiguity_queen_snap001.inla")
