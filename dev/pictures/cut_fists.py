# Run with numpy and pillow:
#   python dev/pictures/cut_fists.py [<the painting of the fists>]
"""
Cut the three painted fists of the rider out of their painting.

The painting (made with ChatGPT, see THIRD_PARTY_NOTICES.md) shows three
left fists side by side on a flat magenta background, each gripping a
braided rope which runs level across its third of the picture:

* low: the arm hangs, the wrist above the fist, the back of the hand to us;
* middle: the hands hold the reins in front of the chest, the curled fingers
  to us, the forearm towards us from below;
* up: the arm raised (the brake), the wrist below the fist.

Each fist is keyed out, the rope beside it is cut off (the game draws its own
rein between the fists), the rope is levelled, and the fist is brought into a
512 x 512 canvas with the rope through the middle (256, 256). All three are
scaled alike, the middle fist to FIST_WIDTH across, as the game expects (see
PaintedBody).

Where the wrist goes into the sleeve is found from the fist (above it for the
low fist, below it for the others); the script prints it for each fist, for
PaintedBody.FIST_WRISTS.
"""
import pathlib
import sys

import numpy as np
from PIL import Image

REPO = pathlib.Path(__file__).resolve().parents[2]
OUT = REPO / "assets" / "pictures" / "body"
DEFAULT = pathlib.Path.home() / "Downloads" / "Three Watercolor Fists Gripping Rope(1).png"

POSES = ["low", "middle", "up"]

# The canvas, and where the rope goes through it.
CANVAS = 512
ROPE = (256.0, 256.0)

# How wide the middle fist is, in the canvas.
FIST_WIDTH = 180.0

# A column belongs to the fist if more of it is painted than this many times
# the thickness of the rope.
FIST_COLUMN = 1.15

# The wrist goes into the sleeve this share of the way from the cut end of
# the wrist to the rope (the low and the raised fist), or this share of the
# way from the rope to the bottom of the fist (the middle one, whose forearm
# comes towards us behind it).
WRIST_FROM_END = 0.2
WRIST_BEHIND = 0.15


def key(rgb):
    """The RGBA of the painting without its magenta background (as cut_body.py)."""
    r, g, b = [rgb[..., i] for i in range(3)]
    magenta = np.minimum(r, b) - g - np.abs(r - b) * 0.5
    alpha = np.clip((140.0 - magenta) / 80.0, 0.0, 1.0)
    a = np.maximum(alpha, 1e-3)[..., None]
    pink = np.array([255.0, 0.0, 255.0])
    color = np.clip((rgb - (1.0 - a) * pink) / a, 0, 255)
    return np.dstack([color, alpha * 255.0])


def panels(alpha):
    """The columns of each of the three fists with their ropes, left to right."""
    painted = (alpha > 128).any(axis=0)
    columns = np.where(painted)[0]
    breaks = np.where(np.diff(columns) > 1)[0]
    starts = np.concatenate([[columns[0]], columns[breaks + 1]])
    ends = np.concatenate([columns[breaks], [columns[-1]]])
    found = [(int(s), int(e)) for s, e in zip(starts, ends) if e - s > 100]
    assert len(found) == 3, f"Expected three fists, found {found}"
    return found


def rope_at(alpha, column):
    """The middle and the thickness of the rope in the column."""
    rows = np.where(alpha[:, column] > 128)[0]
    return (rows[0] + rows[-1]) * 0.5, rows[-1] - rows[0] + 1


def measure(alpha, left, right):
    """The rope (a point on it at the middle of the fist, and its slope), the
    columns of the fist, its top and its bottom."""
    edge = 12
    (y0, thick0), (y1, thick1) = rope_at(alpha, left + edge), rope_at(alpha, right - edge)
    slope = (y1 - y0) / float((right - edge) - (left + edge))
    thickness = max(thick0, thick1)
    heights = (alpha[:, left : right + 1] > 128).sum(axis=0)
    fist = np.where(heights > thickness * FIST_COLUMN)[0] + left
    x0, x1 = int(fist[0]), int(fist[-1])
    rows = np.where((alpha[:, x0 : x1 + 1] > 128).any(axis=1))[0]
    middle = (x0 + x1) * 0.5
    rope_y = y0 + slope * (middle - (left + edge))
    return (middle, rope_y), slope, (x0, x1), int(rows[0]), int(rows[-1])


def cut(rgba, left, right):
    alpha = rgba[..., 3]
    (cx, cy), slope, (x0, x1), top, bottom = measure(alpha, left, right)
    piece = rgba.copy()
    # NOTE (mristin):
    # Only the fist stays: the rope beside it, and the other fists, go.
    piece[:, : x0 + 1, 3] = 0
    piece[:, x1:, 3] = 0
    return piece, (cx, cy), slope, x1 - x0, top, bottom


def place(piece, rope, slope, scale):
    """The piece in the canvas: the rope level through ROPE, scaled."""
    angle = np.arctan(slope)
    cos, sin = np.cos(angle), np.sin(angle)
    # The canvas point p comes from the painting at rope + R(angle) (p - ROPE) / scale.
    a = cos / scale
    b = -sin / scale
    d = sin / scale
    e = cos / scale
    c = rope[0] - a * ROPE[0] - b * ROPE[1]
    f = rope[1] - d * ROPE[0] - e * ROPE[1]
    # NOTE (mristin):
    # Premultiply, so that the transparent background does not bleed into the
    # edges while resampling.
    premultiplied = piece.copy()
    premultiplied[..., :3] *= piece[..., 3:4] / 255.0
    image = Image.fromarray(premultiplied.astype(np.uint8), "RGBA")
    placed = image.transform(
        (CANVAS, CANVAS), Image.AFFINE, (a, b, c, d, e, f), resample=Image.BICUBIC
    )
    result = np.array(placed).astype(np.float32)
    alpha = np.maximum(result[..., 3:4], 1e-3)
    result[..., :3] = np.clip(result[..., :3] * 255.0 / alpha, 0, 255)
    return result, (a, b, c, d, e, f)


def to_canvas(point, rope, slope, scale):
    angle = np.arctan(slope)
    dx, dy = point[0] - rope[0], point[1] - rope[1]
    cos, sin = np.cos(-angle), np.sin(-angle)
    return (ROPE[0] + (cos * dx - sin * dy) * scale, ROPE[1] + (sin * dx + cos * dy) * scale)


def main():
    source = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT
    rgb = np.array(Image.open(source).convert("RGB")).astype(np.float32)
    rgba = key(rgb)
    cuts = [cut(rgba, left, right) for left, right in panels(rgba[..., 3])]
    scale = FIST_WIDTH / cuts[POSES.index("middle")][3]
    OUT.mkdir(parents=True, exist_ok=True)
    for pose, (piece, rope, slope, width, top, bottom) in zip(POSES, cuts):
        canvas, _ = place(piece, rope, slope, scale)
        Image.fromarray(np.round(canvas).astype(np.uint8), "RGBA").save(OUT / f"fist_{pose}.png")
        if pose == "low":
            wrist = (rope[0], top + (rope[1] - top) * WRIST_FROM_END)
        elif pose == "up":
            wrist = (rope[0], bottom - (bottom - rope[1]) * WRIST_FROM_END)
        else:
            wrist = (rope[0], rope[1] + (bottom - rope[1]) * WRIST_BEHIND)
        at = to_canvas(wrist, rope, slope, scale)
        print(
            f"fist_{pose}.png: {width * scale:.0f} wide, the wrist at "
            f"Vector2({at[0]:.0f}, {at[1]:.0f})"
        )


if __name__ == "__main__":
    main()
