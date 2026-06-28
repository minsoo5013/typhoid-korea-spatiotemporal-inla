#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Render supplementary video frames and GIFs (final contiguity M6), 2011-2024.

Deterministic matplotlib/geopandas. Produces per-year PNG frames and GIFs for
observed incidence, fitted incidence, observed-vs-fitted (S1), and Pearson
residual (S2). Fixed class/colour scales across years. No randomness, no AI images.

Inputs (repo-relative):
  data/spatial/final.{gpkg,shp}                                   (SGIS boundary; user-provided)
  outputs/generated/district_year_final_contiguity_M6_for_gifs.csv (R/08_video_frames.R)
Outputs:
  outputs/generated/figures/frames_{incidence,fitted,residual,observed_vs_fitted}/*.png
  outputs/generated/figures/typhoid_*_final_contiguity_M6_2011_2024.gif

Ported from tables/gifs/make_final_contiguity_m6_gifs.py.
"""
from __future__ import annotations

import os
import sys

import geopandas as gpd
import imageio.v2 as imageio
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.cm import ScalarMappable
from matplotlib.colors import BoundaryNorm, ListedColormap, Normalize
from matplotlib.patches import Patch, Rectangle

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


PATH_DY = repo_path("outputs", "generated", "district_year_final_contiguity_M6_for_gifs.csv")
OUT_DIR = repo_path("outputs", "generated", "figures")

YEARS = list(range(2011, 2025))
DPI = 180
FRAME_SECONDS = 0.85
EDGE = "#a6a6a6"
EDGE_LW = 0.16
MISSING = "#d9d9d9"

INC_BREAKS = [0.0, 1e-9, 0.5, 1.0, 2.0, 4.0, np.inf]
INC_LABELS = ["0", ">0-0.5", "0.5-1", "1-2", "2-4", ">=4"]
INC_COLORS = ["#ffffff", "#fed976", "#feb24c", "#fd8d3c", "#f03b20", "#bd0026"]


def clean_region(value):
    value = str(value).replace(" ", "").replace("\t", "")
    value = value.replace("광역시", "시")
    if value in {"경상북도군위군", "경북군위군", "대구광역시군위군", "대구시군위군", "대구군위군"}:
        return "대구시군위군"
    if value == "인천시미추홀구":
        return "인천시남구"
    return value


def load_shape():
    gdf = gpd.read_file(spatial_file())
    if gdf.crs is None:
        gdf = gdf.set_crs("EPSG:5179", allow_override=True)
    elif gdf.crs.to_epsg() != 5179:
        gdf = gdf.to_crs("EPSG:5179")
    gdf["region_clean"] = gdf["region"].map(clean_region)
    return gdf


def add_scale_bar(ax, length_km=100):
    xmin, xmax = ax.get_xlim()
    ymin, ymax = ax.get_ylim()
    width = xmax - xmin
    height = ymax - ymin
    x0 = xmin + 0.045 * width
    y0 = ymin + 0.080 * height
    length = length_km * 1000
    bar_h = 0.010 * height
    ax.add_patch(Rectangle((x0, y0), length / 2, bar_h, facecolor="black", edgecolor="black", linewidth=0.35, zorder=8))
    ax.add_patch(Rectangle((x0 + length / 2, y0), length / 2, bar_h, facecolor="#bdbdbd", edgecolor="black", linewidth=0.35, zorder=8))
    for frac, label in [(0.0, "0"), (0.5, "50"), (1.0, "100")]:
        ax.text(x0 + frac * length, y0 + bar_h * 1.55, label, ha="center", va="bottom", fontsize=7.0, zorder=9)
    ax.text(x0 + length / 2, y0 - 0.014 * height, "km", ha="center", va="top", fontsize=7.0, zorder=9)


def finalize_ax(ax, extent, title):
    ax.set_xlim(extent[0], extent[2])
    ax.set_ylim(extent[1], extent[3])
    ax.set_aspect("equal")
    ax.set_axis_off()
    ax.set_title(title, fontsize=12, fontweight="bold", pad=8)
    add_north_arrow(ax, x=0.965, y=0.985, size=0.07)
    add_scale_bar(ax)


def incidence_legend(ax, title):
    handles = [Patch(facecolor=color, edgecolor="#595959", linewidth=0.35, label=label) for color, label in zip(INC_COLORS, INC_LABELS)]
    legend = ax.legend(
        handles=handles, title=title, loc="lower right", bbox_to_anchor=(1.02, -0.04),
        frameon=True, fontsize=7.6, title_fontsize=8.4, handlelength=1.0, handleheight=1.0,
        labelspacing=0.30, borderpad=0.55,
    )
    legend.get_title().set_fontweight("bold")
    legend.get_frame().set_alpha(0.88)
    legend.get_frame().set_edgecolor("none")


def save_gif(frame_paths, gif_path):
    frames = [imageio.imread(path) for path in frame_paths]
    imageio.mimsave(gif_path, frames, duration=FRAME_SECONDS, loop=0)
    print(f"[ok] {gif_path}")


def plot_incidence_frame(gdf, year, column, title, out_path, extent):
    cmap = ListedColormap(INC_COLORS)
    norm = BoundaryNorm(INC_BREAKS, ncolors=cmap.N, clip=False)
    sub = gdf[gdf[column].notna()]
    miss = gdf[gdf[column].isna()]
    fig, ax = plt.subplots(figsize=(6.1, 7.0))
    if not miss.empty:
        miss.plot(ax=ax, color=MISSING, edgecolor=EDGE, linewidth=EDGE_LW)
    sub.plot(ax=ax, column=column, cmap=cmap, norm=norm, edgecolor=EDGE, linewidth=EDGE_LW)
    finalize_ax(ax, extent, f"{title}, {year}")
    incidence_legend(ax, "Incidence per 100,000")
    fig.text(0.5, 0.030, "Fixed class scale across all years.", ha="center", fontsize=7.2, color="#4d4d4d")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    fig.savefig(out_path, dpi=DPI, facecolor="white")
    plt.close(fig)


def plot_residual_frame(gdf, year, vlim, out_path, extent):
    column = "pearson_resid"
    norm = Normalize(vmin=-vlim, vmax=vlim, clip=True)
    cmap = "RdBu_r"
    sub = gdf[gdf[column].notna()]
    miss = gdf[gdf[column].isna()]
    fig, ax = plt.subplots(figsize=(6.1, 7.0))
    if not miss.empty:
        miss.plot(ax=ax, color=MISSING, edgecolor=EDGE, linewidth=EDGE_LW)
    sub.plot(ax=ax, column=column, cmap=cmap, norm=norm, edgecolor=EDGE, linewidth=EDGE_LW)
    finalize_ax(ax, extent, f"Final M6 Pearson residual, {year}")
    sm = ScalarMappable(norm=norm, cmap=cmap)
    sm.set_array([])
    cax = fig.add_axes([0.86, 0.17, 0.030, 0.20])
    cb = fig.colorbar(sm, cax=cax, extend="both")
    cb.set_label("Pearson residual", fontsize=8)
    cb.ax.tick_params(labelsize=7.5)
    cb.set_ticks([-vlim, -vlim / 2, 0, vlim / 2, vlim])
    fig.text(0.5, 0.030, "Red = observed above fitted; blue = below fitted. Scale fixed across years.", ha="center", fontsize=7.0, color="#4d4d4d")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    fig.savefig(out_path, dpi=DPI, facecolor="white")
    plt.close(fig)


def plot_observed_vs_fitted_frame(gdf, year, out_path, extent):
    cmap = ListedColormap(INC_COLORS)
    norm = BoundaryNorm(INC_BREAKS, ncolors=cmap.N, clip=False)
    fig, axes = plt.subplots(1, 2, figsize=(10.2, 6.0))
    for ax, column, title in [
        (axes[0], "observed_incidence", f"Observed incidence, {year}"),
        (axes[1], "fitted_incidence", f"Model-fitted incidence, {year}"),
    ]:
        sub = gdf[gdf[column].notna()]
        miss = gdf[gdf[column].isna()]
        if not miss.empty:
            miss.plot(ax=ax, color=MISSING, edgecolor=EDGE, linewidth=EDGE_LW)
        sub.plot(ax=ax, column=column, cmap=cmap, norm=norm, edgecolor=EDGE, linewidth=EDGE_LW)
        finalize_ax(ax, extent, title)
    handles = [Patch(facecolor=color, edgecolor="#595959", linewidth=0.35, label=label) for color, label in zip(INC_COLORS, INC_LABELS)]
    legend = axes[1].legend(
        handles=handles, title="Incidence per 100,000", loc="lower right", bbox_to_anchor=(1.02, -0.02),
        frameon=True, fontsize=7.4, title_fontsize=8.2, labelspacing=0.30, borderpad=0.55,
    )
    legend.get_title().set_fontweight("bold")
    legend.get_frame().set_alpha(0.88)
    legend.get_frame().set_edgecolor("none")
    fig.text(0.5, 0.030, "Both panels use the same fixed incidence scale.", ha="center", fontsize=7.0, color="#4d4d4d")
    fig.subplots_adjust(left=0.01, right=0.99, top=0.94, bottom=0.06, wspace=0.04)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    fig.savefig(out_path, dpi=DPI, facecolor="white")
    plt.close(fig)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    shape = load_shape()
    dy = pd.read_csv(PATH_DY)
    dy["region_clean"] = dy["region"].map(clean_region)
    shape = shape[shape["region_clean"].isin(set(dy["region_clean"]))].copy()
    if len(shape) != 223:
        raise RuntimeError(f"Expected 223 mapped districts, got {len(shape)}")

    extent = shape.total_bounds
    validation_rows = []
    frame_inc, frame_fit, frame_resid, frame_compare = [], [], [], []
    vlim = float(np.ceil(np.nanpercentile(np.abs(dy["pearson_resid"]), 98)))

    for year in YEARS:
        year_df = dy.loc[dy["year"] == year, ["region_clean", "observed_incidence", "fitted_incidence", "pearson_resid"]]
        gdf = shape.merge(year_df, on="region_clean", how="left")
        validation_rows.append({
            "year": year,
            "n_districts": len(gdf),
            "missing_observed_incidence": int(gdf["observed_incidence"].isna().sum()),
            "missing_fitted_incidence": int(gdf["fitted_incidence"].isna().sum()),
            "missing_pearson_resid": int(gdf["pearson_resid"].isna().sum()),
        })

        p = os.path.join(OUT_DIR, "frames_incidence", f"typhoid_observed_incidence_{year}.png")
        plot_incidence_frame(gdf, year, "observed_incidence", "Observed typhoid incidence", p, extent)
        frame_inc.append(p)

        p = os.path.join(OUT_DIR, "frames_fitted", f"typhoid_fitted_incidence_{year}.png")
        plot_incidence_frame(gdf, year, "fitted_incidence", "Final M6 fitted incidence", p, extent)
        frame_fit.append(p)

        p = os.path.join(OUT_DIR, "frames_residual", f"typhoid_pearson_residual_{year}.png")
        plot_residual_frame(gdf, year, vlim, p, extent)
        frame_resid.append(p)

        p = os.path.join(OUT_DIR, "frames_observed_vs_fitted", f"typhoid_observed_vs_fitted_{year}.png")
        plot_observed_vs_fitted_frame(gdf, year, p, extent)
        frame_compare.append(p)
        print(f"[ok] frames {year}")

    outputs = {
        "typhoid_observed_incidence_final_contiguity_M6_2011_2024.gif": frame_inc,
        "typhoid_fitted_incidence_final_contiguity_M6_2011_2024.gif": frame_fit,
        "typhoid_pearson_residual_final_contiguity_M6_2011_2024.gif": frame_resid,
        "typhoid_observed_vs_fitted_final_contiguity_M6_2011_2024.gif": frame_compare,
    }
    for name, frames in outputs.items():
        save_gif(frames, os.path.join(OUT_DIR, name))

    pd.DataFrame(validation_rows).to_csv(os.path.join(OUT_DIR, "gif_generation_validation.csv"), index=False, encoding="utf-8-sig")
    pd.DataFrame({
        "gif": list(outputs.keys()),
        "frames": [len(frames) for frames in outputs.values()],
        "years": ["2011-2024"] * len(outputs),
        "source": ["final contiguity M6 panel/RDS"] * len(outputs),
    }).to_csv(os.path.join(OUT_DIR, "gif_outputs_summary.csv"), index=False, encoding="utf-8-sig")
    print("[ok] frame/GIF validation written")


if __name__ == "__main__":
    main()
