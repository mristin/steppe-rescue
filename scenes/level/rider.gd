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

var _solids: Array[Vector3] = []
var _bounds := Rect2()
var _stride := 0.0


func _ready() -> void:
    PaintedTopDown.prepare(self)


## Set what blocks the horse: the circles (x, y, radius) and the edge of the steppe.
func set_obstacles(solids: Array[Vector3], size: Vector2) -> void:
    _solids = solids
    _bounds = Rect2(Vector2.ZERO, size).grow(-EDGE)


## Ride for [param delta] seconds at the speed in [0, 1] and the turn in [-1, 1].
func ride(delta: float, speed_fraction: float, turn: float) -> void:
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
    for i in range(_solids.size()):
        var solid := _solids[i]
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


## Whether the impatient horse looks back and stamps a hoof right now.
func stamping() -> bool:
    if still_time < IMPATIENT_SECONDS:
        return false
    return fposmod(still_time - IMPATIENT_SECONDS, _STAMP_EVERY) < _STAMP_SECONDS


## The gait of the horse at its speed now: 0 stands, 1 walks, 2 trots and 3
## gallops (the same speeds as SquatMeter.WalkFrom, TrotFrom and GallopFrom).
func gait() -> int:
    var fraction := speed / MAX_SPEED
    if fraction >= 0.8:
        return 3
    if fraction >= 0.45:
        return 2
    if fraction >= 0.05:
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
    draw_circle(Vector2(3, 4), 10.0, Palette.SHADOW)
    PaintedTopDown.draw_rider(self, looks, gait, frame, jolt, heading + look)
    if t >= 0.0:
        var hoof := Vector2(7, -24).rotated(heading)
        for k in range(7):
            var puff := hoof + Vector2.from_angle(k * TAU / 7.0 + t) * (4.0 + t * 12.0)
            draw_circle(puff, 4.5 - t * 2.0, Color(0.55, 0.42, 0.28, 0.7 * (1.0 - t)))


func _sound(sound: String, pitch: float, volume_db: float) -> void:
    var sounds := get_node_or_null("/root/Sounds")
    if sounds != null:
        sounds.play(sound, pitch, volume_db)
