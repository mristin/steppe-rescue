class_name Rider
extends Node2D

## Ride the horse across the steppe: the speed comes from the squats, the turn
## from the hands (see section 5 of DESIGN.md). The horse slides along what
## blocks it and never gets stuck.

## The speed of the horse at the full gallop, in pixels per second.
const MAX_SPEED := 120.0

## How fast the horse turns at the full turn, in radians per second.
const TURN_RATE := 2.0

## The horse is a circle of this radius for what blocks it.
const RADIUS := 8.0

## The horse stops this far from the edge of the steppe, at the band of tall
## grass and stones which the map draws there (see [LevelMap]).
const EDGE := 24.0

## A horse which stood still this long, in seconds, looks back at the player
## and stamps a hoof, now and then (see section 5 of DESIGN.md).
const IMPATIENT_SECONDS := 3.0

## It stamps every this many seconds; a stamp lasts [constant _STAMP_SECONDS].
const _STAMP_EVERY := 2.2
const _STAMP_SECONDS := 0.5

## The horse rears up on its hind legs for this long, in seconds, when the
## rider brakes (both hands above her head).
const REAR_SECONDS := 1.4

## A jump from a stand lasts this long, in seconds...
const JUMP_SECONDS := 0.45

## ...and this much longer at full speed: a horse at a gallop flies longer,
## and, keeping its speed in the air, much farther.
const JUMP_SPEED_SECONDS := 0.55

## At the top of a jump from a stand, the horse and the girl are this much
## bigger (nearer to us)...
const JUMP_LIFT := 0.12

## ...and this much more at full speed: a horse at a gallop flies higher.
const JUMP_SPEED_LIFT := 0.12

## The take-off and the landing last this long each, in seconds; the flight
## takes the rest of the jump.
const JUMP_PUSH_SECONDS := 0.12

## After this many jumps which fell short of a creek, every jump carries the
## horse over, as if from a trot, so that a child who can not jump high or
## run up is never stuck.
const SHORT_JUMPS_HELPED := 2

## A helped jump flies as from this speed, in [0, 1].
const HELPED_JUMP_SPEED := 0.65

## The splash of a jump which fell short into a creek lasts this long, in
## seconds.
const SPLASH_SECONDS := 0.7

## The horse makes a stride every this many pixels.
const _STRIDE := 14.0

## The heading in radians: 0 is north, clockwise.
var heading := 0.0

## The speed now, in pixels per second.
var speed := 0.0

## Whether the edge of the steppe stopped the horse in the last ride.
var at_edge := false

## The index of the obstacle (see [method set_obstacles]) which blocked the
## horse in the last ride; -1 if none did.
var blocked_by := -1

## How long the horse has stood still, in seconds.
var still_time := 0.0

## The looks of the rider and her horse, from the creator (see [Looks]).
var looks: Dictionary = Looks.DEFAULT:
    set(value):
        looks = Looks.complete(value)
        queue_redraw()

## How long ago the horse started to rear, in seconds; negative while it
## does not rear.
var rear_time := -1.0

## How long ago the horse jumped off, in seconds; negative while it does not
## jump.
var jump_time := -1.0

## How many jumps fell short of a creek, back onto the bank they started from.
var short_jumps := 0

## How long ago a jump fell short into a creek, in seconds; negative without
## a splash.
var splash_time := -1.0

var _jump_seconds := 0.0
var _take_off := Vector2.ZERO
var _jump_lift := 0.0
var _jump_speed := 0.0

var _solids: Array[Vector3] = []
var _jumpable: Array[Vector3] = []
var _bounds := Rect2()
var _stride := 0.0


func _ready() -> void:
    PaintedTopDown.prepare(self)
    # NOTE (mristin):
    # The dust behind the galloping horse.
    var dust := GallopDust.new()
    dust.name = "Dust"
    add_child(dust)


## Set what blocks the horse: the circles (x, y, radius), the edge of the
## steppe, and the [param jumpable] circles (e.g., a creek), which block it only
## on the ground.
func set_obstacles(solids: Array[Vector3], size: Vector2, jumpable: Array[Vector3] = []) -> void:
    _jumpable = jumpable
    _solids = solids
    _bounds = Rect2(Vector2.ZERO, size).grow(-EDGE)


## Rear up on the hind legs: the rider braked. A horse in the air flies on
## and lands first, as a rearing horse does not jump.
func rear() -> void:
    if rearing() > 0.0 or jump_time >= 0.0:
        return
    rear_time = 0.0
    _sound("stamp", 0.7, 0.0)


## Jump: the player jumped. A horse at a gallop flies longer and farther than
## one at a walk; a rearing horse does not jump.
func jump() -> void:
    if jump_time >= 0.0 or rear_time >= 0.0:
        return
    var fraction := speed / MAX_SPEED
    if short_jumps >= SHORT_JUMPS_HELPED:
        fraction = maxf(fraction, HELPED_JUMP_SPEED)
    jump_time = 0.0
    _take_off = position
    _jump_seconds = JUMP_SECONDS + JUMP_SPEED_SECONDS * fraction
    _jump_lift = JUMP_LIFT + JUMP_SPEED_LIFT * fraction
    _jump_speed = fraction
    _sound("hoof", 0.8, 0.0)


## How far through its jump the horse is, in [0, 1); -1 when it does not jump.
func jumping() -> float:
    if jump_time < 0.0:
        return -1.0
    return clampf(jump_time / _jump_seconds, 0.0, 0.999)


## How much bigger the horse is now, flying nearer to us; 0 on the ground.
func lift() -> float:
    var phase := jumping()
    return 0.0 if phase < 0.0 else _jump_lift * sin(PI * phase)


## The painted frame of the jump now (the take-off, rising, the flight, coming
## down, the landing); -1 when the horse does not jump.
func jump_frame() -> int:
    if jump_time < 0.0:
        return -1
    var left := _jump_seconds - jump_time
    if jump_time < JUMP_PUSH_SECONDS:
        return 0
    if left < JUMP_PUSH_SECONDS:
        return 4
    if jump_time < 2.0 * JUMP_PUSH_SECONDS:
        return 1
    if left < 2.0 * JUMP_PUSH_SECONDS:
        return 3
    return 2


## How far the horse rears up now, in [0, 1]; 0 when it does not.
func rearing() -> float:
    if rear_time < 0.0 or rear_time >= REAR_SECONDS:
        return 0.0
    return sin(rear_time / REAR_SECONDS * PI)


## Ride for [param delta] seconds at the speed in [0, 1] and the turn in [-1, 1].
func ride(delta: float, speed_fraction: float, turn: float) -> void:
    if splash_time >= 0.0:
        splash_time += delta
        if splash_time >= SPLASH_SECONDS:
            splash_time = -1.0
    if jump_time >= 0.0:
        jump_time += delta
        if jump_time >= _jump_seconds:
            jump_time = -1.0
            # NOTE (mristin):
            # Landing in the creek, the horse splashes back onto the bank it
            # jumped from.
            position = slide(position)
            if _fell_short():
                short_jumps += 1
                splash_time = 0.0
                _sound("stamp", 0.6, 0.0)
            else:
                _sound("stamp", 1.1, -2.0)
        else:
            # NOTE (mristin):
            # In the air, the horse keeps its speed and its heading.
            speed_fraction = _jump_speed
            turn = 0.0
    if rear_time >= 0.0:
        rear_time += delta
        if rear_time >= REAR_SECONDS:
            rear_time = -1.0
            _sound("stamp", 0.8, -2.0)
        else:
            # NOTE (mristin):
            # A rearing horse stands on its hind legs and does not go on.
            speed_fraction = 0.0
            turn = 0.0
    speed = clampf(speed_fraction, 0.0, 1.0) * MAX_SPEED

    # NOTE (mristin):
    # A standing horse turns, too, but slower, so that a child can aim before
    # she rides off.
    var rate := TURN_RATE if speed > 1.0 else TURN_RATE * 0.5
    heading = wrapf(heading + clampf(turn, -1.0, 1.0) * rate * delta, -PI, PI)

    var stamping_before := stamping()
    still_time = still_time + delta if speed <= 0.0 else 0.0
    if stamping() and not stamping_before:
        _sound("stamp", 1.0, -2.0)
    position = slide(position + Vector2.UP.rotated(heading) * speed * delta)
    var stride_before := int(_stride * 2.0)
    _stride += speed * delta / _STRIDE
    if int(_stride * 2.0) != stride_before:
        _sound("hoof", 0.9 + 0.1 * gait(), -6.0 if gait() < 3 else -2.0)
    queue_redraw()


## The point moved out of what blocks the horse and into the steppe; the edge
## of the steppe blocks like a wall (see [member at_edge]).
func slide(at: Vector2) -> Vector2:
    blocked_by = -1
    # NOTE (mristin):
    # A horse in the air flies over what it jumps over (e.g., a creek); on the
    # ground, it blocks the horse like the rest (counted after the rest).
    var solids := _solids if jump_time >= 0.0 else _solids + _jumpable
    for i in range(solids.size()):
        var solid := solids[i]
        var center := Vector2(solid.x, solid.y)
        var away := at - center
        var reach := solid.z + RADIUS
        if away.length() < reach:
            at = center + (away.normalized() if away.length() > 0.001 else Vector2.DOWN) * reach
            blocked_by = i
    at_edge = false
    if _bounds.has_area():
        var inside := at.clamp(_bounds.position, _bounds.end)
        at_edge = inside != at
        at = inside
    return at


## Whether the jump which just ended fell short: the horse touches the creek on
## the side it jumped from.
func _fell_short() -> bool:
    if not at_creek():
        return false
    var all := _solids + _jumpable
    var solid: Vector3 = all[blocked_by]
    var center := Vector2(solid.x, solid.y)
    return (_take_off - center).dot(position - center) > 0.0


## Whether the horse stands at a creek, which it must jump over.
func at_creek() -> bool:
    return blocked_by >= _solids.size()


## Whether the impatient horse looks back and stamps a hoof right now.
func stamping() -> bool:
    if still_time < IMPATIENT_SECONDS:
        return false
    return fposmod(still_time - IMPATIENT_SECONDS, _STAMP_EVERY) < _STAMP_SECONDS


## The gait of the horse at its speed now: 0 stands, 1 walks, 2 trots and 3
## gallops (the same speeds as SquatMeter.WalkFrom, TrotFrom and GallopFrom).
func gait() -> int:
    var fraction := speed / MAX_SPEED
    if fraction >= 0.72:
        return 3
    if fraction >= 0.46:
        return 2
    if fraction >= 0.04:
        return 1
    return 0


func _draw() -> void:
    var gait := gait()
    var frame := int(_stride * 3.0)
    var look := 0.0
    var jolt := Vector2.ZERO
    var t := -1.0
    if stamping():
        # NOTE (mristin):
        # The horse turns its head (and with it the picture) back towards the
        # player, and the stamp jolts it and raises a little dust at the front
        # hoof.
        t = fposmod(still_time - IMPATIENT_SECONDS, _STAMP_EVERY) / _STAMP_SECONDS
        look = sin(t * PI) * 0.35
        jolt = Vector2(0, -1.5 * absf(sin(t * TAU * 2.0))).rotated(heading)
    var rear := rearing()
    # NOTE (mristin):
    # In a jump, the shadow stays on the ground: it falls farther from the
    # horse and shrinks, the higher the horse flies.
    var lift := lift()
    draw_circle(Vector2(3, 4) * (1.0 + lift * 6.0), 10.0 * (1.0 - lift), Palette.SHADOW)
    PaintedTopDown.draw_rider(
        self, looks, gait, frame, jolt, heading + look, false, rear, jump_frame(), lift
    )
    if splash_time >= 0.0:
        # NOTE (mristin):
        # The splash of a jump which fell short: rings of water spreading in
        # front of the horse.
        var s := splash_time / SPLASH_SECONDS
        var front := Vector2(0, -26).rotated(heading)
        for k in range(3):
            var grow := clampf(s * 1.4 - k * 0.2, 0.0, 1.0)
            if grow > 0.0:
                draw_arc(
                    front,
                    6.0 + grow * 18.0,
                    0.0,
                    TAU,
                    20,
                    Color(Palette.SKY_LIGHT, 0.8 * (1.0 - grow)),
                    2.0
                )
        for k in range(6):
            var drop := front + Vector2.from_angle(k * TAU / 6.0) * (4.0 + s * 14.0)
            draw_circle(drop - Vector2(0, sin(s * PI) * 6.0), 2.0, Color(Palette.FELT, 1.0 - s))
    if t >= 0.0:
        var hoof := Vector2(7, -24).rotated(heading)
        for k in range(7):
            var puff := hoof + Vector2.from_angle(k * TAU / 7.0 + t) * (4.0 + t * 12.0)
            draw_circle(puff, 4.5 - t * 2.0, Color(0.55, 0.42, 0.28, 0.7 * (1.0 - t)))


func _sound(sound: String, pitch: float, volume_db: float) -> void:
    var sounds := get_node_or_null("/root/Sounds")
    if sounds != null:
        sounds.play(sound, pitch, volume_db)
