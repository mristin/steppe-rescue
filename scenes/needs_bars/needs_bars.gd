class_name NeedsBars
extends Control

## Show the water and the food of the horse, next to the speed bar: two bars,
## each with its picture (a drop of water and a tuft of grass). A bar blinks
## when it runs low, and fills visibly while the horse drinks or grazes (see
## section 4 of DESIGN.md, "Water and grass for the horse").

const _ICON_SCALE := 2.0
const _BAR_HEIGHT := 8.0
const _GAP := 4.0

## How fast a low bar blinks, in blinks per second.
const _BLINK_RATE := 2.5

## The water and the food of the horse, set by the game.
var needs: HorseNeeds = null

var _time := 0.0


func _process(delta: float) -> void:
    _time += delta
    queue_redraw()


func _draw() -> void:
    if needs == null:
        return
    var row := (size.y - _GAP) * 0.5
    _draw_bar(0.0, Icons.water(_ICON_SCALE), needs.water, Palette.SKY, needs.drinking)
    _draw_bar(
        row + _GAP, Icons.grass(_ICON_SCALE), needs.food, Palette.EMERALD_LIGHT, needs.grazing
    )


func _draw_bar(top: float, icon: Texture2D, value: float, color: Color, filling: bool) -> void:
    var icon_size := icon.get_size()
    var row := (size.y - _GAP) * 0.5
    var low := value < HorseNeeds.LOW
    var blink := low and fposmod(_time * _BLINK_RATE, 1.0) < 0.5

    var icon_at := Vector2(0.0, roundf(top + (row - icon_size.y) * 0.5))
    if filling:
        # NOTE (mristin):
        # The picture bobs while the horse drinks or grazes.
        icon_at.y -= 1.0 if fposmod(_time * 3.0, 1.0) < 0.5 else 0.0
    draw_texture(icon, icon_at, Color.WHITE if not blink else Color(1, 1, 1, 0.35))

    var left := icon_size.x + _GAP
    var bar := Rect2(
        Vector2(left + 2.0, roundf(top + (row - _BAR_HEIGHT) * 0.5)),
        Vector2(size.x - left - 4.0, _BAR_HEIGHT)
    )
    draw_rect(bar.grow(2.0), Palette.CRIMSON if blink else Palette.OUTLINE)
    draw_rect(bar, Palette.GRASS_DARK)
    var fill := bar
    fill.size.x = roundf(bar.size.x * clampf(value, 0.0, 1.0) * 2.0) * 0.5
    draw_rect(fill, Palette.CRIMSON if low else color)
