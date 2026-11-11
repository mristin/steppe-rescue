class_name MapView
extends Control

## Draw the map of the level, like a map on felt: the landmarks, the yurts, the
## pen at home and the rider, and the clues the rider heard, each as a dotted
## area with the picture of the animals. It never shows the animals themselves.
##
## The map sits small in a corner; the player opens it [member large] with C.
## With two players, each has her own map in her half of the screen, which
## shows her partner, too (in indigo).

## The small map, in the coordinates of the screen.
const SMALL := Rect2(792, 8, 160, 120)

## The large map, in the coordinates of the screen.
const LARGE := Rect2(80, 40, 800, 460)

## The painting of the parchment behind the map.
const PARCHMENT := "res://assets/pictures/maps/minimap.png"

## The border of the parchment, as a fraction of its size.
const _BORDER := Vector2(0.065, 0.09)

const _COLORS := {
    "spring": Palette.SKY,
    "lake": Palette.SKY,
    "rock": Palette.STONE,
    "bushes": Palette.EMERALD,
    "birches": Palette.EMERALD_LIGHT,
    "kurgan": Palette.GRASS_DARK,
    "well": Palette.STONE,
    "yurt": Palette.CRIMSON,
    "pasture": Palette.EMERALD_LIGHT,
    "salt_lake": Color("#e8efe9"),
    "river": Palette.SKY,
    "creek": Palette.SKY,
}

static var _parchment: Texture2D = null

var map: LevelMap

## Where the rider is in the level, and her heading.
var rider_at := Vector2.ZERO
var rider_heading := 0.0

## Whether a partner rides, too, and where she is and her heading.
var has_partner := false
var partner_at := Vector2.ZERO
var partner_heading := 0.0

## Where the map sits small and large, in the coordinates of the screen.
var small_rect := SMALL
var large_rect := LARGE

## The clues which the rider heard so far.
var clues: Array[Clue] = []

## Which of the clues are done, since their animals were found.
var found := {}

var large := false:
    set(value):
        if value != large:
            large = value
            _place()

var _time := 0.0


func _ready() -> void:
    _place()


func _process(delta: float) -> void:
    _time += delta
    queue_redraw()


func _place() -> void:
    var rect := large_rect if large else small_rect
    position = rect.position
    size = rect.size


func _draw() -> void:
    # NOTE (mristin):
    # The painted parchment with its ornamented border, stretched to the map;
    # the steppe is drawn inside the border.
    if _parchment == null:
        _parchment = load(PARCHMENT)
    draw_texture_rect(_parchment, Rect2(Vector2.ZERO, size), false)
    if map == null:
        return

    var border := (size * _BORDER).round()
    var inner := Rect2(border, size - 2.0 * border)
    var scale := minf(inner.size.x / map.size.x, inner.size.y / map.size.y)
    var origin := inner.position + (inner.size - map.size * scale) * 0.5
    var to_map := func(at: Vector2) -> Vector2: return (origin + at * scale).round()

    var pen := map.home().pen() if map.home() != null else Rect2()
    if pen.has_area():
        var corner: Vector2 = to_map.call(pen.position)
        var pen_size := (pen.size * scale).round().max(Vector2(3, 3))
        draw_rect(Rect2(corner, pen_size), Palette.OCHRE, false, 1.0)

    for landmark in map.landmarks():
        if landmark is River:
            _draw_river(landmark as River, to_map, scale)
            continue
        var at: Vector2 = to_map.call(landmark.position)
        var color: Color = _COLORS.get(landmark.kind_id(), Palette.STONE)
        draw_circle(at, maxf(1.5, landmark.size() * scale), color)
        if large:
            var icon := Icons.landmark(landmark.kind_id())
            draw_texture(icon, (at - icon.get_size() * 0.5).round())

    for clue in clues:
        _draw_clue(clue, to_map, scale)

    if has_partner:
        _draw_rider(to_map.call(partner_at), partner_heading, Palette.INDIGO, Palette.OUTLINE)
    var blink := fposmod(_time, 1.0) < 0.7 or not large
    if blink:
        _draw_rider(to_map.call(rider_at), rider_heading, Palette.CRIMSON, Palette.CRIMSON_DARK)

    if large:
        _draw_compass(Vector2(size.x - 16, 18))


## A rider on the map: a dot with a line to where she heads.
func _draw_rider(at: Vector2, heading: float, color: Color, nose_color: Color) -> void:
    var dot := 2.0 if large else 1.0
    draw_rect(Rect2(at - Vector2.ONE * dot, Vector2.ONE * (2.0 * dot + 1.0)), color)
    var nose := at + Vector2.UP.rotated(heading) * (4.0 + 2.0 * dot)
    draw_line(at, nose.round(), nose_color, 1.0)


## The river as a band across the map, broken by its fords.
func _draw_river(river: River, to_map: Callable, scale: float) -> void:
    var left: Vector2 = to_map.call(Vector2(0, river.position.y))
    var right: Vector2 = to_map.call(Vector2(map.size.x, river.position.y))
    var width := maxf(2.0, river.size() * 2.0 * scale)
    draw_line(left, right, Palette.SKY, width)
    for ford in river.fords:
        var at: Vector2 = to_map.call(Vector2(ford, river.position.y))
        var half := river.ford_width() * 0.5 * scale
        draw_line(at - Vector2(half, 0), at + Vector2(half, 0), Palette.OCHRE, width)


func _draw_clue(clue: Clue, to_map: Callable, scale: float) -> void:
    var area := map.clue_area(clue)
    if area.z <= 0.0:
        return
    var center: Vector2 = to_map.call(Vector2(area.x, area.y))
    var radius := maxf(3.0, area.z * scale)
    var color := Palette.STONE if found.get(clue, false) else Palette.CRIMSON
    var dots := maxi(8, int(radius * 0.8))
    for i in range(dots):
        var at := center + Vector2.from_angle(TAU * i / dots) * radius
        draw_rect(Rect2(at.round(), Vector2.ONE), color)

    if not large:
        draw_rect(Rect2(center - Vector2.ONE, Vector2(2, 2)), color)
        return
    # NOTE (mristin):
    # The picture of the animals sits above the middle, so that it does not
    # hide the landmark of the clue.
    var icon := Icons.animal(clue.animal.id)
    var at := (center - icon.get_size() * 0.5 - Vector2(0, 10)).round()
    draw_texture(icon, at)
    if found.get(clue, false):
        var box := Rect2(at, icon.get_size())
        draw_line(box.position, box.end, Palette.OUTLINE, 1.0)
        draw_line(
            Vector2(box.end.x, box.position.y),
            Vector2(box.position.x, box.end.y),
            Palette.OUTLINE,
            1.0
        )


## The arrow to the north, so that "north of the rock" means something.
func _draw_compass(at: Vector2) -> void:
    var points := PackedVector2Array([at + Vector2(0, -9), at + Vector2(5, 4), at + Vector2(-5, 4)])
    draw_colored_polygon(points, Palette.OUTLINE)
    var inner := PackedVector2Array([at + Vector2(0, -7), at + Vector2(3, 3), at + Vector2(-3, 3)])
    draw_colored_polygon(inner, Palette.CRIMSON)
