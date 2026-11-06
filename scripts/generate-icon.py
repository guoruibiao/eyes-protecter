#!/usr/bin/env python3
"""Compose the supplied sprout artwork into a macOS app icon.

Source artwork: Resources/IconSource.png (152x150, transparent RGBA).
The tiny source is enlarged with Lanczos + a light unsharp pass; the flat
illustration holds up well at Finder/Spotlight sizes.
"""
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Resources" / "IconSource.png"
ICNS = ROOT / "Resources" / "AppIcon.icns"
PREVIEW = ROOT / "previews" / "icon.png"

SIZE = 1024
INSET = 44
RADIUS = 222


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def vertical_gradient(size, top, bottom):
    image = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(image)
    for y in range(size):
        t = y / (size - 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        draw.line((0, y, size, y), fill=color)
    return image


def load_artwork():
    source = Image.open(SOURCE).convert("RGBA")
    enlarged = source.resize((790, 780), Image.LANCZOS)
    enlarged = enlarged.filter(ImageFilter.UnsharpMask(radius=2, percent=70, threshold=2))
    return enlarged.crop(enlarged.getbbox())


def compose():
    artwork = load_artwork()
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rect = (INSET, INSET, SIZE - INSET, SIZE - INSET)

    # macOS-like soft drop shadow behind the tile.
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        (rect[0], rect[1] + 18, rect[2], rect[3] + 22),
        radius=RADIUS,
        fill=(17, 52, 36, 80),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(26))
    canvas = Image.alpha_composite(canvas, shadow)

    # Pale mint tile with a soft white glow.
    tile = vertical_gradient(SIZE, (246, 253, 247), (211, 239, 220))
    glow = Image.new("L", (SIZE, SIZE), 0)
    gd = ImageDraw.Draw(glow)
    gd.ellipse((150, 60, 880, 790), fill=110)
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    glow_layer = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    glow_layer.putalpha(glow)
    tile = Image.alpha_composite(tile, glow_layer)

    masked_tile = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    masked_tile.paste(tile, (0, 0), rounded_mask(SIZE, RADIUS))
    canvas = Image.alpha_composite(canvas, masked_tile)

    # Delicate inner highlight.
    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    hd.rounded_rectangle(
        (rect[0] + 2, rect[1] + 2, rect[2] - 2, rect[3] - 2),
        radius=RADIUS - 2,
        outline=(255, 255, 255, 125),
        width=3,
    )
    canvas = Image.alpha_composite(canvas, highlight)

    # Center the sprout, leaving breathing room on every side.
    width, height = artwork.size
    scale = min(780 / width, 760 / height)
    scaled = artwork.resize((int(width * scale), int(height * scale)), Image.LANCZOS)
    x = (SIZE - scaled.width) // 2
    y = 500 - scaled.height // 2
    canvas.alpha_composite(scaled, (x, y))
    return canvas


def main():
    if not SOURCE.exists():
        raise SystemExit(f"missing artwork: {SOURCE}")

    icon = compose()
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    icon.save(PREVIEW)

    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()
        for base in (16, 32, 128, 256, 512):
            for suffix, scale in (("", 1), ("@2x", 2)):
                size = base * scale
                resized = icon.resize((size, size), Image.LANCZOS)
                resized.save(iconset / f"icon_{base}x{base}{suffix}.png")
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(ICNS)], check=True)

    print(f"wrote {ICNS}")
    print(f"wrote {PREVIEW}")


if __name__ == "__main__":
    main()
