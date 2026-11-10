class_name FrontView
extends RefCounted

## Draw the rider seen from the front, in the [Looks] which the player chose:
## her hat, her hair and her finery for the face overlay over the camera
## picture (see section 6 of DESIGN.md), and her whole figure, standing,
## squatting and reaching across, for the instruction (see [Instruction]).
##
## The pictures are vectors (SVG), pixelated by [Pixelate] at the size they
## are shown, so a head close to the camera gets more pixels, not bigger ones.
##
## The overlay is drawn in eye distances: the origin is the middle between the
## eyes, x goes to the right of the picture and y down, so it follows the
## [code]FaceAnchor[/code] of the vision whatever the size of the face. The
## face itself is left free: the hair frames it, the braids hang beside it,
## and the earrings (сырға) hang from the ears, as on the rider of [SideView].

## The box of a hat at the scale 1; its bottom edge is the band on the
## forehead.
const HAT_BOX := Vector2(16, 8)

const _HATS := {
    "takiya":
    """
<path d="M1 8 C1 1 15 1 15 8 Z" fill="{crimson}"/>
<rect x="0.4" y="6.2" width="15.2" height="1.8" fill="{gold}"/>
<g fill="{gold}">
  <path d="M8 1.8 L9.4 3.6 L8 5.4 L6.6 3.6 Z"/>
  <path d="M3.6 3.8 L4.6 5 L3.6 6 L2.8 5 Z"/>
  <path d="M12.4 3.8 L13.2 5 L12.4 6 L11.4 5 Z"/>
</g>
<circle cx="8" cy="3.6" r="0.6" fill="{crimson_dark}"/>
""",
    "borik":
    """
<path d="M2.4 6 C2.4 0.4 13.6 0.4 13.6 6 Z" fill="{crimson}"/>
<rect x="0.2" y="5" width="15.6" height="3" rx="1.4" fill="{hoof}"/>
<path d="M1.6 5.6 L2.4 6.4 M5 5.4 L5.6 6.6 M9 5.4 L9.6 6.6 M12.6 5.6 L13.4 6.4"
      stroke="{bay}" stroke-width="0.6"/>
<circle cx="8" cy="1.6" r="1" fill="{gold}"/>
""",
    "scarf":
    """
<path d="M0.2 8 C0.2 0.6 15.8 0.6 15.8 8 Z" fill="{crimson}"/>
<rect x="0.2" y="6.8" width="15.6" height="1.2" fill="{crimson_dark}"/>
<g fill="{gold}">
  <circle cx="4" cy="4" r="0.7"/>
  <circle cx="8" cy="2.6" r="0.7"/>
  <circle cx="12" cy="4" r="0.7"/>
  <circle cx="6" cy="5.6" r="0.7"/>
  <circle cx="10" cy="5.6" r="0.7"/>
</g>
""",
    "felt_hat":
    """
<path d="M3 7 L5.6 0.4 L10.4 0.4 L13 7 Z" fill="{felt}"/>
<path d="M0.4 8 L2 5.6 L14 5.6 L15.6 8 Z" fill="{night}"/>
<path d="M5.6 3 L10.4 3" stroke="{stone_light}" stroke-width="0.5"/>
""",
}

## The hat of the overlay is this many eye distances wide...
const HAT_WIDTH := 2.9

## ... and its band sits this many eye distances above the eyes.
const HAT_BAND := 0.75

## The box of the overlay, in eye distances around the middle between the
## eyes: the hat above, the braids and the loose hair down to the shoulders.
const OVERLAY_BOX := Rect2(-2.2, -3.4, 4.4, 7.6)

## The box of the whole figure, in the same units: the head as in the
## overlay, the feet on the line y = 15.2.
const FIGURE_BOX := Rect2(-4, -3.4, 8, 19.4)

## The line on which the figure stands, in eye distances.
const FEET := 15.2

## The owl feathers (үкі) on the hat, for good luck, in the box of the hat,
## standing up from its top, once the rider won them (see [Finery]).
const _OWL_FEATHERS := """
<path d="M7.7 2.9 C6.1 0.6 6.3 -2 7.3 -3.4 C7.9 -1.8 8.3 0.6 8.1 2.8 Z" fill="{felt}"/>
<path d="M8.2 2.8 C8.7 0.2 10.1 -1.2 11.4 -1.4 C10.8 0.4 9.6 2 8.5 3 Z" fill="{felt}"/>
<path d="M7.4 -2.2 C7.6 -0.6 7.9 1 7.9 2.6 M10.6 -0.8 C9.6 0.4 9 1.6 8.4 2.8" stroke="{stone}"
      stroke-width="0.35" fill="none"/>
<circle cx="8" cy="3" r="0.8" fill="{gold}"/>
"""

## The hair on the head, from the crown down to the ears, around the face,
## with a parting and the shine; without a hat.
const _HAIR_CAP := """
<path d="M-1.28 0.5 C-1.55 -1.5 -0.85 -2.45 0 -2.45 C0.85 -2.45 1.55 -1.5 1.28 0.5 L0.98 0.4
         C1.02 -0.3 0.96 -0.7 0.82 -0.98 C0.5 -1.16 0.2 -1.2 0 -1.32
         C-0.2 -1.2 -0.5 -1.16 -0.82 -0.98
         C-0.96 -0.7 -1.02 -0.3 -0.98 0.4 Z" fill="{h1}"/>
<path d="M-0.75 -1.95 C-0.35 -2.2 0.35 -2.2 0.75 -1.95" stroke="{h2}" stroke-width="0.12"
      fill="none" stroke-linecap="round"/>
<path d="M0 -1.32 L0.06 -2.35" stroke="{h0}" stroke-width="0.08"/>
"""

## The hair at the temples below a hat.
const _HAIR_LOCKS := """
<path d="M-1.28 0.5 C-1.36 -0.1 -1.36 -0.5 -1.3 -0.9 L-0.84 -0.9 C-0.98 -0.5 -1.02 0 -0.98 0.4 Z
         M1.28 0.5 C1.36 -0.1 1.36 -0.5 1.3 -0.9 L0.84 -0.9 C0.98 -0.5 1.02 0 0.98 0.4 Z"
      fill="{h1}"/>
"""

## The loose hair, down beside the face to the shoulders.
const _HAIR_LOOSE := """
<path d="M-0.98 0.2 C-1 1.2 -1.05 2.4 -1.3 3.4 L-2 3.2 C-1.75 2 -1.6 0.4 -1.32 -0.9 Z
         M0.98 0.2 C1 1.2 1.05 2.4 1.3 3.4 L2 3.2 C1.75 2 1.6 0.4 1.32 -0.9 Z" fill="{h1}"/>
<path d="M-1.35 0 C-1.4 1.2 -1.5 2.2 -1.62 3.2 M1.35 0 C1.4 1.2 1.5 2.2 1.62 3.2" stroke="{h0}"
      stroke-width="0.1" fill="none" stroke-linecap="round"/>
"""

## The bun on the top of the head, with its golden pin; without a hat.
const _HAIR_BUN := """
<circle cx="0" cy="-2.6" r="0.62" fill="{h1}"/>
<path d="M-0.4 -2.8 C-0.15 -3.05 0.15 -3.05 0.4 -2.8" stroke="{h2}" stroke-width="0.1"
      fill="none"/>
<path d="M-0.75 -2.35 L0.75 -2.9" stroke="{gold}" stroke-width="0.12" stroke-linecap="round"/>
"""

## The earrings (сырға): a silver ring with a crimson drop on each ear.
const _EARRINGS := """
<g fill="{stone_light}">
  <circle cx="-1.04" cy="0.95" r="0.14"/><circle cx="1.04" cy="0.95" r="0.14"/>
</g>
<g fill="{crimson}">
  <ellipse cx="-1.04" cy="1.22" rx="0.1" ry="0.15"/>
  <ellipse cx="1.04" cy="1.22" rx="0.1" ry="0.15"/>
</g>
"""

## The face of the figure: the oval, the eyes with their shine, the brows, the
## nose, the blush and the smile.
const _FACE := """
<rect x="-0.36" y="1.4" width="0.72" height="1.1" fill="{s0}"/>
<ellipse cx="0" cy="0.2" rx="1.02" ry="1.5" fill="{s1}"/>
<g fill="{outline}">
  <ellipse cx="-0.45" cy="0" rx="0.17" ry="0.13"/><ellipse cx="0.45" cy="0" rx="0.17" ry="0.13"/>
</g>
<g fill="{felt}"><circle cx="-0.4" cy="-0.04" r="0.05"/><circle cx="0.5" cy="-0.04" r="0.05"/></g>
<path d="M-0.65 -0.36 C-0.5 -0.46 -0.3 -0.46 -0.2 -0.38
         M0.2 -0.38 C0.3 -0.46 0.5 -0.46 0.65 -0.36"
      stroke="{hoof}" stroke-width="0.08" fill="none" stroke-linecap="round"/>
<path d="M0 0.2 L-0.08 0.55 L0.06 0.58" stroke="{s0}" stroke-width="0.07" fill="none"/>
<g fill="{crimson_light}">
  <ellipse cx="-0.62" cy="0.55" rx="0.2" ry="0.11"/>
  <ellipse cx="0.62" cy="0.55" rx="0.2" ry="0.11"/>
</g>
<path d="M-0.25 0.95 C-0.1 1.08 0.1 1.08 0.25 0.95" stroke="{crimson}" stroke-width="0.1"
      fill="none" stroke-linecap="round"/>
"""

## The painted overlays are this many pixels per eye distance.
const PAINTED_UNIT := 100

## The painted overlays, by the rider and her finery.
static var _painted: Dictionary = {}

## The textures of [method figure], by the looks and the pose.
static var _figures: Dictionary = {}


## The hat of the looks, [param width] logical pixels wide; null without a hat.
static func hat(looks: Dictionary, width: float) -> ImageTexture:
    var picture: String = _HATS.get(looks.get("hat", "takiya"), "")
    if picture == "":
        return null
    var scale := width / HAT_BOX.x
    var body := '<g transform="scale(%s)">%s</g>' % [String.num(scale, 3), picture]
    return Pixelate.texture(body, Rect2(Vector2.ZERO, HAT_BOX * scale))


## All the hats by their names, for the tests.
static func all() -> Dictionary:
    return _HATS.duplicate()


## The hair, the hat and the finery over a face as SVG, in eye distances
## around the middle between the eyes (see [constant OVERLAY_BOX]).
static func overlay_svg(looks: Dictionary) -> String:
    var completed := Looks.complete(looks)
    var hair := _hex(Looks.shades(completed, "hair_color"))
    var hat: String = completed["hat"]
    var parts := PackedStringArray()
    match completed["hair"]:
        "two_braids":
            parts.append(_braid(Vector2(-1.12, 0.3), Vector2(-1.32, 3.3)))
            parts.append(_braid(Vector2(1.12, 0.3), Vector2(1.32, 3.3)))
        "one_braid":
            parts.append(_braid(Vector2(1.12, 0.3), Vector2(1.5, 3.5)))
        "loose":
            parts.append(_HAIR_LOOSE)
    if hat == "none":
        if completed["hair"] == "bun":
            parts.append(_HAIR_BUN)
        parts.append(_HAIR_CAP)
    elif hat != "scarf":
        parts.append(_HAIR_LOCKS)

    var picture: String = _HATS.get(hat, "")
    var scale := HAT_WIDTH / HAT_BOX.x
    if Finery.step(completed, "feathers") >= 1:
        # NOTE (mristin):
        # The feathers stand on the top of the hat, or of the head.
        var top: float = {"borik": -0.4, "felt_hat": -0.47, "scarf": -0.1, "none": -0.8}.get(
            hat, 0.0
        )
        picture = (
            '<g transform="translate(0 %s)">%s</g>' % [_n(top / scale), _OWL_FEATHERS] + picture
        )
    if picture != "":
        parts.append(
            (
                '<g transform="translate(%s %s) scale(%s)">%s</g>'
                % [_n(-HAT_WIDTH * 0.5), _n(-HAT_BAND - HAT_BOX.y * scale), _n(scale), picture]
            )
        )
    if Finery.step(completed, "earrings") >= 1:
        parts.append(_EARRINGS)
    return "".join(parts).format({"h0": hair[0], "h1": hair[1], "h2": hair[2]})


## The painted overlay of the rider of the looks (see [constant Looks.PRESETS]):
## her hair and hat (assets/pictures/overlay/), with the earrings on both
## ears and the owl feathers on the top of her hat once she won them (see
## [Finery]), at [constant PAINTED_UNIT] pixels per eye distance over the
## [constant OVERLAY_BOX]; null if the rider has no painted overlay.
static func painted_overlay(looks: Dictionary) -> ImageTexture:
    var preset: String = looks.get("rider", "")
    var path := "res://assets/pictures/overlay/%s.png" % preset
    if preset == "" or not ResourceLoader.exists(path):
        return null
    var earrings := Finery.step(looks, "earrings") >= 1
    var feathers := Finery.step(looks, "feathers") >= 1
    var key := "%s|%s|%s" % [preset, earrings, feathers]
    if _painted.has(key):
        return _painted[key]

    var image := (load(path) as Texture2D).get_image()
    image.convert(Image.FORMAT_RGBA8)
    var at := func(x: float, y: float) -> Vector2i:
        return Vector2i(
            roundi((x - OVERLAY_BOX.position.x) * PAINTED_UNIT),
            roundi((y - OVERLAY_BOX.position.y) * PAINTED_UNIT)
        )
    if feathers:
        # NOTE (mristin):
        # The feathers stand on the top of the hat (or of the hair), in the
        # middle, where the painting starts from above.
        var top := image.get_height()
        for y in range(image.get_height()):
            if image.get_pixel(image.get_width() / 2, y).a > 0.5:
                top = y
                break
        var feather := _sized("feathers", 1.3)
        var foot := Vector2i(image.get_width() / 2, top + roundi(0.12 * PAINTED_UNIT))
        image.blend_rect(
            feather,
            Rect2i(Vector2i.ZERO, feather.get_size()),
            foot - Vector2i(feather.get_width() / 2, feather.get_height())
        )
    if earrings:
        var earring := _sized("earring", 0.85)
        for side in [-1.0, 1.0]:
            var piece := earring.duplicate() as Image
            if side < 0.0:
                piece.flip_x()
            var hook: Vector2i = at.call(side * 1.04, 0.5)
            image.blend_rect(
                piece,
                Rect2i(Vector2i.ZERO, piece.get_size()),
                hook - Vector2i(piece.get_width() / 2, 0)
            )
    var result := ImageTexture.create_from_image(image)
    _painted[key] = result
    return result


## The painting of the overlay of the name, [param height] eye distances high.
static func _sized(name: String, height: float) -> Image:
    var image := (load("res://assets/pictures/overlay/%s.png" % name) as Texture2D).get_image()
    image.convert(Image.FORMAT_RGBA8)
    var high := roundi(height * PAINTED_UNIT)
    var wide := maxi(1, roundi(image.get_width() * float(high) / image.get_height()))
    image.resize(wide, high, Image.INTERPOLATE_LANCZOS)
    return image


## The overlay of the looks over a face whose eyes are [param eyes] logical
## pixels apart, pixelated; draw it with its [constant OVERLAY_BOX] times
## [param eyes] around the middle between the eyes.
static func overlay(looks: Dictionary, eyes: float) -> ImageTexture:
    var body := '<g transform="scale(%s)">%s</g>' % [_n(eyes), overlay_svg(looks)]
    return Pixelate.texture(body, Rect2(OVERLAY_BOX.position * eyes, OVERLAY_BOX.size * eyes))


## The whole rider seen from the front, standing with her feet apart, as the
## player stands in front of the camera, and shown as in a mirror, like the
## camera picture.
##
## [param squat] in [0, 1] goes from standing to the deep squat, with the back
## straight, the knees over the toes and the arms forward. [param reach] in
## [-1, 1] pulls the reins: both hands go to the side, at the height of her
## chest, to the left of the picture for a positive reach (her right hand, on
## the right of the picture as in a mirror, crosses the axis of her head, and
## the horse turns left), to the right for a negative one. The figure is
## [param eyes] logical pixels per eye distance; its feet stand at the bottom
## of the texture (see [constant FIGURE_BOX]).
static func figure(looks: Dictionary, squat: float, reach: float, eyes: float) -> ImageTexture:
    # NOTE (mristin):
    # The figure moves every frame (e.g., the small figure in the level), so
    # we keep its textures by the pose, without writing its SVG again.
    var key := "%d|%s|%s|%s" % [hash(looks), _n(squat), _n(reach), _n(eyes)]
    if not _figures.has(key):
        var body := '<g transform="scale(%s)">%s</g>' % [_n(eyes), figure_svg(looks, squat, reach)]
        _figures[key] = Pixelate.texture(
            body, Rect2(FIGURE_BOX.position * eyes, FIGURE_BOX.size * eyes)
        )
    return _figures[key]


## The figure of [method figure] as SVG, in eye distances.
static func figure_svg(looks: Dictionary, squat: float, reach: float) -> String:
    var completed := Looks.complete(looks)
    var skin := _hex(Looks.shades(completed, "skin"))
    var coat := _hex(Looks.shades(completed, "coat"))
    var dress := _hex(Looks.shades(completed, "dress"))
    var colors := {
        "s0": skin[0],
        "s1": skin[1],
        "s2": skin[2],
        "k0": coat[0],
        "k1": coat[1],
        "k2": coat[2],
        "d0": dress[0],
        "d1": dress[1],
        "d2": dress[2],
        "trim": SideView.trim_color(completed, coat[0]),
        "belt": "{gold}" if Finery.step(completed, "belt") >= 1 else "{bay}",
    }
    var s := clampf(squat, 0.0, 1.0)
    var r := clampf(reach, -1.0, 1.0)
    var drop := s * 3.6
    var parts := PackedStringArray()

    # NOTE (mristin):
    # The legs: the thighs go out over the toes as she squats, the shins in the
    # embroidered boots stay over the feet.
    for side in [-1.0, 1.0]:
        var hip := Vector2(side * 0.8, 8.0 + drop)
        var knee := Vector2(side * (1.35 + s * 1.3), 11.6 + s * 0.6)
        var ankle := Vector2(side * 1.5, 14.4)
        parts.append(_line([hip, knee], "{d0}", 1.0))
        parts.append(_line([knee, ankle], "{hoof}", 1.0))
        if Finery.step(completed, "boots") >= 1:
            parts.append(
                _line([knee + Vector2(-0.45, 0.55), knee + Vector2(0.45, 0.55)], "{crimson}", 0.4)
            )
            parts.append(
                _line([knee + Vector2(-0.4, 0.55), knee + Vector2(0.4, 0.55)], "{gold}", 0.12)
            )
        parts.append(
            (
                '<ellipse cx="%s" cy="14.9" rx="0.8" ry="0.42" fill="{hoof}"/>'
                % _n(ankle.x + side * 0.25)
            )
        )

    # NOTE (mristin):
    # The dress below the coat, which spreads over the knees as she squats.
    var hem := 11.0 + drop * 0.55
    var spread := 2.0 + s * 1.2
    (
        parts
        . append(
            _polygon(
                [
                    Vector2(-1.5, 6 + drop),
                    Vector2(1.5, 6 + drop),
                    Vector2(spread, hem),
                    Vector2(-spread, hem),
                ],
                "{d1}"
            )
        )
    )
    parts.append(_line([Vector2(-spread, hem - 0.2), Vector2(spread, hem - 0.2)], "{d0}", 0.3))

    # NOTE (mristin):
    # The coat (шапан), open in front over the dress, with its trims, the belt
    # with the silver plates and the ram's horn on the chest.
    var top := 2.5 + drop
    var bottom := 9.4 + drop
    (
        parts
        . append(
            _polygon(
                [
                    Vector2(-1.75, top),
                    Vector2(1.75, top),
                    Vector2(2.35, bottom),
                    Vector2(-2.35, bottom),
                ],
                "{k1}"
            )
        )
    )
    (
        parts
        . append(
            _polygon(
                [
                    Vector2(-1.75, top),
                    Vector2(-1.1, top),
                    Vector2(-1.5, bottom),
                    Vector2(-2.35, bottom),
                ],
                "{k0}"
            )
        )
    )
    (
        parts
        . append(
            _polygon(
                [
                    Vector2(-0.35, top),
                    Vector2(0.35, top),
                    Vector2(0.7, bottom),
                    Vector2(-0.7, bottom),
                ],
                "{d1}"
            )
        )
    )
    parts.append(_line([Vector2(-0.4, top), Vector2(-0.75, bottom)], "{trim}", 0.2))
    parts.append(_line([Vector2(0.4, top), Vector2(0.75, bottom)], "{trim}", 0.2))
    parts.append(_line([Vector2(-2.35, bottom), Vector2(2.35, bottom)], "{trim}", 0.25))
    parts.append('<rect x="-1.75" y="%s" width="3.5" height="0.5" fill="{belt}"/>' % _n(6.0 + drop))
    if Finery.step(completed, "belt") >= 1:
        for x in [-1.2, -0.3, 0.6]:
            parts.append(
                (
                    '<rect x="%s" y="%s" width="0.4" height="0.3" fill="{stone_light}"/>'
                    % [_n(x), _n(6.1 + drop)]
                )
            )
    if Finery.step(completed, "coat") >= 2:
        parts.append(SideView.ornament(Vector2(-1.0, 4.2 + drop), 0.5, "{trim}"))
        parts.append(SideView.ornament(Vector2(1.0, 4.2 + drop), 0.5, "{trim}"))

    # NOTE (mristin):
    # The arms: down at her sides, forward as she squats, and both to the side
    # as she pulls the reins, which run between her hands.
    var bracelets := Finery.step(completed, "bracelets") >= 1
    parts.append(_arm(-1.0, s, r, drop, bracelets))
    parts.append(_arm(1.0, s, r, drop, bracelets))
    if absf(r) > 0.0:
        var left_hand := _hand(-1.0, s, r, drop)
        var right_hand := _hand(1.0, s, r, drop)
        var sag := (left_hand + right_hand) * 0.5 + Vector2(0, 0.6)
        parts.append(_line([left_hand, sag, right_hand], "{crimson_dark}", 0.2))

    parts.append('<g transform="translate(0 %s)">%s%s</g>' % [_n(drop), _FACE, overlay_svg(looks)])
    return "".join(parts).format(colors)


## Where the hand on the [param side] is, squatting and pulling the reins.
static func _hand(side: float, squat: float, reach: float, drop: float) -> Vector2:
    var hand := Vector2(side * 2.4, 7.3).lerp(Vector2(side * 1.2, 4.7), squat)
    var pull := Vector2(-signf(reach) * 3.3 + side * 0.65, 4.2)
    hand = hand.lerp(pull, absf(reach))
    return hand + Vector2(0, drop)


## An arm in its sleeve with the cuff and the hand, on the [param side] (-1
## the left of the picture, 1 the right), squatting and pulling the reins.
static func _arm(side: float, squat: float, reach: float, drop: float, bracelet: bool) -> String:
    var shoulder := Vector2(side * 1.7, 2.9 + drop)
    var hand := _hand(side, squat, reach, drop)
    var elbow := Vector2(side * 2.3, 5.2).lerp(Vector2(side * 1.9, 4.3), squat)
    var bent := (shoulder - Vector2(0, drop)).lerp(hand - Vector2(0, drop), 0.5) + Vector2(0, 0.8)
    elbow = elbow.lerp(bent, absf(reach))
    elbow.y += drop
    var cuff := elbow.lerp(hand, 0.78)
    var result := (
        _line([shoulder, elbow, cuff], "{k1}", 0.85)
        + _line([cuff, elbow.lerp(hand, 0.84)], "{trim}", 0.85)
        + '<circle cx="%s" cy="%s" r="0.42" fill="{s1}"/>' % [_n(hand.x), _n(hand.y)]
    )
    if bracelet:
        result += _line([elbow.lerp(hand, 0.86), elbow.lerp(hand, 0.9)], "{stone_light}", 0.7)
    return result


## The braid from the temple down beside the face, plaited in locks, with the
## tassel (шашбау) of golden beads and a crimson tuft at its end.
static func _braid(from: Vector2, to: Vector2) -> String:
    var parts := PackedStringArray()
    var steps := 8
    var angle := _n(rad_to_deg((to - from).angle()) - 90.0)
    for i in range(steps):
        var at := from.lerp(to, (i + 0.5) / steps)
        parts.append(
            (
                (
                    '<ellipse cx="%s" cy="%s" rx="0.24" ry="0.26" fill="%s" '
                    + 'transform="rotate(%s %s %s)"/>'
                )
                % [_n(at.x), _n(at.y), "{h1}" if i % 2 == 0 else "{h0}", angle, _n(at.x), _n(at.y)]
            )
        )
    parts.append('<circle cx="%s" cy="%s" r="0.15" fill="{gold}"/>' % [_n(to.x), _n(to.y + 0.15)])
    parts.append(
        _polygon(
            [to + Vector2(-0.22, 0.3), to + Vector2(0.22, 0.3), to + Vector2(0, 0.85)], "{crimson}"
        )
    )
    return "".join(parts)


static func _line(points: Array, color: String, width: float) -> String:
    var coordinates := PackedStringArray()
    for point in points:
        coordinates.append("%s,%s" % [_n(point.x), _n(point.y)])
    return (
        (
            '<polyline points="%s" stroke="%s" stroke-width="%s" fill="none" '
            + 'stroke-linecap="round" stroke-linejoin="round"/>'
        )
        % [" ".join(coordinates), color, _n(width)]
    )


static func _polygon(points: Array, color: String) -> String:
    var coordinates := PackedStringArray()
    for point in points:
        coordinates.append("%s,%s" % [_n(point.x), _n(point.y)])
    return '<polygon points="%s" fill="%s"/>' % [" ".join(coordinates), color]


static func _hex(colors: Array[Color]) -> Array[String]:
    var result: Array[String] = []
    for value in colors:
        result.append(Pixelate.color(value))
    return result


static func _n(value: float) -> String:
    return String.num(value, 3)
