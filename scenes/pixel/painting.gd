class_name Painting
extends RefCounted

## Load the paintings of the game (see assets/pictures/), which are made at
## two pixels of the screen per logical pixel, as textures of their logical
## size, so that they are drawn sharp, one pixel of the painting on each
## pixel of the screen, wherever the game draws a texture at its size (e.g.,
## the picture of a [DwellButton]).
##
## The textures are kept: a texture which nothing holds is freed right after
## the drawing, before the frame shows, and would draw white.

static var _cache: Dictionary = {}


## The painting at the path, of half its size in pixels.
static func texture(path: String) -> ImageTexture:
    if not _cache.has(path):
        var painted: Texture2D = load(path)
        var result := ImageTexture.create_from_image(painted.get_image())
        result.set_size_override(Vector2i(painted.get_size() * 0.5))
        _cache[path] = result
    return _cache[path]


## The painted horse of the preset (see [constant Looks.HORSE_PRESETS]),
## standing, facing right, without a saddle; on a card, 80 logical pixels
## tall, else 260.
static func horse(preset: String, card := false) -> ImageTexture:
    var id: String = preset if preset in Looks.HORSE_PRESETS else Looks.DEFAULT["steed"]
    return texture("res://assets/pictures/horses/%s%s.png" % ["card/" if card else "", id])


## The painted rider of the preset (see [constant Looks.PRESETS]), standing,
## facing the viewer; on a card, 140 logical pixels tall, else 290.
static func rider(preset: String, card := false) -> ImageTexture:
    var id: String = preset if preset in Looks.PRESETS else Looks.DEFAULT["rider"]
    return texture("res://assets/pictures/riders/%s%s.png" % ["card/" if card else "", id])
