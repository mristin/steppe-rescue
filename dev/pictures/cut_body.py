# Run with numpy, opencv-python-headless and pillow:
#   python dev/pictures/cut_body.py [<folder of the paintings>]
"""
Cut the painted clothes of the rider's body out of their paintings.

The paintings were made over the templates of ~/Downloads/reins/templates (see
the prompts there): the pieces on a flat magenta background, with black dots.
Each piece is keyed out, the dots removed, and it is brought into the canvas
of its template, where the game expects its joints (see CameraPanel):

* rein: the strap, cropped to its braid without the cut ends;
* coat: the shoulders at y = 300, 400 pixels apart (312..712), the hem at
  y = 1150, in 1024x1536;
* sleeve: from the shoulder at x = 200 to the end of the cuff at x = 1150,
  along y = 512, 184 pixels thick at the elbow (x = 700), in 1536x1024;
* boot: the top of the leg at y = 300 (the knee), the sole at y = 1300,
  around x = 512, in 1024x1536.

The fists are cut by cut_fists.py.

The dots of the rein stayed where they were, but those of the
coats, the sleeves and the boots moved, so these are placed by their outline.

ChatGPT painted every coat and sleeve indigo, so they are recolored to the
coats of the riders (Looks.PRESETS): the indigo cloth turns to the color, the
gold and the fur stay.

The results are halved, to keep the game small.
"""
import pathlib
import sys

import cv2
import numpy as np
from PIL import Image

REPO = pathlib.Path(__file__).resolve().parents[2]
OUT = REPO / "assets" / "pictures" / "body"
SCALE = 0.5

# The paintings, by their names in the download folder.
REIN = "Braided Leather Strap with Golden Rings.png"
COATS = [
    "a_detailed_illustration_on_a_bright_magenta_backgr.png",
    "a_detailed_watercolor_style_illustration_on_a_brig.png",
    "a_detailed_illustration_on_a_flat_magenta_ff00ff.png",
    "a_detailed_watercolor_gouache_illustration_on_a_fl.png",
]
SLEEVES = [
    "Ornate Indigo Sleeve with Golden Embroidery.png",
    "a_detailed_watercolor_gouache_style_illustration_o.png",
    "a_bright_magenta_background_ff00ff_with_a_water.png",
    "a_single_adobe_illustration_style_watercolor_gouac.png",
]
BOOTS = ["boot_1.png", "boot_2.png", "boot_3.png", "boot_4.png"]

# The coat of each rider (Looks.PRESETS), as in Palette; None keeps the indigo.
COAT_COLORS = {
    "1": "#2e7d4f",  # emerald
    "2": None,  # indigo
    "3": "#c9822b",  # ochre
    "4": "#b3263a",  # crimson
}


def key(rgb):
    """The RGBA of the painting without its magenta background and its dots."""
    r, g, b = [rgb[..., i].astype(np.float32) for i in range(3)]
    # NOTE (mristin):
    # How magenta a pixel is: red and blue high and alike, green low.
    magenta = np.minimum(r, b) - g - np.abs(r - b) * 0.5
    alpha = np.clip((140.0 - magenta) / 80.0, 0.0, 1.0)

    # NOTE (mristin):
    # Take the magenta out of the edges, so that they do not glow pink.
    a = np.maximum(alpha, 1e-3)[..., None]
    pink = np.array([255.0, 0.0, 255.0])
    color = (rgb.astype(np.float32) - (1.0 - a) * pink) / a
    color = np.clip(color, 0, 255)
    color = np.where(alpha[..., None] > 0.98, rgb.astype(np.float32), color)

    rgba = np.dstack([color, alpha * 255.0]).astype(np.uint8)
    return remove_dots(rgba)


def dots(rgb):
    """The centers of the black dots, largest first."""
    dark = (rgb.max(axis=2) < 60).astype(np.uint8)
    n, _, stats, centers = cv2.connectedComponentsWithStats(dark, 8)
    found = []
    for k in range(1, n):
        x, y, w, h, area = stats[k]
        if 150 < area < 8000 and 0.6 < w / max(1, h) < 1.6 and area > 0.6 * w * h:
            found.append((area, centers[k]))
    found.sort(key=lambda item: -item[0])
    return [center for _, center in found]


def remove_dots(rgba):
    """Clear the dots, which lie on the background, away from the piece."""
    alpha = (rgba[..., 3] > 128).astype(np.uint8)
    n, labels, stats, _ = cv2.connectedComponentsWithStats(alpha, 8)
    if n <= 1:
        return rgba
    biggest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    keep = np.zeros_like(alpha)
    for k in range(1, n):
        if k == biggest or stats[k, cv2.CC_STAT_AREA] > 0.05 * stats[biggest, cv2.CC_STAT_AREA]:
            keep[labels == k] = 1
    keep = cv2.dilate(keep, np.ones((5, 5), np.uint8))
    result = rgba.copy()
    result[..., 3] = (result[..., 3] * keep).astype(np.uint8)
    return result


def warp(rgba, matrix, size):
    return cv2.warpAffine(
        rgba,
        matrix,
        size,
        flags=cv2.INTER_AREA,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(0, 0, 0, 0),
    )


def similarity(source, target):
    """The similarity which maps the two source points onto the two target points."""
    (sx0, sy0), (sx1, sy1) = source
    (tx0, ty0), (tx1, ty1) = target
    sv = complex(sx1 - sx0, sy1 - sy0)
    tv = complex(tx1 - tx0, ty1 - ty0)
    z = tv / sv
    a, b = z.real, z.imag
    tx = tx0 - (a * sx0 - b * sy0)
    ty = ty0 - (b * sx0 + a * sy0)
    return np.array([[a, -b, tx], [b, a, ty]], dtype=np.float32)


def opaque_rows(alpha):
    rows = np.where(alpha.max(axis=1) > 128)[0]
    return rows[0], rows[-1]


def extent(alpha, y):
    cols = np.where(alpha[int(y)] > 128)[0]
    return cols[0], cols[-1]


def rein(rgb):
    rgba = key(rgb)
    centers = sorted(dots(rgb)[:2], key=lambda c: c[0])
    # NOTE (mristin):
    # Level the strap, then crop it to its braid, without the cut ends.
    matrix = similarity(centers, [(100, 250), (1436, 250)])
    level = warp(rgba, matrix, (1536, 1024))
    top, bottom = opaque_rows(level[..., 3])
    cols = np.where(level[..., 3].max(axis=0) > 128)[0]
    left, right = cols[0], cols[-1]
    trim = int((right - left) * 0.04)
    return level[top : bottom + 1, left + trim : right - trim + 1]


def coat(rgb):
    rgba = key(rgb)
    alpha = rgba[..., 3]
    top, bottom = opaque_rows(alpha)
    # NOTE (mristin):
    # The shoulders are a little below the top, past the collar.
    shoulder_y = top + (bottom - top) * 0.06
    left, right = extent(alpha, shoulder_y)
    sx = 400.0 / max(1, right - left)
    sy = (1150.0 - 300.0) / max(1, bottom - shoulder_y)
    matrix = np.array([[sx, 0, 312 - left * sx], [0, sy, 300 - shoulder_y * sy]], dtype=np.float32)
    return warp(rgba, matrix, (1024, 1536))


def sleeve(rgb):
    rgba = key(rgb)
    alpha = rgba[..., 3]
    # NOTE (mristin):
    # Level the sleeve along its long axis, then put its ends at the shoulder
    # and the end of the cuff.
    ys, xs = np.nonzero(alpha > 128)
    points = np.column_stack([xs, ys]).astype(np.float32)
    mean = points.mean(axis=0)
    _, _, vt = np.linalg.svd(points - mean, full_matrices=False)
    axis = vt[0] if vt[0][0] > 0 else -vt[0]
    angle = np.degrees(np.arctan2(axis[1], axis[0]))
    rotation = cv2.getRotationMatrix2D((float(mean[0]), float(mean[1])), angle, 1.0)
    level = warp(rgba, rotation, (rgba.shape[1], rgba.shape[0]))
    a = level[..., 3]
    cols = np.where(a.max(axis=0) > 128)[0]
    left, right = cols[0], cols[-1]
    # NOTE (mristin):
    # The paintings are thicker than the template; the sleeve is brought to
    # the thickness of the template at the elbow (184 pixels), so that the
    # game sizes every sleeve alike.
    elbow = int(left + (right - left) * (700 - 200) / 950)
    rows = np.where(a[:, elbow] > 128)[0]
    top, bottom = rows[0], rows[-1]
    sx = 950.0 / max(1, right - left)
    sy = 184.0 / max(1, bottom - top)
    middle = (top + bottom) * 0.5
    matrix = np.array([[sx, 0, 200 - left * sx], [0, sy, 512 - middle * sy]], dtype=np.float32)
    return warp(level, matrix, (1536, 1024))


def boot(rgb):
    rgba = key(rgb)
    alpha = rgba[..., 3]
    top, bottom = opaque_rows(alpha)
    left, right = extent(alpha, top + (bottom - top) * 0.5)
    s = 1000.0 / max(1, bottom - top)
    middle = (left + right) * 0.5
    matrix = np.array([[s, 0, 512 - middle * s], [0, s, 300 - top * s]], dtype=np.float32)
    return warp(rgba, matrix, (1024, 1536))


def recolor(rgba, color):
    """Turn the indigo cloth to the color, keeping the gold, the fur and the shading."""
    if color is None:
        return rgba
    rgb = rgba[..., :3]
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
    target = np.array([[[int(color[i : i + 2], 16) for i in (1, 3, 5)]]], dtype=np.uint8)
    th, ts, tv = cv2.cvtColor(target, cv2.COLOR_RGB2HSV_FULL).astype(np.float32)[0, 0]
    hue, sat, value = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    opaque = rgba[..., 3] > 200

    # NOTE (mristin):
    # The indigo is blue (about 120..175 of 256 in the full hue) and saturated;
    # we take its own middle, and fade the weight at its borders, so that the
    # shading stays smooth and the gold and the fur stay as they are.
    cloth = opaque & (hue > 120) & (hue < 175) & (sat > 60)
    middle = float(np.median(hue[cloth]))
    weight = np.clip(1.0 - (np.abs(hue - middle) - 18.0) / 14.0, 0.0, 1.0)
    weight *= np.clip((sat - 35.0) / 30.0, 0.0, 1.0)

    # NOTE (mristin):
    # The light and the dark of the cloth are kept around the saturation and
    # the brightness of the target.
    mean_sat = float(sat[cloth].mean())
    mean_value = float(value[cloth].mean())
    new = np.dstack(
        [
            np.full_like(hue, th),
            np.clip(sat * (ts / mean_sat), 0, 255),
            np.clip(value * (tv / mean_value), 0, 255),
        ]
    ).astype(np.uint8)
    new_rgb = cv2.cvtColor(new, cv2.COLOR_HSV2RGB_FULL).astype(np.float32)
    w = weight[..., None]
    out = rgb.astype(np.float32) * (1.0 - w) + new_rgb * w
    return np.dstack([np.clip(out, 0, 255).astype(np.uint8), rgba[..., 3]])


def save(rgba, name):
    image = Image.fromarray(rgba, "RGBA")
    size = (max(1, round(image.width * SCALE)), max(1, round(image.height * SCALE)))
    image = image.resize(size, Image.LANCZOS)
    OUT.mkdir(parents=True, exist_ok=True)
    image.save(OUT / name, optimize=True)
    print(f"Wrote {OUT / name} {image.size}")


def main():
    folder = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "~/Downloads").expanduser()

    def read(name):
        return np.array(Image.open(folder / name).convert("RGB"))

    save(rein(read(REIN)), "rein.png")
    for i, (preset, color) in enumerate(COAT_COLORS.items()):
        save(recolor(coat(read(COATS[i])), color), f"coat_{preset}.png")
        save(recolor(sleeve(read(SLEEVES[i])), color), f"sleeve_{preset}.png")
        save(boot(read(BOOTS[i])), f"boot_{preset}.png")


if __name__ == "__main__":
    main()
