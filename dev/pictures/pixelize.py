#!/usr/bin/env python3

"""
Turn the old photographs in assets/pictures/sources/ into the pixel-art
portraits of the people in assets/pictures/portraits/.

Each source in assets/pictures/sources/sources.json gives its crop around the
head. We sharpen the crop, shrink it to 32x32, cut it into an oval (the photos
of the 19th century are oval vignettes), and paint it in the sepia ramp of the
palette (scenes/pixel/palette.gd), from the outline to the felt, by fixed
thresholds of the brightness. Outside the oval is the sky, with the outline.

Run it again after changing a crop or adding a source; the result is the same
on every run.
"""

import argparse
import json
import pathlib
import sys

from PIL import Image, ImageFilter, ImageOps

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent

SOURCES_DIR = REPO_ROOT / "assets" / "pictures" / "sources"
PORTRAITS_DIR = REPO_ROOT / "assets" / "pictures" / "portraits"

SIZE = 32

#: The sepia ramp of the palette, from the darkest to the lightest: OUTLINE,
#: HOOF, HORSE_BAY, SKIN_DARK, SKIN, FELT.
RAMP = [
    (0x2B, 0x1A, 0x10),
    (0x3B, 0x2A, 0x20),
    (0x7A, 0x3F, 0x1D),
    (0xB9, 0x7A, 0x52),
    (0xE0, 0xA8, 0x78),
    (0xF4, 0xEA, 0xD5),
]

#: The brightness from which each color of the ramp after the first starts.
THRESHOLDS = [45, 80, 115, 150, 195]

#: The sky behind the oval: SKY_LIGHT.
BACKGROUND = (0x8F, 0xB8, 0xE0)

OUTLINE = RAMP[0]


def _inside(x: int, y: int) -> bool:
    center = (SIZE - 1) / 2
    return ((x - center) / (SIZE / 2 - 1.0)) ** 2 + ((y - center) / (SIZE / 2 - 0.5)) ** 2 <= 1.0


def pixelize(photo: Image.Image, crop: list) -> Image.Image:
    """Make the portrait of the crop of the photo."""
    gray = ImageOps.autocontrast(ImageOps.grayscale(photo.crop(tuple(crop))), cutoff=1)
    small = gray.filter(ImageFilter.UnsharpMask(3, 80, 2)).resize((SIZE, SIZE), Image.LANCZOS)

    portrait = Image.new("RGB", (SIZE, SIZE), BACKGROUND)
    for y in range(SIZE):
        for x in range(SIZE):
            if _inside(x, y):
                value = small.getpixel((x, y))
                portrait.putpixel((x, y), RAMP[sum(value > t for t in THRESHOLDS)])
                continue
            neighbors = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
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
            portrait = pixelize(photo.convert("RGB"), source["crop"])
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
