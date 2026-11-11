class_name PaintedBody
extends RefCounted

## Draw the painted clothes of the rider over the player's body in the camera
## picture: the boots, the coat, the sleeves, the reins and the fists, warped
## onto the joints which the vision follows (see [CameraPanel]).
##
## The paintings are in assets/pictures/body/, cut out of their paintings by
## dev/pictures/cut_body.py, each in the canvas of its template (halved), so
## that its joints lie where the constants below say. Every piece is scaled by
## the width of the player's shoulders, and stretched along her bones.

const DIR := "res://assets/pictures/body/"

## The coat: the shoulders at [constant COAT_SHOULDER_Y], from
## [constant COAT_LEFT] to [constant COAT_RIGHT], the hem at
## [constant COAT_HEM_Y].
const COAT_LEFT := 156.0
const COAT_RIGHT := 356.0
const COAT_SHOULDER_Y := 150.0
const COAT_HEM_Y := 575.0

## The hips lie this share of the way from the shoulders to the hem (the coat
## reaches 0.4 of the torso below the hips).
const COAT_HIPS := 1.0 / 1.4

## The sleeve, along y = [constant SLEEVE_Y]: the shoulder, the elbow and the
## end of the cuff; it is [constant SLEEVE_THICKNESS] thick at the elbow.
const SLEEVE_SHOULDER_X := 100.0
const SLEEVE_ELBOW_X := 350.0
const SLEEVE_END_X := 575.0
const SLEEVE_Y := 256.0
const SLEEVE_THICKNESS := 92.0

## The painted sleeves have a fur cuff at the shoulder, too; they are drawn
## from here on, so that it does not show on the shoulder.
const SLEEVE_TRIM_X := 135.0

## The arm is this share of the shoulders thick.
const SLEEVE_SHARE := 0.28

## The sleeve is drawn this many pixels of its painting above and below its
## middle (the rest is empty; it flares to about 85 at the shoulder), in this
## many pieces along the arm.
const SLEEVE_BAND := 90.0
const SLEEVE_STEPS := 24

## The sleeve fades in over this many pixels of its painting from where it
## starts, so that its start has no edge where the coat does not cover it.
const SLEEVE_FADE := 60.0

## The sleeve starts this share of the way from the shoulder to the neck, so
## that the arm comes out from under the coat.
const SLEEVE_TUCK := 0.12

## The boot, around x = [constant BOOT_X]: the knee and the ankle.
const BOOT_X := 256.0
const BOOT_KNEE_Y := 150.0
const BOOT_ANKLE_Y := 575.0

## The left fist, with the rein through its middle along y.
const FIST_CENTER := Vector2(256, 256)

## The fist is this share of the shoulders wide, over this many pixels of
## its painting; only the fist is drawn, [constant FIST_WIDTH] wide around
## [constant FIST_CENTER], without the stubs of the rein.
const FIST_SHARE := 0.34
const FIST_WIDTH := 180.0

## The rein is this share of the shoulders thick.
const REIN_SHARE := 0.07

## The rein sags this share of the shoulders between slack fists.
const REIN_SAG := 0.3

static var _textures := {}


## The painting of the piece ("coat_1", "fist", ...), or null.
static func texture(piece: String) -> Texture2D:
    if not _textures.has(piece):
        var path := DIR + piece + ".png"
        _textures[piece] = load(path) if ResourceLoader.exists(path) else null
    return _textures[piece]


## Whether the rider of the looks has her painted clothes.
static func has(looks: Dictionary) -> bool:
    var preset: String = looks.get("rider", "")
    return preset != "" and texture("coat_" + preset) != null


## Draw the boots, the coat and the sleeves of the rider of the [param looks]
## on the joints (in the pixels of the [param canvas], null where not seen; in
## the order of [code]Joint[/code], see [CameraPanel]).
static func draw_body(canvas: CanvasItem, joints: Array, looks: Dictionary, alpha: float) -> void:
    var preset: String = looks.get("rider", "")
    var left_shoulder: Variant = joints[CameraPanel.Joint.LEFT_SHOULDER]
    var right_shoulder: Variant = joints[CameraPanel.Joint.RIGHT_SHOULDER]
    if left_shoulder == null or right_shoulder == null:
        return
    var across: Vector2 = (right_shoulder as Vector2) - left_shoulder
    var width := across.length()
    if width < 4.0:
        return
    var scale := width / (COAT_RIGHT - COAT_LEFT)
    var neck: Vector2 = (left_shoulder + right_shoulder) * 0.5
    var down := Vector2(-across.y, across.x).normalized()
    var left_hip: Variant = joints[CameraPanel.Joint.LEFT_HIP]
    var right_hip: Variant = joints[CameraPanel.Joint.RIGHT_HIP]
    var hips: Vector2 = (
        neck + down * width * 1.5
        if left_hip == null or right_hip == null
        else (left_hip + right_hip) * 0.5
    )
    var color := Color(1, 1, 1, alpha)

    var boot := texture("boot_" + preset)
    for leg in [
        [CameraPanel.Joint.LEFT_KNEE, CameraPanel.Joint.LEFT_ANKLE, -1.0],
        [CameraPanel.Joint.RIGHT_KNEE, CameraPanel.Joint.RIGHT_ANKLE, 1.0]
    ]:
        var knee: Variant = joints[leg[0]]
        var ankle: Variant = joints[leg[1]]
        if boot == null or knee == null or ankle == null:
            continue
        var along: Vector2 = ((ankle as Vector2) - knee) / (BOOT_ANKLE_Y - BOOT_KNEE_Y)
        if along.length() < 1e-3:
            continue
        # NOTE (mristin):
        # The x axis is across the leg; the right boot is mirrored, so that
        # both toes turn outwards alike.
        var mirror: float = -float(leg[2])
        var side := Vector2(along.y, -along.x).normalized() * scale * mirror
        _draw(
            canvas,
            boot,
            Transform2D(side, along, knee - side * BOOT_X - along * BOOT_KNEE_Y),
            color
        )

    # NOTE (mristin):
    # Each arm comes out of the armhole: its sleeve starts a little inside the
    # shoulder, and its upper half is drawn under the coat; the lower half is
    # drawn over it, since the forearms hold the reins in front of the body.
    var sleeve := texture("sleeve_" + preset)
    var thickness := width * SLEEVE_SHARE / SLEEVE_THICKNESS
    var strips: Array = []
    for arm in [
        [left_shoulder, CameraPanel.Joint.LEFT_ELBOW, CameraPanel.Joint.LEFT_HAND],
        [right_shoulder, CameraPanel.Joint.RIGHT_ELBOW, CameraPanel.Joint.RIGHT_HAND]
    ]:
        var elbow: Variant = joints[arm[1]]
        if sleeve == null or elbow == null:
            continue
        var start: Vector2 = (arm[0] as Vector2).lerp(neck, SLEEVE_TUCK)
        strips.append(_sleeve_strip(start, elbow, joints[arm[2]]))
    for strip in strips:
        var cut: int = strip[2]
        _draw_strip(
            canvas,
            sleeve,
            (strip[0] as PackedVector2Array).slice(0, cut + 1),
            (strip[1] as PackedFloat32Array).slice(0, cut + 1),
            SLEEVE_Y,
            SLEEVE_BAND,
            thickness,
            color,
            SLEEVE_TRIM_X,
            SLEEVE_FADE
        )

    var coat := texture("coat_" + preset)
    if coat != null:
        var x_axis := across / (COAT_RIGHT - COAT_LEFT)
        var y_axis := (hips - neck) / ((COAT_HEM_Y - COAT_SHOULDER_Y) * COAT_HIPS)
        var origin := neck - x_axis * (COAT_LEFT + COAT_RIGHT) * 0.5 - y_axis * COAT_SHOULDER_Y
        _draw(canvas, coat, Transform2D(x_axis, y_axis, origin), color)

    for strip in strips:
        var cut: int = strip[2]
        _draw_strip(
            canvas,
            sleeve,
            (strip[0] as PackedVector2Array).slice(cut),
            (strip[1] as PackedFloat32Array).slice(cut),
            SLEEVE_Y,
            SLEEVE_BAND,
            thickness,
            color,
            SLEEVE_TRIM_X,
            SLEEVE_FADE
        )


## The sleeve from the shoulder over the elbow to the hand (or only to the
## elbow without the hand) as one strip along a smooth curve, so that it bends
## softly at the elbow instead of breaking there: [points, the columns of the
## painting at them, the index of the point where the upper arm ends].
static func _sleeve_strip(shoulder: Vector2, elbow: Vector2, hand: Variant) -> Array:
    var points := PackedVector2Array()
    var us := PackedFloat32Array()
    if hand == null:
        for i in range(SLEEVE_STEPS + 1):
            var t := float(i) / SLEEVE_STEPS
            points.append(shoulder.lerp(elbow, t))
            us.append(lerpf(SLEEVE_TRIM_X, SLEEVE_ELBOW_X, t))
    else:
        # NOTE (mristin):
        # The quadratic curve from the shoulder to the hand which passes
        # through the elbow halfway; the painting runs along it by the length,
        # with the elbow of the painting at the elbow.
        var end: Vector2 = hand
        var control := elbow * 2.0 - (shoulder + end) * 0.5
        var lengths := PackedFloat32Array([0.0])
        for i in range(SLEEVE_STEPS + 1):
            var t := float(i) / SLEEVE_STEPS
            var point := shoulder.lerp(control, t).lerp(control.lerp(end, t), t)
            if i > 0:
                lengths.append(lengths[i - 1] + point.distance_to(points[i - 1]))
            points.append(point)
        var half := SLEEVE_STEPS / 2
        var to_elbow := maxf(lengths[half], 1e-3)
        var from_elbow := maxf(lengths[SLEEVE_STEPS] - lengths[half], 1e-3)
        for i in range(SLEEVE_STEPS + 1):
            if i <= half:
                us.append(lerpf(SLEEVE_TRIM_X, SLEEVE_ELBOW_X, lengths[i] / to_elbow))
            else:
                us.append(
                    lerpf(SLEEVE_ELBOW_X, SLEEVE_END_X, (lengths[i] - lengths[half]) / from_elbow)
                )
    return [points, us, SLEEVE_STEPS / 2 if hand != null else SLEEVE_STEPS]


## Draw the band of the [param painting] around its row [param middle] (from
## [param band] above to [param band] below it, in its pixels) along the
## [param points], each at the column [param us] of the painting, scaled by
## [param scale] across.
static func _draw_strip(
    canvas: CanvasItem,
    painting: Texture2D,
    points: PackedVector2Array,
    us: PackedFloat32Array,
    middle: float,
    band: float,
    scale: float,
    color: Color,
    fade_from := -INF,
    fade_length := 1.0
) -> void:
    var size := painting.get_size()
    var top := (middle - band) / size.y
    var bottom := (middle + band) / size.y
    var normals := PackedVector2Array()
    for i in range(points.size()):
        var before := points[maxi(0, i - 1)]
        var after := points[mini(points.size() - 1, i + 1)]
        normals.append((after - before).orthogonal().normalized() * band * scale)
    var faded := PackedColorArray()
    for u in us:
        faded.append(Color(color, color.a * clampf((u - fade_from) / fade_length, 0.0, 1.0)))
    for i in range(points.size() - 1):
        var u0 := us[i] / size.x
        var u1 := us[i + 1] / size.x
        var colors := PackedColorArray([faded[i], faded[i + 1], faded[i + 1], faded[i]])
        canvas.draw_primitive(
            PackedVector2Array(
                [
                    points[i] + normals[i],
                    points[i + 1] + normals[i + 1],
                    points[i + 1] - normals[i + 1],
                    points[i] - normals[i]
                ]
            ),
            colors,
            PackedVector2Array(
                [Vector2(u0, top), Vector2(u1, top), Vector2(u1, bottom), Vector2(u0, bottom)]
            ),
            painting
        )


## Draw the rein between the fists (each null if not seen), sagging unless
## [param pull] in [0, 1] pulls it straight, and a fist on each hand, turned
## along the rein; the right fist is the left one mirrored. [param width] is
## the width of the shoulders. Return whether the paintings were there.
static func draw_hands(
    canvas: CanvasItem, left: Variant, right: Variant, width: float, pull: float
) -> bool:
    var fist := texture("fist")
    var rein := texture("rein")
    if fist == null or rein == null:
        return false
    if left != null and right != null:
        _draw_rein(canvas, rein, left, right, width, pull)
    var scale := width * FIST_SHARE / FIST_WIDTH
    for side in range(2):
        var hand: Variant = left if side == 0 else right
        if hand == null:
            continue
        var other: Variant = right if side == 0 else left
        var angle := 0.0
        if other != null:
            var toward: Vector2 = (other as Vector2) - hand
            angle = toward.angle() if side == 0 else (-toward).angle()
        var flip := 1.0 if side == 0 else -1.0
        var transform := Transform2D(angle, Vector2(scale * flip, scale), 0.0, hand)
        var region := Rect2(FIST_CENTER.x - FIST_WIDTH * 0.5, 0.0, FIST_WIDTH, fist.get_height())
        canvas.draw_set_transform_matrix(transform * Transform2D(0.0, -FIST_CENTER))
        canvas.draw_texture_rect_region(fist, region, region)
        canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
    return true


static func _draw_rein(
    canvas: CanvasItem, rein: Texture2D, left: Vector2, right: Vector2, width: float, pull: float
) -> void:
    var height := float(rein.get_height())
    var sag := Vector2(0, width * REIN_SAG * (1.0 - clampf(pull, 0.0, 1.0)))
    var steps := 10
    var points := PackedVector2Array()
    var us := PackedFloat32Array()
    for i in range(steps + 1):
        var t := float(i) / steps
        points.append(left.lerp(right, t) + sag * 4.0 * t * (1.0 - t))
        us.append(t * rein.get_width())
    var scale := maxf(2.0, width * REIN_SHARE) / height
    _draw_strip(canvas, rein, points, us, height * 0.5, height * 0.5, scale, Color.WHITE)


static func _draw(
    canvas: CanvasItem, painting: Texture2D, transform: Transform2D, color: Color
) -> void:
    canvas.draw_set_transform_matrix(transform)
    canvas.draw_texture(painting, Vector2.ZERO, color)
    canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
