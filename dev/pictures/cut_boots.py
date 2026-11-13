"""
Cut the boots of the finery (етік) out of their paintings:

    python dev/pictures/cut_boots.py <folder of the paintings>

* standing_rider_<n>_boots.png: the painted rider standing in the boots (see
  ~/Downloads/boots/PROMPTS.md), made from the rider at twice her size on a
  flat magenta canvas with a margin of 60 pixels. It is matched and placed as
  in cut_standing_coat.py, and only its lower legs are kept: the strip below
  the lowest hem of the rider in any of her coats (assets/pictures/riders/
  and coat_<step>/), so that the boots fit her in every coat. The game clears
  that strip of the rider and lays the boots in (see Painting.dressed_rider),
  into assets/pictures/riders/boots/<n>.png.
* camera_boot.png: a boot painted over the boot template, cut as the boots of
  cut_body.py, into assets/pictures/body/boot_finery.png, for the camera
  picture of every rider who won the boots.

Run with numpy, opencv-python-headless and pillow.
"""

import pathlib
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import cut_body  # noqa: E402
import cut_standing_coat  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parents[2]
RIDERS = REPO / "assets" / "pictures" / "riders"


def hem(rgba: np.ndarray) -> int:
    """
    The row below the hem of the coat and the dress: below it, the legs stand
    apart, so the middle of the figure is empty between them.
    """
    opaque = rgba[..., 3] > 64
    xs = np.nonzero(opaque.any(axis=0))[0]
    middle = (xs.min() + xs.max()) // 2
    column = opaque[:, middle - 3 : middle + 4].any(axis=1)
    rows = np.nonzero(column)[0]
    return int(rows.max()) + 1


def standing(path: pathlib.Path, riders: dict) -> None:
    painted = cut_standing_coat.only_figure(
        cut_standing_coat.key(np.array(Image.open(path).convert("RGB")))
    )
    small = np.array(
        Image.fromarray(painted).resize((painted.shape[1] // 2, painted.shape[0] // 2))
    )
    likeness = {
        name: cut_standing_coat.cv2.compareHist(
            cut_standing_coat.colors(small),
            cut_standing_coat.colors(rider),
            cut_standing_coat.cv2.HISTCMP_CORREL,
        )
        for name, rider in riders.items()
    }
    name = max(likeness, key=likeness.get)
    numbered = re.match(r"standing_rider_(\d)_boots\.png", path.name).group(1)
    if name != numbered:
        print(f"{path.name} shows the rider {name}, not {numbered}")
    placed = cut_standing_coat.place(painted, riders[name])

    # NOTE (mristin):
    # Below the lowest hem of all her coats, and of the painting, with a few
    # rows to spare.
    coats = [riders[name]] + [
        np.array(Image.open(p).convert("RGBA")) for p in sorted(RIDERS.glob(f"coat_*/{name}.png"))
    ]
    cut = max(hem(each) for each in coats + [placed]) + 2
    legs = placed.copy()
    legs[:cut, :, 3] = 0
    out = RIDERS / "boots" / f"{name}.png"
    out.parent.mkdir(exist_ok=True)
    Image.fromarray(legs).save(out)
    print(f"Wrote {out.relative_to(REPO)}, the legs from the row {cut} of {legs.shape[0]}")


def main() -> int:
    folder = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path.cwd()
    riders = {
        path.stem: np.array(Image.open(path).convert("RGBA"))
        for path in sorted(RIDERS.glob("[0-9].png"))
    }
    for path in sorted(folder.glob("standing_rider_*_boots.png")):
        standing(path, riders)
    camera = folder / "camera_boot.png"
    if camera.exists():
        cut_body.save(cut_body.boot(np.array(Image.open(camera).convert("RGB"))), "boot_finery.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
