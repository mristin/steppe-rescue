class_name DepthPlot
extends Control

## Plot how deep the player squats over the last seconds, with the counted
## squats as marks, for the movement test.

## How many seconds the plot shows.
const _SECONDS := 8.0

var _samples: Array[Vector2] = []
var _squats: Array[float] = []
var _time := 0.0


## Add the depth in [0, 1] and whether a squat was just counted.
func add(delta: float, depth: float, counted: bool) -> void:
    _time += delta
    _samples.append(Vector2(_time, depth))
    if counted:
        _squats.append(_time)
    while not _samples.is_empty() and _samples[0].x < _time - _SECONDS:
        _samples.pop_front()
    while not _squats.is_empty() and _squats[0] < _time - _SECONDS:
        _squats.pop_front()
    queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Palette.NIGHT)
    draw_rect(Rect2(Vector2.ZERO, size), Palette.OUTLINE, false, 2.0)

    var to_x := func(t: float) -> float: return size.x * (1.0 - (_time - t) / _SECONDS)

    for t in _squats:
        var x := roundf(to_x.call(t))
        draw_rect(Rect2(x, 2, 1, size.y - 4), Palette.CRIMSON)

    var previous := Vector2.INF
    for sample in _samples:
        var point := Vector2(to_x.call(sample.x), 2 + (size.y - 4) * sample.y).round()
        if previous != Vector2.INF:
            draw_line(previous, point, Palette.GOLD, 1.0)
        previous = point
