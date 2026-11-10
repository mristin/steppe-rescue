class_name HandCursor
extends Control

## Move the cursor of the menus, a small bird, with the player's raised hand
## (see section 5 of DESIGN.md, "Menus: the hand cursor"), or with the mouse
## when no hand is seen.
##
## The [DwellButton]s ask where the bird is with [member at] and whether a
## hand moves it with [member by_hand]: a hand clicks by holding the bird still
## over a button, the mouse by clicking.

## The part of the camera picture, normalized, which maps onto the whole
## screen, so that the player reaches every corner without stretching.
const _REACH := Rect2(0.15, 0.1, 0.7, 0.6)

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

var _service: Node = null


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    z_index = 100
    var vision := get_node_or_null("/root/Vision")
    _service = vision.service if vision != null else null
    by_hand = false
    at = get_viewport().get_mouse_position()


func _process(delta: float) -> void:
    if held:
        queue_redraw()
        return
    var hand := _hand()
    if hand.x >= 0.0:
        var target := (hand - _REACH.position) / _REACH.size * get_viewport_rect().size
        target = target.clamp(Vector2.ZERO, get_viewport_rect().size)
        # NOTE (mristin):
        # Smooth the hand, which jitters a little, so that the bird can rest
        # on a button.
        at = target if not by_hand else at.lerp(target, minf(1.0, delta * 10.0))
        by_hand = true
    else:
        by_hand = false
        at = get_viewport().get_mouse_position()
    queue_redraw()


func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and not held:
        by_hand = false


## The raised hand in the mirrored camera picture, normalized; negative if no
## hand is raised: the higher wrist, if it is above its shoulder's height.
func _hand() -> Vector2:
    if _service == null or not _service.IsRunning():
        return Vector2(-1, -1)
    var points: Array = _service.GetKeypoints()
    var scores: Array = _service.GetKeypointScores()
    if points.size() <= _RIGHT_WRIST:
        return Vector2(-1, -1)
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
    if not by_hand:
        return
    var bird := Icons.bird(2.0)
    draw_texture(bird, (at - bird.get_size() * 0.5).round())
