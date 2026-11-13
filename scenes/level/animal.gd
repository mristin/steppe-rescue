class_name Animal
extends Node2D

## Be a lost animal: graze until the rider comes close, then follow her, and
## run into the pen at home (see section 4 of DESIGN.md).

enum State { LOST, FOLLOWING, ENTERING, HOME }

## How fast the animals walk while grazing, in pixels per second.
const _GRAZE_SPEED := 10.0

## How far the animals wander while grazing, in pixels.
const _GRAZE_RADIUS := 20.0

## An animal which stood this long, in seconds, grazes.
const _GRAZE_AFTER := 0.4

## The animal makes a stride every this many pixels.
const _STRIDE := 8.0

## How long the heart shows after the animal joined the rider, in seconds.
const HEART_SECONDS := 1.2

## The animal joins the rider who stays this close, in pixels, inside the ring
## which shows around it...
const JOIN_DISTANCE := 36.0

## ... for this long, in seconds, while the ring fills.
const JOIN_SECONDS := 1.0

## The waves of a call show this long over an animal, in seconds.
const CALL_SECONDS := 0.9

## The dashes of the ring around a lost animal.
const _DASHES := 16

var kind: AnimalKind
var herd: Herd
var state := State.LOST

## The heading in radians: 0 is north, clockwise.
var heading := 0.0

## Where the animal grazes around.
var spot := Vector2.ZERO

## The point of its rider's trail which a follower reached last (see [member
## LevelPlayer.trail_start]); -1 before it follows.
var crumb := -1

## The way which an animal entering the pen walks first (the rest of its
## rider's trail), before it goes to its spot.
var path := PackedVector2Array()

## How long the rider has been near, in seconds.
var near_time := 0.0

## How long the heart still shows, in seconds.
var heart_time := 0.0

## Whether a follower lags far behind its rider (see [member Level.CALL_DISTANCE]),
## so that she hears it; set by the level.
var lagging := false

## How long the waves of the last call still show, in seconds; how many times
## the animal called; and how long until it calls again while it lags.
var call_time := 0.0
var calls := 0
var call_wait := 0.0

var _rng := RandomNumberGenerator.new()
var _target := Vector2.ZERO
var _graze_radius := _GRAZE_RADIUS
var _stride := 0.0

## When the animal last took a step, to graze while it stands.
var _moved_at := -1.0
var _time := 0.0


func _ready() -> void:
    PaintedTopDown.prepare(self)


func setup(a_kind: AnimalKind, a_herd: Herd, at: Vector2, seed_value: int) -> void:
    kind = a_kind
    herd = a_herd
    position = at
    spot = at
    _target = at
    _rng.seed = seed_value
    heading = _rng.randf() * TAU


func is_lost() -> bool:
    return state == State.LOST


## Wander slowly around the spot, stopping now and then to eat.
func graze(delta: float) -> void:
    if position.distance_to(_target) < 1.0:
        if _rng.randf() < delta * 0.5:
            _target = spot + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * _graze_radius
        heart_time = maxf(0.0, heart_time - delta)
        queue_redraw()
        return
    walk_to(_target, _GRAZE_SPEED, delta)


## Graze from now on around the spot, within the radius.
func settle(at: Vector2, radius: float) -> void:
    spot = at
    _target = at
    _graze_radius = radius


## Walk towards the target, at most at the speed; return how far it still is.
func walk_to(target: Vector2, max_speed: float, delta: float) -> float:
    var away := target - position
    var distance := away.length()
    if distance > 0.5:
        # NOTE (mristin):
        # The animals slow down as they come close, so that they do not jitter.
        var step := minf(distance, minf(max_speed, distance * 4.0) * delta)
        position += away / distance * step
        heading = lerp_angle(heading, Vector2.UP.angle_to(away), minf(1.0, delta * 8.0))
        _stride += step / _STRIDE
        if step > 0.05:
            _moved_at = _time
    heart_time = maxf(0.0, heart_time - delta)
    queue_redraw()
    return maxf(0.0, distance - (minf(distance, max_speed * delta)))


## Walk along the points, in their order, at most at the speed, and return
## how many of them it passed (all but the last, which it walks towards).
func walk_along(points: PackedVector2Array, max_speed: float, delta: float) -> int:
    var passed := 0
    var budget := max_speed * delta
    while passed < points.size() - 1:
        var distance := position.distance_to(points[passed])
        if distance > budget:
            break
        budget -= distance
        position = points[passed]
        passed += 1
    if not points.is_empty() and delta > 0.0:
        walk_to(points[passed], budget / delta, delta)
    return passed


## Step out of what blocks the horse (the circles x, y, radius), e.g., a
## follower which cut across a well on its way onto the trail of its rider.
func keep_out(solids: Array[Vector3]) -> void:
    for solid in solids:
        var center := Vector2(solid.x, solid.y)
        var away := position - center
        if away.length() < solid.z + 1.0:
            var out := away.normalized() if away.length() > 0.001 else Vector2.DOWN
            position = center + out * (solid.z + 1.0)


## Call out to the rider (a follower which fell behind): waves rise over it.
func call_out() -> void:
    call_time = CALL_SECONDS
    calls += 1


## Run a bit away from the point (a galloping horse scares the shy animals).
func flee_from(point: Vector2) -> void:
    var away := (position - point).normalized()
    if away == Vector2.ZERO:
        away = Vector2.from_angle(_rng.randf() * TAU)
    settle(position + away * 60.0, _GRAZE_RADIUS)
    _target = spot


func _process(delta: float) -> void:
    _time += delta
    call_time = maxf(0.0, call_time - delta)
    queue_redraw()


func _draw() -> void:
    match state:
        State.LOST:
            _draw_collect_ring()
        State.FOLLOWING:
            _draw_follow_ring()

    var grazing := _time - _moved_at > _GRAZE_AFTER
    var texture := PaintedTopDown.animal(kind.id, int(_stride), grazing)
    draw_circle(Vector2(1, 2), texture.get_width() * 0.1, Palette.SHADOW)
    PaintedTopDown.draw(self, texture, Vector2.ZERO, heading)

    if call_time > 0.0:
        _draw_call(texture.get_height() * 0.25)

    if heart_time > 0.0:
        var heart := Icons.heart(0.75)
        var rise := roundf((HEART_SECONDS - heart_time) * 10.0)
        var at := Vector2(-heart.get_width() * 0.5, -texture.get_height() * 0.25 - 8.0 - rise)
        draw_texture(heart, at.floor(), Color(1, 1, 1, minf(1.0, heart_time * 2.0)))


## The waves of a call, rising over the animal, [param above] pixels over its
## middle, and fading.
func _draw_call(above: float) -> void:
    var phase := 1.0 - call_time / CALL_SECONDS
    var alpha := minf(1.0, call_time * 3.0)
    for i in range(2):
        var radius := 4.0 + 5.0 * i + 4.0 * phase
        var at := Vector2(0, -above - 2.0)
        draw_arc(at, radius, -PI * 0.8, -PI * 0.2, 8, Color(Palette.OUTLINE, alpha), 2.5)
        draw_arc(at, radius, -PI * 0.8, -PI * 0.2, 8, Color(Palette.GOLD, alpha), 1.5)


## A dashed ring, turning slowly, around a lost animal: ride into it and stay,
## and the ring fills until the animal joins.
func _draw_collect_ring() -> void:
    # NOTE (mristin):
    # White felt with a dark edge, since gold would vanish in the golden grass.
    var turn := _time * 0.6
    for i in range(_DASHES):
        var start := turn + TAU * i / _DASHES
        var end := start + TAU / _DASHES * 0.5
        draw_arc(Vector2(1, 1), JOIN_DISTANCE, start, end, 4, Palette.OUTLINE, 2.0)
        draw_arc(Vector2.ZERO, JOIN_DISTANCE, start, end, 4, Palette.FELT, 2.0)
    if near_time > 0.0:
        var progress := clampf(near_time / JOIN_SECONDS, 0.0, 1.0)
        draw_arc(
            Vector2.ZERO,
            JOIN_DISTANCE,
            -PI / 2.0,
            -PI / 2.0 + TAU * progress,
            48,
            Palette.CRIMSON,
            2.0
        )


## A ring which pulses softly around an animal which follows the rider.
func _draw_follow_ring() -> void:
    var pulse := 0.5 + 0.5 * sin(_time * 4.0)
    var radius := 15.0 + 2.0 * pulse
    draw_arc(
        Vector2.ZERO, radius, 0.0, TAU, 32, Color(Palette.EMERALD_LIGHT, 0.45 + 0.45 * pulse), 2.0
    )
