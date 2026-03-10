#!/usr/bin/env python3
"""
Generates a "beta" variant of the SatStack app icon.

Takes the existing 1024x1024 icon and overlays a white diagonal ribbon
in the bottom-right corner with "beta" written in black.

Output:
  - app_icon_beta_preview.png          (root preview)
  - Assets.xcassets/AppIconDev.appiconset/app_icon_1024.png
"""

from PIL import Image, ImageDraw, ImageFont
import os

SIZE = 1024
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

ICON_IN  = os.path.join(
    BASE_DIR,
    "SatStack/SatStack/Resources/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"
)
ICON_OUT = os.path.join(
    BASE_DIR,
    "SatStack/SatStack/Resources/Assets.xcassets/AppIconDev.appiconset/app_icon_1024.png"
)
PREVIEW  = os.path.join(BASE_DIR, "app_icon_beta_preview.png")

FONT_PATHS = [
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/System/Library/Fonts/Helvetica.ttc",
]


def load_font(size):
    for path in FONT_PATHS:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def add_beta_ribbon(base_img: Image.Image) -> Image.Image:
    img = base_img.convert("RGBA")

    # ── Horizontal ribbon geometry ────────────────────────────────────
    # Full-width white band near the bottom of the icon
    band_top    = int(SIZE * 0.78)
    band_bottom = int(SIZE * 0.94)

    ribbon_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(ribbon_layer).rectangle(
        [(0, band_top), (SIZE, band_bottom)],
        fill=(255, 255, 255, 248),
    )

    # ── Center of the band ────────────────────────────────────────────
    cx = SIZE // 2
    cy = (band_top + band_bottom) // 2

    # ── "beta" text — larger font, centered ──────────────────────────
    font_size = int(SIZE * 0.14)
    font = load_font(font_size)

    dummy_draw = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    bbox = dummy_draw.textbbox((0, 0), "beta", font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]

    text_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(text_layer).text(
        (cx - tw // 2 - bbox[0], cy - th // 2 - bbox[1]),
        "beta",
        font=font,
        fill=(15, 15, 15, 255),
    )

    # ── Composite: base → ribbon → text ──────────────────────────────
    result = Image.alpha_composite(img, ribbon_layer)
    result = Image.alpha_composite(result, text_layer)

    # ── Convert to RGB (App Store requires no alpha channel) ──────────
    final = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    final.paste(result, mask=result.split()[3])
    return final


if __name__ == "__main__":
    base = Image.open(ICON_IN)
    beta_icon = add_beta_ribbon(base)

    # Save to AppIconDev appiconset
    os.makedirs(os.path.dirname(ICON_OUT), exist_ok=True)
    beta_icon.save(ICON_OUT, "PNG")
    print(f"Saved: {ICON_OUT}")

    # Save root preview
    beta_icon.save(PREVIEW, "PNG")
    print(f"Preview: {PREVIEW}")
    print("Done!")
