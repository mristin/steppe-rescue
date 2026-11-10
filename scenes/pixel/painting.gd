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


## The painting at the path fitted into a box of [param box] logical pixels,
## in its middle, at two pixels of the screen per logical pixel, so that
## paintings of any size take the same place (e.g., the icons); null if
## there is no such painting.
static func fitted(path: String, box: Vector2) -> ImageTexture:
    var key := "%s|%s" % [path, box]
    if _cache.has(key):
        return _cache[key]
    if not ResourceLoader.exists(path):
        return null
    var source := (load(path) as Texture2D).get_image()
    source.convert(Image.FORMAT_RGBA8)
    var whole := box.round()
    var pixels := Vector2i(whole * Pixelate.DENSITY)
    var fit := minf(float(pixels.x) / source.get_width(), float(pixels.y) / source.get_height())
    var fitted_size := Vector2i(
        maxi(1, roundi(source.get_width() * fit)), maxi(1, roundi(source.get_height() * fit))
    )
    source.resize(fitted_size.x, fitted_size.y, Image.INTERPOLATE_LANCZOS)
    var canvas := Image.create_empty(pixels.x, pixels.y, false, Image.FORMAT_RGBA8)
    canvas.blit_rect(source, Rect2i(Vector2i.ZERO, fitted_size), (pixels - fitted_size) / 2)
    var result := ImageTexture.create_from_image(canvas)
    result.set_size_override(Vector2i(whole))
    _cache[key] = result
    return result


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
