@tool
class_name Herd
extends Node2D

## Place the lost animals in a level: [member count] animals of the
## [member animal] kind, grazing around this point.
##
## The game never shows where the animals are, so the herd is only drawn in
## the editor.

## The animals keep this far apart, in pixels.
const SPACING := 14.0

@export var animal: AnimalKind:
    set(value):
        animal = value
        queue_redraw()

@export_range(1, 9) var count := 1:
    set(value):
        count = value
        queue_redraw()


## Where each animal of the herd starts, relative to the herd.
func spots() -> Array[Vector2]:
    var result: Array[Vector2] = []
    if count == 1:
        result.append(Vector2.ZERO)
        return result
    for i in range(count):
        result.append((Vector2.from_angle(TAU * i / count) * SPACING).round())
    return result


func _draw() -> void:
    if not Engine.is_editor_hint():
        return
    var texture := Icons.animal(animal.id if animal != null else "sheep")
    for spot in spots():
        draw_texture(texture, spot - (texture.get_size() * 0.5).floor())
