@tool
class_name Landmark
extends Node2D

## Place a landmark in a level and draw it, seen from above.
##
## The landmarks are what the people talk about, so each one is easy to
## recognize from above (see section 2 of DESIGN.md). They are drawn in code,
## in the palette, as placeholders until the drawn sprites arrive.

@export var kind: LandmarkKind:
    set(value):
        kind = value
        queue_redraw()

## The size in pixels; 0 takes the size of the kind.
@export var radius := 0.0:
    set(value):
        radius = value
        queue_redraw()


func size() -> float:
    if radius > 0.0:
        return radius
    return kind.radius if kind != null else 16.0


## How far from the center the landmark blocks the horse; 0 if it does not.
func solid_radius() -> float:
    return size() * (kind.solid if kind != null else 0.0)


func kind_id() -> String:
    return kind.id if kind != null else ""


func _draw() -> void:
    # NOTE (mristin):
    # The same landmark always looks the same, in the game and in the editor.
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(String(name)) ^ hash(Vector2i(position))
    var r := size()
    match kind_id():
        "spring":
            _blob(Vector2.ZERO, r, Palette.EMERALD_LIGHT)
            _blob(Vector2.ZERO, r * 0.6, Palette.SKY)
            draw_rect(Rect2(Vector2(-r * 0.2, -r * 0.25).round(), Vector2(2, 1)), Palette.SKY_LIGHT)
        "rock":
            draw_circle(Vector2(2, 2), r, Palette.SHADOW)
            _blob(Vector2.ZERO, r, Palette.STONE)
            draw_circle(Vector2(-r * 0.3, -r * 0.3).round(), r * 0.45, Palette.STONE_LIGHT)
        "bushes":
            for i in range(7):
                var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf() * r * 0.6
                _blob(at.round(), rng.randf_range(5.0, 8.0), Palette.EMERALD)
        "birches":
            _grove(rng, r)
        "lake":
            _lake(rng, r)
        "kurgan":
            draw_circle(Vector2.ZERO, r, Palette.GRASS_DARK)
            draw_circle(Vector2(-1, -1), r * 0.7, Palette.GRASS)
            draw_circle(Vector2(-2, -2), r * 0.35, Palette.GRASS_LIGHT)
        "well":
            _blob(Vector2.ZERO, r * 0.75, Palette.STONE)
            draw_circle(Vector2.ZERO, r * 0.4, Palette.NIGHT)
            draw_line(Vector2(-r * 2.5, -r * 2.0), Vector2(r * 0.6, r * 0.5), Palette.OCHRE, 2.0)
        "yurt":
            _yurt(r)
        _:
            _blob(Vector2.ZERO, r, Palette.CRIMSON)


## A filled circle with the outline.
func _blob(at: Vector2, r: float, color: Color) -> void:
    draw_circle(at, r + 1.0, Palette.OUTLINE)
    draw_circle(at, r, color)


func _grove(rng: RandomNumberGenerator, r: float) -> void:
    var trees: Array[Vector2] = []
    for i in range(int(r / 5.0)):
        trees.append((Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r * 0.8).round())
    trees.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
    for at in trees:
        draw_circle(at + Vector2(2, 3), 7.0, Palette.SHADOW)
    for at in trees:
        _blob(at, rng.randf_range(6.0, 9.0), Palette.EMERALD_LIGHT)
        draw_rect(Rect2(at + Vector2(-1, -2), Vector2(2, 1)), Palette.EMERALD)
        draw_rect(Rect2(at + Vector2(2, 1), Vector2(1, 2)), Palette.FELT)


func _lake(rng: RandomNumberGenerator, r: float) -> void:
    var parts: Array[Array] = [[Vector2.ZERO, r * 0.75]]
    for i in range(6):
        var at := Vector2.from_angle(TAU * i / 6.0 + rng.randf() * 0.5) * r * 0.45
        parts.append([at.round(), r * rng.randf_range(0.4, 0.55)])
    for part in parts:
        draw_circle(part[0], part[1] + 4.0, Palette.EMERALD_LIGHT)
    for part in parts:
        draw_circle(part[0], part[1] + 1.0, Palette.SKY_LIGHT)
    for part in parts:
        draw_circle(part[0], part[1], Palette.SKY)
    for i in range(5):
        var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf() * r * 0.5
        draw_rect(Rect2(at.round(), Vector2(4, 1)), Palette.SKY_LIGHT)


## A yurt from above: the felt dome with the poles of the roof running to the
## crown (the shanyrak) in the middle, a band of ornament at the edge, the
## door to the south.
func _yurt(r: float) -> void:
    draw_circle(Vector2(2, 2), r, Palette.SHADOW)
    _blob(Vector2.ZERO, r, Palette.FELT)
    for i in range(8):
        var direction := Vector2.from_angle(TAU * i / 8.0 + PI / 8.0)
        draw_line(direction * r * 0.3, direction * r * 0.85, Palette.STONE_LIGHT, 1.0)
    draw_arc(Vector2.ZERO, r - 1.0, 0.0, TAU, 32, Palette.CRIMSON, 1.0)
    draw_circle(Vector2.ZERO, r * 0.3, Palette.OUTLINE)
    draw_circle(Vector2.ZERO, r * 0.3 - 1.0, Palette.OCHRE)
    draw_line(Vector2(-r * 0.3, 0), Vector2(r * 0.3, 0), Palette.OUTLINE, 1.0)
    draw_line(Vector2(0, -r * 0.3), Vector2(0, r * 0.3), Palette.OUTLINE, 1.0)
    draw_rect(Rect2(Vector2(-3, r - 2.0).round(), Vector2(6, 4)), Palette.OUTLINE)
    draw_rect(Rect2(Vector2(-2, r - 1.0).round(), Vector2(4, 3)), Palette.OCHRE)
