class_name Finery
extends RefCounted

## Know the finery which the rider wins at the end of the levels (see section 8
## of DESIGN.md): the pieces for her horse (the tack, ер-тұрман) and for her,
## each built up in steps, the later step on top of the earlier.
##
## The finery is a dictionary from the id of a piece to the step won (1 is the
## first step); a piece not won is missing, and the rider and her horse wear
## its plain form (e.g., a plain leather saddle). [SideView] and [FrontView]
## draw it from [code]looks["finery"][/code] (see [method Profile.dressed]).

## The pieces in their order, with the number of their steps and whom they
## are for.
const PIECES := {
    "saddle": {"steps": 2, "for": "horse", "kazakh": "ер"},
    "saddle_cloth": {"steps": 2, "for": "horse", "kazakh": "тоқым"},
    "bridle": {"steps": 2, "for": "horse", "kazakh": "жүген"},
    "breastplate": {"steps": 1, "for": "horse", "kazakh": "өмілдірік"},
    "stirrups": {"steps": 1, "for": "horse", "kazakh": "үзеңгі"},
    "mane": {"steps": 3, "for": "horse", "kazakh": "жал"},
    "feathers": {"steps": 1, "for": "rider", "kazakh": "үкі"},
    "coat": {"steps": 2, "for": "rider", "kazakh": "шапан"},
    "earrings": {"steps": 1, "for": "rider", "kazakh": "сырға"},
    "bracelets": {"steps": 1, "for": "rider", "kazakh": "білезік"},
    "belt": {"steps": 1, "for": "rider", "kazakh": "белбеу"},
    "boots": {"steps": 1, "for": "rider", "kazakh": "етік"},
}

## How many pieces the reward offers.
const OFFERED := 3


## The step of the piece in the looks; 0 if not won.
static func step(looks: Dictionary, piece: String) -> int:
    var finery: Dictionary = looks.get("finery", {})
    return int(finery.get(piece, 0))


## The finery with only the known pieces and steps.
static func complete(finery: Dictionary) -> Dictionary:
    var result := {}
    for piece in finery:
        if PIECES.has(piece):
            var won := clampi(int(finery[piece]), 0, PIECES[piece]["steps"])
            if won > 0:
                result[piece] = won
    return result


## The pieces to offer after a level with the stars, as [piece, step] pairs:
## the next step of up to [constant OFFERED] pieces not complete yet. More
## stars offer the higher steps, the more splendid pieces, first.
static func offer(finery: Dictionary, stars: int, rng: RandomNumberGenerator) -> Array:
    var candidates := []
    for piece in PIECES:
        var next := int(finery.get(piece, 0)) + 1
        if next <= PIECES[piece]["steps"]:
            candidates.append([piece, next])
    # NOTE (mristin):
    # Shuffle with the generator, so that the tests can repeat an offer.
    for i in range(candidates.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var swap: Array = candidates[i]
        candidates[i] = candidates[j]
        candidates[j] = swap
    if stars >= 2:
        candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
    else:
        candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
    return candidates.slice(0, OFFERED)
