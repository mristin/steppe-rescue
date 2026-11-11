class_name PaintedGirl
extends RefCounted

## Draw the painted girl standing in front of the camera, as the player does:
## squatting in six frames (standing, going down, deep, the deepest, coming
## up, standing) and pulling the reins in six frames (her hands in front, a
## little and far to the left, in front, a little and far to the right; the
## left of the picture, as in a mirror), cut out of painted sprite sheets
## (see assets/pictures/girl/). Her boots stand on the same spot in every
## frame.
##
## The frames come big (290 logical pixels tall), for the instruction and the
## request for room, and small (100), for the small figure in the level.

const FRAMES := 6

static var _cache: Dictionary = {}


## The frame of the squat at its phase in [0, 1) (0 standing).
static func squat_frame(phase: float) -> int:
    return roundi(phase * FRAMES) % FRAMES


## The frame of the reins pulled as far as [param reach], in [-1, 1],
## positive to the left.
static func reins_frame(reach: float) -> int:
    if absf(reach) < 0.3:
        return 0
    var far := absf(reach) >= 0.8
    if reach > 0.0:
        return 2 if far else 1
    return 5 if far else 4


## The picture of the squat in the frame.
static func squat(frame: int, small := false) -> Texture2D:
    return _load("squat", posmod(frame, FRAMES), small)


## The picture of the girl with both hands up above her head (the brake),
## [param amount] of the way up, in [0, 1]; null while it is not painted yet
## (assets/pictures/girl/hands_up_<frame>.png, three frames).
static func hands_up(amount: float, small := false) -> Texture2D:
    var frame := clampi(roundi(amount * 2.0), 0, 2)
    var path := "res://assets/pictures/girl/%shands_up_%d.png" % ["small/" if small else "", frame]
    if not ResourceLoader.exists(path):
        return null
    return _load("hands_up", frame, small)


## The picture of the girl jumping in the frame: the crouch, the take-off, in
## the air (lifted above the ground at the bottom of the picture) and the
## landing (assets/pictures/girl/jump_<frame>.png).
static func jump(frame: int, small := false) -> Texture2D:
    return _load("jump", clampi(frame, 0, 3), small)


## The picture of the reins in the frame.
static func reins(frame: int, small := false) -> Texture2D:
    return _load("reins", posmod(frame, FRAMES), small)


## Draw the picture on the item with her boots at [param feet], [param scale]
## times its size (two pixels of the screen per logical pixel at 1), tinted
## with [param color] (e.g., half transparent to blend two frames).
static func draw(
    item: CanvasItem, picture: Texture2D, feet: Vector2, scale := 1.0, color := Color.WHITE
) -> void:
    var shown := picture.get_size() * 0.5 * scale
    item.draw_texture_rect(
        picture, Rect2((feet - Vector2(shown.x * 0.5, shown.y)).round(), shown), false, color
    )


static func _load(kind: String, frame: int, small: bool) -> Texture2D:
    # NOTE (mristin):
    # Keep the textures: a texture which nothing holds is freed right after
    # the drawing, before the frame shows, and would draw white.
    var path := "res://assets/pictures/girl/%s%s_%d.png" % ["small/" if small else "", kind, frame]
    if not _cache.has(path):
        _cache[path] = load(path)
    return _cache[path]
