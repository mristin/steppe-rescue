class_name MapView
extends Control

## Draw the map of the level, like a painted map on parchment: the landmarks
## and the yurts as their paintings seen from above, at their true size (but
## never too small to see), the river with its fords, the pen at home, the
## people of the steppe with their portraits, the rider as an arrow, and the
## clues the rider heard, each as a dashed area with the picture of the
## animals. The people whom Grandmother told her to ask, and whom she did not
## talk to yet, are ringed. It never shows the animals themselves.
##
## The map is drawn smoothly, at the resolution of the screen, not in the
## pixels of the game, so that it reads well even when small.
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
static var _pen: Texture2D = null

## The portraits by their ids, kept: a texture which nothing holds would draw
## white.
static var _portraits: Dictionary = {}

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

## The people of the steppe.
var people: Array[Person] = []

## The people whom Grandmother told the rider to ask, not visited yet.
var referred: Array[Person] = []

var large := false:
    set(value):
        if value != large:
            large = value
            _place()

var _time := 0.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    _place()


func _process(delta: float) -> void:
    _time += delta
    queue_redraw()


## Move the small map to the position on the screen.
func move_small(to: Vector2) -> void:
    small_rect.position = to
    if not large:
        position = to


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
    var to_map := func(at: Vector2) -> Vector2: return origin + at * scale

    # NOTE (mristin):
    # The steppe itself, a little greener than the parchment around it.
    var steppe := Rect2(origin, map.size * scale)
    draw_rect(steppe, Color(Palette.GRASS_LIGHT, 0.16))
    draw_rect(steppe, Color(Palette.HOOF, 0.35), false, 1.0, true)

    for landmark in map.landmarks():
        if landmark is River:
            _draw_river(landmark as River, to_map, scale)

    var home := map.home()
    if home != null:
        _draw_pen(home, to_map, scale)

    for landmark in map.landmarks():
        if not landmark is River:
            _draw_landmark(landmark, to_map.call(landmark.position), scale)

    for clue in clues:
        _draw_clue(clue, to_map, scale)

    for person in people:
        _draw_person(person, to_map.call(person.position))

    if has_partner:
        _draw_rider(to_map.call(partner_at), partner_heading, Palette.INDIGO_LIGHT, false)
    _draw_rider(to_map.call(rider_at), rider_heading, Palette.CRIMSON, true)

    if large:
        _draw_compass(Vector2(inner.end.x - 18.0, inner.position.y + 22.0))


## The pulse of the marks which call for attention, in [0, 1].
func _pulse(speed := 1.0) -> float:
    return 0.5 + 0.5 * sin(_time * TAU * speed)


## The landmark as its painting seen from above, at its true size, but never
## smaller than a few pixels, so that each one is found on the map.
func _draw_landmark(landmark: Landmark, at: Vector2, scale: float) -> void:
    var id := landmark.kind_id()
    var painting := Landmark.painted(id)
    var smallest := 26.0 if large else 6.0
    if painting != null:
        var side := maxf(smallest, landmark.size() * 2.0 * Landmark.PAINTED[id] * scale)
        var box := Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side)
        draw_circle(
            at + Vector2(1, 2) * (side / 24.0),
            side * 0.4,
            Color(Palette.HOOF, 0.25),
            true,
            -1.0,
            true
        )
        draw_texture_rect(painting, box, false)
        return
    var color: Color = _COLORS.get(id, Palette.STONE)
    draw_circle(at, maxf(smallest * 0.4, landmark.size() * scale), color, true, -1.0, true)
    if large:
        var icon := Icons.landmark(id)
        draw_texture(icon, (at - icon.get_size() * 0.5).round())


## The pen at home, as its painting.
func _draw_pen(home: Home, to_map: Callable, scale: float) -> void:
    if _pen == null:
        _pen = load(Home.PAINTING)
    var pen := home.pen()
    var width := maxf(pen.size.x * 1.25 * scale, 14.0 if large else 5.0)
    var height := width * _pen.get_height() / _pen.get_width()
    var center: Vector2 = to_map.call(pen.get_center())
    draw_texture_rect(
        _pen, Rect2(center - Vector2(width, height) * 0.5, Vector2(width, height)), false
    )


## A rider on the map: an arrow where she heads, with a ring pulsing around
## her own rider on the large map.
func _draw_rider(at: Vector2, heading: float, color: Color, own: bool) -> void:
    var length := 9.0 if large else 5.0
    if large and own:
        var pulse := _pulse(1.2)
        draw_circle(
            at,
            length + 4.0 + 4.0 * pulse,
            Color(color, 0.18 * (1.0 - pulse) + 0.08),
            true,
            -1.0,
            true
        )
        draw_circle(
            at, length + 4.0 + 4.0 * pulse, Color(color, 0.6 * (1.0 - pulse)), false, 1.5, true
        )
    var forward := Vector2.UP.rotated(heading)
    var side := forward.orthogonal()
    var tip := at + forward * length
    var back := at - forward * length * 0.6
    var arrow := PackedVector2Array(
        [
            tip,
            at - forward * length * 0.9 + side * length * 0.75,
            back,
            at - forward * length * 0.9 - side * length * 0.75
        ]
    )
    var outline := PackedVector2Array(arrow)
    outline.append(tip)
    draw_colored_polygon(arrow, color)
    draw_polyline(outline, Palette.FELT if own else Palette.OUTLINE, 1.5 if large else 1.0, true)


## The river as a band across the map, its banks darker and its middle
## lighter, broken by its fords, where stones show the way across.
func _draw_river(river: River, to_map: Callable, scale: float) -> void:
    var left: Vector2 = to_map.call(Vector2(0, river.position.y))
    var right: Vector2 = to_map.call(Vector2(map.size.x, river.position.y))
    var width := maxf(2.0, river.size() * 2.0 * scale)
    draw_line(left, right, Palette.EMERALD, width + 3.0, true)
    draw_line(left, right, Palette.SKY, width, true)
    draw_line(left, right, Color(Palette.SKY_LIGHT, 0.7), maxf(1.0, width * 0.3), true)
    for ford in river.fords:
        var at: Vector2 = to_map.call(Vector2(ford, river.position.y))
        var half := river.ford_width() * 0.5 * scale
        draw_line(at - Vector2(half, 0), at + Vector2(half, 0), Palette.OCHRE, width + 1.0, true)
        if large:
            var stones := maxi(2, int(half * 2.0 / 5.0))
            for i in range(stones):
                var x := lerpf(-half + 2.0, half - 2.0, float(i) / maxf(1.0, stones - 1.0))
                draw_circle(
                    at + Vector2(x, (i % 2) * 2.0 - 1.0), 1.6, Palette.STONE_LIGHT, true, -1.0, true
                )


## A person of the steppe: their portrait in a round golden frame on the large
## map, a golden dot on the small one; ringed in crimson while Grandmother
## told the rider to ask them.
func _draw_person(person: Person, at: Vector2) -> void:
    var asked := person in referred
    var radius := 11.0 if large else 2.5
    if asked:
        var pulse := _pulse(1.5)
        draw_circle(at, radius + 3.0 + 3.0 * pulse, Color(Palette.CRIMSON, 0.3), true, -1.0, true)
        draw_circle(at, radius + 3.0 + 3.0 * pulse, Palette.CRIMSON, false, 1.5, true)
    draw_circle(at, radius + 1.5, Palette.OUTLINE, true, -1.0, true)
    draw_circle(at, radius, Palette.GOLD, true, -1.0, true)
    if not large:
        return
    if not _portraits.has(person.portrait):
        _portraits[person.portrait] = Icons.portrait(person.portrait)
    var portrait: Texture2D = _portraits[person.portrait]
    var inner := radius - 1.5
    # NOTE (mristin):
    # The portrait cut round: a polygon of the circle with the texture mapped
    # onto it.
    var points := PackedVector2Array()
    var uvs := PackedVector2Array()
    for i in range(24):
        var direction := Vector2.from_angle(TAU * i / 24.0)
        points.append(at + direction * inner)
        uvs.append(Vector2(0.5, 0.45) + direction * 0.42)
    draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, portrait)
    if asked:
        var font := get_theme_default_font()
        var bubble := at + Vector2(radius, -radius)
        draw_circle(bubble, 6.0, Palette.OUTLINE, true, -1.0, true)
        draw_circle(bubble, 5.0, Palette.FELT, true, -1.0, true)
        draw_string(
            font,
            bubble + Vector2(-3.0, -8.0 + font.get_ascent(14)),
            "?",
            HORIZONTAL_ALIGNMENT_LEFT,
            -1,
            14,
            Palette.CRIMSON_DARK
        )


func _draw_clue(clue: Clue, to_map: Callable, scale: float) -> void:
    var area := map.clue_area(clue)
    if area.z <= 0.0:
        return
    var center: Vector2 = to_map.call(Vector2(area.x, area.y))
    var radius := maxf(4.0, area.z * scale)
    var done: bool = found.get(clue, false)
    var color := Palette.STONE if done else Palette.CRIMSON
    draw_circle(center, radius, Color(color, 0.12 if done else 0.16), true, -1.0, true)

    # NOTE (mristin):
    # The dashed edge of the area, as arcs, turning slowly while the animals
    # are still lost, so that the eye finds it.
    var dashes := maxi(8, int(radius * TAU / (10.0 if large else 6.0)))
    var turn := 0.0 if done else _time * 0.15
    for i in range(dashes):
        var from := TAU * i / dashes + turn
        draw_arc(
            center, radius, from, from + TAU / dashes * 0.55, 6, color, 2.0 if large else 1.0, true
        )

    if not large:
        draw_circle(center, 1.5, color, true, -1.0, true)
        return

    # NOTE (mristin):
    # The picture of the animals on a small card above the middle, so that it
    # does not hide the landmark of the clue, with their count.
    var icon := Icons.animal(clue.animal.id, 2.0)
    var card_size := icon.get_size() + Vector2(8, 6)
    if clue.count > 1:
        card_size.x += 16.0
    var card := Rect2((center - Vector2(card_size.x * 0.5, card_size.y + 6.0)).round(), card_size)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(Palette.FELT, 0.92)
    style.border_color = color
    style.set_border_width_all(2)
    style.set_corner_radius_all(5)
    style.anti_aliasing = true
    draw_style_box(style, card)
    draw_texture(icon, card.position + Vector2(4, 3), Color(1, 1, 1, 0.5) if done else Color.WHITE)
    if clue.count > 1:
        var font := get_theme_default_font()
        draw_string(
            font,
            Vector2(card.end.x - 17.0, card.position.y + 3.0 + font.get_ascent(16)),
            "×%d" % clue.count,
            HORIZONTAL_ALIGNMENT_LEFT,
            -1,
            16,
            Palette.OUTLINE
        )
    var pin := PackedVector2Array(
        [
            Vector2(card.get_center().x - 4.0, card.end.y),
            Vector2(card.get_center().x + 4.0, card.end.y),
            Vector2(card.get_center().x, card.end.y + 5.0)
        ]
    )
    draw_colored_polygon(pin, color)
    if done:
        # NOTE (mristin):
        # The animals are home: a green tick over the card.
        var tick := PackedVector2Array(
            [
                card.position + Vector2(6, card_size.y * 0.55),
                card.position + Vector2(card_size.x * 0.4, card_size.y - 3.0),
                card.position + Vector2(card_size.x - 5.0, 3.0)
            ]
        )
        draw_polyline(tick, Palette.OUTLINE, 5.0, true)
        draw_polyline(tick, Palette.EMERALD_LIGHT, 3.0, true)


## The compass rose, so that "north of the rock" means something: the north
## in crimson, the south in felt, on a round golden plate.
func _draw_compass(at: Vector2) -> void:
    draw_circle(at, 14.0, Color(Palette.OUTLINE, 0.6), true, -1.0, true)
    draw_circle(at, 13.0, Color(Palette.FELT, 0.9), true, -1.0, true)
    draw_circle(at, 13.0, Palette.GOLD, false, 1.5, true)
    var north := PackedVector2Array([at + Vector2(0, -11), at + Vector2(4, 0), at + Vector2(-4, 0)])
    var south := PackedVector2Array([at + Vector2(0, 11), at + Vector2(-4, 0), at + Vector2(4, 0)])
    var east := PackedVector2Array(
        [at + Vector2(8, 0), at + Vector2(0, 2.5), at + Vector2(0, -2.5)]
    )
    var west := PackedVector2Array(
        [at + Vector2(-8, 0), at + Vector2(0, -2.5), at + Vector2(0, 2.5)]
    )
    draw_colored_polygon(east, Palette.STONE)
    draw_colored_polygon(west, Palette.STONE)
    draw_colored_polygon(north, Palette.CRIMSON)
    draw_colored_polygon(south, Palette.OUTLINE)
    draw_circle(at, 1.5, Palette.GOLD, true, -1.0, true)
