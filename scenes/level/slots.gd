class_name Slots
extends Control

## Show the missing animals at the top of the screen, one slot each: dark while
## the animal is lost, bright while it follows the rider, and framed in gold
## once it is home.

const _SCALE := 2
const _GAP := 6

## The animals of the level, in the order of the slots.
var animals: Array[Animal] = []


func _process(_delta: float) -> void:
    queue_redraw()


func _draw() -> void:
    if animals.is_empty():
        return
    var icon_size := Vector2(12, 9) * _SCALE
    var width := animals.size() * (icon_size.x + _GAP) - _GAP
    var left := roundf((size.x - width) * 0.5)
    draw_rect(Rect2(left - 4, 0, width + 8, icon_size.y + 6), Palette.SHADOW)

    for i in range(animals.size()):
        var animal := animals[i]
        var at := Vector2(left + i * (icon_size.x + _GAP), 3)
        var texture := Icons.animal(animal.kind.id)
        var color := Color.WHITE
        if animal.is_lost():
            color = Color(0.1, 0.07, 0.05, 0.6)
        draw_texture_rect(texture, Rect2(at, icon_size), false, color)
        if animal.state == Animal.State.HOME:
            draw_rect(
                Rect2(at - Vector2(2, 2), icon_size + Vector2(4, 4)), Palette.GOLD, false, 1.0
            )
