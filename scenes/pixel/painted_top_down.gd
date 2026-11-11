class_name PaintedTopDown
extends RefCounted

## Draw the painted creatures seen from above, turned to their heading: the
## rider on her horse (the horse of each preset in the 13 frames of its run,
## and the girl of each preset seated on it) and the lost animals (two
## walking frames and a grazing one), cut out of painted sprite sheets (see
## assets/pictures/top_down/).
##
## Each picture faces north (up), with the middle of the creature in the
## middle of its square, two pixels of the screen per logical pixel. Unlike
## the pixel art, a painting turns smoothly to any heading, so the item which
## draws it filters its textures linearly (see [method prepare]).

## The frames of the run of each painted horse from above.
const HORSE_FRAMES := 13

## The frames of the jump of each painted horse from above: the take-off,
## rising, the flight, coming down and the landing.
const JUMP_FRAMES := 5

## The girl from above is drawn this much smaller than painted: the paintings
## make her as wide as the horse, while a girl of ten is about half as wide as
## the barrel of a horse (about 0.45 m with her arms, against 0.65 m; a horse
## is about 2.4 m from the nose to the croup). Her finery shrinks with her.
const GIRL_SCALE := 0.65

## The horse from above is drawn this much wider than painted, so that, with
## the girl on it, it reads as the sturdy steppe horse it is, not as a stick.
const HORSE_WIDTH := 1.15

## The people of the steppe from above, to the scale of the girl.
const PERSON_SCALE := 0.65

static var _cache: Dictionary = {}


## Let the item draw the paintings smoothly when they are turned.
static func prepare(item: CanvasItem) -> void:
    item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## Draw the rider on her horse from above on the item, the seat of the saddle
## at [param center], turned to the heading: the painted horse of the looks
## (see [constant Looks.HORSE_PRESETS]) in the frame of its run (the first
## frame while it stands), and the painted girl of the looks seated on it,
## her hat over the seat; [param big] for the instruction.
static func draw_rider(
    item: CanvasItem,
    looks: Dictionary,
    gait: int,
    frame: int,
    center: Vector2,
    heading: float,
    big := false,
    rear := 0.0,
    jump_frame := -1,
    lift := 0.0
) -> void:
    var prefix := "big/" if big else ""
    var steed: String = looks.get("steed", "1")
    var index := 0 if gait <= 0 else posmod(frame, HORSE_FRAMES)
    var horse := _load("horses/%s/%s%d" % [steed, prefix, index])
    var wide := Vector2(HORSE_WIDTH, 1.0)
    var girl := Vector2.ONE * GIRL_SCALE
    var seat := center
    var dressed := true
    if jump_frame >= 0:
        # NOTE (mristin):
        # The painted horse jumping, seen from above (assets/pictures/top_down/
        # horses/<steed>/jump_<frame>.png, painted as wide as it is), and the
        # horse and the girl bigger the higher they fly, nearer to us. Its
        # finery is painted for the run, so it is left out for the moment of
        # the jump.
        var painted := "horses/%s/jump_%d" % [steed, clampi(jump_frame, 0, JUMP_FRAMES - 1)]
        if not big and ResourceLoader.exists("res://assets/pictures/top_down/%s.png" % painted):
            horse = _load(painted)
            wide = Vector2.ONE
            dressed = false
        wide *= 1.0 + lift
        girl *= 1.0 + lift
    if rear > 0.0:
        # NOTE (mristin):
        # A painted horse rearing up, seen from above, if there is one
        # (assets/pictures/top_down/horses/<steed>/rear.png); else the horse
        # foreshortens: its front rises towards us, so it looks shorter and a
        # bit wider, its hind legs stay, and the girl leans back and comes
        # nearer to us.
        var painted := "horses/%s/%srear" % [steed, prefix]
        if ResourceLoader.exists("res://assets/pictures/top_down/%s.png" % painted):
            horse = _load(painted)
        else:
            wide = Vector2(HORSE_WIDTH * (1.0 + 0.15 * rear), 1.0 - 0.25 * rear)
        var back := Vector2.DOWN.rotated(heading) * horse.get_size().y * 0.5 * 0.12 * rear
        center += back
        seat = center + back * 0.6
        girl *= 1.0 + 0.12 * rear
    draw(item, horse, center, heading, wide)
    if dressed:
        _dress(item, looks, "horse", horse, center, heading, wide)
    draw(item, _load("girls/%s%s" % [prefix, looks.get("rider", "1")]), seat, heading, girl)
    _dress(item, looks, "rider", horse, seat, heading, girl)


## Lay the finery which she wears, seen from above, over the horse (or the
## rider) drawn at the center: each piece is painted on the canvas of the
## horse from above, around the seat of the saddle (see
## dev/pictures/top_down_template.png), so it is drawn over the same square.
## A piece without its picture from above is not shown.
static func _dress(
    item: CanvasItem,
    looks: Dictionary,
    who: String,
    horse: Texture2D,
    center: Vector2,
    heading: float,
    scale := Vector2.ONE
) -> void:
    for piece in Finery.PIECES:
        if Finery.PIECES[piece]["for"] != who:
            continue
        var at := Finery.step(looks, piece)
        if at < 1:
            continue
        # NOTE (mristin):
        # A step without its own picture from above shows the one before.
        for step in range(at, 0, -1):
            var name := "finery/%s_%d" % [piece, step]
            if ResourceLoader.exists("res://assets/pictures/top_down/%s.png" % name):
                var shown := horse.get_size() * 0.5
                var picture := _load(name)
                item.draw_set_transform(center, heading, scale)
                item.draw_texture_rect(picture, Rect2(-shown * 0.5, shown), false)
                item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
                break


## The animal of the kind ("sheep", "lamb", "horse", "camel"), walking in the
## frame (0 or 1) or grazing.
static func animal(kind: String, frame: int, grazing: bool) -> Texture2D:
    return _load("%s/%s" % [kind, "graze" if grazing else "walk_%d" % posmod(frame, 2)])


## Draw the picture on the item, its middle at [param center], turned to the
## heading (0 is north, clockwise), scaled across and along its heading.
static func draw(
    item: CanvasItem, picture: Texture2D, center: Vector2, heading: float, scale := Vector2.ONE
) -> void:
    var shown := picture.get_size() * 0.5
    item.draw_set_transform(center, heading, scale)
    item.draw_texture_rect(picture, Rect2(-shown * 0.5, shown), false)
    item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _load(name: String) -> Texture2D:
    if not _cache.has(name):
        _cache[name] = load("res://assets/pictures/top_down/%s.png" % name)
    return _cache[name]
