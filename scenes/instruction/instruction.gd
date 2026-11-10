class_name Instruction
extends Control

## Show how to ride (see sections 5 and 6 of DESIGN.md): the rider gets off
## her horse and stands in the frame at the left, like the player in the
## camera picture; she squats next to it, slowly, then steadily, then
## briskly, and the horse walks, trots and gallops, as the speed bar below it
## shows. Then she pulls the reins with both hands to the left, and the
## horse, seen from above, turns left; then to the right, and it turns right.
## Last, she gallops off again and raises both hands above her head: the
## brake, and the horse rears up and stops at once. A short line at the top
## says what she does. The animation repeats until
## the player presses Ready!.
##
## The squats are good ones: the feet apart, the knees over the toes, the back
## straight (see [method FrontView.figure]).
##
## It shows the first time on the way from Play to the level, and from How to
## Play in the intro.
##
## Keys: Enter is Ready!, Escape goes back.

## The painting of the steppe at sunset behind the animation, 1920 x 1080,
## shown as painted, like the painting of the intro.
const BACKGROUND := "res://assets/pictures/instruction/background.png"

## The painted girl riding her horse, at the start, before she jumps off.
const RIDER_ON_HORSE := "res://assets/pictures/instruction/rider_on_horse.png"

## The parts of the animation, by their start in seconds.
const DISMOUNT := 2.0
const SQUAT := 3.5
const STOP := 15.0
const REACH := 17.0
const REACH_RIGHT := 22.5
const GALLOP_AGAIN := 28.0
const BRAKE := 31.0
const LOOP := 36.0

## The squats in the slow, steady and brisk part: [start, seconds per squat,
## the speed of the horse].
const _SQUATS := [[SQUAT, 2.6, 0.3], [7.5, 1.6, 0.62], [11.5, 0.9, 0.95]]

## The brisk squats before the brake.
const _BRISK := [GALLOP_AGAIN, 0.9, 0.95]

## How long the horse rears, in seconds.
const _REAR_SECONDS := 1.4

const _FRAME := Rect2(36, 96, 248, 352)
const _EYES := 12.0
const _HORSE_GROUND := Vector2(660, 404)
const _FIELD := Rect2(440, 96, 440, 320)

## How long a frame of the horse lasts, per gait.
const _FRAME_SECONDS := [1.0, 0.32, 0.2, 0.12]

## The time in the animation, in seconds.
var time := 0.0

## The speed of the horse in [0, 1].
var speed := 0.0

## The heading of the horse seen from above, in radians (0 is north,
## clockwise).
var heading := 0.0

var _caption: Label
var _speed_bar: SpeedBar
var _ready_button: DwellButton
var _scroll := 0.0
var _stride := 0.0
var _looks: Dictionary = {}
var _background: Texture2D
var _rider_on_horse: Texture2D


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _looks = get_node("/root/Profile").dressed()
    _background = load(BACKGROUND)
    PaintedTopDown.prepare(self)
    _rider_on_horse = load(RIDER_ON_HORSE)
    _caption = Label.new()
    _caption.position = Vector2(56, 22)
    _caption.size = Vector2(848, 52)
    _caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _caption.autowrap_mode = TextServer.AUTOWRAP_WORD
    _caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _caption.add_theme_color_override("font_color", Palette.CRIMSON_DARK)
    _caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
    add_child(_caption)
    _speed_bar = SpeedBar.new()
    _speed_bar.position = Vector2(500, 430)
    _speed_bar.size = Vector2(320, 56)
    _speed_bar.thresholds = get_node("/root/Vision").service.GetGaitThresholds()
    _speed_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_speed_bar)

    _ready_button = DwellButton.new()
    _ready_button.position = Vector2(_FRAME.position.x + 24, 470)
    _ready_button.size = Vector2(_FRAME.size.x - 48, 54)
    _ready_button.font_size = 32
    _ready_button.primary = true
    _ready_button.pressed.connect(finish)
    add_child(_ready_button)

    add_child(HandCursor.new())
    _update_texts()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _ready_button != null:
        _update_texts()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
                finish()
            KEY_ESCAPE:
                Flow.cancel(get_tree())


func _process(delta: float) -> void:
    time = fposmod(time + delta, LOOP)
    if time < delta:
        heading = 0.0
    var target: float = pose(time)["speed"]
    # NOTE (mristin):
    # The brake stops the horse at once; else it speeds up and slows gently.
    speed = move_toward(speed, target, delta * (5.0 if pose(time)["hands_up"] > 0.0 else 0.5))
    _speed_bar.speed = speed
    _scroll += speed * delta * 160.0
    _stride += delta / _FRAME_SECONDS[_speed_bar.gait()]
    if time >= REACH and time < GALLOP_AGAIN:
        heading -= pose(time)["reach"] * delta * 0.9
    var line := caption(time)
    if _caption.text != line:
        _caption.text = line
    queue_redraw()


## The player has seen how to ride: go on.
func finish() -> void:
    get_node("/root/Profile").see_instruction()
    Flow.next(get_tree())


## What the rider does at the time of the animation: how deep she squats, in
## [0, 1], how far she pulls the reins, in [-1, 1] (positive to the left),
## how far her hands are up above her head (the brake), in [0, 1], how far the
## horse rears, in [0, 1], whether she sits on the horse, and the speed which
## the horse goes to.
static func pose(at: float) -> Dictionary:
    var result := {
        "squat": 0.0,
        "phase": 0.0,
        "reach": 0.0,
        "hands_up": 0.0,
        "rear": 0.0,
        "riding": at < DISMOUNT,
        "speed": 0.0,
    }
    if at >= BRAKE:
        result["hands_up"] = minf(1.0, (at - BRAKE) / 0.4)
        if at < BRAKE + _REAR_SECONDS:
            result["rear"] = sin((at - BRAKE) / _REAR_SECONDS * PI)
        return result
    if (at >= SQUAT and at < STOP) or at >= GALLOP_AGAIN:
        var part: Array = _BRISK if at >= GALLOP_AGAIN else _SQUATS[0]
        if at < STOP:
            for squats in _SQUATS:
                if at >= squats[0]:
                    part = squats
        var phase: float = (at - part[0]) / part[1]
        result["squat"] = 0.5 - 0.5 * cos(TAU * phase)
        result["phase"] = fposmod(phase, 1.0)
        result["speed"] = part[2]
    elif at >= STOP:
        result["speed"] = 0.3
    if at >= REACH and at < GALLOP_AGAIN:
        var start := REACH if at < REACH_RIGHT else REACH_RIGHT
        var end := REACH_RIGHT if at < REACH_RIGHT else GALLOP_AGAIN
        var into := minf(1.0, (at - start) / 0.6)
        var out := clampf((end - 0.8 - at) / 0.6, 0.0, 1.0)
        result["reach"] = minf(into, out) * (1.0 if at < REACH_RIGHT else -1.0)
    return result


func _update_texts() -> void:
    _ready_button.text = tr("Ready!")
    _caption.text = caption(time)


## What the line at the top says at the time of the animation.
func caption(at: float) -> String:
    var squat := tr("Squat to make your horse run: the faster you squat, the faster it runs!")
    # TRANSLATORS: How to squat safely, after "Squat to make your horse run".
    squat += " " + tr("Feet apart, back straight.")
    var lines := [
        [SQUAT, tr("Stand in front of the camera, like your rider.")],
        [STOP, squat],
        [REACH, tr("Stop squatting, and your horse slows down and stops.")],
        [REACH_RIGHT, tr("Pull the reins: both hands to the left, and your horse turns left.")],
        [GALLOP_AGAIN, tr("Both hands to the right, and your horse turns right.")],
        # TRANSLATORS: In How to Play, before the brake is shown.
        [BRAKE, tr("Squat briskly, and your horse gallops again.")],
    ]
    for line in lines:
        if at < line[0]:
            return line[1]
    # TRANSLATORS: In How to Play: raising both hands above the head is the brake.
    return tr("Both hands up above your head: your horse rears up and stops at once!")


## Until the girl with her hands up is painted, two golden arrows rise over
## her head, [param amount] of the way up.
func _draw_hands_up(feet: Vector2, amount: float) -> void:
    for side in [-1.0, 1.0]:
        var bottom := feet + Vector2(side * 80.0, -200.0)
        var top := bottom + Vector2(0, -60.0 * amount)
        draw_line(bottom, top, Palette.OUTLINE, 9.0)
        draw_line(bottom, top, Palette.GOLD, 5.0)
        var head := PackedVector2Array(
            [top + Vector2(0, -12), top + Vector2(-10, 4), top + Vector2(10, 4)]
        )
        draw_colored_polygon(head, Palette.GOLD)
        draw_polyline(head + PackedVector2Array([head[0]]), Palette.OUTLINE, 2.0)


## The painted horse from the side in the steppe, in its gait.
func _draw_running(_now: Dictionary) -> void:
    if _now_riding():
        var shown := _rider_on_horse.get_size() * 0.5
        var at := _HORSE_GROUND - Vector2(shown.x * 0.5, shown.y)
        draw_texture_rect(_rider_on_horse, Rect2(at.round(), shown), false)
        return
    var rear: float = _now["rear"]
    if rear > 0.0:
        PaintedHorse.draw_rear(self, rear, _HORSE_GROUND)
        return
    var gait := _speed_bar.gait()
    PaintedHorse.draw(self, gait, PaintedHorse.frame_at(gait, time), _HORSE_GROUND)


## Whether the girl still sits on her horse.
func _now_riding() -> bool:
    return pose(time)["riding"]


## The horse from above, which turns to the side the rider pulls the reins.
func _draw_turning(now: Dictionary) -> void:
    draw_texture(Ornaments.panel(_FIELD.size), _FIELD.position)
    var field := _FIELD.grow(-12)
    draw_rect(field, Palette.GRASS)
    var forward := Vector2(sin(heading), -cos(heading))
    var offset := -forward * _scroll
    for i in range(40):
        var spot := Vector2(fposmod(i * 97.0, field.size.x), fposmod(i * 53.0, field.size.y))
        spot = (spot - offset).posmodv(field.size) + field.position
        draw_rect(Rect2(spot.round(), Vector2(3, 2)), Palette.GRASS_DARK)

    var gait := _speed_bar.gait()
    var center := field.get_center()
    # NOTE (mristin):
    # The instruction always shows the same rider (see section 16 of
    # DESIGN.md), here the first painted girl on the bay horse.
    PaintedTopDown.draw_rider(self, Looks.DEFAULT, gait, int(_stride * 3.0), center, heading, true)

    # NOTE (mristin):
    # The curved arrow ahead of the horse, to the side it turns: drawn for a
    # horse heading north, mirrored for the right, and turned with the horse.
    var reach: float = now["reach"]
    if absf(reach) < 0.5:
        return
    var points := PackedVector2Array()
    var radius := 92.0
    for i in range(9):
        var angle := -0.5 - i * 0.1
        var point := Vector2(-radius + radius * cos(angle), radius * sin(angle))
        point.x *= signf(reach)
        points.append(center + point.rotated(heading))
    draw_polyline(points, Palette.OUTLINE, 7.0)
    draw_polyline(points, Palette.GOLD, 3.0)
    var tip := points[points.size() - 1]
    var back := (points[points.size() - 2] - tip).normalized()
    var side := Vector2(-back.y, back.x)
    var head := PackedVector2Array(
        [tip - back * 6.0, tip + back * 8 + side * 8, tip + back * 8 - side * 8]
    )
    draw_colored_polygon(head, Palette.OUTLINE)
    draw_colored_polygon(
        PackedVector2Array(
            [tip - back * 3.0, tip + back * 6 + side * 5, tip + back * 6 - side * 5]
        ),
        Palette.GOLD
    )
