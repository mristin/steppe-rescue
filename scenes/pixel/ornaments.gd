class_name Ornaments
extends RefCounted

## Draw the felt panels of the interface with the Kazakh ornaments (ою-өрнек),
## the way the felt carpets (сырмақ) are bordered: painted panels (see
## assets/pictures/ui/) stretched to any size as a nine-patch. The corners
## with the ram's horn (қошқар мүйіз) keep their shape and shrink to fit a
## small button; the edges are repeated along the sides; the middle is a
## seamless felt (assets/pictures/felt/), repeated in the colour of the
## style. They frame the buttons, the panels and the banners
## (see section 11 of DESIGN.md).

## The styles, by the name of their painting: cream felt with a crimson
## border, then lighter when hovered, golden when chosen, crimson for the
## main button of a screen, and lighter crimson when that is hovered.
const STYLES := ["felt", "hover", "selected", "primary", "primary_hover"]

## The corners of the paintings, in their pixels, which keep their shape:
## the ram's horns reach farther along the top than down the sides.
const _CORNER := Vector2i(200, 130)

## The plain stretches of the border between the corner and the ornament in
## the middle of the long side, and down the short side, which repeat along
## the edges.
const _PLAIN_X := Vector2i(200, 290)
const _PLAIN_Y := Vector2i(135, 245)

## The corners are at most this many pixels of the screen high, and at most
## this fraction of the shorter side.
const _MAX_CORNER := 72
const _CORNER_FRACTION := 0.42

## The seamless felt of the middle of the panels, repeated every this many
## pixels of the screen.
const _FELT := "res://assets/pictures/felt/felt.png"
const _FELT_TILE := 256

static var _sources: Dictionary = {}
static var _felts: Dictionary = {}
static var _panels: Dictionary = {}


## The panel of the size (in logical pixels) in the style.
static func panel(size: Vector2, style := "felt") -> ImageTexture:
    var whole := Vector2i(size.round()).max(Vector2i(2, 2))
    var key := "%s|%s" % [whole, style]
    if _panels.has(key):
        return _panels[key]
    var source := _source(style if style in STYLES else "felt")
    var src := source.get_size()
    var pixels := whole * Pixelate.DENSITY

    # NOTE (mristin):
    # The corners keep the shape of the painted ones, and fit the panel.
    var aspect := float(_CORNER.x) / _CORNER.y
    var high := minf(_MAX_CORNER, pixels.y * _CORNER_FRACTION)
    high = minf(high, pixels.x * _CORNER_FRACTION / aspect)
    var corner := Vector2i(maxi(1, roundi(high * aspect)), maxi(1, roundi(high)))
    var inner := pixels - 2 * corner
    var canvas := Image.create_empty(pixels.x, pixels.y, false, Image.FORMAT_RGBA8)
    var c := _CORNER

    # NOTE (mristin):
    # The middle first, a seamless felt repeated (not the painted middle
    # stretched, which would look lighter on a big panel), then the edges
    # and the corners over it.
    _felt(canvas, style if style in STYLES else "felt", Rect2i(corner, inner))
    var plain_x := _PLAIN_X.y - _PLAIN_X.x
    var plain_y := _PLAIN_Y.y - _PLAIN_Y.x
    _repeat(
        canvas,
        source,
        Rect2i(_PLAIN_X.x, 0, plain_x, c.y),
        Rect2i(corner.x, 0, inner.x, corner.y),
        true
    )
    _repeat(
        canvas,
        source,
        Rect2i(_PLAIN_X.x, src.y - c.y, plain_x, c.y),
        Rect2i(corner.x, pixels.y - corner.y, inner.x, corner.y),
        true
    )
    _repeat(
        canvas,
        source,
        Rect2i(0, _PLAIN_Y.x, c.x, plain_y),
        Rect2i(0, corner.y, corner.x, inner.y),
        false
    )
    _repeat(
        canvas,
        source,
        Rect2i(src.x - c.x, _PLAIN_Y.x, c.x, plain_y),
        Rect2i(pixels.x - corner.x, corner.y, corner.x, inner.y),
        false
    )
    for x in [0, 1]:
        for y in [0, 1]:
            var from := Rect2i(x * (src.x - c.x), y * (src.y - c.y), c.x, c.y)
            var to := Rect2i(
                x * (pixels.x - corner.x), y * (pixels.y - corner.y), corner.x, corner.y
            )
            _put(canvas, source, from, to)

    var result := ImageTexture.create_from_image(canvas)
    result.set_size_override(whole)
    _panels[key] = result
    return result


## Fill the rectangle of the canvas with the seamless felt, in the colour of
## the felt in the middle of the painted panel of the style.
static func _felt(canvas: Image, style: String, to: Rect2i) -> void:
    if to.size.x <= 0 or to.size.y <= 0:
        return
    if not _felts.has(style):
        var felt := (load(_FELT) as Texture2D).get_image()
        felt.convert(Image.FORMAT_RGBA8)
        felt.resize(_FELT_TILE, _FELT_TILE, Image.INTERPOLATE_LANCZOS)
        var source := _source(style)
        var middle := source.get_region(Rect2i(_CORNER, source.get_size() - 2 * _CORNER))
        var target := _mean(middle)
        var own := _mean(felt)
        var gain := Vector3(target.r / own.r, target.g / own.g, target.b / own.b)
        for y in range(felt.get_height()):
            for x in range(felt.get_width()):
                var color := felt.get_pixel(x, y)
                felt.set_pixel(
                    x,
                    y,
                    Color(
                        minf(1.0, color.r * gain.x),
                        minf(1.0, color.g * gain.y),
                        minf(1.0, color.b * gain.z),
                        1.0
                    )
                )
        _felts[style] = felt
    var tile: Image = _felts[style]
    for y in range(to.position.y, to.end.y, _FELT_TILE):
        for x in range(to.position.x, to.end.x, _FELT_TILE):
            var take := Vector2i(mini(_FELT_TILE, to.end.x - x), mini(_FELT_TILE, to.end.y - y))
            canvas.blit_rect(tile, Rect2i(Vector2i.ZERO, take), Vector2i(x, y))


## The mean colour of the image, sampled.
static func _mean(image: Image) -> Color:
    var sum := Color(0, 0, 0, 0)
    var count := 0
    for y in range(0, image.get_height(), 4):
        for x in range(0, image.get_width(), 4):
            sum += image.get_pixel(x, y)
            count += 1
    return sum / maxf(1.0, count)


## The painting of the style.
static func _source(style: String) -> Image:
    if not _sources.has(style):
        var painted: Texture2D = load("res://assets/pictures/ui/panel_%s.png" % style)
        var image := painted.get_image()
        image.convert(Image.FORMAT_RGBA8)
        _sources[style] = image
    return _sources[style]


## Put the part of the source into the rectangle of the canvas, scaled.
static func _put(canvas: Image, source: Image, from: Rect2i, to: Rect2i) -> void:
    if to.size.x <= 0 or to.size.y <= 0:
        return
    var part := source.get_region(from)
    part.resize(to.size.x, to.size.y, Image.INTERPOLATE_LANCZOS)
    canvas.blit_rect(part, Rect2i(Vector2i.ZERO, to.size), to.position)


## Repeat the part of the source along the rectangle of the canvas: scaled to
## its thickness, and repeated along x (or else along y).
static func _repeat(canvas: Image, source: Image, from: Rect2i, to: Rect2i, along_x: bool) -> void:
    if to.size.x <= 0 or to.size.y <= 0:
        return
    var part := source.get_region(from)
    var thickness := to.size.y if along_x else to.size.x
    var scale := float(thickness) / (from.size.y if along_x else from.size.x)
    var length := maxi(1, roundi((from.size.x if along_x else from.size.y) * scale))
    if along_x:
        part.resize(length, thickness, Image.INTERPOLATE_LANCZOS)
    else:
        part.resize(thickness, length, Image.INTERPOLATE_LANCZOS)
    var at := 0
    var total := to.size.x if along_x else to.size.y
    while at < total:
        var take := mini(length, total - at)
        var piece := Rect2i(0, 0, take, thickness) if along_x else Rect2i(0, 0, thickness, take)
        var target := to.position + (Vector2i(at, 0) if along_x else Vector2i(0, at))
        canvas.blit_rect(part, piece, target)
        at += length


static func _n(value: float) -> String:
    return String.num(value, 2)
