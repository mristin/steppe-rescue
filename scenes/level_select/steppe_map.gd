class_name SteppeMap
extends RefCounted

## Paint the map of the level select (see section 6 of DESIGN.md) as vectors
## (SVG), pixelated by [Pixelate]: the steppe around the home aul, seen from
## above like the map of a level, on a felt carpet bordered with the
## ornaments, with the river and its fords, the lakes, the birch groves, the
## kurgans, the pastures with the sheep, and the path which winds from the
## aul past the spots of the levels (see [constant SPOTS]), as far as there
## are levels.

const SIZE := Vector2(960, 540)

## Where the home aul stands.
const AUL := Vector2(465, 450)

## The spots of the levels along the path from the aul, in their order; the
## banner of a level stands over its spot.
const SPOTS := [
    Vector2(563, 379),
    Vector2(402, 321),
    Vector2(517, 270),
    Vector2(609, 247),
    Vector2(459, 212),
    Vector2(298, 195),
    Vector2(207, 166),
    Vector2(344, 132),
    Vector2(505, 86),
    Vector2(442, 49),
]

## The painting of the map (see [constant PAINTING]); its path winds from the
## aul past the spots of the levels.
const PAINTING := "res://assets/pictures/maps/level_select.png"


## The painted map, at the logical size of the screen.
static func texture(_levels := 0) -> ImageTexture:
    return Painting.texture(PAINTING)


## The map drawn as vectors and pixelated, with the path past the spots of
## [param levels] levels, as before the painting.
static func pixelated(levels: int) -> ImageTexture:
    return Pixelate.texture(svg(levels), Rect2(Vector2.ZERO, SIZE), false, 2)


## The map as SVG.
static func svg(levels: int) -> String:
    var rng := RandomNumberGenerator.new()
    rng.seed = 1997
    var parts := PackedStringArray()
    parts.append('<rect width="960" height="540" fill="{grass}"/>')
    for i in range(46):
        var at := Vector2(rng.randf() * SIZE.x, rng.randf() * SIZE.y)
        var color := "{grass_light}" if i % 3 != 0 else "{grass_dark}"
        parts.append(
            (
                '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"/>'
                % [
                    _n(at.x),
                    _n(at.y),
                    _n(rng.randf_range(20, 60)),
                    _n(rng.randf_range(8, 20)),
                    color
                ]
            )
        )
    for i in range(260):
        var at := Vector2(rng.randf() * SIZE.x, rng.randf() * SIZE.y)
        parts.append(
            (
                (
                    '<path d="M%s %s l1.5 -3 M%s %s l-1.5 -3" stroke="{grass_dark}" '
                    + 'stroke-width="0.6"/>'
                )
                % [_n(at.x), _n(at.y), _n(at.x + 1), _n(at.y)]
            )
        )

    # NOTE (mristin):
    # The river comes down from the hills in the north and winds to the west.
    var river := (
        "M600 0 C590 50 650 80 610 120 C570 160 470 130 400 150 C330 170 360 230 270 230 "
        + "C190 230 120 200 60 240 C30 260 10 262 0 264"
    )
    parts.append('<path d="%s" stroke="{sky}" stroke-width="16" fill="none"/>' % river)
    parts.append('<path d="%s" stroke="{sky_light}" stroke-width="5" fill="none"/>' % river)
    for ford in [Vector2(338, 196), Vector2(560, 132)]:
        parts.append(
            (
                '<ellipse cx="%s" cy="%s" rx="10" ry="7" fill="{stone_light}"/>'
                % [_n(ford.x), _n(ford.y)]
            )
        )

    parts.append(_icon(Icons.LAKE, Vector2(820, 470), 5.0))
    parts.append(_icon(Icons.LAKE, Vector2(70, 470), 3.5))
    parts.append(_icon(Icons.SPRING, Vector2(380, 384), 3.0))
    parts.append(_icon(Icons.BIRCHES, Vector2(880, 120), 4.0))
    parts.append(_icon(Icons.BIRCHES, Vector2(60, 90), 3.5))
    parts.append(_icon(Icons.BIRCHES, Vector2(600, 300), 3.0))
    parts.append(_icon(Icons.KURGAN, Vector2(760, 60), 4.0))
    parts.append(_icon(Icons.KURGAN, Vector2(260, 40), 3.0))
    parts.append(_icon(Icons.ROCK, Vector2(900, 360), 3.0))
    parts.append(_icon(Icons.ROCK, Vector2(110, 280), 2.5))
    parts.append(_icon(Icons.PASTURE, Vector2(690, 470), 4.0))
    parts.append(_icon(Icons.PASTURE, Vector2(240, 360), 3.5))
    parts.append(_icon(Icons.WELL, Vector2(380, 500), 2.5))
    for sheep in [Vector2(670, 452), Vector2(710, 486), Vector2(220, 340)]:
        parts.append(_icon(Icons.SHEEP, sheep, 1.6))

    # NOTE (mristin):
    # The path from the aul past the spots of the levels.
    var points: Array[Vector2] = [AUL]
    for i in range(clampi(levels, 0, SPOTS.size())):
        points.append(SPOTS[i])
    var path := _smooth(points)
    parts.append(
        (
            (
                '<path d="%s" stroke="{grass_light}" stroke-width="7" fill="none" '
                + 'stroke-linecap="round"/>'
            )
            % path
        )
    )
    parts.append(
        (
            '<path d="%s" stroke="{ochre}" stroke-width="1.6" fill="none" stroke-dasharray="6 5"/>'
            % path
        )
    )

    # NOTE (mristin):
    # The home aul: the yurts around the pen.
    parts.append(
        (
            (
                '<rect x="%s" y="%s" width="44" height="26" rx="3" fill="none" stroke="{bay}" '
                + 'stroke-width="2" stroke-dasharray="4 2"/>'
            )
            % [_n(AUL.x - 22), _n(AUL.y - 10)]
        )
    )
    for yurt in [Vector2(-56, -6), Vector2(48, -10), Vector2(-20, 34), Vector2(30, 34)]:
        parts.append(_icon(Icons.YURT, AUL + yurt, 3.0))

    # NOTE (mristin):
    # The felt carpet around the map, with its band and the ram's horns.
    parts.append(
        (
            '<rect x="4" y="4" width="952" height="532" rx="4" fill="none" stroke="{crimson}" '
            + 'stroke-width="8"/>'
        )
    )
    parts.append(
        (
            '<rect x="12" y="12" width="936" height="516" rx="2" fill="none" stroke="{gold}" '
            + 'stroke-width="1.2"/>'
        )
    )
    for corner in [[28, 28, -45], [932, 28, 45], [932, 512, 135], [28, 512, -135]]:
        parts.append(
            (
                '<g transform="translate(%d %d) rotate(%d)">%s</g>'
                % [
                    corner[0],
                    corner[1],
                    corner[2],
                    SideView.ornament(Vector2.ZERO, 7.0, "{crimson}")
                ]
            )
        )
    return "".join(parts)


## The smooth curve through the points (a Catmull-Rom spline), as the data of
## an SVG path.
static func _smooth(points: Array[Vector2]) -> String:
    var data := "M%s %s" % [_n(points[0].x), _n(points[0].y)]
    for i in range(points.size() - 1):
        var before := points[maxi(i - 1, 0)]
        var after := points[mini(i + 2, points.size() - 1)]
        var first := points[i] + (points[i + 1] - before) / 6.0
        var second := points[i + 1] - (after - points[i]) / 6.0
        data += (
            " C%s %s %s %s %s %s"
            % [
                _n(first.x),
                _n(first.y),
                _n(second.x),
                _n(second.y),
                _n(points[i + 1].x),
                _n(points[i + 1].y)
            ]
        )
    return data


## The icon centered at the point, at the scale.
static func _icon(picture: String, center: Vector2, scale: float) -> String:
    var at := center - Icons.SIZE * scale * 0.5
    return (
        '<g transform="translate(%s %s) scale(%s)">%s</g>'
        % [_n(at.x), _n(at.y), _n(scale), picture]
    )


static func _n(value: float) -> String:
    return String.num(value, 2)
