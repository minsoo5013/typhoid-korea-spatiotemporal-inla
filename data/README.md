# Data Inputs

This public code release is intended to document and reproduce the manuscript analysis when the required local input files are available.

Do not commit personal information, non-public raw data, or restricted source files to the public repository.

## Expected Local Inputs

Place locally permitted files in the following paths before running the full pipeline:

```text
data/derived/panel_inla_6var_contiguity.csv
data/spatial/final.shp
data/spatial/final.shx
data/spatial/final.dbf
data/spatial/final.cpg
```

For release-gate reproduction, the derived panel must be the final locked panel:

```text
SHA-1   8053d12a14e0ae586d2203f731567ef7669eb14e
SHA-256 2461222cd6068d1e3032e36f972aee9bdaa8ac5f0ad6a1c46c5d43ca99b3937b
```

Verify after placing the panel:

```bash
shasum data/derived/panel_inla_6var_contiguity.csv
shasum -a 256 data/derived/panel_inla_6var_contiguity.csv
```

The archived reference fit `outputs/reference/INLA_M1_M6_final_contiguity_archived_reference.rds`
(tracked in this repository) must match:

```text
SHA-1   07ae2423bf38ad17ce697a98ad0d4dbf9730d0c2
```

It was re-saved with xz compression (lossless); internal values unchanged. Verify:

```bash
shasum outputs/reference/INLA_M1_M6_final_contiguity_archived_reference.rds
```

The panel must include:

- `region`
- `year`
- `cases`
- `population`
- the six raw final covariates
- or their analysis-ready raw-copy `_T` columns

The six final covariates are:

1. `하수도보급률`
2. `인구천명당외국인수`
3. `인구천명당의료기관종사의사수`
4. `재정자립도`
5. `고령인구비율`
6. `성비`

## Boundary shapefile (SGIS) — required for Figure 2 and the videos

The district boundary files under `data/spatial/final.{gpkg,shp,shx,dbf,cpg}` come
from **Statistics Korea SGIS** and are **required** for the queen-contiguity
adjacency (`R/02_adjacency.R`), residual Moran's I (`R/04_diagnostics.R`), the
sensitivity analyses (`R/06`–`R/07`), and the Python Figure 2 / supplementary-video
renderers (`python/`). The boundary shapefile is **not redistributed here**; obtain
it from Statistics Korea SGIS and place it under `data/spatial/` before running. The
`data/spatial/` directory is git-ignored.

## Public Source Documentation

The manuscript data were assembled from official public Korean national and local-area sources, including infectious disease surveillance, population denominators, district boundary data, KOSIS/local statistics, and area-level health and infrastructure indicators. Raw-source links and access dates should be added here before public release, subject to each source's redistribution policy.

## Distribution Policy

The derived analysis panel should only be distributed if all source licences and institutional approvals permit redistribution. Otherwise, this repository should distribute code and metadata only, with instructions for rebuilding the panel from permitted sources.
