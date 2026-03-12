#!/usr/bin/env python3
"""
Generates the SatStack Development app icon.
Style: blue diagonal gradient background + white wallet illustration (no beta banner).
"""

import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SIZE = 1024
ASSETS_DIR = "SatStack/SatStack/Resources/Assets.xcassets"
OUTPUT_ICONSET = os.path.join(ASSETS_DIR, "AppIconDev.appiconset")
OUTPUT_FILE = os.path.join(OUTPUT_ICONSET, "app_icon_1024.png")

# ─── Colours ─────────────────────────────────────────────────────────────────
GRAD_TOP_LEFT     = (68, 152, 248)   # #4498F8  – bright sky blue
GRAD_BOTTOM_RIGHT = (16,  66, 196)   # #1042C4  – deep blue

WHITE             = (255, 255, 255, 255)
WHITE_STRONG      = (255, 255, 255, 230)
WHITE_MID         = (255, 255, 255, 160)
WHITE_SOFT        = (255, 255, 255,  90)

# Detail colour inside the front card (semi-transparent white on white = subtle indent)
CARD_DETAIL = (200, 220, 245, 210)   # very light blue-white


# ─── Helpers ─────────────────────────────────────────────────────────────────

def make_gradient(size: int) -> Image.Image:
    """Diagonal linear gradient top-left → bottom-right."""
    x = np.linspace(0, 1, size, dtype=np.float32)
    y = np.linspace(0, 1, size, dtype=np.float32)
    xx, yy = np.meshgrid(x, y)
    t = np.clip((xx * 0.55 + yy * 0.45), 0, 1)

    s = np.array(GRAD_TOP_LEFT,     dtype=np.float32)
    e = np.array(GRAD_BOTTOM_RIGHT, dtype=np.float32)
    rgb = (s * (1 - t[..., None]) + e * t[..., None]).astype(np.uint8)
    return Image.fromarray(rgb, "RGB").convert("RGBA")


def rounded_rect(draw: ImageDraw.ImageDraw, xy, r: int, fill):
    """Draw a filled rounded rectangle."""
    x0, y0, x1, y1 = xy
    draw.rectangle([x0 + r, y0,     x1 - r, y1    ], fill=fill)
    draw.rectangle([x0,     y0 + r, x1,     y1 - r], fill=fill)
    draw.ellipse  ([x0,          y0,          x0 + 2*r, y0 + 2*r], fill=fill)
    draw.ellipse  ([x1 - 2*r,    y0,          x1,       y0 + 2*r], fill=fill)
    draw.ellipse  ([x0,          y1 - 2*r,    x0 + 2*r, y1      ], fill=fill)
    draw.ellipse  ([x1 - 2*r,    y1 - 2*r,    x1,       y1      ], fill=fill)


def layer(size: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def composite(base: Image.Image, overlay: Image.Image) -> Image.Image:
    return Image.alpha_composite(base, overlay)


BTC_FONT_PATH = "/Library/Fonts/SF-Pro-Display-Bold.otf"
BTC_FONT_SIZE = 148   # gives ~127px cap-height, fits well in a 108px-radius circle


def draw_bitcoin_symbol(draw: ImageDraw.ImageDraw, cx: int, cy: int, color):
    """Renders the ₿ glyph using SF Pro Display Bold, centred at (cx, cy)."""
    font = ImageFont.truetype(BTC_FONT_PATH, BTC_FONT_SIZE)
    bb   = draw.textbbox((0, 0), "₿", font=font)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    tx   = cx - w // 2 - bb[0]
    ty   = cy - h // 2 - bb[1]
    draw.text((tx, ty), "₿", fill=color, font=font)


# ─── Main ─────────────────────────────────────────────────────────────────────

def build_icon(size: int) -> Image.Image:
    img = make_gradient(size)

    # ── Card geometry ─────────────────────────────────────────────────────────
    card_w  = 700
    card_h  = 380
    card_r  = 52

    cx = size // 2
    cy = size // 2 + 15      # very slightly below centre

    fx0 = cx - card_w // 2
    fy0 = cy - card_h // 2
    fx1 = fx0 + card_w
    fy1 = fy0 + card_h

    stack_up   = 44           # vertical offset between each card in the stack
    stack_shrink = 18         # each back card is slightly narrower per side

    # ── Card 3 – furthest back ────────────────────────────────────────────────
    ov3, d3 = layer(size)
    s3 = stack_shrink * 2
    rounded_rect(d3,
                 (fx0 + s3, fy0 - stack_up * 2,
                  fx1 - s3, fy1 - stack_up * 2 + card_h // 6),
                 card_r - 4, WHITE_SOFT)
    img = composite(img, ov3)

    # ── Card 2 – middle ───────────────────────────────────────────────────────
    ov2, d2 = layer(size)
    s2 = stack_shrink
    rounded_rect(d2,
                 (fx0 + s2, fy0 - stack_up,
                  fx1 - s2, fy1 - stack_up + card_h // 10),
                 card_r - 2, WHITE_MID)
    img = composite(img, ov2)

    # ── Front card – solid white ──────────────────────────────────────────────
    ov_f, df = layer(size)
    rounded_rect(df, (fx0, fy0, fx1, fy1), card_r, WHITE)
    img = composite(img, ov_f)

    # ── Horizontal lines on front card (left third) ───────────────────────────
    draw = ImageDraw.Draw(img)
    line_x0     = fx0 + 68
    line_x1     = fx0 + 280
    line_y_base = fy0 + card_h // 2 - 18
    line_h      = 13
    line_gap    = 28
    line_r      = 6

    for i in range(3):
        ly = line_y_base + i * line_gap
        rounded_rect(draw, (line_x0, ly, line_x1, ly + line_h), line_r, CARD_DETAIL)

    # ── Bitcoin circle (right side of front card) ─────────────────────────────
    circ_cx = fx0 + card_w - 190
    circ_cy = fy0 + card_h // 2
    circ_r  = 108

    ov_c, dc = layer(size)
    dc.ellipse([circ_cx - circ_r, circ_cy - circ_r,
                circ_cx + circ_r, circ_cy + circ_r],
               fill=(210, 228, 248, 175))
    img = composite(img, ov_c)

    # ── Bitcoin ₿ glyph ───────────────────────────────────────────────────────
    btc_color = (28, 80, 190, 235)   # dark blue, matching gradient

    ov_b, db = layer(size)
    draw_bitcoin_symbol(db, circ_cx, circ_cy, btc_color)
    img = composite(img, ov_b)

    return img.convert("RGB")


def write_contents_json(iconset_dir: str):
    """Write the minimal Contents.json for a 1024×1024 universal iOS icon."""
    import json
    contents = {
        "images": [
            {
                "filename": "app_icon_1024.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    path = os.path.join(iconset_dir, "Contents.json")
    with open(path, "w") as f:
        json.dump(contents, f, indent=2)
    print(f"  Contents.json → {path}")


def main():
    os.makedirs(OUTPUT_ICONSET, exist_ok=True)

    print("Building icon…")
    icon = build_icon(SIZE)
    icon.save(OUTPUT_FILE, "PNG")
    print(f"  Icon saved  → {OUTPUT_FILE}")

    write_contents_json(OUTPUT_ICONSET)
    print("Done.")


if __name__ == "__main__":
    main()
