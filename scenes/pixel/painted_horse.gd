class_name PaintedHorse
extends RefCounted

## Draw the painted horse from the side, facing right, saddled, in its gaits:
## seven frames each of the walk, the trot and the gallop, cut out of a
## painted sprite sheet (see assets/pictures/horse/). A standing horse shows
## the first frame of the walk.
##
## The frames come in two sizes: big, for the instruction, and small, for the
## icons of the speed bar. Each is drawn with two pixels of the screen per
## logical pixel, like the pixel art, so it stays sharp.

const GAITS := ["walk", "walk", "trot", "gallop"]
const FRAMES := 7

## Where the horse stands in its frame, as a fraction of the frame: the middle
## of its body, on the line of its hooves.
const ANCHOR := Vector2(0.502, 0.97)

## How long a cycle of the seven frames lasts, by the gait, in seconds.
const CYCLE_SECONDS := [1.0, 1.0, 0.7, 0.5]

## The painted frames of the horse rearing up, from the side (see
## [method draw_rear]); without them, the standing horse is tipped back.
const REAR_FRAMES := 5

## Where the hind hooves stand in a frame, as a fraction of the frame: the
## horse rears up around them.
const _HIND := Vector2(0.3, 0.97)

static var _cache: Dictionary = {}


## The frame of the gait (0 stands, 1 walks, 2 trots, 3 gallops).
static func texture(gait: int, frame: int, small := false) -> Texture2D:
    var index := 0 if gait <= 0 else posmod(frame, FRAMES)
    var path := (
        "res://assets/pictures/horse/%s%s_%d.png"
        % ["small/" if small else "", GAITS[clampi(gait, 0, 3)], index]
    )
    if not _cache.has(path):
        _cache[path] = load(path)
    return _cache[path]


## The frame of the gait at the time, in seconds, as the horse moves.
static func frame_at(gait: int, time: float) -> int:
    if gait <= 0:
        return 0
    return int(time / CYCLE_SECONDS[clampi(gait, 0, 3)] * FRAMES) % FRAMES


## The size of a frame in logical pixels.
static func size(small := false) -> Vector2:
    return texture(1, 0, small).get_size() * 0.5


## Draw the frame on the item so that the horse stands at [param ground].
static func draw(
    item: CanvasItem, gait: int, frame: int, ground: Vector2, small := false, tint := Color.WHITE
) -> void:
    var picture := texture(gait, frame, small)
    var shown := picture.get_size() * 0.5
    item.draw_texture_rect(picture, Rect2((ground - shown * ANCHOR).round(), shown), false, tint)


## Draw the horse rearing up on its hind legs, [param progress] through the
## rearing (0 starts, 0.5 is the highest, 1 stands again), so that it stands
## at [param ground]: the painted frame of the rearing if there is one
## (assets/pictures/horse/rear_<frame>.png), else the standing horse tipped
## back around its hind hooves.
static func draw_rear(item: CanvasItem, progress: float, ground: Vector2, small := false) -> void:
    var amount := sin(clampf(progress, 0.0, 1.0) * PI)
    var frame := clampi(roundi(progress * (REAR_FRAMES - 1)), 0, REAR_FRAMES - 1)
    var path := "res://assets/pictures/horse/%srear_%d.png" % ["small/" if small else "", frame]
    if ResourceLoader.exists(path):
        if not _cache.has(path):
            _cache[path] = load(path)
        var painted: Texture2D = _cache[path]
        var shown := painted.get_size() * 0.5
        item.draw_texture_rect(painted, Rect2((ground - shown * ANCHOR).round(), shown), false)
        return
    var picture := texture(0, 0, small)
    var size := picture.get_size() * 0.5
    var hind := ground + (_HIND - ANCHOR) * size
    item.draw_set_transform(hind, -0.55 * amount, Vector2.ONE)
    item.draw_texture_rect(picture, Rect2(-_HIND * size, size), false)
    item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
