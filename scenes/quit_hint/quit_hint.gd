class_name QuitHint
extends Label

## Quit only on the second press of Escape, so that a stray key does not end the
## ride: the first press shows the hint for a moment.

## The second press must come within this many seconds.
const WINDOW := 2.0

var _left := 0.0


func _ready() -> void:
    horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visible = false


func _process(delta: float) -> void:
    if _left > 0.0:
        _left -= delta
        visible = _left > 0.0


## Handle a press of Escape: quit on the second press, else show the hint.
func press() -> void:
    if _left > 0.0:
        get_tree().quit()
        return
    text = tr("Press Esc again to quit.")
    _left = WINDOW
    visible = true
