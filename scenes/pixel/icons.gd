class_name Icons
extends RefCounted

## Hold the small pictures of the interface: the animals and the landmarks in
## the clues, the slots and the hearing, and the stars (as sprites of
## [PixelSprite] with [constant Palette.LEGEND]), and the portraits of the
## people.
##
## The portraits are pixelized from old photographs in the public domain (see
## dev/pictures/pixelize.py and THIRD_PARTY_NOTICES.md).
##
## The pictures carry the clues, so that a child who reads slowly still
## understands them (see section 4 of DESIGN.md).

const SHEEP := [
    "...kkkkk....",
    "..kfffffkkk.",
    ".kffffffkhhk",
    "kfffffffkhkk",
    "kffffffffkk.",
    ".kfffffffk..",
    "..kkkkkkk...",
    "..kh...hk...",
    "..kk...kk...",
]

const HORSE := [
    "........kk..",
    ".......kbbk.",
    "......kbbbbk",
    ".kkkkkkbbkk.",
    "kbbbbbbbbk..",
    "kbbbbbbbbk..",
    ".kbkkkkbk...",
    ".kbk..kbk...",
    ".kk....kk...",
]

const CAMEL := [
    "..kk.kk.kk..",
    ".kookookkook",
    "kooooooookok",
    "kooooooook..",
    ".koooooook..",
    ".kokkkkok...",
    ".kok..kok...",
    ".kok..kok...",
    ".kk...kk....",
]

const SPRING := [
    "............",
    "...mmmmmm...",
    "..mmuuuumm..",
    ".mmuiuuuumm.",
    ".mmuuuuuumm.",
    "..mmuuuumm..",
    "...mmmmmm...",
    "............",
    "............",
]

const ROCK := [
    "............",
    "....kkkk....",
    "...kwwaak...",
    "..kawwaaak..",
    ".kaaaaaaaak.",
    ".kaaaaaaaak.",
    "..kkkkkkkk..",
    "............",
    "............",
]

const BUSHES := [
    "............",
    "..kk...kk...",
    ".keek.keek..",
    "keeeekeeeek.",
    "keeeeeeeeek.",
    ".keeeeeeek..",
    "..kkkkkkk...",
    "............",
    "............",
]

const BIRCHES := [
    "..kk....kk..",
    ".kmmk..kmmk.",
    "kmmmmkkmmmmk",
    "kmmmmkkmmmmk",
    ".kmmk..kmmk.",
    "..kfk..kfk..",
    "..kfk..kfk..",
    "..kkk..kkk..",
    "............",
]

const LAKE := [
    "............",
    "..iiiiiii...",
    ".iuuuuuuuii.",
    "iuuuuuuuuuui",
    "iuuuiuuuuuui",
    ".iuuuuuuuui.",
    "..iiiiiiii..",
    "............",
    "............",
]

const KURGAN := [
    "............",
    "............",
    "....kkkk....",
    "..kkttttkk..",
    ".kttgggggtk.",
    "kcgggggggggk",
    "kkkkkkkkkkkk",
    "............",
    "............",
]

const WELL := [
    "o...........",
    ".o..........",
    "..o.........",
    "...kkkkkk...",
    "..kaaaaaak..",
    "..kannnnak..",
    "..kannnnak..",
    "..kaaaaaak..",
    "...kkkkkk...",
]

const YURT := [
    "............",
    "....kkkk....",
    "..kkffffkk..",
    ".kffrrrrffk.",
    ".kfrfoofrfk.",
    ".kffrrrrffk.",
    "..kkffffkk..",
    "....kook....",
    "............",
]

const STAR := [
    "....k....",
    "...kyk...",
    "kkkyyykkk",
    "kyyyyyyyk",
    ".kyyyyyk.",
    "..kyyyk..",
    ".kyykyyk.",
    ".kyk.kyk.",
    ".kk...kk.",
]

const HEART := [
    ".kk.kk.",
    "krrkrrk",
    "krrrrrk",
    ".krrrk.",
    "..krk..",
    "...k...",
]

## The pictures of the animals, by the id of their kind.
const ANIMALS := {"sheep": SHEEP, "horse": HORSE, "camel": CAMEL}

## The pictures of the landmarks, by the id of their kind.
const LANDMARKS := {
    "spring": SPRING,
    "rock": ROCK,
    "bushes": BUSHES,
    "birches": BIRCHES,
    "lake": LAKE,
    "kurgan": KURGAN,
    "well": WELL,
    "yurt": YURT,
}

## The portraits of the people, by the portrait of a [Person].
const PORTRAITS := ["grandmother", "shepherd", "beekeeper"]

const _PORTRAITS_DIR := "res://assets/pictures/portraits"


static func animal(id: String) -> ImageTexture:
    return PixelSprite.texture(ANIMALS.get(id, SHEEP))


static func landmark(id: String) -> ImageTexture:
    return PixelSprite.texture(LANDMARKS.get(id, ROCK))


static func portrait(id: String) -> Texture2D:
    return load("%s/%s.png" % [_PORTRAITS_DIR, id if id in PORTRAITS else "shepherd"])


## All the pictures by their names, for the tests.
static func all() -> Dictionary:
    var result := {"star": STAR, "heart": HEART}
    for id in ANIMALS:
        result["animal_" + id] = ANIMALS[id]
    for id in LANDMARKS:
        result["landmark_" + id] = LANDMARKS[id]
    return result
