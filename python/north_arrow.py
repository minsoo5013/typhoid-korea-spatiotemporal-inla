"""
North arrow (filled-kite style, Option A) for matplotlib maps.
Deterministic — draws with matplotlib patches, no external image.
Use identically across all typhoid supplementary maps and Figure 2.

Usage:
    import matplotlib.pyplot as plt
    from north_arrow import add_north_arrow

    fig, ax = plt.subplots()
    gdf.plot(ax=ax, ...)        # your choropleth
    ax.set_axis_off()
    add_north_arrow(ax, x=0.92, y=0.90, size=0.10)  # top-right corner
    plt.savefig("map.tiff", dpi=500)
"""
import matplotlib.patches as mpatches


def add_north_arrow(ax, x=0.92, y=0.90, size=0.10, color="#1a1a1a", lw=0.8):
    """
    Draw a filled-kite north arrow in axes-fraction coordinates.

    Parameters
    ----------
    ax    : matplotlib Axes (your map axis)
    x, y  : position of the arrow TIP, in axes fraction (0-1). Default top-right.
    size  : total height of the kite, in axes fraction. ~0.08-0.12 looks right.
    color : fill / stroke colour (default near-black).
    lw    : outline width.
    """
    # Kite geometry, expressed relative to the tip at (0,0), pointing up.
    # Tip at top; two side points; a notch in the middle of the base.
    w = size * 0.28          # half-width of the kite
    h = size                 # full height (tip to base points)
    notch = size * 0.22      # depth the base notch rises toward the tip

    # Vertices (in axes-fraction offsets from the tip)
    tip      = (x,        y)
    right    = (x + w,    y - h)
    notch_pt = (x,        y - h + notch)
    left     = (x - w,    y - h)

    kite = mpatches.Polygon(
        [tip, right, notch_pt, left],
        closed=True,
        transform=ax.transAxes,
        facecolor=color, edgecolor=color,
        linewidth=lw, joinstyle="round",
        zorder=10, clip_on=False,
    )
    ax.add_patch(kite)

    # "N" label above the tip
    ax.text(
        x, y + size * 0.18, "N",
        transform=ax.transAxes,
        ha="center", va="bottom",
        fontsize=size * 95,          # scales with arrow; tweak if needed
        fontweight="bold", color=color,
        zorder=11, clip_on=False,
    )


if __name__ == "__main__":
    # quick self-test render
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(4, 5))
    ax.set_xlim(0, 1); ax.set_ylim(0, 1)
    ax.set_axis_off()
    ax.add_patch(mpatches.Rectangle((0, 0), 1, 1, fc="#eef2f4", ec="none"))
    add_north_arrow(ax, x=0.85, y=0.85, size=0.12)
    add_north_arrow(ax, x=0.5, y=0.55, size=0.08)   # smaller variant
    fig.savefig("north_arrow_test.png", dpi=200, bbox_inches="tight")
    print("saved north_arrow_test.png")
