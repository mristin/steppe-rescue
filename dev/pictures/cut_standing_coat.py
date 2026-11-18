"""
Cut the painted riders standing in their coats of the finery (the coat,
шапан, at its steps) out of their paintings, into
assets/pictures/riders/coat_<step>/<rider>.png, where the game takes them at
home and in the level select (see Painting.dressed_rider):

    python dev/pictures/cut_standing_coat.py <folder of the paintings>

The paintings were made from the riders of assets/pictures/riders/, at twice
their size on a flat magenta canvas with a margin of 60 pixels (see
~/Downloads/coat/PROMPTS.md), and named standing_rider_<n>_coat_<step>.png.
An image model draws the girl again, so she may stand a little bigger or
smaller, or a little to the side; and the names may be mixed up. So each
painting is matched to the rider whom it looks like the most (by the colours
of the figure), and put where the rider stands: as tall, its feet where hers
are, in the middle as she is.

The magenta is keyed out as in cut_body.py; anything which does not touch
the figure (e.g., a thin line at the edge of the painting) is dropped.

Run with numpy, opencv-python-headless and pillow.
"""

import pathlib
import re
import sys

import cv2
import numpy as np
from PIL import Image

REPO = pathlib.Path(__file__).resolve().parents[2]
RIDERS = REPO / "assets" / "pictures" / "riders"


def key(rgb: np.ndarray) -> np.ndarray:
    """The RGBA of the painting without its magenta background."""
    r, g, b = [rgb[..., i].astype(np.float32) for i in range(3)]
    magenta = np.minimum(r, b) - g - np.abs(r - b) * 0.5
    alpha = np.clip((140.0 - magenta) / 80.0, 0.0, 1.0)

    # NOTE (mristin):
    # Take the magenta out of the edges, so that they do not glow pink.
    a = np.maximum(alpha, 1e-3)[..., None]
    pink = np.array([255.0, 0.0, 255.0])
    color = (rgb.astype(np.float32) - (1.0 - a) * pink) / a
    color = np.clip(color, 0, 255)
    color = np.where(alpha[..., None] > 0.98, rgb.astype(np.float32), color)
    return np.dstack([color, alpha * 255.0]).astype(np.uint8)


def only_figure(rgba: np.ndarray) -> np.ndarray:
    """Keep only the biggest opaque blob, the figure."""
    mask = (rgba[..., 3] > 32).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    if count <= 1:
        return rgba
    biggest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    keep = cv2.dilate((labels == biggest).astype(np.uint8), np.ones((5, 5), np.uint8))
    result = rgba.copy()
    result[..., 3] = (result[..., 3] * keep).astype(np.uint8)
    return result


def box(alpha: np.ndarray) -> tuple:
    """The box of the opaque pixels: left, top, right, bottom."""
    ys, xs = np.nonzero(alpha > 32)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def colors(rgba: np.ndarray) -> np.ndarray:
    """A histogram of the hue and the saturation of the figure, to match it."""
    hsv = cv2.cvtColor(np.ascontiguousarray(rgba[..., :3]), cv2.COLOR_RGB2HSV)
    mask = (rgba[..., 3] > 128).astype(np.uint8)
    histogram = cv2.calcHist([hsv], [0, 1], mask, [30, 16], [0, 180, 0, 256])
    return cv2.normalize(histogram, histogram).flatten()


def place(rgba: np.ndarray, rider: np.ndarray) -> np.ndarray:
    """The painting put where the rider stands, on the canvas of the rider."""
    left, top, right, bottom = box(rider[..., 3])
    p_left, p_top, p_right, p_bottom = box(rgba[..., 3])
    scale = (bottom - top) / (p_bottom - p_top)
    figure = Image.fromarray(rgba[p_top:p_bottom, p_left:p_right]).resize(
        (max(1, round((p_right - p_left) * scale)), bottom - top), Image.LANCZOS
    )
    canvas = Image.new("RGBA", (rider.shape[1], rider.shape[0]), (0, 0, 0, 0))
    middle = (left + right) / 2.0
    canvas.alpha_composite(figure, (round(middle - figure.width / 2.0), top))
    return np.array(canvas)


def main() -> int:
    folder = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path.cwd()
    riders = {}
    for path in sorted(RIDERS.glob("[0-9].png")):
        riders[path.stem] = np.array(Image.open(path).convert("RGBA"))
    for path in sorted(folder.glob("standing_rider_*_coat_*.png")):
        found = re.match(r"standing_rider_(\d)_coat_(\d)\.png", path.name)
        if found is None:
            continue
        step = found.group(2)
        painted = only_figure(key(np.array(Image.open(path).convert("RGB"))))
        # NOTE (mristin):
        # Match it by its colours, at the size of the riders.
        small = np.array(
            Image.fromarray(painted).resize((painted.shape[1] // 2, painted.shape[0] // 2))
        )
        likeness = {
            name: cv2.compareHist(colors(small), colors(rider), cv2.HISTCMP_CORREL)
            for name, rider in riders.items()
        }
        name = max(likeness, key=likeness.get)
        if name != found.group(1):
            print(f"{path.name} shows the rider {name}, not {found.group(1)}")
        out = RIDERS / f"coat_{step}" / f"{name}.png"
        out.parent.mkdir(exist_ok=True)
        Image.fromarray(place(painted, riders[name])).save(out)
        print(f"Wrote {out.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
