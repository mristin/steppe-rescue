@tool
class_name Landmark
extends Node2D

## Place a landmark in a level and draw it, seen from above.
##
## The landmarks are what the people talk about, so each one is easy to
## recognize from above (see section 2 of DESIGN.md). They are paintings
## (assets/pictures/landmarks/), each with a ring of grass around it, drawn
## bigger than the size which blocks the horse (see [constant PAINTED]) and
## filtered smoothly at any size. A landmark without a painting is drawn as
## vectors (SVG) and pixelated by [Pixelate].

## How many times its size the painting of each kind is wide.
const PAINTED := {
    "spring": 2.4,
    "rock": 3.0,
    "bushes": 1.6,
    "birches": 1.3,
    "lake": 1.35,
    "salt_lake": 1.35,
    "pasture": 1.2,
    "kurgan": 1.4,
    "well": 6.0,
    "yurt": 2.0,
}

static var _paintings: Dictionary = {}

@export var kind: LandmarkKind:
    set(value):
        kind = value
        queue_redraw()

## The size in pixels; 0 takes the size of the kind.
@export var radius := 0.0:
    set(value):
        radius = value
        queue_redraw()


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


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
    var r := size()
    var painting := painted(kind_id())
    if painting != null:
        var side: float = r * 2.0 * PAINTED[kind_id()]
        draw_texture_rect(painting, Rect2(-side * 0.5, -side * 0.5, side, side), false)
        return
    if kind_id() in ["rock", "yurt"]:
        draw_circle(Vector2(2, 2), r, Palette.SHADOW)
    var texture := picture()
    draw_texture(texture, (-texture.get_size() * 0.5).round())


## The painting of the landmark of the kind, seen from above; null if there
## is none.
static func painted(id: String) -> Texture2D:
    if not PAINTED.has(id):
        return null
    if not _paintings.has(id):
        _paintings[id] = load("res://assets/pictures/landmarks/%s.png" % id)
    return _paintings[id]


## The landmark seen from above, pixelated from its vectors, centered.
func picture() -> ImageTexture:
    # NOTE (mristin):
    # The same landmark always looks the same, in the game and in the editor.
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(String(name)) ^ hash(Vector2i(position))
    var r := size()
    var body := svg(kind_id(), r, rng)
    var half := ceilf(r * (2.6 if kind_id() == "well" else 1.0)) + 6.0
    return Pixelate.texture(body, Rect2(-half, -half, 2.0 * half, 2.0 * half))


## The landmark of the kind and the size as vectors (SVG) around its center.
static func svg(id: String, r: float, rng: RandomNumberGenerator) -> String:
    var parts := PackedStringArray()
    match id:
        "spring":
            parts.append(_circle(Vector2.ZERO, r, "{emerald_light}"))
            parts.append(_circle(Vector2.ZERO, r * 0.6, "{sky}"))
            parts.append(_ellipse(Vector2(-r * 0.15, -r * 0.2), r * 0.25, r * 0.08, "{sky_light}"))
            for i in range(6):
                var at := Vector2.from_angle(TAU * i / 6.0 + rng.randf()) * r * 0.8
                parts.append(_blade(at, "{emerald}"))
        "rock":
            var points := PackedVector2Array()
            for i in range(9):
                points.append(Vector2.from_angle(TAU * i / 9.0) * r * rng.randf_range(0.85, 1.0))
            parts.append(_polygon(points, "{stone}"))
            var light := PackedVector2Array()
            for point in points.slice(4, 8):
                light.append(point * 0.6 + Vector2(-r * 0.15, -r * 0.15))
            light.append(Vector2(-r * 0.1, -r * 0.1))
            parts.append(_polygon(light, "{stone_light}"))
        "bushes":
            for i in range(7):
                var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf() * r * 0.6
                var size := rng.randf_range(5.0, 8.0)
                parts.append(_circle(at, size, "{emerald}"))
                parts.append(_circle(at + Vector2(-1.5, -1.5), size * 0.35, "{emerald_light}"))
        "birches":
            var trees: Array[Vector2] = []
            for i in range(int(r / 5.0)):
                trees.append(Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r * 0.8)
            trees.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
            for at in trees:
                var crown := rng.randf_range(6.0, 9.0)
                parts.append(_circle(at, crown, "{emerald_light}"))
                parts.append(_circle(at + Vector2(1.5, 1.5), crown * 0.45, "{emerald}"))
                parts.append(_ellipse(at + Vector2(crown * 0.5, crown * 0.3), 1.2, 0.6, "{felt}"))
        "lake", "pasture":
            var parts_of := [[Vector2.ZERO, r * 0.75]]
            for i in range(6):
                var at := Vector2.from_angle(TAU * i / 6.0 + rng.randf() * 0.5) * r * 0.45
                parts_of.append([at, r * rng.randf_range(0.4, 0.55)])
            if id == "lake":
                for part in parts_of:
                    parts.append(_circle(part[0], part[1] + 4.0, "{emerald_light}"))
                for part in parts_of:
                    parts.append(_circle(part[0], part[1] + 1.0, "{sky_light}"))
                for part in parts_of:
                    parts.append(_circle(part[0], part[1], "{sky}"))
                for i in range(5):
                    var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf() * r * 0.5
                    parts.append(_ellipse(at, 2.0, 0.4, "{sky_light}"))
            else:
                for part in parts_of:
                    parts.append(_circle(part[0], part[1], "{emerald_light}"))
                for i in range(int(r * r / 40.0)):
                    var at := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r * 0.85
                    parts.append(_blade(at, "{emerald}"))
                for i in range(int(r / 6.0)):
                    var at := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r * 0.8
                    var flower := "{gold}" if rng.randf() < 0.5 else "{felt}"
                    parts.append(_circle(at, 0.8, flower))
        "kurgan":
            parts.append(_circle(Vector2.ZERO, r, "{grass_dark}"))
            parts.append(_circle(Vector2(-1, -1), r * 0.7, "{grass}"))
            parts.append(_circle(Vector2(-2, -2), r * 0.35, "{grass_light}"))
        "well":
            parts.append(
                (
                    (
                        '<path d="M%s %s L%s %s" stroke="{ochre}" stroke-width="2" '
                        + 'stroke-linecap="round"/>'
                    )
                    % [_n(-r * 2.5), _n(-r * 2.0), _n(r * 0.6), _n(r * 0.5)]
                )
            )
            parts.append(_circle(Vector2(-r * 0.6, -r * 0.5), 1.6, "{bay}"))
            parts.append(_circle(Vector2.ZERO, r * 0.75, "{stone}"))
            parts.append(_circle(Vector2.ZERO, r * 0.4, "{night}"))
        "yurt":
            parts.append(_circle(Vector2.ZERO, r, "{felt}"))
            for i in range(8):
                var direction := Vector2.from_angle(TAU * i / 8.0 + PI / 8.0)
                parts.append(_line(direction * r * 0.3, direction * r * 0.85, "{stone_light}", 0.8))
            parts.append(
                '<circle r="%s" fill="none" stroke="{crimson}" stroke-width="1.2"/>' % _n(r - 1.0)
            )
            parts.append(_circle(Vector2.ZERO, r * 0.3, "{outline}"))
            parts.append(_circle(Vector2.ZERO, r * 0.3 - 0.8, "{ochre}"))
            parts.append(_line(Vector2(-r * 0.3, 0), Vector2(r * 0.3, 0), "{outline}", 0.6))
            parts.append(_line(Vector2(0, -r * 0.3), Vector2(0, r * 0.3), "{outline}", 0.6))
            parts.append('<rect x="-3" y="%s" width="6" height="4" fill="{ochre}"/>' % _n(r - 2.0))
        _:
            parts.append(_circle(Vector2.ZERO, r, "{crimson}"))
    return "".join(parts)


## The landmarks of every kind, for dev/pictures/contact_sheet.gd.
static func contact_sheet() -> Array:
    var result := []
    for id in ["spring", "rock", "bushes", "birches", "lake", "pasture", "kurgan", "well", "yurt"]:
        var rng := RandomNumberGenerator.new()
        rng.seed = 5
        var r := 40.0 if id in ["lake", "birches", "pasture"] else 16.0
        var half := ceilf(r * (2.6 if id == "well" else 1.0)) + 6.0
        result.append(Pixelate.texture(svg(id, r, rng), Rect2(-half, -half, 2 * half, 2 * half)))
    return result


static func _circle(at: Vector2, r: float, color: String) -> String:
    return '<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % [_n(at.x), _n(at.y), _n(r), color]


static func _ellipse(at: Vector2, rx: float, ry: float, color: String) -> String:
    return (
        '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"/>'
        % [_n(at.x), _n(at.y), _n(rx), _n(ry), color]
    )


static func _line(from: Vector2, to: Vector2, color: String, width: float) -> String:
    return (
        '<path d="M%s %s L%s %s" stroke="%s" stroke-width="%s"/>'
        % [_n(from.x), _n(from.y), _n(to.x), _n(to.y), color, _n(width)]
    )


static func _polygon(points: PackedVector2Array, color: String) -> String:
    var coordinates := PackedStringArray()
    for point in points:
        coordinates.append("%s,%s" % [_n(point.x), _n(point.y)])
    return '<polygon points="%s" fill="%s"/>' % [" ".join(coordinates), color]


## A blade of grass, standing up.
static func _blade(at: Vector2, color: String) -> String:
    return (
        '<path d="M%s %s L%s %s L%s %s Z" fill="%s"/>'
        % [
            _n(at.x - 0.8),
            _n(at.y + 1.2),
            _n(at.x),
            _n(at.y - 2.0),
            _n(at.x + 0.8),
            _n(at.y + 1.2),
            color
        ]
    )


static func _n(value: float) -> String:
    return String.num(value, 3)
