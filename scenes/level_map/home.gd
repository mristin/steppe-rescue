@tool
class_name Home
extends Node2D

## Place the pen of the home aul in a level. When the rider rides up to its
## gate (in the middle of the north side), the animals which follow her run
## into it. The pen is a painting of a woven fence (see [constant PAINTING]),
## a little wider than the pen, filtered smoothly at any size.

const _GATE_WIDTH := 24.0

## The painting of the pen, seen from above, its gate open at the top.
const PAINTING := "res://assets/pictures/home/pen.png"

static var _painting: Texture2D = null

## The size of the pen in pixels.
@export var pen_size := Vector2(112, 72):
    set(value):
        pen_size = value
        queue_redraw()


## The pen, in the coordinates of the level.
func pen() -> Rect2:
    return Rect2(position - pen_size * 0.5, pen_size)


## The middle of the gate, in the coordinates of the level.
func gate() -> Vector2:
    return position + Vector2(0, -pen_size.y * 0.5)


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _draw() -> void:
    if _painting == null:
        _painting = load(PAINTING)
    var width := absf(pen_size.x) * 1.25
    var height := width * _painting.get_height() / _painting.get_width()
    height = maxf(height, absf(pen_size.y) * 1.1)
    draw_texture_rect(_painting, Rect2(-width * 0.5, -height * 0.5, width, height), false)
