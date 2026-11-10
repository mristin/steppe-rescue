#!/usr/bin/env python3

"""
Turn the old photographs in assets/pictures/sources/ into the pixel-art
portraits of the people in assets/pictures/portraits/.

Each source in assets/pictures/sources/sources.json gives its crop around the
head. We sharpen the crop, shrink it to 128x128 (a portrait is shown 64
logical pixels wide, at the two pixels of the screen per logical pixel of the
game, see scenes/pixel/pixelate.gd), cut it into an oval (the photos of the
19th century are oval vignettes), and paint it in the sepia ramp of the palette
(scenes/pixel/palette.gd), from the outline to the felt, each pixel in the tone
nearest to its brightness. Outside the oval is the sky, with the outline.

A source may also give the outline of the person in the photo ("figure", a
polygon in the pixels of the photo), where the person is as pale as the paper
behind (e.g., a white headdress): outside it is the sky, too, and the outline
goes around the person.

A source may also retouch the photo before ("retouch", a list of
[x, y, dx, dy, radius] in the pixels of the photo): the photo is warped
smoothly, so that what is around (x, y) moves by (dx, dy), fading out over
the radius. Grandmother's mouth corners and cheeks are lifted this way into a
gentle smile, since nobody smiled for the camera in the 19th century.

A source may lift the shadows ("gamma" below 1), so that a face in the shade
reads friendly in the few tones of the portrait.

The photos stay photos: only the pictures which are drawn are vectors.

Run it again after changing a crop or adding a source; the result is the same
on every run.
"""

import argparse
import json
import math
import pathlib
import sys
from typing import Optional

from PIL import Image, ImageDraw, ImageFilter, ImageOps

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent

SOURCES_DIR = REPO_ROOT / "assets" / "pictures" / "sources"
PORTRAITS_DIR = REPO_ROOT / "assets" / "pictures" / "portraits"

SIZE = 128

#: The sepia ramp of the palette, from the darkest to the lightest: OUTLINE,
#: HOOF, HORSE_BAY, SKIN_DEEP, SKIN_DARK, SKIN_TAN, SKIN, SKIN_FAIR, FELT.
RAMP = [
    (0x2B, 0x1A, 0x10),
    (0x3B, 0x2A, 0x20),
    (0x7A, 0x3F, 0x1D),
    (0x8A, 0x56, 0x34),
    (0xB9, 0x7A, 0x52),
    (0xCF, 0x91, 0x62),
    (0xE0, 0xA8, 0x78),
    (0xF2, 0xCF, 0xAE),
    (0xF4, 0xEA, 0xD5),
]

#: The brightness (0-255) at which each color of the ramp is placed; a pixel
#: takes the color whose brightness is nearest to its own.
LEVELS = [0, 40, 80, 105, 135, 160, 190, 222, 255]

#: The sky behind the oval: SKY_LIGHT.
BACKGROUND = (0x8F, 0xB8, 0xE0)

OUTLINE = RAMP[0]


def _inside(x: int, y: int) -> bool:
    center = (SIZE - 1) / 2
    return ((x - center) / (SIZE / 2 - 1.0)) ** 2 + ((y - center) / (SIZE / 2 - 0.5)) ** 2 <= 1.0


#: The side of the cells of the mesh which warps a photo, in its pixels.
WARP_CELL = 4


def retouch(photo: Image.Image, moves: list) -> Image.Image:
    """Warp the photo smoothly by the moves, each [x, y, dx, dy, radius]."""

    def source(x: float, y: float) -> tuple:
        sx, sy = x, y
        for cx, cy, dx, dy, radius in moves:
            weight = math.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (2.0 * radius**2))
            sx -= dx * weight
            sy -= dy * weight
        return (sx, sy)

    width, height = photo.size
    reach = max(3 * radius for *_, radius in moves)
    left = max(0, int(min(m[0] for m in moves) - reach))
    top = max(0, int(min(m[1] for m in moves) - reach))
    right = min(width, int(max(m[0] for m in moves) + reach))
    bottom = min(height, int(max(m[1] for m in moves) + reach))

    mesh = []
    for y in range(top, bottom, WARP_CELL):
        for x in range(left, right, WARP_CELL):
            x1, y1 = min(x + WARP_CELL, right), min(y + WARP_CELL, bottom)
            quad = source(x, y) + source(x, y1) + source(x1, y1) + source(x1, y)
            mesh.append(((x - left, y - top, x1 - left, y1 - top), quad))
    warped = photo.transform((right - left, bottom - top), Image.MESH, mesh, resample=Image.BICUBIC)
    result = photo.copy()
    result.paste(warped, (left, top))
    return result


def _tone(value: int) -> tuple:
    return RAMP[min(range(len(LEVELS)), key=lambda i: abs(LEVELS[i] - value))]


def pixelize(
    photo: Image.Image, crop: list, figure: Optional[list] = None, gamma: float = 1.0
) -> Image.Image:
    """Make the portrait of the crop of the photo, with the figure if given."""
    mask = Image.new("L", photo.size, 255)
    if figure is not None:
        mask = Image.new("L", photo.size, 0)
        ImageDraw.Draw(mask).polygon([tuple(point) for point in figure], fill=255)
    box = tuple(crop)
    gray = ImageOps.autocontrast(ImageOps.grayscale(photo.crop(box)), cutoff=1, mask=mask.crop(box))
    if gamma != 1.0:
        gray = gray.point(lambda value: round(255.0 * (value / 255.0) ** gamma))
    small = gray.filter(ImageFilter.UnsharpMask(3, 80, 2)).resize((SIZE, SIZE), Image.LANCZOS)
    small_mask = mask.crop(box).resize((SIZE, SIZE), Image.BOX)

    def person(x: int, y: int) -> bool:
        return (
            0 <= x < SIZE and 0 <= y < SIZE and _inside(x, y) and small_mask.getpixel((x, y)) >= 128
        )

    portrait = Image.new("RGB", (SIZE, SIZE), BACKGROUND)
    for y in range(SIZE):
        for x in range(SIZE):
            neighbors = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
            if person(x, y):
                portrait.putpixel((x, y), _tone(small.getpixel((x, y))))
                continue
            if _inside(x, y):
                if any(person(nx, ny) for nx, ny in neighbors):
                    portrait.putpixel((x, y), OUTLINE)
                continue
            if any(0 <= nx < SIZE and 0 <= ny < SIZE and _inside(nx, ny) for nx, ny in neighbors):
                portrait.putpixel((x, y), OUTLINE)
    return portrait


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Do not write anything; fail if a portrait is out of date.",
    )
    args = parser.parse_args()

    sources = json.loads((SOURCES_DIR / "sources.json").read_text(encoding="utf-8"))
    stale = []
    for source in sources:
        with Image.open(SOURCES_DIR / source["source"]) as photo:
            picture = photo.convert("RGB")
            if "retouch" in source:
                picture = retouch(picture, source["retouch"])
            portrait = pixelize(
                picture, source["crop"], source.get("figure"), source.get("gamma", 1.0)
            )
        path = PORTRAITS_DIR / f"{source['id']}.png"
        if path.exists():
            with Image.open(path) as existing:
                if list(existing.convert("RGB").getdata()) == list(portrait.getdata()):
                    continue
        stale.append(path)
        if not args.check:
            PORTRAITS_DIR.mkdir(parents=True, exist_ok=True)
            portrait.save(path)
            print(f"Wrote {path.relative_to(REPO_ROOT)}")

    if args.check and stale:
        for path in stale:
            print(f"{path.relative_to(REPO_ROOT)} is out of date; run dev/pictures/pixelize.py")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
