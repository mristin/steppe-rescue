"""
Study a recording of squats made with dev/squats/record_squats.gd.

Print, for each step of the recording (e.g., "walk 2"), how many face frames
and poses it has, how many squats the game counted, and, for the steps of a
gait, the period, the size of the swings of the head (in the unit of the
player) and how far the head travels up and down per second (the effort the
squat meter turns into the speed).

With --plot, draw the height of the eyes, of the shoulders and of the hips
over time, with the steps and the counted squats, into a PNG (needs
matplotlib).

With --extract, write the face frames as compact CSV for the replay tests
(tests/SteppeRescue.Tests/data/): the time from the start, the step, the eyes,
the head box and whether the head detector found it in that frame.

Run with numpy (and matplotlib for --plot):

  python dev/squats/analyze.py <recording.jsonl> [--plot out.png] [--extract out.csv]
"""

import argparse
import collections
import csv
import json
import pathlib
import sys

import numpy as np

# NOTE (mristin):
# As in the game: a swing counts when the head turned back by this many units,
# and the unit is this many distances between the eyes.
SWING_DEPTH = 0.25
UNIT_PER_EYE_DISTANCE = 4.4


def load(path):
    rows = [json.loads(line) for line in pathlib.Path(path).read_text().splitlines() if line]
    faces = [row for row in rows if row["kind"] == "face"]
    poses = [row for row in rows if row["kind"] == "pose"]
    return faces, poses


def eye_height(player):
    eyes = player["eyes"]
    if eyes is not None:
        return (eyes[1] + eyes[3]) / 2.0, float(np.hypot(eyes[2] - eyes[0], eyes[3] - eyes[1]))
    return (player["gauge_y"] if player["gauge_y"] is not None else np.nan), np.nan


def swings(t, y, unit):
    """The times and sizes (in units) of the completed swings of the head."""
    found = []
    down = False
    top = bottom = None
    for i in range(len(y)):
        if np.isnan(y[i]) or np.isnan(unit[i]):
            continue
        if top is None:
            top = bottom = y[i]
        if not down:
            top = min(top, y[i])
            if (y[i] - top) / unit[i] >= SWING_DEPTH:
                if bottom > top:
                    found.append((t[i], (bottom - top) / unit[i]))
                down = True
                bottom = y[i]
        else:
            bottom = max(bottom, y[i])
            if (bottom - y[i]) / unit[i] >= SWING_DEPTH:
                found.append((t[i], (bottom - top) / unit[i]))
                down = False
                top = y[i]
    return found


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("recording")
    parser.add_argument("--plot", help="write a plot into this PNG")
    parser.add_argument("--extract", help="write the face frames as CSV for the replay tests")
    args = parser.parse_args()

    faces, poses = load(args.recording)
    if not faces:
        print("The recording has no face frames.", file=sys.stderr)
        return 1

    start = faces[0]["t"]
    t = np.array([row["t"] - start for row in faces])
    labels = [row["label"] for row in faces]
    measured = [eye_height(row["players"][0]) for row in faces]
    y = np.array([m[0] for m in measured])
    eyes = np.array([m[1] for m in measured])

    # NOTE (mristin):
    # The unit follows the distance between the eyes slowly, as in the game.
    unit = np.full_like(y, np.nan)
    smoothed = np.nan
    for i in range(len(y)):
        if not np.isnan(eyes[i]):
            smoothed = eyes[i] if np.isnan(smoothed) else smoothed + (eyes[i] - smoothed) * 0.02
        unit[i] = smoothed * UNIT_PER_EYE_DISTANCE

    found = swings(t, y, unit)
    steps = collections.OrderedDict()
    for i, label in enumerate(labels):
        steps.setdefault(label, []).append(i)

    print(
        f"{'step':10s} {'frames':>6s} {'fps':>5s} {'squats':>6s} {'period':>7s} {'swing':>6s} {'effort':>6s}"
    )
    for label, indices in steps.items():
        first, last = t[indices[0]], t[indices[-1]]
        counts = [faces[i]["players"][0]["count"] for i in indices]
        in_step = [(when, size) for when, size in found if first <= when <= last]
        squat_times = [when for k, (when, _) in enumerate(in_step) if k % 2 == 1]
        period = np.median(np.diff(squat_times)) if len(squat_times) > 2 else np.nan
        size = np.median([s for _, s in in_step]) if in_step else np.nan
        effort = sum(s for _, s in in_step) / max(1e-6, last - first)
        print(
            f"{label:10s} {len(indices):6d} {len(indices) / max(1e-6, last - first):5.1f} "
            f"{counts[-1] - counts[0]:6d} {period:7.2f} {size:6.2f} {effort:6.2f}"
        )

    if args.extract:
        with open(args.extract, "w", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(
                ["t", "label", "lx", "ly", "rx", "ry", "x1", "y1", "x2", "y2", "detected"]
            )
            for row, when in zip(faces, t):
                player = row["players"][0]
                eyes_row = player["eyes"] or [""] * 4
                head = player["head"] or [""] * 4
                writer.writerow(
                    [f"{when:.3f}", row["label"]]
                    + [f"{v:.1f}" if v != "" else "" for v in eyes_row]
                    + [f"{v:.1f}" if v != "" else "" for v in head]
                    + [1 if player["detected"] else 0]
                )
        print(f"Wrote {args.extract}")

    if args.plot:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        pose_t = np.array([row["t"] - start for row in poses if row["players"][0]])
        points = np.array([row["players"][0] for row in poses if row["players"][0]]).reshape(
            -1, 17, 3
        )
        shoulders = (points[:, 5, 1] + points[:, 6, 1]) / 2.0
        hips = (points[:, 11, 1] + points[:, 12, 1]) / 2.0
        counts = np.array([row["players"][0]["count"] for row in faces])
        counted = np.where(np.diff(counts) > 0)[0] + 1

        span = 72.0
        rows = int(np.ceil(t[-1] / span))
        figure, axes = plt.subplots(rows, 1, figsize=(22, 4.4 * rows), squeeze=False)
        for k, axis in enumerate(axes[:, 0]):
            low, high = k * span, (k + 1) * span
            inside = (t >= low) & (t < high)
            axis.plot(t[inside], y[inside], "b-", lw=1, label="eyes")
            near = (pose_t >= low) & (pose_t < high)
            axis.plot(pose_t[near], shoulders[near], "mo-", ms=3, lw=0.8, label="shoulders (pose)")
            axis.plot(pose_t[near], hips[near], "yo-", ms=3, lw=0.8, label="hips (pose)")
            for i in counted:
                if low <= t[i] < high:
                    axis.axvline(t[i], color="r", lw=0.6, alpha=0.6)
            previous = None
            for i in np.where(inside)[0]:
                if labels[i] != previous:
                    axis.axvline(t[i], color="k", lw=1.5)
                    axis.text(t[i] + 0.3, 20, labels[i], fontsize=12)
                    previous = labels[i]
            axis.set_xlim(low, high)
            axis.set_ylim(480, 0)
        axes[0, 0].legend(loc="lower right", fontsize=8)
        plt.tight_layout()
        plt.savefig(args.plot, dpi=70)
        print(f"Wrote {args.plot}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
