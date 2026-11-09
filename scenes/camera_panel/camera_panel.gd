class_name CameraPanel
extends Control

## Show the player in the camera picture, mirrored, dressed as her rider: the
## chosen hat is drawn over her head, following the landmarks of her face.
##
## With [member show_skeleton], also draw the key points of the pose, the axis
## of the head and the hands which reach across it (for the movement test).
##
## The picture is drawn at the resolution of the game, so it becomes pixelated
## like everything else.

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
const _KEYPOINT_THRESHOLD := 0.5

## The hat is this many eye distances wide.
const _HAT_WIDTH_IN_EYES := 2.9

## The band of the hat sits this many eye distances above the eyes.
const _HAT_BAND_IN_EYES := 0.75

## Draw the key points, the axis of the head and the reaching hands.
@export var show_skeleton := false

var _service: Node = null


func _ready() -> void:
    _service = get_node("/root/Vision").service
    clip_contents = true


func _process(_delta: float) -> void:
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

    if show_skeleton:
        _draw_skeleton()

    _draw_hat()

    draw_rect(Rect2(Vector2.ZERO, size), Palette.OUTLINE, false, 2.0)


func _draw_skeleton() -> void:
    var points: Array = _service.GetKeypoints()
    var scores: Array = _service.GetKeypointScores()
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

    var across: Vector2 = _service.GetHandsAcross()
    for wrist in [[_LEFT_WRIST, across.x], [_RIGHT_WRIST, across.y]]:
        if seen.call(wrist[0]):
            var color := Palette.CRIMSON if wrist[1] > 0.0 else Palette.EMERALD_LIGHT
            var center: Vector2 = at.call(wrist[0])
            draw_rect(Rect2(center - Vector2(3, 3), Vector2(6, 6)), color)

    for i in range(points.size()):
        if seen.call(i) and i != _LEFT_WRIST and i != _RIGHT_WRIST:
            var center: Vector2 = at.call(i)
            draw_rect(Rect2(center.round() - Vector2(1, 1), Vector2(2, 2)), Palette.GOLD)


func _draw_hat() -> void:
    var anchor: Dictionary = _service.GetFaceAnchor()
    var alpha: float = anchor["alpha"]
    if alpha <= 0.0:
        return

    var texture := PixelSprite.texture(Sprites.TAKIYA)
    var eyes: float = anchor["eye_distance"] * size.x
    if eyes < 2.0:
        return

    # NOTE (mristin):
    # We scale the hat by whole pixels of the game, so that it stays pixel art.
    var scale := maxf(1.0, roundf(eyes * _HAT_WIDTH_IN_EYES / texture.get_width()))
    var hat_size := texture.get_size() * scale
    var center: Vector2 = anchor["center"] * size
    var angle: float = anchor["angle"]
    var up := Vector2(sin(angle), -cos(angle))
    var band := center + up * eyes * _HAT_BAND_IN_EYES

    draw_set_transform(band, angle, Vector2.ONE)
    draw_texture_rect(
        texture,
        Rect2(Vector2(-hat_size.x * 0.5, -hat_size.y), hat_size),
        false,
        Color(1, 1, 1, alpha)
    )
    draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
