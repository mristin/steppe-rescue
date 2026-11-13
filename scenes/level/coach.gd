class_name Coach
extends Control

## Show, next to the camera picture, a small figure of the rider, which does
## what the game understood of the player, so that she sees at once that her
## body is understood (see section 5 of DESIGN.md): she goes down as far as
## the player's head goes down (or, from the keys, squats once with each
## squat), pulls the reins as the player does, raises her hands when the
## player brakes, and jumps, lifted off the ground, when the player jumps.
##
## What the game waits for shows only as a hint over her head ([member
## mode]): the curved arrow which way to pull after the edge of the steppe or
## the second run into the same obstacle, and the arrow up at a creek.

enum Mode { STAND, SQUAT, REACH, JUMP }

## How long the echo of a squat lasts, in seconds.
const ECHO_SECONDS := 0.8

## How long an inviting squat lasts, in seconds.
const SQUAT_SECONDS := 2.2

## The frames of the squat from standing to the deepest (see [PaintedGirl]).
const LIVE_FRAMES := 4

## An inviting jump lasts this long, in seconds.
const JUMP_SECONDS := 1.2

## The figure shows her landing this long after a jump, in seconds.
const LANDING_SECONDS := 0.35

## A jump from the keys keeps the figure in the air this long, in seconds.
const JUMP_ECHO_SECONDS := 0.5

## What the game waits for, shown as a hint over her head: the reins pulled
## (REACH) or a jump (JUMP); STAND and SQUAT show none.
var mode := Mode.STAND:
    set(value):
        if value != mode:
            _time = 0.0
        mode = value

## Whether the camera follows the player herself (see [member live]); else,
## she squats and jumps with the keys (see [method echo] and [method
## echo_jump]).
var following := false

## What the game measures of the player: x how deep her head is in the squat,
## in [0, 1]; y how far she pulls the reins to the left, in [-1, 1]; z 1 while
## she brakes.
var live := Vector3.ZERO

## Whether the player jumps now (the figure follows her).
var jumping := false

var _time := 0.0
var _echo := 0.0
var _jump_echo := 0.0
var _was_jumping := false
var _landing := 0.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
    _time += delta
    _landing = maxf(0.0, _landing - delta)
    _jump_echo = maxf(0.0, _jump_echo - delta)
    if _was_jumping and not in_air():
        _landing = LANDING_SECONDS
    _was_jumping = in_air()
    _echo = maxf(0.0, _echo - delta)
    queue_redraw()


## Echo a squat of the player (from the keys, which tell no depth).
func echo() -> void:
    _echo = ECHO_SECONDS


## Echo a jump of the player (from the keys, which tell no height).
func echo_jump() -> void:
    _jump_echo = JUMP_ECHO_SECONDS


## Whether the figure is in the air now.
func in_air() -> bool:
    return jumping or _jump_echo > 0.0


## How deep the figure squats now, in [0, 1]: as deep as the player, or in
## the echo of a squat from the keys.
func depth() -> float:
    var echoed := 0.0
    if _echo > 0.0:
        echoed = sin(PI * (1.0 - _echo / ECHO_SECONDS))
    return maxf(clampf(live.x, 0.0, 1.0), echoed)


func _draw() -> void:
    draw_texture(Ornaments.panel(size), Vector2.ZERO)
    _draw_live(Vector2(size.x * 0.5, size.y - 8.0))
    if mode == Mode.REACH:
        _draw_arrow()
    elif mode == Mode.JUMP:
        _draw_jump_arrow()


## What the figure shows now: "jump" (in the air or landing), "brake" (her
## hands up), "reins" (pulling them), "squat" (down in a squat) or "stand".
func showing() -> String:
    if in_air() or _landing > 0.0:
        return "jump"
    if live.z > 0.5:
        return "brake"
    if absf(live.y) >= 0.3:
        return "reins"
    return "squat" if roundi(depth() * float(LIVE_FRAMES - 1)) > 0 else "stand"


## Draw the figure as the player is now: jumping, braking, pulling the reins,
## or as deep in the squat as she is, between the frames of the squat.
func _draw_live(feet: Vector2) -> void:
    match showing():
        "jump":
            # NOTE (mristin):
            # In the air, she is painted lifted above the ground (her shadow
            # stays on it), and then she lands.
            if in_air():
                draw_set_transform(feet, 0.0, Vector2(1.0, 0.3))
                draw_circle(Vector2.ZERO, size.x * 0.22, Color(Palette.OUTLINE, 0.35))
                draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
            PaintedGirl.draw(self, PaintedGirl.jump(2 if in_air() else 3, true), feet)
        "brake":
            PaintedGirl.draw(self, PaintedGirl.hands_up(1.0, true), feet)
        "reins":
            PaintedGirl.draw(self, PaintedGirl.reins(PaintedGirl.reins_frame(live.y), true), feet)
        _:
            # NOTE (mristin):
            # The frames 0 to 3 go from standing to the deepest squat; she
            # shows the one nearest to how deep the player is (blending two
            # would show two heads).
            var frame := roundi(depth() * float(LIVE_FRAMES - 1))
            PaintedGirl.draw(self, PaintedGirl.squat(frame, true), feet)


## The arrow up over her head: jump!
func _draw_jump_arrow() -> void:
    var bob := absf(sin(_time * TAU / JUMP_SECONDS)) * 4.0
    var tip := Vector2(size.x * 0.5, 10.0 - bob)
    var arrow := PackedVector2Array(
        [
            tip,
            tip + Vector2(7, 9),
            tip + Vector2(2.5, 9),
            tip + Vector2(2.5, 20),
            tip + Vector2(-2.5, 20),
            tip + Vector2(-2.5, 9),
            tip + Vector2(-7, 9)
        ]
    )
    draw_colored_polygon(arrow, Palette.GOLD)
    draw_polyline(arrow + PackedVector2Array([arrow[0]]), Palette.OUTLINE, 1.5)


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
