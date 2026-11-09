class_name Sprites
extends RefCounted

## Hold the placeholder sprites of the game as pictures in characters (see
## [PixelSprite] and [constant Palette.LEGEND]).

# gdlint: disable=max-line-length

## The upper part of the horse, seen from the side, facing right; the legs
## differ per gait and frame.
const _HORSE_TOP := [
    "................kk..",
    "...............kbbk.",
    "..............kbbbbk",
    ".............kbblbbk",
    "............kbbk.kkk",
    "...........kbbk.....",
    "..kkkkkkkkkbbbk.....",
    ".kbbbbbbbbbbbbk.....",
    "kkbbbbbbbbbbbbk.....",
    "k.kbbbbbbbbbbk......",
]

const _WALK_LEGS := [
    [
        "k..kbk....kbk.......",
        "...kbk....kbk.......",
        "...hh.....hh........",
    ],
    [
        "k..kbk....kbbk......",
        "...kbk....k..bk.....",
        "...hh.....h...hh....",
    ],
]

const _TROT_LEGS := [
    [
        "k..kbbk...kbk.......",
        "..kbk.bk..kbk.......",
        ".hh....hh.hh........",
    ],
    [
        "k..kbk...kbbk.......",
        "...kbk..kbk.bk......",
        "...hh..hh....hh.....",
    ],
]

const _GALLOP_BODY := [
    "................kk..",
    "...............kbbk.",
    "..............kbbbbk",
    ".............kbblbbk",
    "............kbbk.kkk",
    "...........kbbk.....",
    "kkkkkkkkkkkbbbk.....",
    ".kkbbbbbbbbbbbk.....",
    "..kbbbbbbbbbbbk.....",
    "..kbbbbbbbbbbk......",
]

const _GALLOP_LEGS := [
    [
        ".kbk.......kbk......",
        "kbk.........kbk.....",
        "hh...........hh.....",
    ],
    [
        "...kbk...kbk........",
        "....kbkkbk..........",
        ".....hhhh...........",
    ],
]

## The embroidered skullcap (тақия) of the rider, for the face overlay. Its
## band sits on the forehead, at the bottom of the sprite.
const TAKIYA := [
    ".....kkkkkk.....",
    "...kkrrrrrrkk...",
    "..krrryrryrrrk..",
    ".krryyyrryyyrrk.",
    ".krrrryrryrrrrk.",
    "kkrrrrrrrrrrrrkk",
    "kyyyyyyyyyyyyyyk",
    "kkkkkkkkkkkkkkkk",
]


## The frames of the horse for the gait: 1 walks, 2 trots, 3 gallops; a
## standing horse (0) shows the first frame of the walk.
static func horse(gait: int, frame: int) -> Array:
    match gait:
        2:
            return _HORSE_TOP + _TROT_LEGS[frame % 2]
        3:
            return _GALLOP_BODY + _GALLOP_LEGS[frame % 2]
        1:
            return _HORSE_TOP + _WALK_LEGS[frame % 2]
        _:
            return _HORSE_TOP + _WALK_LEGS[0]


## All the sprites with their names, for the tests.
static func all() -> Dictionary:
    var result := {"takiya": TAKIYA}
    for gait in range(4):
        for frame in range(2):
            result["horse_%d_%d" % [gait, frame]] = horse(gait, frame)
    return result
