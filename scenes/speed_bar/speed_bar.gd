class_name SpeedBar
extends Control

## Show the speed of the horse as a bar between three horse icons: a horse
## walking at the left, trotting in the middle and galloping at the right.
##
## The bar fills from the left with the speed. The icon of the gait which the
## fill has reached lights up and moves; the icons of the faster gaits stay
## dim. This is how the player sees, without any words, that squatting faster
## makes the horse go faster. The horses are painted (see [PaintedHorse]).

const _BAR_HEIGHT := 8

## The speed in [0, 1], set by the game every frame.
var speed := 0.0

## The speeds from which the horse walks, trots and gallops (see
## SquatMeter.WalkFrom, TrotFrom and GallopFrom in C#).
var thresholds := Vector3(0.05, 0.45, 0.8)

var _time := 0.0


func _process(delta: float) -> void:
    _time += delta
    queue_redraw()


## The gait at the speed: 0 stands, 1 walks, 2 trots and 3 gallops.
func gait() -> int:
    if speed >= thresholds.z:
        return 3
    if speed >= thresholds.y:
        return 2
    if speed >= thresholds.x:
        return 1
    return 0


func _draw() -> void:
    var bar_top := size.y - _BAR_HEIGHT - 2
    var bar := Rect2(Vector2(2, bar_top), Vector2(size.x - 4, _BAR_HEIGHT))

    draw_rect(bar.grow(2), Palette.OUTLINE)
    draw_rect(bar, Palette.GRASS_DARK)
    var fill := bar
    fill.size.x = roundf(bar.size.x * clampf(speed, 0.0, 1.0))
    draw_rect(fill, Palette.GOLD)

    # NOTE (mristin):
    # The marks where the gaits change.
    for threshold in [thresholds.y, thresholds.z]:
        var x := roundf(bar.position.x + bar.size.x * threshold)
        draw_rect(Rect2(x, bar.position.y, 1, bar.size.y), Palette.OUTLINE)

    var current := gait()
    var zones := [
        [thresholds.x, thresholds.y],
        [thresholds.y, thresholds.z],
        [thresholds.z, 1.0],
    ]
    for i in range(3):
        var icon_gait := i + 1
        var zone: Array = zones[i]
        var middle: float = (zone[0] + zone[1]) * 0.5
        var center := bar.position.x + bar.size.x * middle
        var frame := PaintedHorse.frame_at(icon_gait, _time) if icon_gait == current else 0
        var icon_size := PaintedHorse.size(true)
        var ground := Vector2(roundf(center), bar_top - 4)
        var reached := icon_gait <= current
        var tint := Color.WHITE if reached else Color(0.35, 0.3, 0.3, 0.6)
        PaintedHorse.draw(self, icon_gait, frame, ground, true, tint)
        var position := ground - icon_size * PaintedHorse.ANCHOR
        if icon_gait == current:
            draw_rect(Rect2(position.x, bar_top - 3, icon_size.x, 1), Palette.GOLD)
