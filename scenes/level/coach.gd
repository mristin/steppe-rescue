class_name Coach
extends Control

## Show, next to the camera picture, a small figure of the rider.
##
## While the camera sees the player ([member following]), the figure does what
## the game measures of her, frame by frame ([member live]): she goes down as
## far as the player's head goes down, pulls the reins as the player does, and
## raises her hands when the player brakes. So the player sees at once what
## the game sees; after the edge of the steppe, the curved arrow still shows
## which way to pull.
##
## Without the camera, she does the movement the game is waiting for (see
## section 5 of DESIGN.md): she squats slowly and invitingly while the horse
## stands still or a conversation waits for a squat, she pulls the reins with
## both hands to the left, under a curved arrow, after the rider ran into the
## edge of the steppe, and else she stands and echoes each squat of the
## player.

enum Mode { STAND, SQUAT, REACH }

## How long the echo of a squat lasts, in seconds.
const ECHO_SECONDS := 0.8

## How long an inviting squat lasts, in seconds.
const SQUAT_SECONDS := 2.2

## The frames of the squat from standing to the deepest (see [PaintedGirl]).
const LIVE_FRAMES := 4

## What the figure does.
var mode := Mode.STAND:
    set(value):
        if value != mode:
            _time = 0.0
        mode = value

## Whether the figure follows the player herself (see [member live]).
var following := false

## What the game measures of the player: x how deep her head is in the squat,
## in [0, 1]; y how far she pulls the reins to the left, in [-1, 1]; z 1 while
## she brakes.
var live := Vector3.ZERO

var _time := 0.0
var _echo := 0.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
    _time += delta
    _echo = maxf(0.0, _echo - delta)
    queue_redraw()


## Echo a squat of the player.
func echo() -> void:
    _echo = ECHO_SECONDS


## How deep the figure squats and how far she pulls the reins to the left now,
## in [0, 1].
func pose() -> Vector2:
    match mode:
        Mode.SQUAT:
            return Vector2(0.5 - 0.5 * cos(TAU * _time / SQUAT_SECONDS), 0.0)
        Mode.REACH:
            return Vector2(0.0, minf(1.0, _time / 0.5))
    if _echo > 0.0:
        return Vector2(sin(PI * (1.0 - _echo / ECHO_SECONDS)), 0.0)
    return Vector2.ZERO


func _draw() -> void:
    draw_texture(Ornaments.panel(size), Vector2.ZERO)
    var feet := Vector2(size.x * 0.5, size.y - 8.0)
    if following:
        _draw_live(feet)
        if mode == Mode.REACH:
            _draw_arrow()
        return
    var picture := PaintedGirl.squat(0, true)
    match mode:
        Mode.SQUAT:
            var phase := fposmod(_time / SQUAT_SECONDS, 1.0)
            picture = PaintedGirl.squat(PaintedGirl.squat_frame(phase), true)
        Mode.REACH:
            picture = PaintedGirl.reins(PaintedGirl.reins_frame(pose().y), true)
        _:
            if _echo > 0.0:
                var phase := 1.0 - _echo / ECHO_SECONDS
                picture = PaintedGirl.squat(PaintedGirl.squat_frame(phase), true)
    PaintedGirl.draw(self, picture, feet)

    if mode == Mode.REACH:
        _draw_arrow()


## Draw the figure as the player is now: braking, pulling the reins, or as
## deep in the squat as she is, between the frames of the squat.
func _draw_live(feet: Vector2) -> void:
    if live.z > 0.5:
        var up := PaintedGirl.hands_up(1.0, true)
        if up != null:
            PaintedGirl.draw(self, up, feet)
            return
    if absf(live.y) >= 0.3:
        PaintedGirl.draw(self, PaintedGirl.reins(PaintedGirl.reins_frame(live.y), true), feet)
        return
    # NOTE (mristin):
    # The frames 0 to 3 go from standing to the deepest squat; she shows the
    # one nearest to how deep the player is (blending two would show two
    # heads).
    var frame := roundi(clampf(live.x, 0.0, 1.0) * float(LIVE_FRAMES - 1))
    PaintedGirl.draw(self, PaintedGirl.squat(frame, true), feet)


## The curved arrow over her head, to the left, the way the horse turns.
func _draw_arrow() -> void:
    # NOTE (mristin):
    # The curved arrow over her head, to the left, the way the horse turns.
    var points := PackedVector2Array()
    var center := Vector2(size.x * 0.5, 22.0)
    for i in range(8):
        var angle := -0.2 - i * 0.35
        points.append(center + Vector2(cos(angle), sin(angle) * 0.6) * 14.0)
    draw_polyline(points, Palette.OUTLINE, 4.0)
    draw_polyline(points, Palette.GOLD, 2.0)
    var tip := points[points.size() - 1]
    draw_colored_polygon(
        PackedVector2Array([tip + Vector2(-3, 0), tip + Vector2(2, -4), tip + Vector2(2, 4)]),
        Palette.GOLD
    )
