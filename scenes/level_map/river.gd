@tool
class_name River
extends Landmark

## Place a river in a level (the Esil), flowing from the west to the east
## across the whole steppe at the height of this node: the painted stretch of
## the river (see [constant PAINTING]) repeated along it, and the painted ford
## (see [constant FORD_PAINTING]) at each of the [member fords], where the
## water is shallow and the horse crosses. Everywhere else, the water blocks
## the horse (see [method solids]); the horse drinks on its banks.
##
## The size of the landmark (see [method Landmark.size]) is half the width of
## the water; the clues name the river by this node, e.g., "north of the
## Esil" is north of its position.

const PAINTING := "res://assets/pictures/landmarks/river.png"
const FORD_PAINTING := "res://assets/pictures/landmarks/river_ford.png"

## Where the water runs in the paintings, as fractions of their height.
const _WATER_TOP := 0.34
const _WATER_BOTTOM := 0.73

## The circles which block the horse lie this far apart along the river, as a
## share of the half width of the water.
const _SOLID_SPACING := 0.5

static var _stretch: Texture2D = null
static var _ford: Texture2D = null

## Where the horse crosses: the x of each ford, in the coordinates of the
## level.
@export var fords: PackedFloat32Array = PackedFloat32Array():
    set(value):
        fords = value
        queue_redraw()


## How wide each ford is, in pixels, from one bank of dry land to the other.
func ford_width() -> float:
    return size() * 2.4


## The circles which block the horse, each as (x, y, radius) in the
## coordinates of the level: a chain along the river, broken at the fords.
func solids() -> Array[Vector3]:
    var result: Array[Vector3] = []
    var radius := size()
    var step := radius * _SOLID_SPACING
    var x := 0.0
    var end := _level_width()
    while x <= end:
        var open := false
        for ford in fords:
            if absf(x - ford) < ford_width() * 0.5 + radius:
                open = true
        if not open:
            result.append(Vector3(x, position.y, radius))
        x += step
    return result


## Whether the point is on the bank of the river, close enough for the horse
## to drink.
func at_water(at: Vector2, shore: float) -> bool:
    return absf(at.y - position.y) <= size() + shore


func solid_radius() -> float:
    return 0.0


func _level_width() -> float:
    var level := get_parent() as LevelMap
    return level.size.x if level != null else 1920.0


func _draw() -> void:
    if _stretch == null:
        _stretch = load(PAINTING)
        _ford = load(FORD_PAINTING)
    # NOTE (mristin):
    # The painting is scaled so that its water is as wide as the river.
    var height := size() * 2.0 / (_WATER_BOTTOM - _WATER_TOP)
    var width := height * _stretch.get_width() / _stretch.get_height()
    var top := -(_WATER_TOP + _WATER_BOTTOM) * 0.5 * height
    var x := -position.x
    while x < _level_width() - position.x:
        draw_texture_rect(_stretch, Rect2(x, top, width, height), false)
        x += width - 1.0
    for ford in fords:
        var left := ford - position.x - width * 0.5
        draw_texture_rect(_ford, Rect2(left, top, width, height), false)
