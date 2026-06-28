#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Render the manuscript Figure 2 (final contiguity M6), deterministic matplotlib/geopandas.

Reproduces the published Figure 2: (A) crude cumulative incidence and (B) model-based
posterior spatial relative risk by district, locked contiguity values (223 districts,
14 elevated, 9 in Gyeongnam). No model refit, no randomness, no AI-generated images.

Inputs (repo-relative):
  data/spatial/final.{gpkg,shp}                          (SGIS boundary; user-provided, not redistributed)
  outputs/generated/panel_inla_6var_contiguity.csv       (R/01-02)
  outputs/generated/spatial_RE_all_6var.csv              (R/04_diagnostics.R)
  outputs/generated/Table_S_elevated_spatial_RR_districts.csv  (R/04_diagnostics.R)
Outputs:
  outputs/generated/figures/Figure2_contiguity_M6.{png,tif}
  outputs/generated/figures/Figure2_validation.csv

Ported from 논문화/TRSTMH/figure2/Figure2_contiguity_M6_v41_layout_python_northarrow.py.
"""
from __future__ import annotations

import os
import sys

import geopandas as gpd
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.patches import Patch
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from north_arrow import add_north_arrow  # noqa: E402


def repo_path(*parts):
    return os.path.join(REPO, *parts)


def spatial_file():
    gpkg = repo_path("data", "spatial", "final.gpkg")
    shp = repo_path("data", "spatial", "final.shp")
    if os.path.exists(gpkg):
        return gpkg
    if os.path.exists(shp):
        return shp
    raise FileNotFoundError("Missing SGIS boundary under data/spatial/ (final.gpkg or final.shp).")


PATH_PANEL = repo_path("outputs", "generated", "panel_inla_6var_contiguity.csv")
PATH_SPATIAL_RE = repo_path("outputs", "generated", "spatial_RE_all_6var.csv")
PATH_ELEVATED = repo_path("outputs", "generated", "Table_S_elevated_spatial_RR_districts.csv")
OUT_DIR = repo_path("outputs", "generated", "figures")

DPI = 600
FIG_W, FIG_H = 7.4, 4.8
EDGE = "#b8b8b8"
EDGE_LW = 0.12

# RColorBrewer YlOrRd(5) and PuRd(5).
PAL_A = ["#FFFFB2", "#FECC5C", "#FD8D3C", "#F03B20", "#BD0026"]
PAL_B = ["#F1EEF6", "#D7B5D8", "#DF65B0", "#DD1C77", "#980043"]


def clean_region(value):
    value = str(value).replace(" ", "").replace("\t", "")
    value = value.replace("광역시", "시")
    if value in {"경상북도군위군", "경북군위군", "대구광역시군위군", "대구시군위군", "대구군위군"}:
        return "대구시군위군"
    if value == "인천시미추홀구":
        return "인천시남구"
    return value


def quantile_class(series, k=5, digits=2):
    values = np.asarray(series, dtype=float)
    clean = values[~np.isnan(values)]
    breaks = np.quantile(clean, np.linspace(0, 1, k + 1), method="linear")
    breaks[0] = np.nanmin(values)
    breaks[-1] = np.nanmax(values)
    breaks = np.unique(breaks)
    if len(breaks) < 2:
        raise ValueError("Not enough unique values to classify.")
    labels = [f"{breaks[i]:.{digits}f} to {breaks[i + 1]:.{digits}f}" for i in range(len(breaks) - 1)]
    return pd.cut(values, bins=breaks, include_lowest=True, right=True, labels=labels), labels


def add_scale_bar(ax, length_km=100):
    xmin, xmax = ax.get_xlim()
    ymin, ymax = ax.get_ylim()
    width = xmax - xmin
    height = ymax - ymin
    x0 = xmin + 0.030 * width
    y0 = ymin + 0.120 * height
    length = length_km * 1000
    tick = 0.012 * height
    ax.plot([x0, x0 + length / 2], [y0, y0], color="black", linewidth=1.25, solid_capstyle="butt", zorder=8)
    ax.plot([x0 + length / 2, x0 + length], [y0, y0], color="#bdbdbd", linewidth=1.25, solid_capstyle="butt", zorder=8)
    for frac, label in [(0.0, "0"), (0.5, "50"), (1.0, "100")]:
        x = x0 + frac * length
        ax.plot([x, x], [y0, y0 + tick], color="black", linewidth=0.35, zorder=9)
        ax.text(x, y0 + 0.020 * height, label, ha="center", va="bottom", fontsize=5.8, zorder=9)
    ax.text(x0 + length / 2, y0 - 0.018 * height, "km", ha="center", va="top", fontsize=5.8, zorder=9)


def add_legend(ax, labels, palette, title):
    handles = [Patch(facecolor=palette[i], edgecolor="#808080", linewidth=0.15, label=label) for i, label in enumerate(labels)]
    legend = ax.legend(
        handles=handles, title=title, loc="center", bbox_to_anchor=(0.80, 0.11),
        frameon=True, fontsize=6.4, title_fontsize=7.0, handlelength=1.05,
        handleheight=1.00, labelspacing=0.33, borderpad=0.35,
    )
    legend.get_title().set_fontweight("bold")
    legend.get_frame().set_alpha(0.86)
    legend.get_frame().set_edgecolor("none")


def plot_panel(ax, gdf, column, labels, palette, title, legend_title, extent):
    for idx, label in enumerate(labels):
        subset = gdf[gdf[column] == label]
        if not subset.empty:
            subset.plot(ax=ax, color=palette[idx], edgecolor=EDGE, linewidth=EDGE_LW)
    ax.set_xlim(extent[0], extent[2])
    ax.set_ylim(extent[1], extent[3])
    ax.set_aspect("equal")
    ax.set_axis_off()
    ax.text(0.0, 1.015, title, transform=ax.transAxes, ha="left", va="bottom",
            fontsize=8.3, fontweight="bold", clip_on=False, zorder=12)
    add_north_arrow(ax, x=0.945, y=0.965, size=0.072)
    add_scale_bar(ax, length_km=100)
    add_legend(ax, labels, palette, legend_title)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    panel = pd.read_csv(PATH_PANEL)
    spatial_re = pd.read_csv(PATH_SPATIAL_RE)
    elevated_ref = pd.read_csv(PATH_ELEVATED)

    panel["region_clean"] = panel["region"].map(clean_region)
    spatial_re["region_clean"] = spatial_re["district"].map(clean_region)
    elevated_ref["region_clean"] = elevated_ref["district"].map(clean_region)

    crude = (
        panel.groupby("region_clean", as_index=False)
        .agg(cases_2011_2024=("cases", "sum"), population_2011_2024=("population", "sum"))
    )
    crude["crude_incidence_per_100000"] = crude["cases_2011_2024"] / crude["population_2011_2024"] * 100000

    dat = spatial_re.merge(crude, on="region_clean", how="left")
    dat["elevated_posterior_spatial_rr"] = dat["elevated_posterior_spatial_rr"].astype(bool)

    # Locked-value guards: figure must reflect the manuscript contiguity result.
    assert len(dat) == 223
    assert int(dat["elevated_posterior_spatial_rr"].sum()) == 14
    assert int(((dat["elevated_posterior_spatial_rr"]) & (dat["province"] == "경상남도")).sum()) == 9
    assert int(panel["cases"].sum()) == 1202
    assert len(panel) == 3122
    assert len(panel["region_clean"].unique()) == 223
    expected_order = list(elevated_ref.sort_values("rank")["region_clean"])
    observed_order = list(dat[dat["elevated_posterior_spatial_rr"]].sort_values("spatial_RE", ascending=False)["region_clean"])
    assert observed_order == expected_order

    shape = gpd.read_file(spatial_file())
    if shape.crs is None:
        shape = shape.set_crs("EPSG:5179", allow_override=True)
    elif shape.crs.to_epsg() != 5179:
        shape = shape.to_crs("EPSG:5179")
    shape["region_clean"] = shape["region"].map(clean_region)

    gdf = shape.merge(dat, on="region_clean", how="inner")
    if len(gdf) != 223:
        missing_shape = sorted(set(dat["region_clean"]) - set(shape["region_clean"]))
        missing_data = sorted(set(shape["region_clean"]) - set(dat["region_clean"]))
        raise RuntimeError(f"Map join failed: missing_shape={missing_shape}; missing_data={missing_data}")

    gdf["crude_incidence_class"], labels_a = quantile_class(gdf["crude_incidence_per_100000"], k=5, digits=2)
    gdf["posterior_rr_class"], labels_b = quantile_class(gdf["posterior_spatial_RR"], k=5, digits=2)
    extent = gdf.total_bounds

    fig, axes = plt.subplots(1, 2, figsize=(FIG_W, FIG_H))
    plot_panel(axes[0], gdf, "crude_incidence_class", labels_a, PAL_A,
               "(A) Crude cumulative incidence", "Incidence per 100,000", extent)
    plot_panel(axes[1], gdf, "posterior_rr_class", labels_b, PAL_B,
               "(B) Model-based posterior spatial relative risk", "Posterior spatial RR", extent)
    fig.subplots_adjust(left=0.005, right=0.995, top=0.93, bottom=0.01, wspace=0.02)

    out_png = os.path.join(OUT_DIR, "Figure2_contiguity_M6.png")
    out_tif = os.path.join(OUT_DIR, "Figure2_contiguity_M6.tif")
    fig.savefig(out_png, dpi=DPI, facecolor="white")
    fig.savefig(out_tif, dpi=DPI, facecolor="white")
    plt.close(fig)

    image = Image.open(out_tif).convert("RGBA")
    background = Image.new("RGB", image.size, (255, 255, 255))
    background.paste(image, mask=image.split()[-1])
    background.save(out_tif, format="TIFF", compression="tiff_lzw", dpi=(DPI, DPI))

    validation = pd.DataFrame(
        {
            "check": [
                "mapped_districts",
                "elevated_posterior_spatial_rr_districts",
                "gyeongnam_among_elevated",
                "panel_cases",
                "panel_district_years",
                "panel_regions",
                "top_elevated_district",
            ],
            "value": [
                len(gdf),
                int(dat["elevated_posterior_spatial_rr"].sum()),
                int(((dat["elevated_posterior_spatial_rr"]) & (dat["province"] == "경상남도")).sum()),
                int(panel["cases"].sum()),
                len(panel),
                len(panel["region_clean"].unique()),
                dat[dat["elevated_posterior_spatial_rr"]].sort_values("spatial_RE", ascending=False).iloc[0]["district"],
            ],
            "expected": ["223", "14", "9", "1202", "3122", "223", "경상남도사천시"],
        }
    )
    validation["status"] = np.where(validation["value"].astype(str) == validation["expected"].astype(str), "PASS", "FAIL")
    validation.to_csv(os.path.join(OUT_DIR, "Figure2_validation.csv"), index=False, encoding="utf-8-sig")

    print(f"Saved PNG: {out_png}")
    print(f"Saved TIFF: {out_tif}")
    print("Validation PASS:", bool((validation["status"] == "PASS").all()))


if __name__ == "__main__":
    main()
