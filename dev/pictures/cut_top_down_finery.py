"""
Cut a piece of the finery, painted by an image model on the template of the
rider on her horse seen from above (dev/pictures/top_down_template.png), into
assets/pictures/top_down/finery/<piece>_<step>.png:

    python dev/pictures/cut_top_down_finery.py <painted.png> <piece> <step>

or a whole sheet, painted on dev/pictures/top_down_template_grid.png, with the
pieces of GRID in its cells, row by row:

    python dev/pictures/cut_top_down_finery.py <painted_sheet.png>

The template is a flat grey horse (light) with the rider (dark) on white. The
script finds the grey silhouette in the painting, maps the painting onto the
canvas of the template by the box of the silhouette, and keeps only what is
not the white background and not the flat grey: the painted piece.

Run with numpy, opencv-python-headless and pillow.
"""

import pathlib
import sys

import cv2
import numpy as np
from PIL import Image

REPO = pathlib.Path(__file__).resolve().parents[2]
TEMPLATE = REPO / "dev" / "pictures" / "top_down_template.png"
CANVAS = 282  # the big canvas of the horses from above, in pixels

# The greys of the horse and the rider in the template (and, as painted, in
# the sheets: the image model keeps them flat).
HORSE_GREY = 171
RIDER_GREY = 130

## The pieces in the cells of the grid sheet, row by row: [piece, step].
GRID = [
    ["saddle", 1],
    ["saddle", 2],
    ["saddle_cloth", 1],
    ["saddle_cloth", 2],
    ["bridle", 1],
    ["bridle", 2],
    ["breastplate", 1],
    ["stirrups", 1],
    ["mane", 1],
    ["mane", 2],
    ["mane", 3],
    ["feathers", 1],
]


def flat_background(rgb: np.ndarray) -> np.ndarray:
    """
    The pixels of the template in the painting: the white background and the
    flat greys of the horse and the rider. Silver and white pieces are
    textured, so a pixel counts only where the colour is also flat around it.
    """
    image = rgb.astype(np.float32)
    grey = image.mean(axis=2)
    spread = image.max(axis=2) - image.min(axis=2)
    mean = cv2.blur(grey, (5, 5))
    variance = cv2.blur(grey * grey, (5, 5)) - mean * mean
    flat = (spread < 8) & (variance < 6.0)
    tones = (grey > 246) | (np.abs(grey - HORSE_GREY) < 7) | (np.abs(grey - RIDER_GREY) < 7)
    background = flat & tones
    # NOTE (mristin):
    # The soft edges of the template (and the lines of the grid) blend its
    # tones, so they are neither flat nor of a tone: any neutral pixel right
    # next to the template counts as the template, too.
    near = cv2.dilate(background.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0
    return background | (near & (spread < 14))


def silhouette_box(rgb: np.ndarray) -> tuple:
    """The box of the flat greys of the horse and the rider (the pieces may
    split them, but they never cover the nose or the tip of the tail)."""
    image = rgb.astype(np.float32)
    grey = image.mean(axis=2)
    spread = image.max(axis=2) - image.min(axis=2)
    silhouette = (spread < 8) & (grey > 100) & (grey < 200)
    silhouette = cv2.morphologyEx(silhouette.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3)))
    ys, xs = np.where(silhouette > 0)
    return xs.min(), ys.min(), xs.max(), ys.max()


def main() -> None:
    painted = np.array(Image.open(sys.argv[1]).convert("RGB"))
    if len(sys.argv) > 2:
        cut(painted, sys.argv[2], int(sys.argv[3]))
        return
    # NOTE (mristin):
    # A sheet: the cells of the grid, 4 across and 3 down, whatever its size.
    h, w = painted.shape[:2]
    for i, (piece, step) in enumerate(GRID):
        r, c = divmod(i, 4)
        cell = painted[r * h // 3 : (r + 1) * h // 3, c * w // 4 : (c + 1) * w // 4].copy()
        # NOTE (mristin):
        # The lines of the grid run along the borders of the cells: paint the
        # borders white.
        margin = max(4, cell.shape[1] // 40)
        cell[:margin] = cell[-margin:] = 255
        cell[:, :margin] = cell[:, -margin:] = 255
        cut(cell, piece, step)


def cut(painted: np.ndarray, piece: str, step: int) -> None:
    """Cut the piece out of the painting of one template, and save it."""
    template = np.array(Image.open(TEMPLATE).convert("RGB"))

    tx0, ty0, tx1, ty1 = silhouette_box(template)
    px0, py0, px1, py1 = silhouette_box(painted)
    # NOTE (mristin):
    # The scale from the height of the silhouette (the length of the horse),
    # which the pieces do not change; the position from its middle.
    scale = (ty1 - ty0) / max(1, py1 - py0)
    tcx, pcx = (tx0 + tx1) / 2, (px0 + px1) / 2
    M = np.array([[scale, 0, tcx - pcx * scale], [0, scale, ty0 - py0 * scale]])
    size = template.shape[1], template.shape[0]
    warped = cv2.warpAffine(painted, M, size, flags=cv2.INTER_AREA, borderValue=(255, 255, 255))

    alpha = np.where(flat_background(warped), 0, 255).astype(np.uint8)
    alpha = cv2.morphologyEx(alpha, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats((alpha > 0).astype(np.uint8), 8)
    for k in range(1, n):
        thin = max(stats[k, cv2.CC_STAT_WIDTH], stats[k, cv2.CC_STAT_HEIGHT]) < 40
        if stats[k, cv2.CC_STAT_AREA] < 200 or (thin and stats[k, cv2.CC_STAT_AREA] < 600):
            alpha[labels == k] = 0
    alpha = cv2.GaussianBlur(alpha, (0, 0), 0.8)

    out = REPO / "assets" / "pictures" / "top_down" / "finery" / f"{piece}_{step}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    image = Image.fromarray(np.dstack([warped, alpha])).resize((CANVAS, CANVAS), Image.LANCZOS)
    image.save(out, optimize=True)
    print(f"Wrote {out.relative_to(REPO)}")


if __name__ == "__main__":
    main()
