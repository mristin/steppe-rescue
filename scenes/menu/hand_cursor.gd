class_name HandCursor
extends Control

## Move the cursor of the menus, a small bird, with the player's raised hand
## (see section 5 of DESIGN.md, "Menus: the hand cursor"), or with the mouse
## when no hand is seen.
##
## The [DwellButton]s ask where the bird is with [member at] and whether a
## hand moves it with [member by_hand]: a hand clicks by holding the bird still
## over a button, the mouse by clicking.
##
## The bird of a hand is calm and sticky, since the hands of children are hard
## to hold still and the detections jitter: on a button, it is drawn towards
## the middle and leaves only when the hand moves clearly beyond the edge,
## and it glides instead of jumping.
##
## Behind the buttons, the player sees herself dimly, mirrored, so that her
## hand in the picture lies right under the bird (see [constant _REACH]).

## The part of the camera picture, normalized, which maps onto the whole
## screen, so that the player reaches every corner without stretching. Its
## bottom follows the shoulders of the player (see [member reach]), so that
## the bottom of the screen is reached with the hand still raised.
const _REACH := Rect2(0.15, 0.1, 0.7, 0.6)

## The bottom of the screen lies this far below the shoulders, in the
## normalized picture: just within a raised hand.
const _BELOW_SHOULDERS := 0.04

## How fast the reach follows the shoulders (they move as the player does).
const _REACH_FOLLOW := 2.0

## The bird is drawn this many times the size of an icon, big enough to see
## from two metres away.
const BIRD_SCALE := 6.0

## A bird on a button leaves it only when the hand is this far beyond its edge,
## in pixels, but at most [constant STICKY_MARGIN_SHARE] of the smaller side
## of the button (so that the keys of the name keyboard stay easy to reach).
const STICKY_MARGIN := 36.0
const STICKY_MARGIN_SHARE := 0.35

## On a button, the bird moves only this share of the way of the hand from the
## middle of the button, so that it stays well inside.
const STICKY_SHARE := 0.35

## The time constant of the bird gliding onto, along and off a button.
const _GLIDE_SECONDS := 0.08

## How bright the mirror of the player is behind the buttons, and how much
## the picture of the screen behind it is dimmed.
const MIRROR_ALPHA := 0.6
const MIRROR_DIM := 0.35

## A wrist counts when the pose model is this sure of it.
const _THRESHOLD := 0.5

const _LEFT_WRIST := 9
const _RIGHT_WRIST := 10
const _LEFT_SHOULDER := 5
const _RIGHT_SHOULDER := 6

## Where the bird is, in the logical pixels of the screen.
static var at := Vector2(-100, -100)

## Whether a hand moves the bird now (else the mouse does).
static var by_hand := false

## Whether the tests hold the bird (at [member at], by hand), so that neither
## the camera nor the mouse moves it.
static var held := false

## The part of the camera picture which maps onto the screen now.
static var reach := _REACH

var _service: Node = null
var _stuck: DwellButton = null
var _mirror: Control = null


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    z_index = 100
    var vision := get_node_or_null("/root/Vision")
    _service = vision.service if vision != null else null
    by_hand = false
    at = get_viewport().get_mouse_position()
    _add_mirror.call_deferred()


func _process(delta: float) -> void:
    if held:
        queue_redraw()
        return
    var hand := _hand()
    if hand.x >= 0.0:
        var target := (hand - reach.position) / reach.size * get_viewport_rect().size
        target = target.clamp(Vector2.ZERO, get_viewport_rect().size)
        at = target if not by_hand else _glide(target, delta)
        by_hand = true
    else:
        by_hand = false
        at = get_viewport().get_mouse_position()
    queue_redraw()


## The bird glides towards the hand, and sticks to the button under it.
func _glide(target: Vector2, delta: float) -> Vector2:
    var glide := 1.0 - exp(-delta / _GLIDE_SECONDS)
    var button: DwellButton = null
    if (
        is_instance_valid(_stuck)
        and _stuck.is_visible_in_tree()
        and _stuck.get_global_rect().grow(_margin_of(_stuck)).has_point(target)
    ):
        button = _stuck
    if button == null:
        button = _button_at(target)
    _stuck = button
    if button == null:
        return at.lerp(target, glide)
    var middle := button.get_global_rect().get_center()
    var wanted := middle + (target - middle) * STICKY_SHARE
    if not button.get_global_rect().has_point(wanted):
        wanted = middle
    return at.lerp(wanted, glide)


func _margin_of(button: DwellButton) -> float:
    return minf(STICKY_MARGIN, minf(button.size.x, button.size.y) * STICKY_MARGIN_SHARE)


## The smallest visible button under the point, or null.
func _button_at(point: Vector2) -> DwellButton:
    var best: DwellButton = null
    for node in get_tree().root.find_children("*", "DwellButton", true, false):
        var button := node as DwellButton
        if not button.is_visible_in_tree() or not button.get_global_rect().has_point(point):
            continue
        if best == null or button.size.x * button.size.y < best.size.x * best.size.y:
            best = button
    return best


## Put the mirror of the player behind the buttons: the first child of the
## screen, over its background.
func _add_mirror() -> void:
    var screen := get_parent() as Control
    if screen == null or _service == null:
        return
    _mirror = Control.new()
    _mirror.name = "Mirror"
    _mirror.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _mirror.set_anchors_preset(Control.PRESET_FULL_RECT)
    _mirror.draw.connect(_draw_mirror)
    screen.add_child(_mirror)
    screen.move_child(_mirror, 0)


## The camera picture, mirrored and dim, stretched so that the part of it
## which the hand reaches ([constant _REACH]) covers the whole screen: the hand
## in the picture lies under the bird.
func _draw_mirror() -> void:
    if _service == null or not _service.IsRunning():
        return
    var texture: Texture2D = _service.GetCameraTexture()
    if texture == null:
        return
    var screen := get_viewport_rect().size
    # NOTE (mristin):
    # Dim the picture of the screen behind, so that the player stands out.
    _mirror.draw_rect(Rect2(Vector2.ZERO, screen), Color(Palette.NIGHT, MIRROR_DIM))
    var whole := screen / reach.size
    var origin := -reach.position * whole
    # NOTE (mristin):
    # The keypoints are in the mirrored picture, so the texture is flipped.
    _mirror.draw_set_transform(Vector2(screen.x, 0), 0, Vector2(-1, 1))
    var flipped := Rect2(Vector2(screen.x - origin.x - whole.x, origin.y), whole)
    _mirror.draw_texture_rect(texture, flipped, false, Color(1, 1, 1, MIRROR_ALPHA))
    _mirror.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and not held:
        by_hand = false


## Let the bottom of the reach follow the shoulders of the player, so that
## the hand reaches the bottom of the screen while it is still raised.
func _follow_shoulders(points: Array, scores: Array) -> void:
    var shoulders := 0.0
    var count := 0
    for i in [_LEFT_SHOULDER, _RIGHT_SHOULDER]:
        if scores[i] >= _THRESHOLD:
            shoulders += (points[i] as Vector2).y
            count += 1
    if count == 0:
        return
    var bottom := clampf(shoulders / count + _BELOW_SHOULDERS, _REACH.position.y + 0.25, 0.95)
    var height := bottom - _REACH.position.y
    var step := minf(1.0, get_process_delta_time() * _REACH_FOLLOW)
    reach.size.y = lerpf(reach.size.y, height, step)


## The raised hand in the mirrored camera picture, normalized; negative if no
## hand is raised: the higher wrist, if it is above its shoulder's height.
func _hand() -> Vector2:
    if _service == null or not _service.IsRunning():
        return Vector2(-1, -1)
    var points: Array = _service.GetKeypoints()
    var scores: Array = _service.GetKeypointScores()
    if points.size() <= _RIGHT_WRIST:
        return Vector2(-1, -1)
    _follow_shoulders(points, scores)
    var best := Vector2(-1, -1)
    for pair in [[_LEFT_WRIST, _LEFT_SHOULDER], [_RIGHT_WRIST, _RIGHT_SHOULDER]]:
        if scores[pair[0]] < _THRESHOLD:
            continue
        var wrist: Vector2 = points[pair[0]]
        var shoulder: Vector2 = points[pair[1]]
        if scores[pair[1]] >= _THRESHOLD and wrist.y > shoulder.y + 0.05:
            continue
        if best.x < 0.0 or wrist.y < best.y:
            best = wrist
    return best


func _draw() -> void:
    if _mirror != null:
        _mirror.queue_redraw()
    if not by_hand:
        return
    var bird := Icons.bird(BIRD_SCALE)
    draw_texture(bird, (at - bird.get_size() * 0.5).round())
