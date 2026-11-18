"""
Cut the gold embroidery of the coat of the finery (шапан, at its steps) for
the camera picture out of its paintings, into assets/pictures/body/
coat_trim_<step>.png and sleeve_trim_<step>.png:

    python dev/pictures/cut_coat_trims.py <folder of the paintings> <folder of the templates>

The paintings (camera_coat_<step>.png and camera_sleeve_<step>.png, see
~/Downloads/coat/PROMPTS.md) are the templates of cut_body.py
(coat_template.png and sleeve_template.png) with only the gold painted over
their gray shapes, the rest of the template left as it was. So the gold is
what differs from the template; it is placed as cut_body.py places a coat
(or a sleeve) painted over the template, by the outline of the template's
gray shape, so that it lies over the painted coat of every rider. The game
lays it over her coat and sleeves (see PaintedBody), the same for every rider.

Run with numpy, opencv-python-headless and pillow.
"""

import pathlib
import sys

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import cut_body  # noqa: E402


def gold(painted: np.ndarray, template: np.ndarray) -> np.ndarray:
    """The RGBA of what was painted over the template: the gold, keyed out."""
    difference = np.abs(painted.astype(np.float32) - template.astype(np.float32)).max(axis=2)
    alpha = np.clip((difference - 24.0) / 40.0, 0.0, 1.0)
    alpha = cv2.GaussianBlur(alpha, (3, 3), 0)
    return np.dstack([painted, alpha * 255.0]).astype(np.uint8)


def coat_matrix(alpha: np.ndarray) -> np.ndarray:
    """The matrix of cut_body.coat for the outline of the alpha."""
    top, bottom = cut_body.opaque_rows(alpha)
    shoulder_y = top + (bottom - top) * 0.06
    left, right = cut_body.extent(alpha, shoulder_y)
    sx = 400.0 / max(1, right - left)
    sy = (1150.0 - 300.0) / max(1, bottom - shoulder_y)
    return np.array([[sx, 0, 312 - left * sx], [0, sy, 300 - shoulder_y * sy]], dtype=np.float32)


def sleeve_matrix(alpha: np.ndarray) -> np.ndarray:
    """The matrix of cut_body.sleeve for the outline of the alpha (level already)."""
    cols = np.where(alpha.max(axis=0) > 128)[0]
    left, right = cols[0], cols[-1]
    elbow = int(left + (right - left) * (700 - 200) / 950)
    rows = np.where(alpha[:, elbow] > 128)[0]
    top, bottom = rows[0], rows[-1]
    sx = 950.0 / max(1, right - left)
    sy = 184.0 / max(1, bottom - top)
    middle = (top + bottom) * 0.5
    return np.array([[sx, 0, 200 - left * sx], [0, sy, 512 - middle * sy]], dtype=np.float32)


def main() -> int:
    paintings = pathlib.Path(sys.argv[1])
    templates = pathlib.Path(sys.argv[2])
    for kind, matrix_of, size in [
        ("coat", coat_matrix, (1024, 1536)),
        ("sleeve", sleeve_matrix, (1536, 1024)),
    ]:
        template = np.array(Image.open(templates / f"{kind}_template.png").convert("RGB"))
        matrix = matrix_of(cut_body.key(template)[..., 3])
        for step in [1, 2]:
            path = paintings / f"camera_{kind}_{step}.png"
            if not path.exists():
                continue
            painted = np.array(Image.open(path).convert("RGB"))
            cut_body.save(
                cut_body.warp(gold(painted, template), matrix, size), f"{kind}_trim_{step}.png"
            )
    return 0


if __name__ == "__main__":
    sys.exit(main())
