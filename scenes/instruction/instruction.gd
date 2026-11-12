class_name Instruction
extends Control

## Show how to ride (see sections 5 and 6 of DESIGN.md): the rider gets off
## her horse and stands in the frame at the left, like the player in the
## camera picture; she squats next to it, slowly, then steadily, then
## briskly, and the horse walks, trots and gallops, as the speed bar below it
## shows. Then she pulls the reins with both hands to the left, and the
## horse, seen from above, turns left; then to the right, and it turns right.
## Then she gallops off again and jumps, and the horse, seen from above, jumps
## with her over a creek, twice. Last, she raises both hands above her head:
## the brake, and the horse rears up and stops at once. A short line at the
## top says what she does. The animation repeats until the player presses
## Ready!.
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
const JUMP := 31.0
const BRAKE := 36.5
const LOOP := 41.5

## When the horse takes off over each creek, in seconds of the animation.
const TAKE_OFFS := [32.3, 34.6]

## The squats in the slow, steady and brisk part: [start, seconds per squat,
## the speed of the horse].
const _SQUATS := [[SQUAT, 2.6, 0.3], [7.5, 1.6, 0.62], [11.5, 0.9, 0.95]]

## The brisk squats before the brake.
const _BRISK := [GALLOP_AGAIN, 0.9, 0.95]

## How long the horse rears, in seconds.
const _REAR_SECONDS := 1.4

## The jump of the horse from a gallop, as in the level (see
## [constant Rider.JUMP_SECONDS] and [constant Rider.JUMP_LIFT]): how long it
## flies, in seconds, and how much bigger (nearer to us) it is at the top.
const _JUMP_SECONDS := Rider.JUMP_SECONDS + Rider.JUMP_SPEED_SECONDS * 0.95
const _JUMP_LIFT := Rider.JUMP_LIFT + Rider.JUMP_SPEED_LIFT * 0.95

## The girl in the frame jumps a little before her horse, as the player does
## (the horse jumps when the game sees her rise): she crouches, takes off,
## flies and lands, each from this many seconds after the take-off of the
## horse.
const _GIRL_JUMP := [-0.35, -0.12, 0.05, 0.7, 0.95]

## How many pixels the steppe moves per second at full speed.
const _SCROLL := 160.0

## Half the width of the water of the creek from above, in pixels.
const _CREEK_HALF := 18.0

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
var _creek: Texture2D


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _looks = get_node("/root/Profile").rider().dressed()
    _background = load(BACKGROUND)
    PaintedTopDown.prepare(self)
    _rider_on_horse = load(RIDER_ON_HORSE)
    _creek = load(River.PAINTING)
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
    # The brake stops the horse at once; else it speeds up gently, and slows
    # down within a second, as in the level.
    var rate := 0.5 if target > speed else 1.0
    if pose(time)["hands_up"] > 0.0:
        rate = 5.0
    speed = move_toward(speed, target, delta * rate)
    _speed_bar.speed = speed
    _scroll += speed * delta * _SCROLL
    _stride += delta / _FRAME_SECONDS[_speed_bar.gait()]
    if time >= REACH and time < GALLOP_AGAIN:
        heading -= pose(time)["reach"] * delta * 0.9
    elif time >= JUMP and time < BRAKE:
        # NOTE (mristin):
        # She gallops north, straight at the creeks.
        heading = 0.0
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
## how far her hands are up above her head (the brake), in [0, 1], how far
## the horse is through its rearing, in [0, 1] (0 when it does not rear),
## the painted frame of her jump (-1 when she does not jump), how far the
## horse is through its jump, in [0, 1) (-1 when it does not jump), whether
## she sits on the horse, and the speed which the horse goes to.
static func pose(at: float) -> Dictionary:
    var result := {
        "squat": 0.0,
        "phase": 0.0,
        "reach": 0.0,
        "hands_up": 0.0,
        "rear": 0.0,
        "jump": -1,
        "flight": -1.0,
        "riding": at < DISMOUNT,
        "speed": 0.0,
    }
    if at >= BRAKE:
        result["hands_up"] = minf(1.0, (at - BRAKE) / 0.4)
        if at < BRAKE + _REAR_SECONDS:
            result["rear"] = (at - BRAKE) / _REAR_SECONDS
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
    elif at >= REACH:
        # NOTE (mristin):
        # She walks the horse while she pulls the reins; before, it stopped.
        result["speed"] = 0.3
    if at >= REACH and at < GALLOP_AGAIN:
        var start := REACH if at < REACH_RIGHT else REACH_RIGHT
        var end := REACH_RIGHT if at < REACH_RIGHT else GALLOP_AGAIN
        var into := minf(1.0, (at - start) / 0.6)
        var out := clampf((end - 0.8 - at) / 0.6, 0.0, 1.0)
        result["reach"] = minf(into, out) * (1.0 if at < REACH_RIGHT else -1.0)
    for take_off in TAKE_OFFS:
        var since: float = at - take_off
        if since >= 0.0 and since < _JUMP_SECONDS:
            result["flight"] = since / _JUMP_SECONDS
        if since >= _GIRL_JUMP[0] and since < _GIRL_JUMP[4]:
            # NOTE (mristin):
            # She does not squat while she jumps; the horse keeps its gallop.
            result["squat"] = 0.0
            result["phase"] = 0.0
            for frame in range(4):
                if since >= _GIRL_JUMP[frame]:
                    result["jump"] = frame
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
        # TRANSLATORS: In How to Play, before the jump is shown.
        [JUMP, tr("Squat briskly, and your horse gallops again.")],
        # TRANSLATORS: In How to Play: when the player jumps, her horse jumps over a creek.
        [BRAKE, tr("Jump, and your horse jumps, too: over a creek! From a gallop, it flies far.")],
    ]
    for line in lines:
        if at < line[0]:
            return line[1]
    # TRANSLATORS: In How to Play: raising both hands above the head is the brake.
    return tr(
        "Both hands up above your head: your horse stops at once. From a gallop, it rears up!"
    )


func _draw() -> void:
    draw_texture_rect(_background, Rect2(Vector2.ZERO, Vector2(960, 540)), false)
    draw_texture(Ornaments.panel(Vector2(888, 66)), Vector2(36, 15))
    draw_texture(
        Ornaments.panel(_speed_bar.size + Vector2(28, 16)), _speed_bar.position - Vector2(14, 8)
    )
    var now := pose(time)

    # NOTE (mristin):
    # The frame of the camera picture, where the rider stands as the player
    # does, seen in the mirror.
    draw_texture(Ornaments.panel(_FRAME.size), _FRAME.position)
    var inside := _FRAME.grow(-12)
    draw_rect(inside, Palette.SKY_LIGHT)
    draw_rect(Rect2(inside.position.x, inside.end.y - 40, inside.size.x, 40), Palette.GRASS_LIGHT)
    var feet := Vector2(inside.get_center().x, inside.end.y - 18)

    if (time >= REACH and time < GALLOP_AGAIN) or (time >= JUMP and time < BRAKE):
        _draw_turning(now)
    else:
        _draw_running(now)

    # NOTE (mristin):
    # She rides in, then jumps off the saddle into the frame, getting bigger as
    # she comes.
    if now["riding"]:
        return
    var hop := clampf((time - DISMOUNT) / 0.8, 0.0, 1.0)
    var from := _HORSE_GROUND + Vector2(10, -80)
    var at := from.lerp(feet, hop) + Vector2(0, -sin(hop * PI) * 40.0)
    var painted := PaintedGirl.squat(0)
    var reach: float = now["reach"]
    var hands_up: float = now["hands_up"]
    var shrink := 1.0
    if hands_up > 0.0:
        var raised := PaintedGirl.hands_up(hands_up)
        if raised != null:
            painted = raised
            # NOTE (mristin):
            # Her raised hands reach higher than the frame; she steps back a
            # little.
            shrink = 0.9
        else:
            _draw_hands_up(at, hands_up)
    elif reach != 0.0:
        painted = PaintedGirl.reins(PaintedGirl.reins_frame(reach))
    elif now["jump"] >= 0:
        painted = PaintedGirl.jump(now["jump"])
        # NOTE (mristin):
        # The jump is painted taller than the squat (in the air, she is
        # lifted above the ground in the picture), higher than the frame; she
        # steps back a little. Her shadow stays on the ground while she flies.
        shrink = 0.82
        if now["jump"] == 2:
            draw_set_transform(feet, 0.0, Vector2(1.0, 0.3))
            draw_circle(Vector2.ZERO, 50.0, Color(Palette.OUTLINE, 0.35))
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    elif now["squat"] > 0.0 or now["phase"] > 0.0:
        painted = PaintedGirl.squat(PaintedGirl.squat_frame(now["phase"]))
    # NOTE (mristin):
    # A frame has two pixels of the screen per logical pixel, like the pixel
    # art; it grows from small as she jumps off the horse.
    var size := painted.get_size() * 0.5 * lerpf(0.3, 1.0, hop) * shrink
    draw_texture_rect(painted, Rect2((at - Vector2(size.x * 0.5, size.y)).round(), size), false)


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


## The horse from above, which turns to the side the rider pulls the reins,
## or gallops north and jumps over the creeks.
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
    if time >= JUMP and time < BRAKE:
        for take_off in TAKE_OFFS:
            # NOTE (mristin):
            # The creek comes down the field at the speed of the gallop and is
            # under the horse in the middle of its jump.
            var under: float = take_off + _JUMP_SECONDS * 0.5
            _draw_creek(field, center.y - (under - time) * 0.95 * _SCROLL)

    var flight: float = now["flight"]
    var jump_frame := -1
    var lift := 0.0
    if flight >= 0.0:
        lift = _JUMP_LIFT * sin(PI * flight)
        jump_frame = clampi(int(flight * PaintedTopDown.JUMP_FRAMES), 0, 4)
        # NOTE (mristin):
        # In the air, the shadow stays on the ground, as in the level.
        draw_circle(
            center + Vector2(4, 6) * (1.0 + lift * 6.0), 30.0 * (1.0 - lift), Palette.SHADOW
        )
    # NOTE (mristin):
    # The instruction always shows the same rider (see section 16 of
    # DESIGN.md), here the first painted girl on the bay horse.
    PaintedTopDown.draw_rider(
        self, Looks.DEFAULT, gait, int(_stride * 3.0), center, heading, true, 0.0, jump_frame, lift
    )

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


## Draw the creek across the field from the west to the east, the middle of
## its water at [param y], cut off at the edges of the field: the painted
## stretch of the river, as narrow as a creek.
func _draw_creek(field: Rect2, y: float) -> void:
    var painted := _creek.get_size()
    var height := _CREEK_HALF * 2.0 / (River.WATER_BOTTOM - River.WATER_TOP)
    var scale := height / painted.y
    var top := y - (River.WATER_TOP + River.WATER_BOTTOM) * 0.5 * height
    var shown := Rect2(field.position.x, top, painted.x * scale, height)
    while shown.position.x < field.end.x:
        var cut := shown.intersection(field)
        if cut.has_area():
            var source := Rect2((cut.position - shown.position) / scale, cut.size / scale)
            draw_texture_rect_region(_creek, cut, source)
        shown.position.x += shown.size.x - 1.0
