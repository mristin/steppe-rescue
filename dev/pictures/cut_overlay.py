# The face template is dev/pictures/face_template.png (200 pixels per eye
# distance, the middle between the eyes at 440, 680); run with numpy,
# opencv-python-headless and pillow.
"""Cut the painted hair and hats out of the face template, aligned by the eyes."""
import cv2
import numpy as np
from PIL import Image

BOX = (-2.2, -3.4, 4.4, 7.6)  # FrontView.OVERLAY_BOX, in eye distances
OUT_UNIT = 100  # pixels per eye distance in the result
FILES = {
    "1": "Crimson Gold-Embroidered Cap and Braids",
    "2": "Blue Velvet Hat and Braided Hair",
    "3": "Embroidered Cream Headscarf Portrait",
    "4": "Gray Avatar with Wavy Brown Bob and Bangs",
}


def eyes(rgb):
    """The centres of the two dark eyes of the template in the picture."""
    r, g, b = [rgb[..., i].astype(int) for i in range(3)]
    neutral = (np.abs(r - g) < 12) & (np.abs(g - b) < 12)
    dark = neutral & (r < 70)
    n, labels, stats, cent = cv2.connectedComponentsWithStats(dark.astype(np.uint8), 8)
    h, w = dark.shape
    found = []
    for k in range(1, n):
        x, y, bw, bh, area = stats[k]
        if 800 < area < 6000 and 1.3 < bw / max(1, bh) < 3.5 and 0.3 * h < cent[k][1] < 0.6 * h:
            found.append(cent[k])
    # The eyes are the pair on one line, about a quarter of the width apart,
    # around the middle (dark hair may make blobs, too).
    best = None
    for i in range(len(found)):
        for j in range(len(found)):
            a, c = found[i], found[j]
            dx, dy = c[0] - a[0], abs(c[1] - a[1])
            if dy < 6 and 0.18 * w < dx < 0.32 * w:
                score = abs((a[0] + c[0]) / 2 - w / 2)
                if best is None or score < best[0]:
                    best = (score, a, c)
    assert best is not None, found
    return np.array(best[1]), np.array(best[2])


for preset, name in FILES.items():
    rgb = np.array(Image.open(f"/home/marko/Downloads/{name}.png").convert("RGB"))
    left, right = eyes(rgb)
    unit = np.linalg.norm(right - left)
    middle = (left + right) / 2
    # Map the result's pixels to the picture: x_result = (x - middle)/unit*OUT_UNIT + offset.
    W, H = int(BOX[2] * OUT_UNIT), int(BOX[3] * OUT_UNIT)
    s = OUT_UNIT / unit
    M = np.array(
        [[s, 0, -middle[0] * s - BOX[0] * OUT_UNIT], [0, s, -middle[1] * s - BOX[1] * OUT_UNIT]]
    )
    warped = cv2.warpAffine(rgb, M, (W, H), flags=cv2.INTER_AREA, borderValue=(255, 255, 255))

    hsv = cv2.cvtColor(warped, cv2.COLOR_RGB2HSV).astype(int)
    r, g, b = [warped[..., i].astype(int) for i in range(3)]
    spread = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
    # NOTE (mristin):
    # The white background is perfectly flat, also where the hair encloses
    # it (e.g., between the braids); a white scarf is textured, so it stays.
    lum = warped.astype(np.float32).mean(axis=2)
    mean = cv2.blur(lum, (7, 7))
    flat = (cv2.blur(lum * lum, (7, 7)) - mean * mean) < 4.0
    white = (spread < 14) & (np.minimum(np.minimum(r, g), b) > 232) & flat
    white = cv2.dilate(white.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    white &= (spread < 20) & (np.minimum(np.minimum(r, g), b) > 215)
    grey = (spread < 16) & (r > 115) & (r < 222)

    # The template's shapes, in the result's pixels: where the face, the neck
    # and the shoulders are, plain grey there is template, not paint.
    def p(x, y):
        return (int((x - BOX[0]) * OUT_UNIT), int((y - BOX[1]) * OUT_UNIT))

    body = np.zeros((H, W), np.uint8)
    cv2.ellipse(body, p(0, 0.2), (int(1.02 * OUT_UNIT), int(1.5 * OUT_UNIT)), 0, 0, 360, 255, -1)
    for sx in (-1, 1):
        cv2.ellipse(
            body,
            p(sx * 1.04, 0.22),
            (int(0.18 * OUT_UNIT), int(0.4 * OUT_UNIT)),
            0,
            0,
            360,
            255,
            -1,
        )
    cv2.rectangle(body, p(-0.4, 1.3), p(0.4, 2.7), 255, -1)
    cv2.ellipse(body, p(0, 3.5), (int(1.95 * OUT_UNIT), int(1.15 * OUT_UNIT)), 0, 0, 360, 255, -1)
    body = cv2.dilate(body, np.ones((5, 5), np.uint8))
    # The eyes, the nose and the mouth of the template.
    features = np.zeros((H, W), np.uint8)
    for sx in (-0.5, 0.5):
        cv2.ellipse(
            features, p(sx, 0), (int(0.2 * OUT_UNIT), int(0.13 * OUT_UNIT)), 0, 0, 360, 255, -1
        )
    cv2.rectangle(features, p(-0.05, 0.15), p(0.05, 0.6), 255, -1)
    cv2.ellipse(
        features, p(0, 0.8), (int(0.36 * OUT_UNIT), int(0.25 * OUT_UNIT)), 0, 0, 180, 255, -1
    )
    dark_neutral = (spread < 16) & (r < 130)
    erase = white | (grey & (body > 0)) | ((features > 0) & (dark_neutral | grey))
    alpha = np.where(erase, 0, 255).astype(np.uint8)
    alpha = cv2.morphologyEx(alpha, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    # Drop specks left of the template's outlines.
    n, labels, stats, _ = cv2.connectedComponentsWithStats((alpha > 0).astype(np.uint8), 8)
    for k in range(1, n):
        thin = min(stats[k, cv2.CC_STAT_WIDTH], stats[k, cv2.CC_STAT_HEIGHT]) <= 8
        if stats[k, cv2.CC_STAT_AREA] < 150 or thin:
            alpha[labels == k] = 0
    alpha = cv2.GaussianBlur(alpha, (0, 0), 0.8)
    Image.fromarray(np.dstack([warped, alpha])).save(
        f"assets/pictures/overlay/{preset}.png", optimize=True
    )
    print(preset, "eye distance", round(unit, 1))
