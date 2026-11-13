class_name HudLayout
extends RefCounted

## Keep the HUD of a level out of the way of the riders (see section 6 of
## DESIGN.md, "HUD"): every piece of the HUD (the conversation, the camera
## picture with the small figures, the missing animals, the map, the speed,
## the water and the food, the status of the camera) has its home on the
## screen, and when a rider comes near it, it glides to the nearest free spot
## at the edges of its part of the screen (a corner, the middle of an edge, or
## its home mirrored), and back home once she is clearly away.
##
## The pieces are placed in the order they were added, which is their
## priority: a piece never moves onto one placed before it, and rather not
## onto any other piece either; so the conversation stays where it opens, and
## the smaller pieces make room for it.

## A piece glides to its new spot over this many seconds.
const GLIDE_SECONDS := 1.2

## A piece leaves its spot once a rider comes this close to it, in pixels...
const NEAR := 4.0

## ... and goes to a spot (also back home) only if every rider is this far.
const CLEAR := 16.0

## The pieces stay this far from the edges of their part of the screen.
const MARGIN := 8.0

## A rider on her horse fits into a square this big around her saddle, at
## any heading, in logical pixels (the painted horse is about 86 by 46).
const RIDER_HALF := 48.0


## A piece of the HUD.
class Piece:
    ## A name, for the tests, e.g., "camera" or "map 1".
    var name := ""

    ## Where the piece stands when nothing is in its way, with its size now:
    ## a Callable returning a Rect2 on the screen.
    var home: Callable

    ## Whether the piece shows now: a Callable returning a bool. A hidden
    ## piece is not in the way of the others.
    var shown: Callable

    ## Put the piece at a position on the screen: a Callable taking a Vector2.
    var apply: Callable

    ## The part of the screen in which the piece moves.
    var bounds := Rect2()

    ## Where the piece goes, where it glided from, where it is, and how far
    ## it glided, in [0, 1].
    var target := Vector2.ZERO
    var from := Vector2.ZERO
    var at := Vector2.ZERO
    var glided := 1.0
    var was_shown := false
    var size := Vector2.ZERO

    func rect() -> Rect2:
        return Rect2(target, size)


var _pieces: Array[Piece] = []


## Add a piece, after all the pieces added so far in priority.
func add(name: String, bounds: Rect2, home: Callable, shown: Callable, apply: Callable) -> Piece:
    var piece := Piece.new()
    piece.name = name
    piece.bounds = bounds
    piece.home = home
    piece.shown = shown
    piece.apply = apply
    var rect: Rect2 = home.call()
    piece.target = rect.position
    piece.from = rect.position
    piece.at = rect.position
    piece.size = rect.size
    _pieces.append(piece)
    return piece


## The piece of the name; null if there is none.
func piece(name: String) -> Piece:
    for each in _pieces:
        if each.name == name:
            return each
    return null


## Whether the piece of the name stands, or goes, away from its home.
func is_away(name: String) -> bool:
    var each := piece(name)
    return each != null and each.target != (each.home.call() as Rect2).position


## The square around a rider standing at the point on the screen.
static func rider_rect(at: Vector2) -> Rect2:
    return Rect2(at - Vector2.ONE * RIDER_HALF, Vector2.ONE * RIDER_HALF * 2.0)


## Choose where each piece goes, out of the way of the [param riders] (their
## rectangles on the screen), and glide them there for the [param delta]
## seconds.
func update(riders: Array[Rect2], delta: float) -> void:
    var placed: Array[Rect2] = []
    for i in range(_pieces.size()):
        var each := _pieces[i]
        if not each.shown.call():
            each.was_shown = false
            continue
        var home: Rect2 = each.home.call()
        each.size = home.size
        var others: Array[Rect2] = []
        for j in range(i + 1, _pieces.size()):
            if _pieces[j].was_shown:
                others.append(_pieces[j].rect())
        var target := _choose(each, home, riders, placed, others)
        if not each.was_shown:
            # NOTE (mristin):
            # A piece which appears (e.g., a conversation) shows at once where
            # it belongs, instead of gliding there.
            each.target = target
            each.at = target
            each.glided = 1.0
        elif target != each.target:
            each.from = each.at
            each.target = target
            each.glided = 0.0
        each.was_shown = true
        each.glided = minf(1.0, each.glided + delta / GLIDE_SECONDS)
        each.at = each.from.lerp(each.target, smoothstep(0.0, 1.0, each.glided))
        if each.glided >= 1.0:
            each.at = each.target
        each.apply.call(each.at.round())
        placed.append(each.rect())


## The spots where the piece may stand, the nearest to its home first: its
## home, its home mirrored across its part of the screen, the spots of a grid
## over that part (at its edges, its quarters and its middle), and the spots
## right next to each of the [param obstacles].
func _spots(each: Piece, home: Rect2, obstacles: Array[Rect2]) -> Array[Vector2]:
    var inner := each.bounds.grow(-MARGIN)
    var size := home.size
    var mirrored := each.bounds.position + each.bounds.end - home.end
    var xs := [home.position.x, mirrored.x]
    var ys := [home.position.y, mirrored.y]
    for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
        xs.append(inner.position.x + (inner.size.x - size.x) * fraction)
        ys.append(inner.position.y + (inner.size.y - size.y) * fraction)
    for obstacle in obstacles:
        xs.append_array([obstacle.end.x + MARGIN, obstacle.position.x - size.x - MARGIN])
        ys.append_array([obstacle.end.y + MARGIN, obstacle.position.y - size.y - MARGIN])
    var spots: Array[Vector2] = []
    for x in xs:
        for y in ys:
            var spot := (
                Vector2(
                    clampf(x, inner.position.x, maxf(inner.position.x, inner.end.x - size.x)),
                    clampf(y, inner.position.y, maxf(inner.position.y, inner.end.y - size.y))
                )
                . round()
            )
            if spot not in spots:
                spots.append(spot)
    var origin := home.position
    spots.sort_custom(
        func(a: Vector2, b: Vector2) -> bool:
            return a.distance_squared_to(origin) < b.distance_squared_to(origin)
    )
    # NOTE (mristin):
    # The home first, even if a clamped spot ties with it.
    spots.erase(home.position.round())
    spots.push_front(home.position.round())
    return spots


func _choose(
    each: Piece, home: Rect2, riders: Array[Rect2], placed: Array[Rect2], others: Array[Rect2]
) -> Vector2:
    # NOTE (mristin):
    # First a spot which is in nobody's way; then one which is at least out of
    # the way of the riders and of the pieces placed before; else the one
    # which covers the riders the least. The home, and then the spot where the
    # piece stands, are tried before all the others, so that the pieces move
    # only when they must.
    var fits := func(spot: Vector2, strict: bool) -> bool:
        var rect := Rect2(spot, home.size)
        var margin := NEAR if spot == each.target else CLEAR
        if _hits(rect, riders, margin) or _hits(rect, placed, 0.0):
            return false
        return not (strict and _hits(rect, others, 0.0))
    var origin := home.position.round()
    if fits.call(origin, true):
        return origin
    if each.target != origin and fits.call(each.target, true):
        return each.target
    var obstacles: Array[Rect2] = placed.duplicate()
    obstacles.append_array(others)
    for rider in riders:
        obstacles.append(rider.grow(CLEAR))
    var spots := _spots(each, home, obstacles)
    for strict in [true, false]:
        for spot in spots:
            if fits.call(spot, strict):
                return spot
    var best := each.target
    var least := INF
    for spot in spots:
        var covered := 0.0
        for rider in riders:
            covered += Rect2(spot, home.size).intersection(rider).get_area()
        if covered < least:
            least = covered
            best = spot
    return best


static func _hits(rect: Rect2, others: Array[Rect2], margin: float) -> bool:
    for other in others:
        if rect.intersects(other.grow(margin)):
            return true
    return false
