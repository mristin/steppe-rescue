class_name HandCursor
extends Control

## Move the cursors of the menus, birds, with the players' raised hands (see
## section 5 of DESIGN.md, "Menus: the hand cursor"), or with the mouse when
## no hand is seen. The hands come from the hand detector (YOLOX), which runs
## on every frame while the bird shows; the pose only tells where the
## shoulders are, below which a hand rests and does not count.
##
## Every raised hand has its own bird, so that a child sees at once which bird
## is hers, and two riders can point together. The [DwellButton]s ask where
## the birds are with [method points]: a hand clicks by holding its bird still
## over a button, the mouse by clicking.
##
## The bird of a hand is calm and sticky, since the hands of children are hard
## to hold still and the detections jitter: on a button, it is drawn towards
## the middle and leaves only when the hand moves clearly beyond the edge,
## and it glides instead of jumping.
##
## Behind the buttons, the player sees herself dimly, mirrored, so that her
## hand in the picture lies right under the bird (see [constant _REACH]).
##
## With two players, a screen of one player (e.g., the creator of her rider)
## sets [member player]: then only the hands in her half of the camera picture
## move the birds, and her half maps onto the whole screen (see section 6 of
## DESIGN.md, "Two players").

## The part of the camera picture, normalized, which maps onto the whole
## screen, so that the player reaches every corner without stretching. Its
## bottom follows the shoulders of the player (see [member reach]), so that
## the bottom of the screen is reached with the hand still raised.
const _REACH := Rect2(0.15, 0.1, 0.7, 0.6)

## The part of the camera picture which maps onto the whole screen for the
## player of the left half; the right half is the same, moved by a half.
const _HALF_REACH := Rect2(0.04, 0.1, 0.42, 0.6)

## The bottom of the screen lies this far below the shoulders, in the
## normalized picture: just within a raised hand.
const _BELOW_SHOULDERS := 0.04

## A hand lower than this below the bottom of the reach rests at the side of
## the player and does not count.
const _BELOW_REACH := 0.08

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

## A shoulder counts when the pose model is this sure of it.
const _THRESHOLD := 0.5

const _LEFT_SHOULDER := 5
const _RIGHT_SHOULDER := 6

## A hand is followed this long after the detector lost it, in seconds, so
## that a missed frame does not make its bird vanish.
const _GRACE_SECONDS := 0.3

## A hand moving further than this in one frame, normalized, is another hand.
const _SAME_HAND := 0.25

## Where the first bird is (or the mouse), in the logical pixels of the screen.
static var at := Vector2(-100, -100)

## Whether hands move the birds now (else the mouse moves the cursor).
static var by_hand := false

## Where all the birds are, in the logical pixels of the screen.
static var birds: Array[Vector2] = []

## Whether the tests hold the bird (at [member at], by hand), so that neither
## the camera nor the mouse moves it.
static var held := false

## The part of the camera picture which maps onto the screen now.
static var reach := _REACH

## The player (0 or 1) whose hands alone move the birds, with two players;
## -1 for the hands of everybody. Set it before the cursor enters the tree.
var player := -1

var _service: Node = null
var _hands: Array[Hand] = []
var _mirror: Control = null


## Where the hands point: all the birds, or the held bird of the tests.
static func points() -> Array[Vector2]:
    var result: Array[Vector2] = []
    if held:
        if by_hand:
            result.append(at)
        return result
    return birds if by_hand else result


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    z_index = 100
    var vision := get_node_or_null("/root/Vision")
    _service = vision.service if vision != null else null
    if _service != null:
        _service.SetWantHands(true)
    # NOTE (mristin):
    # The height of the reach follows the shoulders across the screens.
    var base := _base_reach()
    reach = Rect2(base.position.x, reach.position.y, base.size.x, reach.size.y)
    by_hand = false
    at = get_viewport().get_mouse_position()
    _add_mirror.call_deferred()


func _process(delta: float) -> void:
    if held:
        queue_redraw()
        return
    _follow_hands()
    var screen := get_viewport_rect().size
    birds.clear()
    for hand in _hands:
        var target := (hand.smoothed - reach.position) / reach.size * screen
        target = target.clamp(Vector2.ZERO, screen)
        hand.bird = target if hand.fresh else _glide(hand, target, delta)
        hand.fresh = false
        birds.append(hand.bird)
    by_hand = not birds.is_empty()
    at = birds[0] if by_hand else get_viewport().get_mouse_position()
    queue_redraw()


## Whether the cursor follows only the hands of one player, in her half of
## the camera picture.
func _in_half() -> bool:
    return player >= 0 and _service != null and _service.GetPlayerCount() > 1


## The part of the camera picture which maps onto the screen, before it
## follows the shoulders.
func _base_reach() -> Rect2:
    if not _in_half():
        return _REACH
    return Rect2(_HALF_REACH.position + Vector2(0.5 * player, 0.0), _HALF_REACH.size)


## The bird glides towards its hand, and sticks to the button under it.
func _glide(hand: Hand, target: Vector2, delta: float) -> Vector2:
    var glide := 1.0 - exp(-delta / _GLIDE_SECONDS)
    var stuck := hand.stuck
    var button: DwellButton = null
    if (
        is_instance_valid(stuck)
        and stuck.is_visible_in_tree()
        and stuck.get_global_rect().grow(_margin_of(stuck)).has_point(target)
    ):
        button = stuck
    if button == null:
        button = _button_at(target)
    hand.stuck = button
    if button == null:
        return hand.bird.lerp(target, glide)
    var middle := button.get_global_rect().get_center()
    var wanted := middle + (target - middle) * STICKY_SHARE
    if not button.get_global_rect().has_point(wanted):
        wanted = middle
    return hand.bird.lerp(wanted, glide)


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


func _exit_tree() -> void:
    birds.clear()
    if _service != null:
        _service.SetWantHands(false)


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


## Follow the raised hands in the mirrored camera picture, normalized and
## smoothed. Each found hand continues the nearest hand followed before, if
## close; the others start new birds. The hands resting below the shoulders do
## not count.
func _follow_hands() -> void:
    if _service == null or not _service.IsRunning():
        _hands.clear()
        return
    var keypoints: Array = _service.GetKeypoints(maxi(0, player))
    var scores: Array = _service.GetKeypointScores(maxi(0, player))
    if keypoints.size() > _RIGHT_SHOULDER:
        _follow_shoulders(keypoints, scores)
    var lowest := reach.end.y + _BELOW_REACH
    var now := Time.get_ticks_msec() / 1000.0
    var found: Array[Vector2] = []
    var half := _in_half()
    for hand in _service.GetHands():
        if half and int(hand.x >= 0.5) != player:
            continue
        if hand.y <= lowest:
            found.append(hand)
    # NOTE (mristin):
    # Match greedily, the closest pairs first; there are only a few hands.
    var pairs := []
    for h in _hands.size():
        for f in found.size():
            var distance := _hands[h].raw.distance_to(found[f])
            if distance <= _SAME_HAND:
                pairs.append([distance, h, f])
    pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
    var taken_hands := {}
    var taken_found := {}
    for pair in pairs:
        if taken_hands.has(pair[1]) or taken_found.has(pair[2]):
            continue
        taken_hands[pair[1]] = true
        taken_found[pair[2]] = true
        _hands[pair[1]].see(found[pair[2]], now)
    for f in found.size():
        if not taken_found.has(f):
            var born := Hand.new()
            born.see(found[f], now)
            _hands.append(born)
    var kept: Array[Hand] = []
    for hand in _hands:
        if now - hand.seen_at <= _GRACE_SECONDS:
            kept.append(hand)
    _hands = kept


func _draw() -> void:
    if _mirror != null:
        _mirror.queue_redraw()
    if not by_hand:
        return
    var bird := Icons.bird(BIRD_SCALE)
    for point in birds:
        draw_texture(bird, (point - bird.get_size() * 0.5).round())


## A raised hand which we follow, and its bird.
class Hand:
    extends RefCounted
    ## Where the detector saw it last, normalized.
    var raw := Vector2.ZERO
    ## Where it is, smoothed, normalized.
    var smoothed := Vector2.ZERO
    var seen_at := 0.0
    ## Where its bird is, in the logical pixels of the screen.
    var bird := Vector2.ZERO
    ## Whether the bird just appeared (it jumps to the hand, not glides).
    var fresh := true
    var stuck: DwellButton = null
    var _x := OneEuro.new()
    var _y := OneEuro.new()

    func see(point: Vector2, now: float) -> void:
        raw = point
        seen_at = now
        smoothed = Vector2(_x.filter(point.x, now), _y.filter(point.y, now))


## Smooth a noisy signal with little lag: the faster it moves, the less we
## smooth (Casiez, Roussel and Vogel, "1€ Filter", CHI 2012), as in Bird Dog.
class OneEuro:
    extends RefCounted
    var min_cutoff := 1.2
    var beta := 4.0
    var derivative_cutoff := 1.0
    var _value := 0.0
    var _derivative := 0.0
    var _last := -1.0

    func reset(value: float) -> void:
        _value = value
        _derivative = 0.0
        _last = -1.0

    func filter(value: float, time: float) -> float:
        if _last < 0.0:
            _value = value
            _last = time
            return value
        var dt := time - _last
        if dt <= 0.000001:
            return _value
        _last = time
        var derivative := (value - _value) / dt
        _derivative += _alpha(derivative_cutoff, dt) * (derivative - _derivative)
        var cutoff := min_cutoff + beta * absf(_derivative)
        _value += _alpha(cutoff, dt) * (value - _value)
        return _value

    func _alpha(cutoff: float, dt: float) -> float:
        var tau := 1.0 / (TAU * cutoff)
        return 1.0 / (1.0 + tau / dt)
