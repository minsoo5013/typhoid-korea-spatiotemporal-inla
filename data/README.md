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

## Public Source Documentation

The manuscript data were assembled from official public Korean national and local-area sources, including infectious disease surveillance, population denominators, district boundary data, KOSIS/local statistics, and area-level health and infrastructure indicators. Raw-source links and access dates should be added here before public release, subject to each source's redistribution policy.

## Distribution Policy

The derived analysis panel should only be distributed if all source licences and institutional approvals permit redistribution. Otherwise, this repository should distribute code and metadata only, with instructions for rebuilding the panel from permitted sources.
