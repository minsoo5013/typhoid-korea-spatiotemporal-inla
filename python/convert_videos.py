#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Encode the two supplementary videos (S1, S2) from per-year PNG frames.

S1 = observed-vs-fitted incidence; S2 = Pearson residual. Encodes directly from
the frames (not the GIF) to H.264 (yuv420p) MP4, each frame held ~1.2 s. No model
refit, no value changes. Deterministic given the input frames.

Inputs (repo-relative): outputs/generated/figures/frames_observed_vs_fitted/, frames_residual/
   (produced by python/make_video_frames.py).
Outputs: outputs/generated/figures/Supplementary_Video_S1.mp4, Supplementary_Video_S2.mp4

Ported from tables/gifs/supplementary_videos/convert_supplementary_videos.py.
"""
from __future__ import annotations

import csv
import json
import os
import subprocess

import imageio_ffmpeg

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
FIG_DIR = os.path.join(REPO, "outputs", "generated", "figures")
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

YEARS = list(range(2011, 2025))
SEC_PER_FRAME = 1.2
OUT_FPS = 25

JOBS = [
    {
        "id": "S1",
        "frames_dir": os.path.join(FIG_DIR, "frames_observed_vs_fitted"),
        "pattern": "typhoid_observed_vs_fitted_{year}.png",
        "out": os.path.join(FIG_DIR, "Supplementary_Video_S1.mp4"),
    },
    {
        "id": "S2",
        "frames_dir": os.path.join(FIG_DIR, "frames_residual"),
        "pattern": "typhoid_pearson_residual_{year}.png",
        "out": os.path.join(FIG_DIR, "Supplementary_Video_S2.mp4"),
    },
]


def build_concat(job):
    lines = []
    frames = []
    for y in YEARS:
        f = os.path.join(job["frames_dir"], job["pattern"].format(year=y))
        if not os.path.exists(f):
            raise FileNotFoundError(f)
        frames.append(f)
        lines.append(f"file '{f}'")
        lines.append(f"duration {SEC_PER_FRAME}")
    lines.append(f"file '{frames[-1]}'")  # concat needs the last file repeated
    list_path = os.path.join(FIG_DIR, f"_concat_{job['id']}.txt")
    with open(list_path, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    return list_path, frames


def encode(job):
    list_path, frames = build_concat(job)
    vf = "scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=%d" % OUT_FPS
    cmd = [
        FFMPEG, "-y",
        "-f", "concat", "-safe", "0", "-i", list_path,
        "-vf", vf,
        "-c:v", "libx264", "-profile:v", "high", "-pix_fmt", "yuv420p",
        "-crf", "23", "-preset", "veryslow",
        "-movflags", "+faststart",
        job["out"],
    ]
    subprocess.run(cmd, check=True, capture_output=True, text=True)
    os.remove(list_path)
    return frames


def probe(path):
    return subprocess.run([FFMPEG, "-i", path], capture_output=True, text=True).stderr


def main():
    os.makedirs(FIG_DIR, exist_ok=True)
    rows = []
    for job in JOBS:
        frames = encode(job)
        size = os.path.getsize(job["out"])
        meta = probe(job["out"])
        codec_ok = "h264" in meta.lower()
        yuv_ok = "yuv420p" in meta.lower()
        dur = None
        for tok in meta.split("Duration:"):
            if tok.strip().startswith("00:"):
                hms = tok.strip().split(",")[0]
                h, m, s = hms.split(":")
                dur = int(h) * 3600 + int(m) * 60 + float(s)
                break
        exp_dur = len(YEARS) * SEC_PER_FRAME
        rows.append({
            "video": os.path.basename(job["out"]),
            "n_input_frames": len(frames),
            "expected_frames": len(YEARS),
            "sec_per_frame": SEC_PER_FRAME,
            "measured_duration_s": round(dur, 2) if dur else "NA",
            "expected_duration_s": exp_dur,
            "codec_h264": codec_ok,
            "pix_fmt_yuv420p": yuv_ok,
            "size_bytes": size,
            "size_MB": round(size / 1e6, 3),
            "status": "PASS" if (codec_ok and yuv_ok and len(frames) == len(YEARS)
                                 and dur and abs(dur - exp_dur) < 0.5) else "CHECK",
        })
        print(f"[ok] {os.path.basename(job['out'])}  {rows[-1]['size_MB']} MB  {rows[-1]['measured_duration_s']}s  {rows[-1]['status']}")

    log = os.path.join(FIG_DIR, "video_conversion_validation.csv")
    with open(log, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    with open(os.path.join(FIG_DIR, "video_conversion_validation.json"), "w") as fh:
        json.dump({"ffmpeg": FFMPEG, "results": rows}, fh, indent=2)
    print(f"[ok] {log}")


if __name__ == "__main__":
    main()
