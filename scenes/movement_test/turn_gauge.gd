class_name TurnGauge
extends Control

## Show the turn of the horse in [-1, 1] as a marker on a gauge: left of the
## middle turns left, right of it turns right.

## The turn in [-1, 1], set every frame.
var turn := 0.0


func _process(_delta: float) -> void:
    queue_redraw()


func _draw() -> void:
    var bar := Rect2(Vector2(2, size.y * 0.5 - 3), Vector2(size.x - 4, 6))
    draw_rect(bar.grow(2), Palette.OUTLINE)
    draw_rect(bar, Palette.GRASS_DARK)

    var middle := roundf(bar.position.x + bar.size.x * 0.5)
    var x := roundf(middle + bar.size.x * 0.5 * clampf(turn, -1.0, 1.0))
    draw_rect(Rect2(minf(middle, x), bar.position.y, absf(x - middle), bar.size.y), Palette.GOLD)
    draw_rect(Rect2(middle, bar.position.y - 3, 1, bar.size.y + 6), Palette.FELT)
    draw_rect(Rect2(x - 2, bar.position.y - 4, 5, bar.size.y + 8), Palette.CRIMSON)
