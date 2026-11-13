class_name Hearing
extends Control

## Show the animals which the rider hears but does not see: a picture of the
## animal with sound waves at the edge of the screen, where the line from the
## rider to the animal leaves the screen (see section 4 of DESIGN.md).
##
## The closer the animal, the bigger and brighter the picture and the faster
## its waves pulse.

## The rider hears the animals up to this far, in pixels (about two screens).
const RADIUS := 600.0

const _INSET := 18.0

## What the rider hears, each a dictionary with "id" (the kind of the animal),
## "at" (where it is in the level) and "closeness" (in [0, 1]); set by the level.
var heard: Array[Dictionary] = []

## Where the rider is in the level.
var rider_at := Vector2.ZERO

## How the level maps onto this control: the view of the rider (see
## [LevelPlayer]).
var view := Transform2D.IDENTITY

var _time := 0.0


func _process(delta: float) -> void:
    _time += delta
    queue_redraw()


## Listen at the point of the level, where the rider is: she hears every
## lost animal near her which she does not see, and every follower which lags
## far behind and calls out (see [member Animal.lagging]), each with its own
## picture at the edge of the screen, in its direction, like a compass (see
## section 4 of DESIGN.md).
func listen(animals: Array[Animal], at: Vector2) -> void:
    heard.clear()
    rider_at = at
    for animal in animals:
        var calling := animal.state == Animal.State.FOLLOWING and animal.lagging
        if not animal.is_lost() and not calling:
            continue
        var distance := animal.position.distance_to(at)
        if distance < RADIUS and not on_screen(animal.position):
            (
                heard
                . append(
                    {
                        "id": animal.kind.id,
                        "at": animal.position,
                        "closeness": 1.0 - distance / RADIUS,
                    }
                )
            )


## Whether the point of the level is on the screen.
func on_screen(at: Vector2) -> bool:
    var screen := view * at
    return Rect2(Vector2.ZERO, size).grow(-4.0).has_point(screen)


func _draw() -> void:
    var transform := view
    var center := transform * rider_at
    var inner := Rect2(Vector2.ONE * _INSET, size - Vector2.ONE * 2.0 * _INSET)
    for sound in heard:
        var target: Vector2 = transform * (sound["at"] as Vector2)
        var direction := (target - center).normalized()
        if direction == Vector2.ZERO:
            continue
        var t := INF
        if direction.x > 0.0:
            t = minf(t, (inner.end.x - center.x) / direction.x)
        elif direction.x < 0.0:
            t = minf(t, (inner.position.x - center.x) / direction.x)
        if direction.y > 0.0:
            t = minf(t, (inner.end.y - center.y) / direction.y)
        elif direction.y < 0.0:
            t = minf(t, (inner.position.y - center.y) / direction.y)
        _draw_sound((center + direction * t).round(), direction, sound)


func _draw_sound(at: Vector2, direction: Vector2, sound: Dictionary) -> void:
    var closeness: float = sound["closeness"]
    var scale := 2.0 if closeness > 0.5 else 1.0
    var alpha := 0.45 + 0.55 * closeness
    var texture := Icons.animal(sound["id"], scale)
    var icon := texture.get_size()

    draw_circle(at, icon.x * 0.5 + 3.0, Color(Palette.OUTLINE, alpha))
    draw_circle(at, icon.x * 0.5 + 2.0, Color(Palette.FELT, alpha))
    draw_texture_rect(texture, Rect2((at - icon * 0.5).round(), icon), false, Color(1, 1, 1, alpha))

    # NOTE (mristin):
    # The waves run from the animal towards the rider.
    var rate := lerpf(0.8, 2.5, closeness)
    var inward := (-direction).angle()
    for offset in [0.0, 0.5]:
        var phase := fposmod(_time * rate + offset, 1.0)
        var radius := icon.x * 0.5 + 4.0 + phase * 8.0 * scale
        draw_arc(
            at,
            radius,
            inward - 0.7,
            inward + 0.7,
            8,
            Color(Palette.GOLD, alpha * (1.0 - phase)),
            1.0
        )
