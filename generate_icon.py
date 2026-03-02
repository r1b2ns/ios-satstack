#!/usr/bin/env python3
"""
Generate the SatStack app icon at 1024x1024.

Design concept (no text — iOS best practice):
- Dark gradient background (deep navy to near-black)
- Three stacked rounded-rect wallet "cards" (the "Stack")
- Hand-drawn Bitcoin ₿ symbol on the front card
- Orange/amber/gold accent (Bitcoin brand color)
- Subtle glow for depth and premium feel
"""

from PIL import Image, ImageDraw, ImageFont
import math
import os

SIZE = 1024


def lerp_color(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_rounded_card(img, bbox, radius, color_top, color_bottom,
                      border_color=None, border_width=2, alpha=255):
    x0, y0, x1, y1 = bbox
    w, h = x1 - x0, y1 - y0

    card = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    for y in range(h):
        t = y / max(1, h - 1)
        c = lerp_color(color_top, color_bottom, t)
        cd.line([(0, y), (w, y)], fill=(*c, alpha))

    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [(0, 0), (w - 1, h - 1)], radius=radius, fill=255
    )
    card.putalpha(mask)

    if border_color and border_width > 0:
        border = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(border).rounded_rectangle(
            [(1, 1), (w - 2, h - 2)],
            radius=radius, outline=border_color, width=border_width,
        )
        bm = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        bm.paste(border, mask=mask)
        card = Image.alpha_composite(card, bm)

    img.paste(card, (x0, y0), card)


def draw_bitcoin_b(draw, cx, cy, size, color, stroke_width=None):
    """
    Draw a recognizable Bitcoin "₿" symbol (capital B with two vertical bars)
    using only basic drawing primitives.
    """
    if stroke_width is None:
        stroke_width = max(4, int(size * 0.085))

    half = size // 2
    # Vertical bar positions (two bars through the B)
    bar_left  = cx - int(size * 0.08)
    bar_right = cx + int(size * 0.08)
    bar_top    = cy - half - int(size * 0.08)
    bar_bottom = cy + half + int(size * 0.08)

    # Draw vertical bars
    draw.rounded_rectangle(
        [bar_left - stroke_width // 2, bar_top,
         bar_left + stroke_width // 2, bar_bottom],
        radius=stroke_width // 2, fill=color
    )
    draw.rounded_rectangle(
        [bar_right - stroke_width // 2, bar_top,
         bar_right + stroke_width // 2, bar_bottom],
        radius=stroke_width // 2, fill=color
    )

    # B shape: left vertical spine + two bumps (upper and lower arcs)
    spine_x = cx - int(size * 0.22)
    top_y = cy - half
    mid_y = cy
    bot_y = cy + half

    # Left vertical spine of B
    draw.rounded_rectangle(
        [spine_x - stroke_width // 2, top_y,
         spine_x + stroke_width // 2, bot_y],
        radius=stroke_width // 2, fill=color
    )

    # Top horizontal bar
    draw.rounded_rectangle(
        [spine_x, top_y - stroke_width // 2,
         cx + int(size * 0.10), top_y + stroke_width // 2],
        radius=stroke_width // 2, fill=color
    )

    # Middle horizontal bar
    draw.rounded_rectangle(
        [spine_x, mid_y - stroke_width // 2,
         cx + int(size * 0.14), mid_y + stroke_width // 2],
        radius=stroke_width // 2, fill=color
    )

    # Bottom horizontal bar
    draw.rounded_rectangle(
        [spine_x, bot_y - stroke_width // 2,
         cx + int(size * 0.10), bot_y + stroke_width // 2],
        radius=stroke_width // 2, fill=color
    )

    # Upper bump (arc) — using an ellipse arc
    upper_bump_w = int(size * 0.38)
    upper_bump_h = int(size * 0.46)
    upper_cx = cx + int(size * 0.02)
    upper_cy = cy - int(size * 0.25)

    draw.arc(
        [upper_cx - upper_bump_w // 2, upper_cy - upper_bump_h // 2,
         upper_cx + upper_bump_w // 2, upper_cy + upper_bump_h // 2],
        start=-90, end=90, fill=color, width=stroke_width
    )

    # Lower bump (slightly wider) — using an ellipse arc
    lower_bump_w = int(size * 0.44)
    lower_bump_h = int(size * 0.50)
    lower_cx = cx + int(size * 0.04)
    lower_cy = cy + int(size * 0.25)

    draw.arc(
        [lower_cx - lower_bump_w // 2, lower_cy - lower_bump_h // 2,
         lower_cx + lower_bump_w // 2, lower_cy + lower_bump_h // 2],
        start=-90, end=90, fill=color, width=stroke_width
    )


def generate_icon():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # ── Background gradient ──────────────────────────────────────────
    bg_top = (18, 18, 42)
    bg_bottom = (6, 6, 18)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        c = lerp_color(bg_top, bg_bottom, t)
        draw.line([(0, y), (SIZE, y)], fill=c)

    # ── Subtle radial glow ───────────────────────────────────────────
    glow_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow_layer)
    gcx, gcy = SIZE // 2, int(SIZE * 0.45)
    gr = int(SIZE * 0.50)
    for r in range(gr, 0, -3):
        frac = r / gr
        alpha = int(20 * frac)
        c = lerp_color((255, 160, 30), (20, 20, 42), frac)
        gd.ellipse([gcx - r, gcy - r, gcx + r, gcy + r], fill=(*c, alpha))
    img = Image.alpha_composite(img, glow_layer)
    draw = ImageDraw.Draw(img)

    # ── Card dimensions ──────────────────────────────────────────────
    card_w = int(SIZE * 0.62)
    card_h = int(SIZE * 0.38)
    card_r = int(SIZE * 0.045)
    cx = SIZE // 2
    cy = int(SIZE * 0.47)

    # ── Back card (darkest, smallest) ────────────────────────────────
    bw, bh = int(card_w * 0.86), int(card_h * 0.86)
    draw_rounded_card(
        img,
        (cx - bw // 2, cy - int(SIZE * 0.10) - bh // 2,
         cx + bw // 2, cy - int(SIZE * 0.10) + bh // 2),
        radius=card_r,
        color_top=(55, 45, 22), color_bottom=(35, 28, 12),
        border_color=(140, 110, 45, 50), border_width=2, alpha=160,
    )

    # ── Middle card ──────────────────────────────────────────────────
    mw, mh = int(card_w * 0.93), int(card_h * 0.93)
    draw_rounded_card(
        img,
        (cx - mw // 2, cy - int(SIZE * 0.04) - mh // 2,
         cx + mw // 2, cy - int(SIZE * 0.04) + mh // 2),
        radius=card_r,
        color_top=(100, 78, 22), color_bottom=(72, 55, 15),
        border_color=(190, 150, 50, 65), border_width=2, alpha=200,
    )

    # ── Front card (Bitcoin gold) ────────────────────────────────────
    fx0 = cx - card_w // 2
    fy0 = cy + int(SIZE * 0.04) - card_h // 2
    fx1 = cx + card_w // 2
    fy1 = cy + int(SIZE * 0.04) + card_h // 2

    draw_rounded_card(
        img,
        (fx0, fy0, fx1, fy1),
        radius=card_r,
        color_top=(248, 170, 35), color_bottom=(210, 125, 12),
        border_color=(255, 210, 90, 110), border_width=3, alpha=255,
    )

    # ── Accent lines on front card ───────────────────────────────────
    detail = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    dd = ImageDraw.Draw(detail)
    lx = fx0 + int(card_w * 0.07)

    dd.rounded_rectangle(
        [(lx, fy0 + int(card_h * 0.20)),
         (lx + int(card_w * 0.24), fy0 + int(card_h * 0.20) + 7)],
        radius=4, fill=(255, 230, 140, 100)
    )
    dd.rounded_rectangle(
        [(lx, fy0 + int(card_h * 0.31)),
         (lx + int(card_w * 0.38), fy0 + int(card_h * 0.31) + 6)],
        radius=3, fill=(255, 230, 140, 70)
    )
    dd.rounded_rectangle(
        [(lx, fy0 + int(card_h * 0.40)),
         (lx + int(card_w * 0.17), fy0 + int(card_h * 0.40) + 5)],
        radius=3, fill=(255, 230, 140, 50)
    )
    img = Image.alpha_composite(img, detail)
    draw = ImageDraw.Draw(img)

    # ── Bitcoin ₿ symbol on front card ───────────────────────────────
    btc_size = int(card_h * 0.50)
    btc_cx = fx0 + int(card_w * 0.72)
    btc_cy = (fy0 + fy1) // 2

    # Glow behind symbol
    btc_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    bd = ImageDraw.Draw(btc_layer)
    for r in range(btc_size // 2 + 30, 0, -2):
        alpha = int(28 * (r / (btc_size // 2 + 30)))
        bd.ellipse([btc_cx - r, btc_cy - r, btc_cx + r, btc_cy + r],
                    fill=(255, 255, 210, alpha))
    img = Image.alpha_composite(img, btc_layer)
    draw = ImageDraw.Draw(img)

    # Draw the ₿ using shapes — dark color for contrast on gold
    draw_bitcoin_b(draw, btc_cx, btc_cy, btc_size,
                   color=(55, 30, 5, 230), stroke_width=int(btc_size * 0.095))

    # ── Floating sat dots ────────────────────────────────────────────
    dots_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    dots_d = ImageDraw.Draw(dots_layer)
    dots = [
        (int(SIZE * 0.14), int(SIZE * 0.22), 8,  (255, 180, 50, 40)),
        (int(SIZE * 0.84), int(SIZE * 0.17), 6,  (255, 180, 50, 30)),
        (int(SIZE * 0.89), int(SIZE * 0.58), 10, (255, 180, 50, 25)),
        (int(SIZE * 0.11), int(SIZE * 0.65), 7,  (255, 180, 50, 22)),
        (int(SIZE * 0.20), int(SIZE * 0.82), 5,  (255, 180, 50, 18)),
        (int(SIZE * 0.80), int(SIZE * 0.84), 9,  (255, 180, 50, 20)),
    ]
    for dx, dy, dr, dc in dots:
        dots_d.ellipse([dx - dr, dy - dr, dx + dr, dy + dr], fill=dc)
    img = Image.alpha_composite(img, dots_layer)

    # ── Convert to RGB (App Store requires no alpha) ─────────────────
    final = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    final.paste(img, mask=img.split()[3])
    return final


if __name__ == "__main__":
    icon = generate_icon()

    output_dir = "/home/user/ios-mempool-monitor/MempoolMonitor/MempoolMonitor/Resources/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(output_dir, exist_ok=True)

    icon_path = os.path.join(output_dir, "app_icon_1024.png")
    icon.save(icon_path, "PNG")
    print(f"Saved: {icon_path}")

    preview_path = "/home/user/ios-mempool-monitor/app_icon_preview.png"
    icon.save(preview_path, "PNG")
    print(f"Preview: {preview_path}")
    print("Done!")
