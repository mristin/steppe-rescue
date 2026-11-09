@tool
class_name Home
extends Node2D

## Place the pen of the home aul in a level. When the rider rides up to its
## gate (in the middle of the north side), the animals which follow her run
## into it.

const _GATE_WIDTH := 24.0

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


func _draw() -> void:
    var rect := Rect2(-pen_size * 0.5, pen_size).abs()
    draw_rect(rect, Palette.GRASS_LIGHT)
    var top_left := rect.position
    var bottom_right := rect.end
    var gate_left := -_GATE_WIDTH * 0.5
    var gate_right := _GATE_WIDTH * 0.5
    var segments := [
        [top_left, Vector2(gate_left, top_left.y)],
        [Vector2(gate_right, top_left.y), Vector2(bottom_right.x, top_left.y)],
        [Vector2(bottom_right.x, top_left.y), bottom_right],
        [bottom_right, Vector2(top_left.x, bottom_right.y)],
        [Vector2(top_left.x, bottom_right.y), top_left],
    ]
    for segment in segments:
        _fence(segment[0], segment[1])


## A wooden fence with posts.
func _fence(from: Vector2, to: Vector2) -> void:
    draw_line(from + Vector2(1, 1), to + Vector2(1, 1), Palette.SHADOW, 2.0)
    draw_line(from, to, Palette.OCHRE, 2.0)
    var length := from.distance_to(to)
    var count := maxi(1, int(length / 12.0))
    for i in range(count + 1):
        var at := from.lerp(to, float(i) / count).round()
        draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), Palette.HORSE_BAY)
