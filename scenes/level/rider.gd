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

## The horse makes a stride every this many pixels.
const _STRIDE := 14.0

## The heading in radians: 0 is north, clockwise.
var heading := 0.0

## The speed now, in pixels per second.
var speed := 0.0

## Whether the edge of the steppe stopped the horse in the last ride.
var at_edge := false

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

    position = slide(position + Vector2.UP.rotated(heading) * speed * delta)
    _stride += speed * delta / _STRIDE
    queue_redraw()


## The point moved out of what blocks the horse and into the steppe; the edge
## of the steppe blocks like a wall (see [member at_edge]).
func slide(at: Vector2) -> Vector2:
    for solid in _solids:
        var center := Vector2(solid.x, solid.y)
        var away := at - center
        var reach := solid.z + RADIUS
        if away.length() < reach:
            at = center + (away.normalized() if away.length() > 0.001 else Vector2.DOWN) * reach
    at_edge = false
    if _bounds.has_area():
        var inside := at.clamp(_bounds.position, _bounds.end)
        at_edge = inside != at
        at = inside
    return at


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
    var frame := int(_stride * 2.0)
    draw_circle(Vector2(3, 4), 10.0, Palette.SHADOW)
    PaintedTopDown.draw(self, PaintedTopDown.rider(gait, frame), Vector2.ZERO, heading)
