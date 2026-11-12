class_name GallopDust
extends Node2D

## Raise dust behind the horse while it gallops on the ground (not in a jump),
## and a little while it trots, in three layers, all of which stay where they
## were kicked up while the horse rides on:
##
## * the clouds: big, soft puffs drawn by a shader (see dust.gdshader), which
##   rise at the hind hooves, swell, drift back and fade into wisps;
## * the kicks: smaller, denser puffs, a burst at each stride of the gallop,
##   one hoof after the other; the trot raises only these, fewer and shorter;
## * the grit: fine clods of soil flung back from the hooves, which fall
##   short and vanish.
##
## Add it to a [Rider]; it is drawn under the horse.

const _SHADER := preload("res://scenes/level/dust.gdshader")

## The hind hooves are this far behind the middle of the horse, and this far
## apart, in pixels.
const HIND := 18.0
const HOOVES_APART := 7.0

## The gallop kicks up dust this many times a second (the strides)...
const KICKS_PER_SECOND := 3.2

## ... and each kick lasts this long, in seconds.
const KICK_SECONDS := 0.1

## The trot kicks up a little dust this many times a second, each kick this
## long.
const TROT_KICKS_PER_SECOND := 2.4
const TROT_KICK_SECONDS := 0.05

static var _blank: ImageTexture = null

var _rider: Rider
var _clouds: CPUParticles2D
var _kicks: CPUParticles2D
var _grit: CPUParticles2D
var _kick_time := 0.0
var _hoof := 0
var _raising := 0


func _ready() -> void:
    _rider = get_parent() as Rider
    show_behind_parent = true

    _clouds = _layer(36, 1.8, 1.0)
    _clouds.initial_velocity_min = 12.0
    _clouds.initial_velocity_max = 30.0
    _clouds.damping_min = 10.0
    _clouds.damping_max = 18.0
    _clouds.spread = 55.0
    _clouds.scale_amount_min = 0.8
    _clouds.scale_amount_max = 1.3
    _clouds.scale_amount_curve = _curve([Vector2(0.0, 0.35), Vector2(0.4, 0.8), Vector2(1.0, 1.25)])
    _clouds.color_ramp = _fade([[0.0, 0.0], [0.12, 0.8], [0.5, 0.55], [1.0, 0.0]])

    _kicks = _layer(40, 0.8, 1.6)
    _kicks.initial_velocity_min = 24.0
    _kicks.initial_velocity_max = 46.0
    _kicks.damping_min = 50.0
    _kicks.damping_max = 70.0
    _kicks.spread = 40.0
    _kicks.scale_amount_min = 0.45
    _kicks.scale_amount_max = 0.75
    _kicks.scale_amount_curve = _curve([Vector2(0.0, 0.5), Vector2(1.0, 1.4)])
    _kicks.color_ramp = _fade([[0.0, 0.0], [0.08, 0.85], [0.5, 0.45], [1.0, 0.0]])

    _grit = CPUParticles2D.new()
    _grit.local_coords = false
    _grit.amount = 24
    _grit.lifetime = 0.35
    _grit.emitting = false
    _grit.spread = 35.0
    _grit.gravity = Vector2.ZERO
    _grit.initial_velocity_min = 50.0
    _grit.initial_velocity_max = 95.0
    _grit.damping_min = 120.0
    _grit.damping_max = 180.0
    _grit.scale_amount_min = 1.0
    _grit.scale_amount_max = 2.0
    _grit.color_ramp = _fade([[0.0, 0.9], [0.7, 0.7], [1.0, 0.0]], Palette.HORSE_BAY)
    _grit.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
    _grit.emission_points = PackedVector2Array([Vector2(0, HIND)])
    _grit.direction = Vector2(0, 1)
    add_child(_grit)


func _process(delta: float) -> void:
    if _rider == null:
        return
    # NOTE (mristin):
    # The layers turn with the horse: their hooves and their "back" are in its
    # frame, while their puffs stay in the world.
    rotation = _rider.heading
    var on_ground := _rider.lift() <= 0.0
    var gait := _rider.gait() if on_ground else 0
    _raising = clampi(gait - 1, 0, 2)
    _clouds.emitting = gait >= 3
    if gait < 2:
        _kick_time = 0.0
        _kicks.emitting = false
        _grit.emitting = false
        return
    # NOTE (mristin):
    # A trot kicks up only a little dust: shorter puffs at its slower strides,
    # without the clouds and the grit of the gallop.
    var galloping := gait >= 3
    var every := 1.0 / (KICKS_PER_SECOND if galloping else TROT_KICKS_PER_SECOND)
    var lasts := KICK_SECONDS if galloping else TROT_KICK_SECONDS
    _kick_time += delta
    if _kick_time >= every:
        _kick_time = 0.0
        _hoof = 1 - _hoof
        _kick(_kicks)
        if galloping:
            _kick(_grit)
    if _kick_time >= lasts:
        _kicks.emitting = false
        _grit.emitting = false


## How much dust the horse raises now: 0 none, 1 a little (at a trot), 2 the
## full dust of the gallop.
func raising() -> int:
    return _raising


## A burst of the layer from one hind hoof after the other: the layer
## emits from that hoof for a moment.
func _kick(layer: CPUParticles2D) -> void:
    var side := (HOOVES_APART * 0.5) * (1.0 if _hoof == 0 else -1.0)
    layer.emission_points = PackedVector2Array([Vector2(side, HIND)])
    layer.emitting = true


## A layer of puffs drawn by the shader, at the hind hooves, flying back.
func _layer(amount: int, lifetime: float, density: float) -> CPUParticles2D:
    var layer := CPUParticles2D.new()
    layer.local_coords = false
    layer.amount = amount
    layer.lifetime = lifetime
    layer.randomness = 0.5
    layer.lifetime_randomness = 0.35
    layer.texture = _texture()
    var shader := ShaderMaterial.new()
    shader.shader = _SHADER
    shader.set_shader_parameter("density", density)
    layer.material = shader
    layer.direction = Vector2(0, 1)
    layer.gravity = Vector2.ZERO
    layer.angle_min = 0.0
    layer.angle_max = 360.0
    layer.angular_velocity_min = -20.0
    layer.angular_velocity_max = 20.0
    layer.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
    layer.emission_points = PackedVector2Array(
        [Vector2(HOOVES_APART * 0.5, HIND), Vector2(-HOOVES_APART * 0.5, HIND)]
    )
    layer.emitting = false
    add_child(layer)
    return layer


static func _curve(points: Array) -> Curve:
    var curve := Curve.new()
    curve.max_value = 2.0
    for point in points:
        curve.add_point(point)
    return curve


## The opacity over the life of a puff, as [offset, alpha] pairs.
static func _fade(stops: Array, color := Color.WHITE) -> Gradient:
    var gradient := Gradient.new()
    var offsets := PackedFloat32Array()
    var colors := PackedColorArray()
    for stop in stops:
        offsets.append(stop[0])
        colors.append(Color(color, stop[1]))
    gradient.offsets = offsets
    gradient.colors = colors
    return gradient


## A white square for the puffs, 56 logical pixels wide: the shader draws
## them, but the particles need a texture for their size and coordinates.
static func _texture() -> ImageTexture:
    if _blank == null:
        var image := Image.create_empty(56, 56, false, Image.FORMAT_RGBA8)
        image.fill(Color.WHITE)
        _blank = ImageTexture.create_from_image(image)
    return _blank
