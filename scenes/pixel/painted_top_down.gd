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
    big := false
) -> void:
    var prefix := "big/" if big else ""
    var steed: String = looks.get("steed", "1")
    var index := 0 if gait <= 0 else posmod(frame, HORSE_FRAMES)
    var horse := _load("horses/%s/%s%d" % [steed, prefix, index])
    draw(item, horse, center, heading)
    _dress(item, looks, "horse", horse, center, heading)
    draw(item, _load("girls/%s%s" % [prefix, looks.get("rider", "1")]), center, heading)
    _dress(item, looks, "rider", horse, center, heading)


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
    heading: float
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
                item.draw_set_transform(center, heading, Vector2.ONE)
                item.draw_texture_rect(picture, Rect2(-shown * 0.5, shown), false)
                item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
                break


## The animal of the kind ("sheep", "lamb", "horse", "camel"), walking in the
## frame (0 or 1) or grazing.
static func animal(kind: String, frame: int, grazing: bool) -> Texture2D:
    return _load("%s/%s" % [kind, "graze" if grazing else "walk_%d" % posmod(frame, 2)])


## Draw the picture on the item, its middle at [param center], turned to the
## heading (0 is north, clockwise).
static func draw(item: CanvasItem, picture: Texture2D, center: Vector2, heading: float) -> void:
    var shown := picture.get_size() * 0.5
    item.draw_set_transform(center, heading, Vector2.ONE)
    item.draw_texture_rect(picture, Rect2(-shown * 0.5, shown), false)
    item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _load(name: String) -> Texture2D:
    if not _cache.has(name):
        _cache[name] = load("res://assets/pictures/top_down/%s.png" % name)
    return _cache[name]
