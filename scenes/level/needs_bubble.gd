class_name NeedsBubble
extends Node2D

## Show above the horse what it needs, without words: a bubble with a drop of
## water when it is thirsty, with a tuft of grass when it is hungry, and the
## picture dipping while it drinks or grazes (see section 4 of DESIGN.md).

## The bubble floats this high above the horse, in pixels.
const _HEIGHT := 30.0

## With both needs, the bubble shows each for this long, in seconds.
const _SWITCH_SECONDS := 1.5

## The water and the food of the horse, set by the game.
var needs: HorseNeeds = null

var _time := 0.0


func _process(delta: float) -> void:
    _time += delta
    queue_redraw()


func _draw() -> void:
    if needs == null:
        return

    if needs.drinking or needs.grazing:
        var icon := Icons.water() if needs.drinking else Icons.grass()
        var dip := 2.0 if fposmod(_time * 1.5, 1.0) < 0.5 else 0.0
        draw_texture(icon, (Vector2(-icon.get_width() * 0.5, -_HEIGHT + dip)).round())
        return

    var wants: Array[Texture2D] = []
    if needs.thirsty():
        wants.append(Icons.water())
    if needs.hungry():
        wants.append(Icons.grass())
    if wants.is_empty():
        return

    var icon: Texture2D = wants[int(_time / _SWITCH_SECONDS) % wants.size()]
    var rise := roundf(sin(_time * 3.0) * 1.5)
    var center := Vector2(0.0, -_HEIGHT + rise)
    var radius := icon.get_width() * 0.5 + 3.0
    draw_circle(Vector2(5, -14), 2.0, Palette.OUTLINE)
    draw_circle(Vector2(5, -14), 1.5, Palette.FELT)
    draw_circle(Vector2(3, -18 + rise * 0.5), 3.0, Palette.OUTLINE)
    draw_circle(Vector2(3, -18 + rise * 0.5), 2.5, Palette.FELT)
    draw_circle(center, radius + 1.0, Palette.OUTLINE)
    draw_circle(center, radius, Palette.FELT)
    draw_texture(icon, (center - icon.get_size() * 0.5).round())
