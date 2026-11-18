extends RefCounted
## Find the way through the steppe of a level for the riders of the tests
## (see rider_bot.gd): on a grid of the steppe, around what blocks the horse
## (with some room to spare), with [AStarGrid2D]. The creeks do not block the
## way, since the horse jumps over them, but they cost more, so that the way
## crosses them only where it must.
##
## It also knows where the horse can drink and graze.
##
## Not a test itself (its name does not start with test_), it is preloaded by
## the tests.

## The side of a cell of the grid, in pixels.
const STEP := 12.0

## The way keeps this much farther from what blocks the horse than its radius.
const CLEARANCE := 5.0

## Crossing a cell of a creek costs this many cells of the open steppe.
const CREEK_COST := 6.0

var map: LevelMap

## The spots where the horse stands at fresh water, and on a pasture.
var water: Array[Vector2] = []
var pasture: Array[Vector2] = []

var _grid := AStarGrid2D.new()
var _jumpable: Array[Vector3] = []


func _init(a_map: LevelMap) -> void:
    map = a_map
    _jumpable = map.jumpable()
    var cells := Vector2i((map.size / STEP).ceil()) + Vector2i.ONE
    _grid.region = Rect2i(Vector2i.ZERO, cells)
    _grid.cell_size = Vector2(STEP, STEP)
    _grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    _grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
    _grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
    _grid.update()

    var inside := Rect2(Vector2.ZERO, map.size).grow(-Rider.EDGE - 2.0)
    for x in range(cells.x):
        for y in range(cells.y):
            if not inside.has_point(point(Vector2i(x, y))):
                _grid.set_point_solid(Vector2i(x, y))
    for solid in map.solids():
        _paint(solid, solid.z + Rider.RADIUS + CLEARANCE, -1.0)
    for solid in _jumpable:
        _paint(solid, solid.z + Rider.RADIUS + 2.0, CREEK_COST)

    for each in map.landmarks():
        if each.kind == null:
            continue
        if each.kind.fresh_water or each is River:
            var circles: Array[Vector3] = []
            if each is River:
                circles = (each as River).solids()
            else:
                circles = [Vector3(each.position.x, each.position.y, each.solid_radius())]
            for circle in circles:
                for k in range(12):
                    var at := (
                        Vector2(circle.x, circle.y)
                        + Vector2.from_angle(k * TAU / 12.0) * (circle.z + Rider.RADIUS + 3.0)
                    )
                    if map.at_fresh_water(at) and is_free(at):
                        water.append(at)
        if each.kind.pasture:
            for ring: float in [0.0, 0.3, 0.6]:
                for k in range(8):
                    var at := each.position + Vector2.from_angle(k * TAU / 8.0) * each.size() * ring
                    if map.on_pasture(at) and is_free(at):
                        pasture.append(at)


## Mark the cells within the radius around the circle (x, y, radius) as
## blocked (with a negative [param cost]) or as costing more.
func _paint(circle: Vector3, radius: float, cost: float) -> void:
    var center := Vector2(circle.x, circle.y)
    var low := Vector2i(((center - Vector2.ONE * radius) / STEP).floor())
    var high := Vector2i(((center + Vector2.ONE * radius) / STEP).ceil())
    for x in range(low.x, high.x + 1):
        for y in range(low.y, high.y + 1):
            var cell := Vector2i(x, y)
            if not _grid.is_in_boundsv(cell) or point(cell).distance_to(center) > radius:
                continue
            if cost < 0.0:
                _grid.set_point_solid(cell)
            elif not _grid.is_point_solid(cell):
                _grid.set_point_weight_scale(cell, cost)


## The middle of the cell, in the steppe.
static func point(cell: Vector2i) -> Vector2:
    return Vector2(cell) * STEP


static func cell_of(at: Vector2) -> Vector2i:
    return Vector2i((at / STEP).round())


## Whether the way may lead through the point.
func is_free(at: Vector2) -> bool:
    var cell := cell_of(at)
    return _grid.is_in_boundsv(cell) and not _grid.is_point_solid(cell)


## The free cell nearest to the point.
func free_cell(at: Vector2) -> Vector2i:
    var start := cell_of(at).clamp(_grid.region.position, _grid.region.end - Vector2i.ONE)
    if not _grid.is_point_solid(start):
        return start
    for radius in range(1, 40):
        var best := Vector2i(-1, -1)
        var best_distance := INF
        for dx in range(-radius, radius + 1):
            for dy in [-radius, radius]:
                for cell in [start + Vector2i(dx, dy), start + Vector2i(dy, dx)]:
                    if not _grid.is_in_boundsv(cell) or _grid.is_point_solid(cell):
                        continue
                    var distance := point(cell).distance_to(at)
                    if distance < best_distance:
                        best = cell
                        best_distance = distance
        if best_distance < INF:
            return best
    return start


## The way from the point to the point, as points of the steppe, ending at
## [param to] itself; empty if there is none.
func way(from: Vector2, to: Vector2) -> PackedVector2Array:
    var path := _grid.get_point_path(free_cell(from), free_cell(to), true)
    if path.is_empty():
        return path
    path.append(to)
    return path


## Whether the point lies in a creek, or this close to one.
func near_creek(at: Vector2, within: float) -> bool:
    for solid in _jumpable:
        if at.distance_to(Vector2(solid.x, solid.y)) < solid.z + Rider.RADIUS + within:
            return true
    return false
