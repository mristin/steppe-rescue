"""
Write the melody of "Көзімнің қарасы" (Kozimnin Karasi), the song of Abai
Qunanbaiuly (1845-1904), as a MIDI file, assets/music/kozimnin_karasi.mid,
and print it as the notes of scenes/sound/sounds.gd.

The melody is in the public domain (Abai died in 1904). It is transcribed
from the oboe (bars 1-8) and the flute (bars 9-16) of the band arrangement
published by the Center for Middle Eastern Studies of the University of
Arizona (https://cmes.arizona.edu/node/648); only the melody is taken, not
the arrangement. Transposed an octave down, to the range of the dombra.

    python dev/music/kozimnin_karasi.py
"""

import pathlib
import struct

REPO = pathlib.Path(__file__).resolve().parents[2]

# [MIDI note, beats]; 2/4, D major. Phrase A, then phrase B.
PHRASE_A = [
    [62, 1],
    [64, 1],
    [66, 2],
    [66, 0.5],
    [64, 0.5],
    [66, 0.5],
    [64, 0.5],
    [71, 2],
    [71, 1],
    [73, 1],
    [74, 0.5],
    [67, 0.5],
    [71, 0.5],
    [74, 0.5],
    [73, 0.5],
    [71, 0.5],
    [74, 0.5],
    [73, 0.5],
    [71, 2],
]
PHRASE_B = [
    [78, 0.5],
    [76, 0.5],
    [74, 0.5],
    [71, 0.5],
    [76, 1.5],
    [78, 0.5],
    [81, 1],
    [83, 0.5],
    [81, 0.25],
    [83, 0.25],
    [78, 2],
    [73, 1],
    [74, 1],
    [76, 0.5],
    [67, 0.5],
    [71, 0.5],
    [73, 0.5],
    [74, 0.5],
    [76, 0.5],
    [73, 0.5],
    [69, 0.5],
    [71, 2],
]
MELODY = [[note - 12, beats] for note, beats in PHRASE_A + PHRASE_B]
TEMPO_BPM = 76
TICKS = 480


def variable(value: int) -> bytes:
    out = [value & 0x7F]
    value >>= 7
    while value:
        out.insert(0, (value & 0x7F) | 0x80)
        value >>= 7
    return bytes(out)


def main() -> None:
    assert sum(beats for _, beats in PHRASE_A) == 16 and sum(b for _, b in PHRASE_B) == 16
    events = bytearray()
    events += variable(0) + bytes([0xFF, 0x51, 3]) + (60_000_000 // TEMPO_BPM).to_bytes(3, "big")
    events += variable(0) + bytes([0xFF, 0x58, 4, 2, 2, 24, 8])  # 2/4
    events += variable(0) + bytes([0xC0, 25])  # acoustic guitar (steel), close to a dombra
    for note, beats in MELODY:
        events += variable(0) + bytes([0x90, note, 80])
        events += variable(int(beats * TICKS)) + bytes([0x80, note, 0])
    events += variable(0) + bytes([0xFF, 0x2F, 0])
    header = b"MThd" + struct.pack(">IHHH", 6, 0, 1, TICKS)
    track = b"MTrk" + struct.pack(">I", len(events)) + bytes(events)
    out = REPO / "assets" / "music" / "kozimnin_karasi.mid"
    out.write_bytes(header + track)
    print(f"Wrote {out.relative_to(REPO)}")
    print(", ".join(f"[{n}, {b}]" for n, b in MELODY))


if __name__ == "__main__":
    main()
