class_name Pixelate
extends RefCounted

## Turn the vector pictures of the game into pixel art.
##
## Every picture of the game (the creatures, the landmarks, the icons, the
## intro picture, ...) is first drawn as vectors, in SVG, in the logical
## coordinates of the game (960x540). We rasterize it at [constant DENSITY]
## pixels per logical pixel (the game shows 1920x1080), sample each pixel
## [constant _SUPERSAMPLE] x [constant _SUPERSAMPLE] times, snap every sample
## to the nearest color of the [Palette], and give the pixel the color of the
## most samples. So the edges stay crisp and only the colors of the palette
## appear, without the blended colors of anti-aliasing. Finally, the dark
## outline goes around the opaque pixels.
##
## The textures report their logical size (see
## [method ImageTexture.set_size_override]), so that they are drawn at their
## logical size with every pixel of them on a pixel of the screen.
##
## The photographs (the portraits) are not vectors; they are pixelized
## offline by dev/pictures/pixelize.py, at the same density.

## The pixels of the screen per logical pixel of the game.
const DENSITY := 2

## Each pixel is sampled this many times along each axis.
const _SUPERSAMPLE := 3

## The names of the colors of the [Palette] in the SVG of the pictures.
const NAMES := {
    "outline": Palette.OUTLINE,
    "night": Palette.NIGHT,
    "sky": Palette.SKY,
    "sky_light": Palette.SKY_LIGHT,
    "grass": Palette.GRASS,
    "grass_dark": Palette.GRASS_DARK,
    "grass_light": Palette.GRASS_LIGHT,
    "emerald": Palette.EMERALD,
    "emerald_light": Palette.EMERALD_LIGHT,
    "crimson": Palette.CRIMSON,
    "crimson_dark": Palette.CRIMSON_DARK,
    "crimson_light": Palette.CRIMSON_LIGHT,
    "ochre": Palette.OCHRE,
    "gold": Palette.GOLD,
    "felt": Palette.FELT,
    "stone": Palette.STONE,
    "stone_light": Palette.STONE_LIGHT,
    "bay": Palette.HORSE_BAY,
    "bay_light": Palette.HORSE_BAY_LIGHT,
    "hoof": Palette.HOOF,
    "skin": Palette.SKIN,
    "skin_dark": Palette.SKIN_DARK,
    "skin_fair": Palette.SKIN_FAIR,
    "skin_tan": Palette.SKIN_TAN,
    "skin_deep": Palette.SKIN_DEEP,
    "indigo": Palette.INDIGO,
    "indigo_light": Palette.INDIGO_LIGHT,
    "hair_black": Palette.HAIR_BLACK,
    "chestnut": Palette.CHESTNUT,
    "dun": Palette.DUN,
}

static var _cache: Dictionary = {}

static var _quantizer_instance: RefCounted = null


## Make (or take from the cache) the pixel-art texture of the SVG picture.
##
## The [param body] is the content of the SVG (without the [code]<svg>[/code]
## element) in logical pixels, in the view box of [param view] (its position
## and size). The colors are named after the [Palette] in braces, e.g.,
## [code]fill="{crimson}"[/code] (see [constant NAMES]). The texture has the
## logical size of the view box.
##
## A big picture (e.g., the intro picture) may take fewer [param samples] per
## pixel along each axis, which is faster and needs less memory.
static func texture(
    body: String, view: Rect2, outline := true, samples := _SUPERSAMPLE
) -> ImageTexture:
    var key := "%s|%s|%s|%s" % [view, outline, samples, body]
    if _cache.has(key):
        return _cache[key]

    var result := ImageTexture.create_from_image(image_of(svg_colors(body), view, outline, samples))
    result.set_size_override(Vector2i(view.size.round()))
    _cache[key] = result
    return result


## Rasterize the SVG picture into pixel art at [constant DENSITY].
static func image_of(body: String, view: Rect2, outline := true, samples := _SUPERSAMPLE) -> Image:
    var width := maxi(1, roundi(view.size.x * DENSITY))
    var height := maxi(1, roundi(view.size.y * DENSITY))

    var svg := (
        (
            '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" '
            + 'viewBox="%s %s %s %s">%s</svg>'
        )
        % [
            _number(view.size.x),
            _number(view.size.y),
            _number(view.position.x),
            _number(view.position.y),
            _number(view.size.x),
            _number(view.size.y),
            body,
        ]
    )
    var sampled := Image.new()
    var error := sampled.load_svg_from_string(svg, float(DENSITY * samples))
    if error != OK:
        push_error("Pixelate: the SVG could not be read: %s" % error_string(error))
        var broken := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
        broken.fill(Color.MAGENTA)
        return broken
    if sampled.get_format() != Image.FORMAT_RGBA8:
        sampled.convert(Image.FORMAT_RGBA8)

    var pixels: PackedByteArray = _quantizer().Quantize(
        sampled.get_data(),
        sampled.get_width(),
        sampled.get_height(),
        width,
        height,
        samples,
        outline,
        Palette.OUTLINE
    )
    return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, pixels)


## The body with the names of the colors in braces replaced by the colors.
static func svg_colors(body: String) -> String:
    var names := {}
    for name in NAMES:
        names[name] = color(NAMES[name])
    return body.format(names)


## The color as SVG writes it, e.g., "#b3263a".
static func color(value: Color) -> String:
    return "#" + value.to_html(false)


## The number as SVG writes it, short and without a locale.
static func _number(value: float) -> String:
    return String.num(value, 3)


## The quantizer in C# (scenes/pixel/PixelQuantizer.cs), with the palette.
static func _quantizer() -> RefCounted:
    if _quantizer_instance == null:
        _quantizer_instance = load("res://scenes/pixel/PixelQuantizer.cs").new()
        _quantizer_instance.SetPalette(Palette.COLORS)
    return _quantizer_instance
