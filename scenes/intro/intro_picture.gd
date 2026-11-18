class_name IntroPicture
extends RefCounted

## Paint the picture of the intro screen as vectors (SVG), pixelated by
## [Pixelate]: the steppe near Astana under a wide sky with the sun, the
## clouds and an eagle; the city far on the horizon with the Bayterek tower,
## the Khan Shatyr tent and the blue domes of the mosque; the hazy hills, a
## birch grove, the yurts of the aul with their smoke, the sheep, the feather
## grass and the tulips. The rider and her horse stand in front, drawn in her
## looks by [SideView] (see [method rider]); the title and the buttons are
## written by the game, so that they can be translated (see section 6 of
## DESIGN.md). The creator of the rider stands her in the same steppe.

const SIZE := Vector2(960, 540)

## The horizon, in logical pixels from the top.
const HORIZON := 318.0

## Where the hooves of the horse stand, and how big the rider is drawn.
const RIDER_GROUND := Vector2(240, 512)
const RIDER_SCALE := 8.0

## The painting of the steppe at sunset behind the menus (the language, the
## creator, the settings, the request for room, the reward and the
## instruction), 1920 x 1080, shown at the logical size of the screen.
const PAINTING := "res://assets/pictures/instruction/background.png"

static var _painting: ImageTexture = null


## The painting behind the menus, one pixel of it on each pixel of the screen.
static func background() -> ImageTexture:
    if _painting == null:
        var painted: Texture2D = load(PAINTING)
        _painting = ImageTexture.create_from_image(painted.get_image())
        _painting.set_size_override(Vector2i(SIZE))
    return _painting


## The steppe painted as vectors and pixelated, as it was behind the menus.
static func pixelated() -> ImageTexture:
    return Pixelate.texture(svg(), Rect2(Vector2.ZERO, SIZE), false, 2)


## The rider on her horse in the looks, and where to draw her.
static func rider(looks: Dictionary) -> Array:
    var texture := SideView.texture(looks, 0, 0, true, RIDER_SCALE)
    return [texture, SideView.top_left(RIDER_GROUND, true, RIDER_SCALE)]


## The picture as SVG.
static func svg() -> String:
    var rng := RandomNumberGenerator.new()
    rng.seed = 2026
    var parts := PackedStringArray()
    parts.append(_sky())
    parts.append(_city(Vector2(560, HORIZON)))
    parts.append(_land(rng))
    parts.append(_grove(Vector2(60, HORIZON + 4), rng))
    parts.append(_yurt(Vector2(640, 350), 0.8, rng))
    parts.append(_yurt(Vector2(735, 362), 1.05, rng))
    parts.append(_yurt(Vector2(850, 376), 1.3, rng))
    for sheep in [[540, 404, 1.6], [578, 416, 1.8], [500, 426, 2.0], [610, 434, 1.7]]:
        parts.append(_sheep(Vector2(sheep[0], sheep[1]), sheep[2]))
    parts.append(_foreground(rng))
    return "".join(parts)


## The sky: deep blue above, lighter towards the horizon with a painted, wavy
## edge, streaks of haze at the horizon, the sun with its halo, the clouds
## with their shaded bellies, and an eagle (бүркіт) circling.
static func _sky() -> String:
    var parts := PackedStringArray()
    parts.append('<rect width="960" height="%d" fill="{sky_light}"/>' % int(HORIZON + 2))
    parts.append(
        (
            '<path d="M0 0 L960 0 L960 120 C840 150 760 104 640 132 C520 160 440 112 320 140 '
            + 'C200 168 120 118 0 146 Z" fill="{sky}"/>'
        )
    )
    for streak in [[150, 304, 70], [420, 310, 90], [880, 308, 60]]:
        parts.append(
            (
                '<ellipse cx="%d" cy="%d" rx="%d" ry="1.6" fill="{felt}"/>'
                % [streak[0], streak[1], streak[2]]
            )
        )
    parts.append('<circle cx="860" cy="196" r="40" fill="{felt}"/>')
    parts.append('<circle cx="860" cy="196" r="30" fill="{grass_light}"/>')
    parts.append('<circle cx="860" cy="196" r="24" fill="{gold}"/>')
    parts.append('<circle cx="852" cy="188" r="8" fill="{grass_light}"/>')
    for cloud in [[330, 168, 1.1], [90, 210, 0.8], [700, 116, 0.9], [470, 250, 0.5]]:
        parts.append(_cloud(Vector2(cloud[0], cloud[1]), cloud[2]))
    parts.append(
        (
            '<path d="M420 96 C428 90 436 90 444 96 C452 90 460 90 468 96 C460 94 452 96 446 100 '
            + 'L442 100 C436 96 428 94 420 96 Z" fill="{hoof}"/>'
        )
    )
    parts.append('<path d="M442 100 L444 104 L446 100 Z" fill="{hoof}"/>')
    return "".join(parts)


## A cloud of felt: puffs with their light tops, a shaded belly and a flat
## bottom.
static func _cloud(at: Vector2, scale: float) -> String:
    return (
        """
<g transform="translate(%s %s) scale(%s)">
  <g fill="{felt}">
    <circle cx="-38" cy="0" r="16"/>
    <circle cx="-14" cy="-12" r="22"/>
    <circle cx="16" cy="-18" r="26"/>
    <circle cx="44" cy="-4" r="18"/>
    <rect x="-56" y="-2" width="118" height="12" rx="6"/>
  </g>
  <path d="M-56 6 C-30 12 30 12 62 6 L62 10 C30 16 -30 16 -56 10 Z" fill="{sky_light}"/>
  <g fill="{felt}" stroke="{stone_light}" stroke-width="0.8">
    <path d="M-28 -6 C-24 -14 -12 -16 -6 -12" fill="none"/>
    <path d="M6 -26 C16 -34 30 -30 34 -20" fill="none"/>
  </g>
</g>
"""
        % [_n(at.x), _n(at.y), _n(scale)]
    )


## The city far away on the horizon, in the haze: towers of glass with their
## windows, the Khan Shatyr tent at the left, the white mosque with its blue
## domes and minarets, and the Bayterek tower: a white trunk which opens like
## a tree and holds the golden ball.
static func _city(at: Vector2) -> String:
    var parts := PackedStringArray()
    parts.append(
        (
            (
                '<path d="M300 %s C380 300 460 304 520 306 C620 298 760 296 960 304 '
                + 'L960 %s Z" fill="{sky}"/>'
            )
            % [_n(at.y), _n(at.y)]
        )
    )
    parts.append(
        (
            '<path d="M%s %s C%s %s %s %s %s %s Z" fill="{stone_light}"/>'
            % [
                _n(at.x - 140),
                _n(at.y),
                _n(at.x - 126),
                _n(at.y - 40),
                _n(at.x - 98),
                _n(at.y - 40),
                _n(at.x - 84),
                _n(at.y)
            ]
        )
    )
    (
        parts
        . append(
            (
                '<path d="M%s %s L%s %s M%s %s L%s %s" stroke="{felt}" stroke-width="0.8"/>'
                % [
                    _n(at.x - 120),
                    _n(at.y - 22),
                    _n(at.x - 104),
                    _n(at.y - 22),
                    _n(at.x - 126),
                    _n(at.y - 10),
                    _n(at.x - 98),
                    _n(at.y - 10),
                ]
            )
        )
    )
    var buildings := [
        [-70, 30, 12, 0],
        [-56, 44, 9, 1],
        [-44, 26, 16, 0],
        [-24, 38, 10, 2],
        [44, 54, 12, 1],
        [58, 34, 14, 0],
        [74, 62, 9, 2],
        [86, 40, 14, 0],
        [104, 28, 18, 0],
        [126, 46, 11, 1],
        [140, 32, 16, 0],
        [160, 24, 22, 0],
    ]
    for building in buildings:
        var x: float = at.x + building[0]
        var height: float = building[1]
        var width: float = building[2]
        parts.append(
            (
                '<rect x="%s" y="%s" width="%s" height="%s" fill="{stone_light}"/>'
                % [_n(x), _n(at.y - height), _n(width), _n(height)]
            )
        )
        parts.append(
            (
                '<rect x="%s" y="%s" width="%s" height="%s" fill="{felt}"/>'
                % [_n(x), _n(at.y - height), _n(width * 0.3), _n(height)]
            )
        )
        for floor in range(4, int(height) - 2, 5):
            parts.append(
                (
                    '<rect x="%s" y="%s" width="%s" height="1" fill="{sky_light}"/>'
                    % [_n(x + width * 0.4), _n(at.y - height + floor), _n(width * 0.5)]
                )
            )
        if building[3] == 1:
            parts.append(
                (
                    '<path d="M%s %s L%s %s L%s %s Z" fill="{stone_light}"/>'
                    % [
                        _n(x),
                        _n(at.y - height),
                        _n(x + width * 0.5),
                        _n(at.y - height - 10),
                        _n(x + width),
                        _n(at.y - height)
                    ]
                )
            )
        elif building[3] == 2:
            parts.append(
                (
                    '<path d="M%s %s L%s %s" stroke="{stone_light}" stroke-width="1"/>'
                    % [
                        _n(x + width * 0.5),
                        _n(at.y - height),
                        _n(x + width * 0.5),
                        _n(at.y - height - 12)
                    ]
                )
            )
    # NOTE (mristin):
    # The mosque: a white hall, a blue dome, four minarets.
    var mosque := at + Vector2(196, 0)
    (
        parts
        . append(
            (
                """
<rect x="{x0}" y="{y0}" width="34" height="14" fill="{felt}"/>
<path d="M{x1} {y0} C{x1} {y1} {x2} {y1} {x2} {y0} Z" fill="{sky}"/>
<circle cx="{x3}" cy="{y2}" r="1.2" fill="{gold}"/>
<rect x="{m1}" y="{y3}" width="2.4" height="34" fill="{felt}"/>
<rect x="{m2}" y="{y3}" width="2.4" height="34" fill="{felt}"/>
<path d="M{m1} {y3} L{m1t} {y4} L{m1e} {y3} Z M{m2} {y3} L{m2t} {y4} L{m2e} {y3} Z" fill="{sky}"/>
"""
                . format(
                    {
                        "x0": _n(mosque.x),
                        "y0": _n(mosque.y - 14),
                        "x1": _n(mosque.x + 6),
                        "x2": _n(mosque.x + 28),
                        "y1": _n(mosque.y - 36),
                        "x3": _n(mosque.x + 17),
                        "y2": _n(mosque.y - 31),
                        "m1": _n(mosque.x - 6),
                        "m2": _n(mosque.x + 38),
                        "y3": _n(mosque.y - 34),
                        "y4": _n(mosque.y - 42),
                        "m1t": _n(mosque.x - 4.8),
                        "m1e": _n(mosque.x - 3.6),
                        "m2t": _n(mosque.x + 39.2),
                        "m2e": _n(mosque.x + 40.4),
                    }
                )
            )
        )
    )
    # NOTE (mristin):
    # The Bayterek: the trunk, the branches of the crown and the golden ball.
    var tower := at + Vector2(18, 0)
    (
        parts
        . append(
            (
                """
<path d="M{a} {b} L{c} {d} L{e} {d} L{f} {b} Z" fill="{felt}"/>
<path d="M{g} {d} L{g} {b}" stroke="{stone_light}" stroke-width="0.8"/>
<path d="M{c} {d} C{h} {i} {j} {k} {l} {m} M{e} {d} C{n} {i} {o} {k} {p} {m}
         M{q} {d} C{q} {i} {r} {k} {s} {t} M{u} {d} C{u} {i} {v} {k} {w} {t}"
      stroke="{felt}" stroke-width="1.4" fill="none" stroke-linecap="round"/>
<circle cx="{x}" cy="{y}" r="10" fill="{gold}"/>
<path d="M{x1} {y} C{x1} {y1} {x2} {y1} {x2} {y}" stroke="{grass_light}" stroke-width="1.2"
      fill="none"/>
<circle cx="{x3}" cy="{y3}" r="3" fill="{grass_light}"/>
"""
                . format(
                    {
                        "a": _n(tower.x - 5),
                        "b": _n(tower.y),
                        "c": _n(tower.x - 1.6),
                        "d": _n(tower.y - 70),
                        "e": _n(tower.x + 1.6),
                        "f": _n(tower.x + 5),
                        "g": _n(tower.x + 1),
                        "h": _n(tower.x - 4),
                        "i": _n(tower.y - 78),
                        "j": _n(tower.x - 12),
                        "k": _n(tower.y - 86),
                        "l": _n(tower.x - 11),
                        "m": _n(tower.y - 98),
                        "n": _n(tower.x + 4),
                        "o": _n(tower.x + 12),
                        "p": _n(tower.x + 11),
                        "q": _n(tower.x - 0.6),
                        "r": _n(tower.x - 5),
                        "s": _n(tower.x - 6),
                        "t": _n(tower.y - 92),
                        "u": _n(tower.x + 0.6),
                        "v": _n(tower.x + 5),
                        "w": _n(tower.x + 6),
                        "x": _n(tower.x),
                        "y": _n(tower.y - 92),
                        "x1": _n(tower.x - 10),
                        "x2": _n(tower.x + 10),
                        "y1": _n(tower.y - 86),
                        "x3": _n(tower.x - 3.5),
                        "y3": _n(tower.y - 95.5),
                    }
                )
            )
        )
    )
    return "".join(parts)


## The land: the pale steppe far away, the rolling bands of grass coming
## nearer, darker and richer, and the path winding from the front to the aul.
static func _land(rng: RandomNumberGenerator) -> String:
    var parts := PackedStringArray()
    parts.append(
        (
            '<rect y="%s" width="960" height="%s" fill="{grass_light}"/>'
            % [_n(HORIZON), _n(SIZE.y - HORIZON)]
        )
    )
    parts.append(
        (
            '<path d="M0 %s L960 %s" stroke="{felt}" stroke-width="1"/>'
            % [_n(HORIZON + 0.5), _n(HORIZON + 0.5)]
        )
    )
    parts.append(
        (
            '<path d="M0 352 C200 336 420 348 640 338 C780 332 880 336 960 330 '
            + 'L960 540 L0 540 Z" fill="{grass}"/>'
        )
    )
    for i in range(70):
        var x := rng.randf() * SIZE.x
        var y := rng.randf_range(326.0, 350.0)
        parts.append('<path d="M%s %s l3 0" stroke="{grass}" stroke-width="0.8"/>' % [_n(x), _n(y)])
    parts.append(
        (
            '<path d="M0 418 C180 402 380 420 560 408 C720 398 860 404 960 396 L960 430 '
            + "C820 440 640 432 "
            + '480 444 C320 456 160 438 0 452 Z" fill="{grass_dark}"/>'
        )
    )
    parts.append(
        (
            '<path d="M0 446 C160 434 320 452 480 440 C640 428 820 436 960 426 '
            + 'L960 540 L0 540 Z" fill="{grass}"/>'
        )
    )
    parts.append(
        (
            '<path d="M520 540 C560 500 600 470 640 444 C680 420 700 400 720 384 L736 384 '
            + 'C720 402 702 424 668 448 C628 476 600 506 590 540 Z" fill="{grass_light}"/>'
        )
    )
    parts.append(
        (
            '<path d="M548 540 C584 500 618 472 652 450 C684 428 706 404 726 386" stroke="{ochre}" '
            + 'stroke-width="1.2" fill="none" stroke-dasharray="6 5"/>'
        )
    )
    return "".join(parts)


## A grove of birches (қайың) on the horizon: white trunks with their black
## marks, the crowns in clumps of light and shade.
static func _grove(at: Vector2, rng: RandomNumberGenerator) -> String:
    var parts := PackedStringArray()
    for i in range(12):
        var x := at.x + i * 17.0 + rng.randf_range(-5.0, 5.0)
        var height := rng.randf_range(34.0, 56.0)
        var top := at.y - height
        parts.append(
            (
                '<path d="M%s %s L%s %s" stroke="{felt}" stroke-width="2.6"/>'
                % [_n(x), _n(at.y), _n(x + rng.randf_range(-1.5, 1.5)), _n(top + height * 0.3)]
            )
        )
        for mark in range(3):
            parts.append(
                (
                    '<rect x="%s" y="%s" width="1.6" height="0.9" fill="{outline}"/>'
                    % [_n(x - 1.2 + (mark % 2) * 1.0), _n(at.y - 6.0 - mark * height * 0.18)]
                )
            )
        for clump in range(5):
            var center := Vector2(
                x + rng.randf_range(-height * 0.22, height * 0.22),
                top + height * 0.15 + rng.randf() * height * 0.35
            )
            var r := height * rng.randf_range(0.12, 0.18)
            parts.append(_circle(center, r, "{emerald_light}"))
            parts.append(_circle(center + Vector2(r * 0.35, r * 0.35), r * 0.55, "{emerald}"))
            parts.append(_circle(center - Vector2(r * 0.35, r * 0.4), r * 0.35, "{grass_light}"))
    return "".join(parts)


## A yurt seen from the side: the felt walls on the lattice (кереге), the
## dome over its poles (уық), the crimson band with the ornament, the carved
## door, the crown (шаңырақ) on the top and the smoke curling from it.
static func _yurt(at: Vector2, scale: float, rng: RandomNumberGenerator) -> String:
    var parts := PackedStringArray()
    parts.append('<g transform="translate(%s %s) scale(%s)">' % [_n(at.x), _n(at.y), _n(scale)])
    parts.append('<ellipse cx="0" cy="22" rx="30" ry="3.4" fill="{grass_dark}"/>')
    parts.append('<path d="M-26 22 L-26 6 L26 6 L26 22 Z" fill="{felt}"/>')
    for x in range(-24, 26, 6):
        parts.append(
            '<path d="M%d 9 L%d 21" stroke="{stone_light}" stroke-width="0.5"/>' % [x, x + 3]
        )
    parts.append('<path d="M-28 7 C-22 -12 22 -12 28 7 Z" fill="{felt}"/>')
    for i in range(7):
        var x := -18.0 + i * 6.0
        parts.append(
            (
                (
                    '<path d="M%s -6 C%s -1 %s 3 %s 6" stroke="{stone_light}" '
                    + 'stroke-width="0.6" fill="none"/>'
                )
                % [_n(x * 0.3), _n(x * 0.6), _n(x * 0.9), _n(x * 1.3)]
            )
        )
    parts.append('<path d="M-28 5 L28 5 L28 9 L-28 9 Z" fill="{crimson}"/>')
    for i in range(9):
        parts.append(SideView.ornament(Vector2(-24 + i * 6.0, 7.6), 1.2, "{gold}"))
    parts.append('<path d="M-6 -9 C-4 -11 4 -11 6 -9 L6 -7 L-6 -7 Z" fill="{ochre}"/>')
    parts.append('<rect x="-5" y="10" width="10" height="12" fill="{ochre}"/>')
    parts.append('<rect x="-4" y="11" width="8" height="11" fill="{bay}"/>')
    parts.append('<path d="M0 11 L0 22" stroke="{ochre}" stroke-width="0.6"/>')
    parts.append(SideView.ornament(Vector2(-2, 15), 1.1, "{gold}"))
    parts.append(SideView.ornament(Vector2(2, 15), 1.1, "{gold}"))
    var drift := rng.randf_range(6.0, 12.0)
    var smoke := (
        '<path d="M0 -10 C-4 -16 4 -20 0 -26 C-3 -30 %s -34 %s -40" stroke="{felt}" '
        + 'stroke-width="2.4" fill="none" stroke-linecap="round"/>'
    )
    parts.append(smoke % [_n(drift * 0.5), _n(drift)])
    parts.append("</g>")
    return "".join(parts)


## A sheep grazing: the woolly fleece in puffs of light and shade, the dark
## head and legs.
static func _sheep(at: Vector2, scale: float) -> String:
    return (
        """
<g transform="translate(%s %s) scale(%s)">
  <ellipse cx="6" cy="9" rx="6" ry="1" fill="{grass_dark}"/>
  <g fill="{hoof}">
    <rect x="2.6" y="5.6" width="1.1" height="3.4"/>
    <rect x="7.6" y="5.6" width="1.1" height="3.4"/>
    <rect x="3.8" y="5.6" width="1" height="3"/>
  </g>
  <g fill="{stone_light}">
    <circle cx="3.4" cy="4.8" r="2.3"/>
    <circle cx="7.8" cy="4.8" r="2.2"/>
    <ellipse cx="5.6" cy="5.4" rx="3.8" ry="1.6"/>
  </g>
  <g fill="{felt}">
    <circle cx="3.2" cy="4.2" r="2.1"/>
    <circle cx="5.4" cy="3.2" r="2.4"/>
    <circle cx="7.6" cy="4.1" r="2"/>
  </g>
  <circle cx="4.8" cy="2.6" r="0.8" fill="{felt}" stroke="{stone_light}" stroke-width="0.25"/>
  <ellipse cx="10.2" cy="4.6" rx="1.6" ry="1.2" fill="{hoof}" transform="rotate(25 10.2 4.6)"/>
  <ellipse cx="9.2" cy="3.7" rx="0.9" ry="0.45" fill="{hoof}" transform="rotate(-20 9.2 3.7)"/>
</g>
"""
        % [_n(at.x), _n(at.y), _n(scale)]
    )


## The foreground: the feather grass (қау, ковыль) with its silvery plumes
## bending in the wind, the tulips with their leaves, and a few stones.
static func _foreground(rng: RandomNumberGenerator) -> String:
    var parts := PackedStringArray()
    for i in range(6):
        var at := Vector2(rng.randf_range(20.0, 940.0), rng.randf_range(470.0, 530.0))
        var r := rng.randf_range(4.0, 8.0)
        parts.append(
            (
                '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="{stone}"/>'
                % [_n(at.x), _n(at.y), _n(r), _n(r * 0.6)]
            )
        )
        parts.append(
            (
                '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="{stone_light}"/>'
                % [_n(at.x - r * 0.25), _n(at.y - r * 0.2), _n(r * 0.5), _n(r * 0.3)]
            )
        )
    for i in range(130):
        var x := rng.randf() * SIZE.x
        var depth := pow(rng.randf(), 0.6)
        var y := lerpf(392.0, SIZE.y + 4.0, depth)
        var height := lerpf(5.0, 26.0, depth)
        var lean := height * rng.randf_range(0.25, 0.5)
        var stem := "{grass_dark}" if rng.randf() < 0.4 else "{ochre}"
        parts.append(
            (
                '<path d="M%s %s Q%s %s %s %s" stroke="%s" stroke-width="%s" fill="none"/>'
                % [
                    _n(x),
                    _n(y),
                    _n(x + lean * 0.2),
                    _n(y - height * 0.6),
                    _n(x + lean),
                    _n(y - height),
                    stem,
                    _n(maxf(0.5, height / 22.0))
                ]
            )
        )
        if depth > 0.35:
            var tip := Vector2(x + lean, y - height)
            (
                parts
                . append(
                    (
                        (
                            '<path d="M%s %s Q%s %s %s %s" stroke="{felt}" stroke-width="%s" '
                            + 'fill="none" stroke-linecap="round"/>'
                        )
                        % [
                            _n(tip.x),
                            _n(tip.y),
                            _n(tip.x + height * 0.35),
                            _n(tip.y - height * 0.1),
                            _n(tip.x + height * 0.6),
                            _n(tip.y + height * 0.12),
                            _n(maxf(0.7, height / 13.0)),
                        ]
                    )
                )
            )
    for i in range(26):
        var at := Vector2(rng.randf() * SIZE.x, rng.randf_range(440.0, 536.0))
        var s := lerpf(0.7, 1.6, (at.y - 440.0) / 96.0)
        (
            parts
            . append(
                (
                    """
<g transform="translate(%s %s) scale(%s)">
  <path d="M0 0 L0 -8" stroke="{emerald}" stroke-width="0.8"/>
  <path d="M0 -1 C-3 -3 -3 -6 -2 -8 C-1 -6 -0.4 -4 0 -2 Z" fill="{emerald_light}"/>
  <path d="M0 -2 C2.6 -3 3 -5 2.4 -7 C1.4 -5 0.6 -4 0 -3 Z" fill="{emerald}"/>
  <path d="M-2.2 -8 L-2.4 -12 L-1 -10.4 L0 -12.6 L1 -10.4 L2.4 -12 L2.2 -8
           C1.4 -7 -1.4 -7 -2.2 -8 Z"
        fill="{crimson}"/>
  <path d="M-1.2 -8.4 L-1.4 -11" stroke="{crimson_light}" stroke-width="0.6"/>
</g>
"""
                    % [_n(at.x), _n(at.y), _n(s)]
                )
            )
        )
    return "".join(parts)


static func _circle(at: Vector2, r: float, color: String) -> String:
    return '<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % [_n(at.x), _n(at.y), _n(r), color]


static func _n(value: float) -> String:
    return String.num(value, 2)


## The pictures for dev/pictures/contact_sheet.gd: the picture, a third big.
static func contact_sheet() -> Array:
    var image := pixelated().get_image()
    image.resize(image.get_width() / 3, image.get_height() / 3, Image.INTERPOLATE_NEAREST)
    return [ImageTexture.create_from_image(image)]
