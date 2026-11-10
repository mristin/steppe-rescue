class_name PaintedTopDown
extends RefCounted

## Draw the painted creatures seen from above, turned to their heading: the
## rider on her horse (walk, trot and gallop, four frames each) and the lost
## animals (two walking frames and a grazing one), cut out of painted sprite
## sheets (see assets/pictures/top_down/).
##
## Each picture faces north (up), with the middle of the creature in the
## middle of its square, two pixels of the screen per logical pixel. Unlike
## the pixel art, a painting turns smoothly to any heading, so the item which
## draws it filters its textures linearly (see [method prepare]).

const RIDER_GAITS := ["walk", "walk", "trot", "gallop"]
const RIDER_FRAMES := 4

static var _cache: Dictionary = {}


## Let the item draw the paintings smoothly when they are turned.
static func prepare(item: CanvasItem) -> void:
    item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## The rider on her horse in the gait (0 stands, 1 walks, 2 trots, 3 gallops)
## and the frame; [param big] for the instruction.
static func rider(gait: int, frame: int, big := false) -> Texture2D:
    var index := 0 if gait <= 0 else posmod(frame, RIDER_FRAMES)
    return _load("rider/%s%s_%d" % ["big/" if big else "", RIDER_GAITS[clampi(gait, 0, 3)], index])


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
