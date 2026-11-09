class_name Sprites
extends RefCounted

## Hold the placeholder sprites of the game as pictures in characters (see
## [PixelSprite] and [constant Palette.LEGEND]).

# gdlint: disable=max-line-length

## The horse walking, seen from the side, facing right, in two frames.
const _WALK := [
    [
        "....................kk....",
        "...................khhk...",
        "..................khbbbk..",
        ".................khbbbbbk.",
        "................khbbkbbbbk",
        "...............khbbbbbbbbk",
        "..............khbbbkkkbbk.",
        "....kkkkkkkkkkhbbbk...kk..",
        "..kkllllllllllllbbk.......",
        ".khblllllllllllbbbbk......",
        "khhbbbbbbbbbbbbbbbbk......",
        "khkbbbbbbbbbbbbbbbk.......",
        "kk.kbbbbbbbbbbbbbbk.......",
        "....kbbbkkkkkkkbbbk.......",
        "....kbbk.....kbbk.........",
        "....kbk.......kbk.........",
        "....kbk.......kbk.........",
        "....khh.......khh.........",
    ],
    [
        "....................kk....",
        "...................khhk...",
        "..................khbbbk..",
        ".................khbbbbbk.",
        "................khbbkbbbbk",
        "...............khbbbbbbbbk",
        "..............khbbbkkkbbk.",
        "....kkkkkkkkkkhbbbk...kk..",
        "..kkllllllllllllbbk.......",
        ".khblllllllllllbbbbk......",
        "khhbbbbbbbbbbbbbbbbk......",
        "khkbbbbbbbbbbbbbbbk.......",
        "kk.kbbbbbbbbbbbbbbk.......",
        "....kbbbkkkkkkkbbbk.......",
        "....kbbk.....kbbk.........",
        "....kbk.......kbbk........",
        "...kbk.........kbk........",
        "...khh.........khh........",
    ],
]

## The horse trotting, seen from the side, facing right, in two frames.
const _TROT := [
    [
        "....................kk....",
        "...................khhk...",
        "..................khbbbk..",
        ".................khbbbbbk.",
        "................khbbkbbbbk",
        "...............khbbbbbbbbk",
        "..............khbbbkkkbbk.",
        "....kkkkkkkkkkhbbbk...kk..",
        "..kkllllllllllllbbk.......",
        ".khblllllllllllbbbbk......",
        "khhbbbbbbbbbbbbbbbbk......",
        "khkbbbbbbbbbbbbbbbk.......",
        "kk.kbbbbbbbbbbbbbbk.......",
        "....kbbbkkkkkkkbbbk.......",
        "...kbbk......kbbk.........",
        "..kbk.kbk....kbk.kbk......",
        "..khh..khh..kbk...khh.....",
        ".............khh..........",
    ],
    [
        "....................kk....",
        "...................khhk...",
        "..................khbbbk..",
        ".................khbbbbbk.",
        "................khbbkbbbbk",
        "...............khbbbbbbbbk",
        "..............khbbbkkkbbk.",
        "....kkkkkkkkkkhbbbk...kk..",
        "..kkllllllllllllbbk.......",
        ".khblllllllllllbbbbk......",
        "khhbbbbbbbbbbbbbbbbk......",
        "khkbbbbbbbbbbbbbbbk.......",
        "kk.kbbbbbbbbbbbbbbk.......",
        "....kbbbkkkkkkkbbbk.......",
        "....kbbk....kbbk..........",
        "...kbk.kbk.kbk.kbk........",
        "..kbk...khhkbk...khh......",
        "..khh......khh............",
    ],
]

## The horse galloping, seen from the side, facing right, in two frames.
const _GALLOP := [
    [
        "......................kk..",
        ".....................khhk.",
        "....................khbbbk",
        "...................khbbkbk",
        "..................khbbbbbk",
        ".................khbbkkkk.",
        "kkk.............khbbk.....",
        "khhkkkkkkkkkkkkkhbbbk.....",
        ".kkhllllllllllllllbbk.....",
        "...kblllllllllllbbbbk.....",
        "...kbbbbbbbbbbbbbbbk......",
        "...kbbbbbbbbbbbbbbbk......",
        "....kbbbkkkkkkkbbbk.......",
        "...kbbk........kbbk.......",
        "..kbk...........kbbk......",
        ".kbk..............kbk.....",
        "khh................khh....",
        "..........................",
    ],
    [
        "......................kk..",
        ".....................khhk.",
        "....................khbbbk",
        "...................khbbkbk",
        "..................khbbbbbk",
        ".................khbbkkkk.",
        "kkk.............khbbk.....",
        "khhkkkkkkkkkkkkkhbbbk.....",
        ".kkhllllllllllllllbbk.....",
        "...kblllllllllllbbbbk.....",
        "...kbbbbbbbbbbbbbbbk......",
        "...kbbbbbbbbbbbbbbbk......",
        "....kbbbkkkkkkkbbbk.......",
        "......kbbk...kbbk.........",
        ".......kbk..kbk...........",
        "........kbkkbk............",
        "........khhkhh............",
        "..........................",
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
            return _TROT[frame % 2]
        3:
            return _GALLOP[frame % 2]
        1:
            return _WALK[frame % 2]
        _:
            return _WALK[0]


## All the sprites with their names, for the tests.
static func all() -> Dictionary:
    var result := {"takiya": TAKIYA}
    for gait in range(4):
        for frame in range(2):
            result["horse_%d_%d" % [gait, frame]] = horse(gait, frame)
    return result
