# Run with numpy, opencv-python-headless and pillow:
#   python dev/pictures/cut_jump.py <folder with the jump sheets>
"""
Cut the painted jumps out of their sprite sheets (on a flat magenta background):

* horse_<n>_jump.png: a painted horse jumping, seen from above, in five frames
  (the take-off, rising, the flight, coming down, the landing). The sheets came
  back in the order of the riders' horses reversed, so each is matched to its
  horse (Looks.HORSE_PRESETS) by HORSE_OF below. Each frame goes into the
  188x188 square of the run (assets/pictures/top_down/horses/<n>/jump_<k>.png),
  scaled so that the horse at the take-off is as long as running, with its
  red saddle cloth where the girl sits (the middle of the square, a little
  lower).
* girl_jump.png: the girl of the small figure jumping, from the front, in four
  frames (the crouch, the take-off, in the air, the landing), to
  assets/pictures/girl/jump_<k>.png (big) and assets/pictures/girl/small/
  (small). All the frames share the line of the ground at their bottom, so
  that in the air she is lifted above it.
"""
import pathlib
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from cut_body import key  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parents[2]
PICTURES = REPO / "assets" / "pictures"

# NOTE (mristin):
# The sheet of each horse of the riders (1 bay, 2 chestnut, 3 grey, 4 dun), by
# its coat.
HORSE_OF = {
    "1": "horse_4_jump.png",
    "2": "horse_3_jump.png",
    "3": "horse_2_jump.png",
    "4": "horse_1_jump.png",
}

HORSE_SQUARE = 188
HORSE_LENGTH = 142  # the length of a running horse in its square
SADDLE_AT = (94, 100)  # where the saddle cloth goes in the square

GIRL_TAKE_OFF_HEIGHT = 600  # the girl on her toes at the take-off, big
GIRL_SMALL = 200 / 580  # the small frames to the big ones


def clear_lines(rgba):
    """Clear the thin lines across the whole sheet (a hint of the ground)."""
    across = (rgba[..., 3] > 128).mean(axis=1) > 0.6
    for y in np.where(across)[0]:
        rgba[max(0, y - 2) : y + 3, :, 3] = 0
    return rgba


def frames(rgba, expected):
    """The column spans of the frames of the sheet, from the left."""
    columns = rgba[..., 3].max(axis=0) > 128
    spans = []
    start = None
    for x, filled in enumerate(columns):
        if filled and start is None:
            start = x
        elif not filled and start is not None:
            spans.append((start, x))
            start = None
    if start is not None:
        spans.append((start, len(columns)))
    spans = [span for span in spans if span[1] - span[0] > 20]
    assert len(spans) == expected, f"expected {expected} frames, found {len(spans)}: {spans}"
    return spans


def rows(alpha):
    filled = np.where(alpha.max(axis=1) > 128)[0]
    return filled[0], filled[-1] + 1


def saddle(rgba):
    """The middle of the red saddle cloth."""
    r, g, b, a = [rgba[..., i].astype(int) for i in range(4)]
    red = (a > 200) & (r > 140) & (g < 80) & (b < 90)
    ys, xs = np.nonzero(red)
    assert len(xs) > 50, "no saddle cloth found"
    return xs.mean(), ys.mean()


def resized(image, scale):
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    return image.resize(size, Image.LANCZOS)


def cut_horse(path, steed):
    rgba = clear_lines(key(np.array(Image.open(path).convert("RGB"))))
    spans = frames(rgba, 5)
    top, bottom = rows(rgba[:, spans[0][0] : spans[0][1], 3])
    scale = HORSE_LENGTH / (bottom - top)
    for k, (left, right) in enumerate(spans):
        piece = rgba[:, left:right]
        x, y = saddle(piece)
        image = resized(Image.fromarray(piece, "RGBA"), scale)
        square = Image.new("RGBA", (HORSE_SQUARE, HORSE_SQUARE), (0, 0, 0, 0))
        square.alpha_composite(
            image, (round(SADDLE_AT[0] - x * scale), round(SADDLE_AT[1] - y * scale))
        )
        out = PICTURES / "top_down" / "horses" / steed / f"jump_{k}.png"
        square.save(out, optimize=True)
        print(f"Wrote {out}")


def cut_girl(path):
    rgba = clear_lines(key(np.array(Image.open(path).convert("RGB"))))
    spans = frames(rgba, 4)
    tops, bottoms = [], []
    for left, right in spans:
        top, bottom = rows(rgba[:, left:right, 3])
        tops.append(top)
        bottoms.append(bottom)
    # NOTE (mristin):
    # The ground is where her boots stand in the frames on the ground (all but
    # the third, in the air).
    ground = max(bottoms[0], bottoms[1], bottoms[3])
    top = min(tops) - 4
    scale = GIRL_TAKE_OFF_HEIGHT / (ground - tops[1])
    for k, (left, right) in enumerate(spans):
        piece = Image.fromarray(rgba[top:ground, max(0, left - 4) : right + 4], "RGBA")
        big = resized(piece, scale)
        for folder, image in (
            (PICTURES / "girl", big),
            (PICTURES / "girl" / "small", resized(big, GIRL_SMALL)),
        ):
            out = folder / f"jump_{k}.png"
            image.save(out, optimize=True)
            print(f"Wrote {out} {image.size}")


def main():
    folder = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "~/Downloads").expanduser()
    for steed, name in HORSE_OF.items():
        cut_horse(folder / name, steed)
    cut_girl(folder / "girl_jump.png")


if __name__ == "__main__":
    main()
