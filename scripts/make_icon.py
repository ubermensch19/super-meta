#!/usr/bin/env python3
"""Generate the Super Meta app icon and in-app logomark from the cropped source logo.

Produces:
  - App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
        1024x1024, white background, mark centered (equal L/R and T/B margins), opaque RGB.
  - App/Resources/Assets.xcassets/Logomark.imageset/logomark.png
        transparent-background version of the mark for use on the app's dark canvas.

Run:  python3 scripts/make_icon.py
"""
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / ".context/attachments/B7i1jD/image.png"
ICON_OUT = ROOT / "App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
MARK_OUT = ROOT / "App/Resources/Assets.xcassets/Logomark.imageset/logomark.png"

# A pixel counts as background when every channel is this bright or above.
WHITE_CUTOFF = 244


def content_bbox(im):
    """Tight bounding box of the non-white content."""
    rgb = im.convert("RGB")
    px = rgb.load()
    w, h = rgb.size
    minx, miny, maxx, maxy = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if not (r >= WHITE_CUTOFF and g >= WHITE_CUTOFF and b >= WHITE_CUTOFF):
                minx, miny = min(minx, x), min(miny, y)
                maxx, maxy = max(maxx, x), max(maxy, y)
    return (minx, miny, maxx + 1, maxy + 1)


def alpha_from_white(im):
    """Knock the white background out to transparency.

    Alpha is derived from how far a pixel is from pure white so anti-aliased
    edges feather cleanly instead of leaving a hard white halo.
    """
    rgba = im.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            # distance-from-white on the brightest channel; 0 at white, 255 at black/saturated
            dist = 255 - min(r, g, b)
            a = 0 if dist <= 0 else min(255, int(dist * 255 / (255 - (255 - WHITE_CUTOFF))))
            px[x, y] = (r, g, b, a)
    return rgba


def main():
    src = Image.open(SRC).convert("RGB")
    box = content_bbox(src)
    mark = src.crop(box)
    mw, mh = mark.size
    print(f"source {src.size}  content bbox {box}  mark {mw}x{mh}")

    # --- App icon: white square, mark centered, ~12% horizontal padding per side ---
    canvas = 1024
    target_w = int(canvas * 0.76)          # ~12% padding on left and right
    scale = target_w / mw
    target_h = int(round(mh * scale))
    mark_icon = mark.resize((target_w, target_h), Image.LANCZOS)
    mark_icon = mark_icon.filter(ImageFilter.UnsharpMask(radius=1.4, percent=80, threshold=2))

    icon = Image.new("RGB", (canvas, canvas), (255, 255, 255))
    ox = (canvas - target_w) // 2          # equal left/right margins
    oy = (canvas - target_h) // 2          # equal top/bottom margins
    icon.paste(mark_icon, (ox, oy))
    ICON_OUT.parent.mkdir(parents=True, exist_ok=True)
    icon.save(ICON_OUT)
    print(f"wrote {ICON_OUT}  ({canvas}x{canvas}, RGB)  margins L/R={ox} T/B={oy}")

    # --- In-app logomark: transparent background, ~600px wide ---
    mark_w = 600
    mark_h = int(round(mh * (mark_w / mw)))
    mark_big = mark.resize((mark_w, mark_h), Image.LANCZOS)
    mark_t = alpha_from_white(mark_big)
    MARK_OUT.parent.mkdir(parents=True, exist_ok=True)
    mark_t.save(MARK_OUT)
    print(f"wrote {MARK_OUT}  ({mark_w}x{mark_h}, RGBA transparent)")


if __name__ == "__main__":
    main()
