"""
Cut the sounds of the game, assets/sounds/*.ogg, out of CC0 recordings on
Freesound, as listed in dev/sounds/sources.json.

Each recording is downloaded once, as its high-quality preview (Ogg Vorbis),
into .cache/sounds/; we check on its page that it is still under CC0. Each
sound is cut out of it, made mono at 44.1 kHz and filtered with the effects of
sox. A one-shot fades in and out briefly and is normalized to its peak; a loop
is cross-faded at its seam, so that it repeats seamlessly, and normalized to
the same loudness as the other loops.

You need sox with the Vorbis format (e.g., "apt install sox
libsox-fmt-all"):

    python dev/sounds/cut_sounds.py
"""

import argparse
import array
import json
import math
import pathlib
import re
import subprocess
import sys
import time
import urllib.request

REPO = pathlib.Path(__file__).resolve().parents[2]
SOURCES = REPO / "dev" / "sounds" / "sources.json"
CACHE = REPO / ".cache" / "sounds"
OUTPUT = REPO / "assets" / "sounds"

RATE = 44100

# A loop cross-fades this long over its seam, in seconds.
CROSSFADE = 0.4

# The peak of a one-shot, and the loudness (RMS) of a loop, in dBFS.
PEAK_DB = -1.0
LOOP_RMS_DB = -20.0

# A one-shot fades in and out this long, in seconds.
FADE_IN = 0.005
FADE_OUT = 0.08

CC0 = "creativecommons.org/publicdomain/zero/1.0"


def fetch(url: str) -> bytes:
    """Fetch the URL, waiting when Freesound asks us to slow down."""
    for attempt in range(6):
        request = urllib.request.Request(url, headers={"User-Agent": "steppe-rescue-dev"})
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            if error.code != 429 or attempt == 5:
                raise
            time.sleep(10.0 * (attempt + 1))
    raise AssertionError("unreachable")


def download(sound_id: int) -> pathlib.Path:
    """Download the high-quality preview of the sound, after checking its license."""
    path = CACHE / f"{sound_id}.ogg"
    if path.exists():
        return path
    page = fetch(f"https://freesound.org/s/{sound_id}/").decode("utf-8", "replace")
    licenses = set(re.findall(r'href="https?://(creativecommons\.org/[^"]+?)/?"', page))
    if licenses != {CC0}:
        raise RuntimeError(f"Freesound {sound_id} is not under CC0, but {licenses}")
    preview = re.search(r'data-ogg="([^"]+)"', page)
    if preview is None:
        raise RuntimeError(f"Found no preview of Freesound {sound_id}")
    CACHE.mkdir(parents=True, exist_ok=True)
    path.write_bytes(fetch(preview.group(1).replace("-lq.ogg", "-hq.ogg")))
    time.sleep(2.0)
    return path


def decode(path: pathlib.Path, start: float, end: float, effects: list[str]) -> array.array:
    """The samples of the recording from start to end, mono, filtered."""
    command = ["sox", str(path), "-t", "f32", "-c", "1", "-r", str(RATE), "-"]
    command += ["trim", str(start), f"={end}"] + effects
    raw = subprocess.run(command, check=True, capture_output=True).stdout
    samples = array.array("f")
    samples.frombytes(raw)
    return samples


def encode(samples: array.array, path: pathlib.Path) -> None:
    """Write the samples as Ogg Vorbis."""
    command = ["sox", "-t", "f32", "-c", "1", "-r", str(RATE), "-", "-C", "5", str(path)]
    subprocess.run(command, check=True, input=samples.tobytes())


def scale(samples: array.array, gain: float) -> array.array:
    return array.array("f", (value * gain for value in samples))


def one_shot(samples: array.array) -> array.array:
    """Fade the sound in and out, and normalize its peak."""
    count = len(samples)
    fade_in = min(count // 4, round(FADE_IN * RATE))
    fade_out = min(count // 2, round(FADE_OUT * RATE))
    for i in range(fade_in):
        samples[i] *= i / fade_in
    for i in range(fade_out):
        samples[count - 1 - i] *= i / fade_out
    peak = max(abs(value) for value in samples)
    return scale(samples, 10.0 ** (PEAK_DB / 20.0) / peak)


def loop(samples: array.array) -> array.array:
    """Cross-fade the tail beyond the loop into its head, so that it repeats
    seamlessly, and normalize its loudness."""
    overlap = round(CROSSFADE * RATE)
    length = len(samples) - overlap
    result = samples[:length]
    for i in range(overlap):
        # NOTE (mristin):
        # Equal power, since the two ends are not correlated.
        weight = math.sin(0.5 * math.pi * i / overlap)
        tail = math.cos(0.5 * math.pi * i / overlap)
        result[i] = samples[i] * weight + samples[length + i] * tail
    rms = math.sqrt(sum(value * value for value in result) / len(result))
    gain = 10.0 ** (LOOP_RMS_DB / 20.0) / rms
    peak = max(abs(value) for value in result) * gain
    if peak > 0.99:
        gain *= 0.99 / peak
    return scale(result, gain)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("names", nargs="*", help="cut only these sounds (default: all)")
    args = parser.parse_args()

    sources = json.loads(SOURCES.read_text(encoding="utf-8"))["sounds"]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for source in sources:
        if args.names and source["name"] not in args.names:
            continue
        recording = download(source["freesound"])
        is_loop = source.get("loop", False)
        end = source["end"] + (CROSSFADE if is_loop else 0.0)
        samples = decode(recording, source["start"], end, source.get("effects", []))
        samples = loop(samples) if is_loop else one_shot(samples)
        path = OUTPUT / f"{source['name']}.ogg"
        encode(samples, path)
        print(f"{path.relative_to(REPO)}: {len(samples) / RATE:.2f} s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
