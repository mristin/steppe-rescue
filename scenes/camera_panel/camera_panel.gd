class_name CameraPanel
extends Control

## Show the player in the camera picture, mirrored, dressed as her rider: the
## painted hat and hair of her rider and her finery (see
## [method FrontView.painted_overlay]) are drawn over her head, following the
## landmarks of her face.
##
## Her body is dressed, too: the coat of her rider with its sleeves, the
## dress and the boots, drawn along the joints which the vision follows (see
## [code]BodyFollower[/code]); the sleeves reach to her hands, so that every
## child sees which hands are hers.
##
## With two players, each is dressed as her own rider, and a line down the
## middle of the picture parts their halves (see section 6 of DESIGN.md, "Two
## players").
##
## A dashed line across her part of the picture, with an arrow down, shows how
## far down her eyes must go in a squat (see [code]SquatMeter.Line[/code]): a
## swing below her usual height. It is gold, and green while her eyes are
## below it. It moves slowly, so that it does not jump from squat to squat.
##
## With [member show_skeleton], also draw the key points of the pose, the axis
## of the head and the hands which reach across it (for the movement test).
##
## The picture is drawn at the resolution of the game, so it becomes pixelated
## like everything else.

## The joints of [code]GetBody[/code], in the order of [code]Joint[/code].
enum Joint {
    LEFT_SHOULDER,
    RIGHT_SHOULDER,
    LEFT_ELBOW,
    RIGHT_ELBOW,
    LEFT_HAND,
    RIGHT_HAND,
    LEFT_HIP,
    RIGHT_HIP,
    LEFT_KNEE,
    RIGHT_KNEE,
    LEFT_ANKLE,
    RIGHT_ANKLE,
}

## The bones between the key points (see BodyPart in C#), for the skeleton.
const _BONES := [
    [5, 6],
    [5, 7],
    [7, 9],
    [6, 8],
    [8, 10],
    [5, 11],
    [6, 12],
    [11, 12],
]

const _NOSE := 0
const _LEFT_WRIST := 9
const _RIGHT_WRIST := 10
## How opaque the clothes of the body are.
const BODY_ALPHA := 0.85

## Without the body, the shoulders are this many eye distances wide, to size
## the fists.
const FIST_EYES := 4.4

const _KEYPOINT_THRESHOLD := 0.5

## The line of the squat glides to where it should be over about this long, in
## seconds, so that it does not jump (it moves slowly anyway).
const TARGET_GLIDE_SECONDS := 0.6

## The color of the marks of each player's hands.
const _PLAYER_COLORS := [Palette.GOLD, Palette.INDIGO_LIGHT]

## Draw the key points, the axis of the head and the reaching hands, and
## mark each hand with its player and its side.
@export var show_skeleton := false

## The looks to dress the [member player] in; empty for those of the
## profile, in her finery (e.g., the creator shows the looks while they are
## chosen).
var looks: Dictionary = {}

## The only player to dress up (0 or 1); -1 dresses up every player.
var player := -1

var _service: Node = null

## The line of the squat of each player, as drawn (normalized; NAN: hidden).
var _target_y: Array[float] = [NAN, NAN]


func _ready() -> void:
    _service = get_node("/root/Vision").service
    clip_contents = true
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _process(delta: float) -> void:
    if _service != null:
        for i in range(_target_y.size()):
            var target: Dictionary = _service.GetSquatLine(i)
            if target.is_empty() or not _service.HasPlayer(i):
                _target_y[i] = NAN
            elif is_nan(_target_y[i]):
                _target_y[i] = target["y"]
            else:
                _target_y[i] = lerpf(
                    _target_y[i], target["y"], 1.0 - exp(-delta / TARGET_GLIDE_SECONDS)
                )
    queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Palette.NIGHT)

    var texture: Texture2D = _service.GetCameraTexture() if _service != null else null
    if texture != null and texture.get_size().x > 0:
        draw_set_transform(Vector2(size.x, 0), 0, Vector2(-1, 1))
        draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
        draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

    if _service == null:
        return

    var count: int = _service.GetPlayerCount()
    for i in range(count):
        if player >= 0 and i != player:
            continue
        if show_skeleton:
            _draw_skeleton(i)
        var dressed := _dressed(i)
        _draw_body(i, dressed)
        _draw_overlay(i, dressed)
        _draw_fists(i, dressed)
        _draw_target(i, count)
        if show_skeleton:
            _draw_hand_marks(i)

    if count > 1:
        var middle := roundf(size.x * 0.5)
        draw_rect(Rect2(middle - 2, 0, 4, size.y), Palette.OUTLINE)
        draw_rect(Rect2(middle - 1, 0, 2, size.y), Palette.GOLD)

    draw_rect(Rect2(Vector2.ZERO, size), Palette.OUTLINE, false, 2.0)


## Draw the line of the squat of the player across her part of the picture.
func _draw_target(index: int, count: int) -> void:
    if index >= _target_y.size() or is_nan(_target_y[index]):
        return
    var target: Dictionary = _service.GetSquatLine(index)
    if target.is_empty():
        return
    var reached: bool = target["reached"]
    var color := Palette.EMERALD_LIGHT if reached else Palette.GOLD
    var y := roundf(_target_y[index] * size.y)
    var left := 0.0 if count < 2 else size.x * 0.5 * index
    var right := size.x if count < 2 else left + size.x * 0.5
    var dash := 8.0
    var x := left + 4.0
    while x < right - 16.0:
        var end := minf(x + dash, right - 16.0)
        draw_line(Vector2(x, y), Vector2(end, y), Palette.OUTLINE, 4.0)
        draw_line(Vector2(x, y), Vector2(end, y), color, 2.0)
        x += dash * 1.75
    # NOTE (mristin):
    # The arrow at its end points down, the way her eyes must go.
    var tip := Vector2(right - 9.0, y + 7.0)
    var arrow := PackedVector2Array([Vector2(right - 14.0, y), Vector2(right - 4.0, y), tip])
    draw_colored_polygon(arrow, color)
    draw_polyline(arrow + PackedVector2Array([arrow[0]]), Palette.OUTLINE, 1.0)


func _draw_skeleton(index: int) -> void:
    var points: Array = _service.GetKeypoints(index)
    var scores: Array = _service.GetKeypointScores(index)
    if points.is_empty():
        return

    var at := func(i: int) -> Vector2: return (points[i] as Vector2) * size
    var seen := func(i: int) -> bool: return scores[i] >= _KEYPOINT_THRESHOLD

    for bone in _BONES:
        if seen.call(bone[0]) and seen.call(bone[1]):
            draw_line(at.call(bone[0]), at.call(bone[1]), Palette.FELT, 1.0)

    # NOTE (mristin):
    # The axis of the head, through the mean of the confident points of the head.
    var head_sum := Vector2.ZERO
    var head_count := 0
    for i in range(5):
        if seen.call(i):
            head_sum += at.call(i)
            head_count += 1
    if head_count > 0:
        var head_x := roundf(head_sum.x / head_count)
        for y in range(0, int(size.y), 4):
            draw_rect(Rect2(head_x, y, 1, 2), Palette.GOLD)

    var across: Vector2 = _service.GetHandsAcross(index)
    for wrist in [[_LEFT_WRIST, across.x], [_RIGHT_WRIST, across.y]]:
        if seen.call(wrist[0]):
            var color := Palette.CRIMSON if wrist[1] > 0.0 else Palette.EMERALD_LIGHT
            var center: Vector2 = at.call(wrist[0])
            draw_rect(Rect2(center - Vector2(3, 3), Vector2(6, 6)), color)

    for i in range(points.size()):
        if seen.call(i) and i != _LEFT_WRIST and i != _RIGHT_WRIST:
            var center: Vector2 = at.call(i)
            draw_rect(Rect2(center.round() - Vector2(1, 1), Vector2(2, 2)), Palette.GOLD)


## The looks of the player, in her finery.
func _dressed(index: int) -> Dictionary:
    if not looks.is_empty() and index == maxi(player, 0):
        return looks
    return get_node("/root/Profile").rider(index).dressed()


## Mark each hand of the player with her color, and "L" or "R" for its side.
func _draw_hand_marks(index: int) -> void:
    var hands: Array = _service.GetPlayerHands(index)
    var color: Color = _PLAYER_COLORS[index % _PLAYER_COLORS.size()]
    var font := ThemeDB.fallback_font
    for side in range(2):
        if hands[side] == null:
            continue
        var at: Vector2 = (hands[side] as Vector2) * size
        draw_arc(at, 7.0, 0.0, TAU, 16, Palette.OUTLINE, 3.0)
        draw_arc(at, 7.0, 0.0, TAU, 16, color, 1.5)
        var label := "%d%s" % [index + 1, "L" if side == 0 else "R"]
        draw_string_outline(
            font, at + Vector2(9, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Palette.OUTLINE
        )
        draw_string(font, at + Vector2(9, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


## Dress the body of the player as her rider: in the painted clothes of her
## painted rider (see [PaintedBody]), else drawn: the boots and the legs, the
## dress, the coat with its trims and belt, and the sleeves with the cuffs.
func _draw_body(index: int, dressed: Dictionary) -> void:
    var body: Dictionary = _service.GetBody(index)
    var alpha: float = body["alpha"]
    var joints: Array = body["joints"]
    if alpha <= 0.0 or joints.size() < Joint.size():
        return
    var at := func(joint: int) -> Variant:
        return null if joints[joint] == null else (joints[joint] as Vector2) * size
    var left_shoulder: Variant = at.call(Joint.LEFT_SHOULDER)
    var right_shoulder: Variant = at.call(Joint.RIGHT_SHOULDER)
    if left_shoulder == null or right_shoulder == null:
        return
    var width: float = (left_shoulder as Vector2).distance_to(right_shoulder)
    if width < 4.0:
        return

    # NOTE (mristin):
    # The painted riders wear their painted clothes; the others are drawn.
    if PaintedBody.has(dressed):
        var placed: Array = []
        for joint in range(Joint.size()):
            placed.append(at.call(joint))
        PaintedBody.draw_body(self, placed, dressed, alpha)
        return

    var completed := Looks.complete(dressed)
    var coat := Looks.shades(completed, "coat")
    var dress := Looks.shades(completed, "dress")
    var trim := coat[0]
    if Finery.step(completed, "coat") >= 1:
        trim = Palette.CRIMSON_DARK if completed["coat"] == "ochre" else Palette.GOLD
    var belt := Palette.GOLD if Finery.step(completed, "belt") >= 1 else Palette.HORSE_BAY
    var fade := func(color: Color) -> Color: return Color(color, color.a * alpha * BODY_ALPHA)

    # NOTE (mristin):
    # Without the hips (e.g., behind a table), the coat hangs one and a half
    # shoulder widths below the shoulders.
    var down := Vector2(0, width * 1.5)
    var left_hip: Variant = at.call(Joint.LEFT_HIP)
    var right_hip: Variant = at.call(Joint.RIGHT_HIP)
    if left_hip == null or right_hip == null:
        left_hip = left_shoulder + down
        right_hip = right_shoulder + down

    # NOTE (mristin):
    # The legs in the dress, and the boots below the knees.
    for pair in [
        [left_hip, Joint.LEFT_KNEE, Joint.LEFT_ANKLE],
        [right_hip, Joint.RIGHT_KNEE, Joint.RIGHT_ANKLE]
    ]:
        var knee: Variant = at.call(pair[1])
        if knee == null:
            continue
        draw_line(pair[0], knee, fade.call(dress[0]), width * 0.3)
        var ankle: Variant = at.call(pair[2])
        if ankle != null:
            draw_line(knee, ankle, fade.call(Palette.HOOF), width * 0.26)
            draw_circle(ankle, width * 0.14, fade.call(Palette.HOOF))

    # NOTE (mristin):
    # The coat (шапан) from the shoulders to the middle of the thighs, open in
    # front over the dress, with its trims and the belt.
    var neck: Vector2 = (left_shoulder + right_shoulder) * 0.5
    var waist: Vector2 = (left_hip + right_hip) * 0.5
    var outward: Vector2 = ((right_shoulder as Vector2) - left_shoulder).normalized() * width * 0.12
    var left_hem: Vector2 = left_hip + (left_hip - left_shoulder) * 0.4 - outward
    var right_hem: Vector2 = right_hip + (right_hip - right_shoulder) * 0.4 + outward
    var hem: Vector2 = (left_hem + right_hem) * 0.5
    draw_colored_polygon(
        PackedVector2Array([left_shoulder, right_shoulder, right_hem, left_hem]), fade.call(coat[1])
    )
    draw_colored_polygon(
        PackedVector2Array(
            [left_shoulder, left_shoulder.lerp(neck, 0.35), left_hem.lerp(hem, 0.3), left_hem]
        ),
        fade.call(coat[0])
    )
    var opening := outward * 0.9
    draw_colored_polygon(
        PackedVector2Array(
            [neck - opening * 0.6, neck + opening * 0.6, hem + opening, hem - opening]
        ),
        fade.call(dress[1])
    )
    var line := maxf(1.0, width * 0.05)
    draw_line(neck - opening * 0.6, hem - opening, fade.call(trim), line)
    draw_line(neck + opening * 0.6, hem + opening, fade.call(trim), line)
    draw_line(left_hem, right_hem, fade.call(trim), line * 1.4)
    var belt_y: Vector2 = neck.lerp(waist, 0.8)
    draw_line(
        belt_y.lerp(left_shoulder.lerp(left_hip, 0.8), 1.0),
        belt_y.lerp(right_shoulder.lerp(right_hip, 0.8), 1.0),
        fade.call(belt),
        line * 2.0
    )

    # NOTE (mristin):
    # The sleeves to the cuffs; the fists are drawn over the face (see
    # [method _draw_fists]), since the raised hands are in front of it.
    for arm in [
        [left_shoulder, Joint.LEFT_ELBOW, Joint.LEFT_HAND],
        [right_shoulder, Joint.RIGHT_ELBOW, Joint.RIGHT_HAND]
    ]:
        var elbow: Variant = at.call(arm[1])
        if elbow == null:
            continue
        var hand: Variant = at.call(arm[2])
        if hand == null:
            draw_line(arm[0], elbow, fade.call(coat[1]), width * 0.28)
            draw_circle(elbow, width * 0.14, fade.call(coat[1]))
            continue
        var cuff: Vector2 = (elbow as Vector2).lerp(hand, 0.75)
        draw_polyline(PackedVector2Array([arm[0], elbow, cuff]), fade.call(coat[1]), width * 0.28)
        draw_circle(elbow, width * 0.14, fade.call(coat[1]))
        draw_line(cuff, (elbow as Vector2).lerp(hand, 0.82), fade.call(trim), width * 0.3)


## The width of the player's shoulders in the picture, in pixels: from her
## body, else from the distance between her eyes, else a guess.
func _unit(index: int) -> float:
    var body: Dictionary = _service.GetBody(index)
    var joints: Array = body["joints"]
    if (
        float(body["alpha"]) > 0.0
        and joints.size() > Joint.RIGHT_SHOULDER
        and joints[Joint.LEFT_SHOULDER] != null
        and joints[Joint.RIGHT_SHOULDER] != null
    ):
        var shoulders: Vector2 = (
            ((joints[Joint.RIGHT_SHOULDER] as Vector2) - joints[Joint.LEFT_SHOULDER]) * size
        )
        if shoulders.length() > 4.0:
            return shoulders.length()
    var anchor: Dictionary = _service.GetFaceAnchor(index)
    if float(anchor["alpha"]) > 0.0:
        return float(anchor["eye_distance"]) * size.x * FIST_EYES
    return size.x * 0.25


## Draw a fist on each hand of the player which the detector sees, with the
## thumb turned inwards, and the reins between her fists: they sag, and are
## pulled straight when a hand reaches across to turn. The fist and the rein
## are painted (see [PaintedBody]), else drawn.
func _draw_fists(index: int, dressed: Dictionary) -> void:
    var hands: Array = _service.GetPlayerHands(index)
    if hands.size() < 2 or (hands[0] == null and hands[1] == null):
        return
    var unit := _unit(index)
    var at: Array = []
    for hand in hands:
        at.append(null if hand == null else (hand as Vector2) * size)
    var across: Vector2 = _service.GetHandsAcross(index)
    var pull := clampf(maxf(across.x, across.y), 0.0, 1.0)
    if PaintedBody.draw_hands(self, at[0], at[1], unit, pull):
        return

    var radius := maxf(3.0, unit * 0.11)
    var skin := Looks.shades(Looks.complete(dressed), "skin")
    if at[0] != null and at[1] != null:
        var sag := Vector2(0, unit * 0.3 * (1.0 - pull))
        var rein := PackedVector2Array([at[0], (at[0] + at[1]) * 0.5 + sag, at[1]])
        draw_polyline(rein, Palette.OUTLINE, maxf(3.0, radius * 0.6))
        draw_polyline(rein, Palette.HORSE_BAY_LIGHT, maxf(1.0, radius * 0.3))

    for side in range(2):
        if at[side] == null:
            continue
        var center: Vector2 = at[side]
        # NOTE (mristin):
        # In the mirrored picture, her left hand is on the left, with its thumb
        # turned to the right, towards the other hand.
        var inward := 1.0 if side == 0 else -1.0
        var thumb := center + Vector2(inward * radius * 0.8, radius * 0.2)
        draw_circle(center, radius + 1.5, Palette.OUTLINE)
        draw_circle(thumb, radius * 0.4 + 1.5, Palette.OUTLINE)
        draw_circle(center, radius, skin[1])
        for k in [-1.0, 0.0, 1.0]:
            draw_circle(center + Vector2(k * radius * 0.55, -radius * 0.45), radius * 0.24, skin[2])
            draw_line(
                center + Vector2(k * radius * 0.55 + radius * 0.27, -radius * 0.65),
                center + Vector2(k * radius * 0.55 + radius * 0.27, -radius * 0.1),
                skin[0],
                1.0
            )
        draw_circle(thumb, radius * 0.4, skin[0])


func _draw_overlay(index: int, dressed: Dictionary) -> void:
    var anchor: Dictionary = _service.GetFaceAnchor(index)
    var alpha: float = anchor["alpha"]
    if alpha <= 0.0:
        return

    var eyes: float = anchor["eye_distance"] * size.x
    if eyes < 2.0:
        return

    # NOTE (mristin):
    # The painted hair and hat of the rider, scaled smoothly to the eyes; a
    # rider without a painting is pixelated anew at the distance of the eyes
    # (in whole pixels, so that only a few sizes are cached).
    var unit := maxf(3.0, roundf(eyes))
    var texture: Texture2D = FrontView.painted_overlay(dressed)
    if texture == null:
        texture = FrontView.overlay(dressed, unit)
    else:
        unit = eyes
    var center: Vector2 = anchor["center"] * size
    var angle: float = anchor["angle"]

    draw_set_transform(center, angle, Vector2.ONE)
    draw_texture_rect(
        texture,
        Rect2(FrontView.OVERLAY_BOX.position * unit, FrontView.OVERLAY_BOX.size * unit),
        false,
        Color(1, 1, 1, alpha)
    )
    draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
