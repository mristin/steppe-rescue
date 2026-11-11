class_name Wildlife
extends Node2D

## Bring the steppe to life with the wild animals (see section 7 of DESIGN.md),
## which are decoration, not animals to gather: herds of saigas (ақбөкен) and
## roe deer, hares, corsac foxes and swarms of locusts (саранша) graze and run
## away from the rider, the faster she rides the sooner; the marmots stand by
## their burrows and dive in as she passes; the larks fly up from the grass
## and land farther on; the eagles (бүркіт) and the falcons circle high above,
## and the swallows dart around the steppe in wide, random arcs, lower.
##
## The creatures on the ground are drawn by this node, under the rider; the
## birds in the air by its sky (see [method sky]), over her, with their
## shadows on the ground: the higher a bird flies, the farther its shadow lies
## from it, the fainter the shadow, and the bigger the bird (it is nearer to
## us, who look from above). They are paintings seen from above
## (assets/pictures/top_down/wild/), turned smoothly to their heading; the
## locusts are a few pixels.

enum State { IDLE, FLEE, HIDDEN, FLYING }

## Each kind: how near the rider may come before it flees (at a walk; a
## gallop scares it from farther), how fast it flees and wanders, in pixels
## per second, and how big it is drawn.
const KINDS := {
    "saiga": {"flee": 110.0, "speed": 150.0, "wander": 6.0, "scale": 1.35},
    "roe_deer": {"flee": 100.0, "speed": 140.0, "wander": 5.0, "scale": 1.35},
    "hare": {"flee": 70.0, "speed": 135.0, "wander": 4.0, "scale": 1.2},
    "fox": {"flee": 90.0, "speed": 115.0, "wander": 8.0, "scale": 1.25},
    "marmot": {"flee": 80.0, "speed": 0.0, "wander": 0.0, "scale": 1.2},
    "locust": {"flee": 45.0, "speed": 80.0, "wander": 0.0, "scale": 1.0},
    "lark": {"flee": 55.0, "speed": 90.0, "wander": 2.0, "scale": 1.0},
    "eagle": {"flee": 0.0, "speed": 28.0, "wander": 0.0, "scale": 1.0},
    "falcon": {"flee": 0.0, "speed": 45.0, "wander": 0.0, "scale": 1.0},
    "swallow": {"flee": 0.0, "speed": 110.0, "wander": 0.0, "scale": 1.0},
}

## How many of each kind live on a steppe of 1920 x 1280 pixels, in groups:
## [kind, groups, in each group, spread of a group in pixels].
const _POPULATION := [
    ["saiga", 1, 6, 40.0],
    ["roe_deer", 1, 3, 30.0],
    ["hare", 5, 1, 0.0],
    ["fox", 2, 1, 0.0],
    ["marmot", 2, 4, 50.0],
    ["locust", 3, 12, 22.0],
    ["lark", 8, 1, 0.0],
    ["eagle", 2, 1, 0.0],
    ["falcon", 1, 1, 0.0],
    ["swallow", 2, 3, 60.0],
]

## A fleeing creature calms down this many times its fleeing distance away.
const _CALM := 2.6

## A marmot stays in its burrow this long, in seconds, once the rider left.
const _HIDE_SECONDS := 4.0

## A lark flies this long, in seconds, before it lands again.
const _FLIGHT_SECONDS := 2.5

## A locust hops this long, in seconds.
const _HOP_SECONDS := 0.45

## How high each bird flies, in pixels: [lowest, highest]; it rises and sinks
## slowly between them.
const _ALTITUDES := {
    "eagle": [150.0, 220.0],
    "falcon": [100.0, 160.0],
    "swallow": [25.0, 60.0],
}

## A swallow turns this fast, in radians per second.
const _SWALLOW_TURN := 3.0

## A swallow flies to random points this far away, in pixels.
const _SWALLOW_REACH := 260.0

## The steppe keeps the creatures this far from its edge, in pixels.
const _MARGIN := 16.0


## A wild creature.
class Creature:
    extends RefCounted
    var kind := ""
    var position := Vector2.ZERO
    var heading := 0.0
    var state: int = 0
    var timer := 0.0
    var target := Vector2.ZERO
    var home := Vector2.ZERO
    var stride := 0.0
    var altitude := 0.0
    var phase := 0.0

    func on_ground() -> bool:
        return kind not in ["eagle", "falcon", "swallow"] and altitude <= 0.0


## The paintings of the kinds in their frames, by "kind_frame".
static var _paintings: Dictionary = {}

var creatures: Array[Creature] = []

## The parts of the steppe which the views of the riders show (see [Level]);
## empty for the view of the viewport.
var views: Array[Rect2] = []
var _bounds := Rect2()
var _solids: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _sky: Node2D
var _time := 0.0


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    _sky = Node2D.new()
    _sky.name = "Sky"
    _sky.z_index = 10
    _sky.draw.connect(_draw_sky)
    add_child(_sky)


## The layer which draws the birds in the air, over the rider.
func sky() -> Node2D:
    return _sky


## Let the creatures live on the steppe of the size, away from what blocks
## them and from the [param keep_away] points (e.g., the start and the home).
func populate(
    size: Vector2, solids: Array[Vector3], keep_away: Array[Vector2], seed_value: int
) -> void:
    _bounds = Rect2(Vector2.ZERO, size).grow(-_MARGIN)
    _solids = solids
    _rng.seed = seed_value
    creatures.clear()
    var area_factor := size.x * size.y / (1920.0 * 1280.0)
    for entry in _POPULATION:
        var groups := maxi(1, roundi(entry[1] * area_factor))
        for g in range(groups):
            var center := _free_spot(keep_away)
            for i in range(entry[2]):
                var creature := Creature.new()
                creature.kind = entry[0]
                var offset := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
                creature.position = _push_out(_bounds_clamp(center + offset * entry[3]))
                creature.home = creature.position
                creature.target = creature.position
                creature.heading = _rng.randf() * TAU
                creature.phase = _rng.randf() * TAU
                if _ALTITUDES.has(creature.kind):
                    creature.altitude = _altitude(creature)
                creatures.append(creature)


## Live for [param delta] seconds while the rider is at [param rider_at]
## riding at the gait (0 stands, 1 walks, 2 trots, 3 gallops); with two
## players, [param others] holds the other rider as [code][at, gait][/code],
## and each creature heeds the rider nearer to it.
func update(delta: float, rider_at: Vector2, gait: int, others: Array = []) -> void:
    _time += delta
    var first_alarm := 1.0 + 0.35 * maxi(0, gait - 1)
    for creature in creatures:
        var alarm := first_alarm
        var near := rider_at
        for other in others:
            var at: Vector2 = other[0]
            if (
                creature.position.distance_squared_to(at)
                < creature.position.distance_squared_to(near)
            ):
                near = at
                alarm = 1.0 + 0.35 * maxi(0, int(other[1]) - 1)
        match creature.kind:
            "eagle", "falcon":
                _circle(creature, delta)
            "swallow":
                _swoop(creature, delta)
            "marmot":
                _burrow(creature, delta, near, alarm)
            "lark":
                _lark(creature, delta, near, alarm)
            "locust":
                _locust(creature, delta, near, alarm)
            _:
                _runner(creature, delta, near, alarm)
    queue_redraw()
    _sky.queue_redraw()


## The creatures of the kind, for the tests.
func of_kind(kind: String) -> Array[Creature]:
    var result: Array[Creature] = []
    for creature in creatures:
        if creature.kind == kind:
            result.append(creature)
    return result


## A runner (saiga, roe deer, hare, fox) grazes, and flees from the rider who
## comes near, until it is far enough.
func _runner(creature: Creature, delta: float, rider_at: Vector2, alarm: float) -> void:
    var kind: Dictionary = KINDS[creature.kind]
    var distance := creature.position.distance_to(rider_at)
    if distance < kind["flee"] * alarm:
        creature.state = State.FLEE
    elif creature.state == State.FLEE and distance > kind["flee"] * _CALM:
        creature.state = State.IDLE
        creature.target = creature.position

    if creature.state == State.FLEE:
        var away := (creature.position - rider_at).normalized()
        if away == Vector2.ZERO:
            away = Vector2.UP
        # NOTE (mristin):
        # The hare runs in zigzags.
        if creature.kind == "hare":
            away = away.rotated(sin(_time * 7.0 + creature.phase) * 0.6)
        _move(creature, away * kind["speed"], delta)
        return

    if creature.position.distance_to(creature.target) < 2.0:
        if _rng.randf() < delta * 0.3:
            var wander := Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-30, 30))
            creature.target = _bounds_clamp(creature.position + wander)
        return
    var towards := (creature.target - creature.position).normalized()
    _move(creature, towards * kind["wander"], delta)


## A marmot stands by its burrow and dives in when the rider comes near; it
## peeks out again a while after she left.
func _burrow(creature: Creature, delta: float, rider_at: Vector2, alarm: float) -> void:
    var near := creature.position.distance_to(rider_at) < KINDS["marmot"]["flee"] * alarm
    if near:
        creature.state = State.HIDDEN
        creature.timer = _HIDE_SECONDS
    elif creature.state == State.HIDDEN:
        creature.timer -= delta
        if creature.timer <= 0.0:
            creature.state = State.IDLE
    # NOTE (mristin):
    # A standing marmot looks around.
    creature.heading = sin(_time * 0.7 + creature.phase) * 1.2


## A lark hides in the grass, flies up when the rider comes near, and lands
## again farther on.
func _lark(creature: Creature, delta: float, rider_at: Vector2, alarm: float) -> void:
    if creature.state == State.FLYING:
        creature.timer -= delta
        var t := 1.0 - creature.timer / _FLIGHT_SECONDS
        creature.altitude = sin(clampf(t, 0.0, 1.0) * PI) * 26.0
        _move(creature, Vector2.UP.rotated(creature.heading) * KINDS["lark"]["speed"], delta)
        if creature.timer <= 0.0:
            creature.state = State.IDLE
            creature.altitude = 0.0
        return
    if creature.position.distance_to(rider_at) < KINDS["lark"]["flee"] * alarm:
        creature.state = State.FLYING
        creature.timer = _FLIGHT_SECONDS
        var away := creature.position - rider_at
        creature.heading = (
            Vector2.UP.angle_to(away if away != Vector2.ZERO else Vector2.UP)
            + _rng.randf_range(-0.6, 0.6)
        )


## A locust hops away from the horse on its wings, then sits in the grass.
func _locust(creature: Creature, delta: float, rider_at: Vector2, alarm: float) -> void:
    if creature.state == State.FLEE:
        creature.timer -= delta
        creature.altitude = sin(clampf(1.0 - creature.timer / _HOP_SECONDS, 0.0, 1.0) * PI) * 6.0
        _move(creature, Vector2.UP.rotated(creature.heading) * KINDS["locust"]["speed"], delta)
        if creature.timer <= 0.0:
            creature.state = State.IDLE
            creature.altitude = 0.0
        return
    if creature.position.distance_to(rider_at) < KINDS["locust"]["flee"] * alarm:
        creature.state = State.FLEE
        creature.timer = _HOP_SECONDS * _rng.randf_range(0.8, 1.4)
        var away := creature.position - rider_at
        creature.heading = (
            Vector2.UP.angle_to(away if away != Vector2.ZERO else Vector2.UP)
            + _rng.randf_range(-0.8, 0.8)
        )


## How high the bird flies now: between its lowest and its highest, rising and
## sinking slowly, each bird in its own rhythm.
func _altitude(creature: Creature) -> float:
    var span: Array = _ALTITUDES[creature.kind]
    var wave := 0.5 + 0.5 * sin(_time * 0.25 + creature.phase * 3.0)
    return lerpf(span[0], span[1], wave)


## An eagle or a falcon circles slowly high over its home, in wide circles.
func _circle(creature: Creature, delta: float) -> void:
    creature.altitude = _altitude(creature)
    var radius := 140.0 if creature.kind == "eagle" else 90.0
    var speed: float = KINDS[creature.kind]["speed"]
    creature.phase += speed / radius * delta
    var before := creature.position
    creature.position = creature.home + Vector2(cos(creature.phase), sin(creature.phase)) * radius
    creature.heading = Vector2.UP.angle_to(creature.position - before)
    creature.stride += delta


## A swallow darts around the steppe on its own: it flies at its speed towards
## a random point, turning in wide arcs, and picks the next one when it is
## near; the rider does not bother it.
func _swoop(creature: Creature, delta: float) -> void:
    creature.altitude = _altitude(creature)
    if creature.position.distance_to(creature.target) < 40.0 or creature.target == creature.home:
        var angle := _rng.randf() * TAU
        var reach := _rng.randf_range(0.4, 1.0) * _SWALLOW_REACH
        creature.target = _bounds_clamp(creature.position + Vector2.from_angle(angle) * reach)
    var wanted := Vector2.UP.angle_to(creature.target - creature.position)
    var turn := wrapf(wanted - creature.heading, -PI, PI)
    creature.heading += clampf(turn, -_SWALLOW_TURN * delta, _SWALLOW_TURN * delta)
    var velocity := Vector2.UP.rotated(creature.heading) * KINDS["swallow"]["speed"] * delta
    # NOTE (mristin):
    # A swallow flies over everything, but stays over the steppe.
    creature.position = _bounds_clamp(creature.position + velocity)
    if not _bounds.has_point(creature.position + velocity * 10.0):
        creature.target = _bounds.get_center()
    creature.stride += delta


## Move the creature at the velocity, out of what blocks it and within the
## steppe, and turn it the way it goes.
func _move(creature: Creature, velocity: Vector2, delta: float) -> void:
    if velocity.length() < 0.01:
        return
    var wanted := creature.position + velocity * delta
    var moved := _push_out(_bounds_clamp(wanted))
    if moved.distance_to(creature.position) > 0.01:
        creature.heading = Vector2.UP.angle_to(moved - creature.position)
    creature.stride += moved.distance_to(creature.position) / 6.0
    creature.position = moved


func _bounds_clamp(at: Vector2) -> Vector2:
    if not _bounds.has_area():
        return at
    return at.clamp(_bounds.position, _bounds.end)


func _push_out(at: Vector2) -> Vector2:
    for solid in _solids:
        var center := Vector2(solid.x, solid.y)
        var away := at - center
        if away.length() < solid.z + 4.0:
            at = (
                center
                + (away.normalized() if away.length() > 0.001 else Vector2.DOWN) * (solid.z + 4.0)
            )
    return at


func _free_spot(keep_away: Array[Vector2]) -> Vector2:
    var spot := _bounds.get_center()
    for attempt in range(40):
        spot = Vector2(
            _rng.randf_range(_bounds.position.x, _bounds.end.x),
            _rng.randf_range(_bounds.position.y, _bounds.end.y)
        )
        var free := true
        for point in keep_away:
            if spot.distance_to(point) < 180.0:
                free = false
        for solid in _solids:
            if spot.distance_to(Vector2(solid.x, solid.y)) < solid.z + 30.0:
                free = false
        if free:
            return spot
    return spot


func _draw() -> void:
    var seen := _seen()
    for creature in creatures:
        if not _in(seen, creature.position):
            continue
        if creature.kind == "marmot":
            _paint(self, "burrow", 0, creature.position, 0.0)
            if creature.state == State.HIDDEN:
                continue
        if not creature.on_ground():
            continue
        if creature.kind == "locust":
            draw_rect(Rect2(creature.position.round(), Vector2(2, 1)), Palette.GRASS_DARK)
            continue
        _paint(self, creature.kind, int(creature.stride) % 2, creature.position, creature.heading)


func _draw_sky() -> void:
    var seen := _seen(_ALTITUDES["eagle"][1] * 0.7)
    for creature in creatures:
        if creature.on_ground() or not _in(seen, creature.position):
            continue
        var frame := int(creature.stride * (2.0 if creature.kind == "eagle" else 8.0)) % 2
        var lift := Vector2(-0.3, -0.6) * creature.altitude
        if creature.kind == "locust":
            _sky.draw_rect(Rect2(creature.position.round(), Vector2(2, 1)), Palette.SHADOW)
            var at := (creature.position + lift).round()
            _sky.draw_rect(Rect2(at, Vector2(2, 1)), Palette.GRASS_DARK)
            _sky.draw_rect(Rect2(at + Vector2(-1 + frame * 2, -1), Vector2(2, 1)), Palette.FELT)
            continue
        # NOTE (mristin):
        # The shadow on the ground, under the bird which flies higher: the
        # higher, the fainter; the bird itself is nearer to us, and bigger.
        var shadow := Color(0, 0, 0, clampf(0.3 - creature.altitude / 1000.0, 0.08, 0.3))
        var nearer := 1.0 + creature.altitude / 450.0
        _paint(_sky, creature.kind, frame, creature.position, creature.heading, shadow)
        _paint(
            _sky,
            creature.kind,
            frame,
            creature.position + lift,
            creature.heading,
            Color.WHITE,
            nearer
        )


## Draw the painting of the kind in the frame on the item, its middle at the
## point, turned to the heading.
func _paint(
    item: CanvasItem,
    kind: String,
    frame: int,
    at: Vector2,
    heading: float,
    tint := Color.WHITE,
    scale := 1.0
) -> void:
    var key := "%s_%d" % [kind, frame]
    if not _paintings.has(key):
        _paintings[key] = load("res://assets/pictures/top_down/wild/%s.png" % key)
    var picture: Texture2D = _paintings[key]
    var shown := picture.get_size() * 0.5
    item.draw_set_transform(at, heading, Vector2.ONE * scale)
    item.draw_texture_rect(picture, Rect2(-shown * 0.5, shown), false, tint)
    item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The parts of the steppe on the screen (see [member views]), with a margin
## and [param more].
func _seen(more := 0.0) -> Array[Rect2]:
    var result: Array[Rect2] = []
    if views.is_empty():
        result.append(get_canvas_transform().affine_inverse() * get_viewport_rect())
    result.append_array(views)
    for i in range(result.size()):
        result[i] = result[i].grow(48.0 + more)
    return result


## Whether the point is in any of the rectangles.
static func _in(rects: Array[Rect2], at: Vector2) -> bool:
    for rect in rects:
        if rect.has_point(at):
            return true
    return false
