@tool
class_name LevelMap
extends Node2D

## Hold a level as data: the steppe of [member size] with its landmarks
## ([Landmark]), the people ([Person]) with their clues, the lost animals
## ([Herd]), the pen at home ([Home]) and the start of the rider (the
## [Marker2D] named "Start", whose rotation is her heading).
##
## The levels live in [code]data/levels/[/code] as scenes, so that they can
## be edited in the Godot editor; the tests check every level with
## [method problems].

## The painted ground, a seamless tile (see [method _ground_texture]).
const _GROUND_PAINTING := "res://assets/pictures/ground/steppe.png"

## The tile of the ground is this many logical pixels wide.
const _GROUND_TILE := 400

## The animals are near a landmark if they are this much farther than its size.
const _NEAR := 90.0

## The animals on one side of a landmark are this far beyond its size...
const _SIDE_DISTANCE := 130.0

## ... in a circle of this radius.
const _SIDE_RADIUS := 110.0

## The horse drinks within this distance from the edge of the water, in
## pixels; the water blocks the horse (see [member LandmarkKind.solid]), so it
## stands at the shore.
const _SHORE := 12.0

const _SIDES := {
    "north": Vector2.UP,
    "south": Vector2.DOWN,
    "east": Vector2.RIGHT,
    "west": Vector2.LEFT,
}

static var _ground: ImageTexture = null

## The name of the level, e.g., on its banner in the level select.
@export var title := ""

## What Grandmother says when all the animals are home; {rider} is the name of
## the rider.
@export_multiline var thanks := ""

## The size of the steppe in pixels.
@export var size := Vector2(1920, 1280):
    set(value):
        size = value
        queue_redraw()

## A rider who brings all the animals home within this many seconds gets three
## stars, within twice as long two, and later one.
@export var par_seconds := 240.0


func _ready() -> void:
    texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func landmarks() -> Array[Landmark]:
    var result: Array[Landmark] = []
    for child in get_children():
        if child is Landmark:
            result.append(child)
    return result


func people() -> Array[Person]:
    var result: Array[Person] = []
    for child in get_children():
        if child is Person:
            result.append(child)
    return result


func herds() -> Array[Herd]:
    var result: Array[Herd] = []
    for child in get_children():
        if child is Herd:
            result.append(child)
    return result


func home() -> Home:
    for child in get_children():
        if child is Home:
            return child
    return null


func start() -> Marker2D:
    return get_node_or_null("Start") as Marker2D


func landmark(node_name: String) -> Landmark:
    return get_node_or_null(node_name) as Landmark


## The circles which block the horse, each as (x, y, radius); without the
## creeks, which it jumps over (see [method jumpable]).
func solids() -> Array[Vector3]:
    var result: Array[Vector3] = []
    for each in landmarks():
        var radius := each.solid_radius()
        if radius > 0.0:
            result.append(Vector3(each.position.x, each.position.y, radius))
        if each is River and not each is Creek:
            result.append_array((each as River).solids())
    return result


## The circles which block the horse on the ground, but which it jumps over
## (the creeks), each as (x, y, radius).
func jumpable() -> Array[Vector3]:
    var result: Array[Vector3] = []
    for each in landmarks():
        if each is Creek:
            result.append_array((each as Creek).solids())
    return result


## The horse at this point stands at fresh water, close enough to drink.
func at_fresh_water(at: Vector2) -> bool:
    for each in landmarks():
        if each is River:
            if (each as River).at_water(at, _SHORE):
                return true
        elif each.kind != null and each.kind.fresh_water:
            if at.distance_to(each.position) <= each.size() + _SHORE:
                return true
    return false


## The horse at this point stands on a pasture, where it can graze.
func on_pasture(at: Vector2) -> bool:
    for each in landmarks():
        if each.kind != null and each.kind.pasture:
            if at.distance_to(each.position) <= each.size():
                return true
    return false


## The area which the clue marks, as (x, y, radius); zero if its landmarks are
## missing.
func clue_area(clue: Clue) -> Vector3:
    var first := landmark(clue.landmark)
    if first == null:
        return Vector3.ZERO
    if clue.form == "near":
        return Vector3(first.position.x, first.position.y, first.size() + _NEAR)
    if clue.form == "between":
        var second := landmark(clue.other)
        if second == null:
            return Vector3.ZERO
        var middle := (first.position + second.position) * 0.5
        var radius := maxf(80.0, 0.35 * first.position.distance_to(second.position))
        return Vector3(middle.x, middle.y, radius)
    var direction: Vector2 = _SIDES.get(clue.form, Vector2.ZERO)
    var center := first.position + direction * (first.size() + _SIDE_DISTANCE)
    return Vector3(center.x, center.y, _SIDE_RADIUS)


## The herd which the clue points to: the first herd of its kind in its area.
func herd_of(clue: Clue) -> Herd:
    var area := clue_area(clue)
    for herd in herds():
        if (
            herd.animal == clue.animal
            and herd.position.distance_to(Vector2(area.x, area.y)) <= area.z
        ):
            return herd
    return null


## The clue as the person says it, in the language of the game.
func clue_text(clue: Clue) -> String:
    var pattern := ""
    match clue.form:
        "near":
            # TRANSLATORS: {landmark@near} is a landmark in its form "near", e.g., "у родника".
            pattern = tr("I saw {animals} near {landmark@near}.")
        "between":
            # TRANSLATORS: {landmark@and}, {other@between}: landmarks in the forms "and", "between".
            pattern = tr("I saw {animals} between {landmark@and} and {other@between}.")
        "north":
            # TRANSLATORS: {landmark@of} is a landmark in its form "of", e.g., "родника".
            pattern = tr("I saw {animals} north of {landmark@of}.")
        "south":
            # TRANSLATORS: {landmark@of} is a landmark in its form "of", e.g., "родника".
            pattern = tr("I saw {animals} south of {landmark@of}.")
        "east":
            # TRANSLATORS: {landmark@of} is a landmark in its form "of", e.g., "родника".
            pattern = tr("I saw {animals} east of {landmark@of}.")
        "west":
            # TRANSLATORS: {landmark@of} is a landmark in its form "of", e.g., "родника".
            pattern = tr("I saw {animals} west of {landmark@of}.")

    var first := landmark(clue.landmark)
    var second := landmark(clue.other)
    var text := (
        Grammar
        . format(
            pattern,
            {
                "animals": clue.animal.one if clue.count == 1 else clue.animal.many,
                "landmark": first.kind.name if first != null else "",
                "other": second.kind.name if second != null else "",
            }
        )
    )

    # NOTE (mristin):
    # A translation may start with a name in a form, e.g., "бұлақтың жанында ...".
    return text.left(1).to_upper() + text.substr(1)


## The problems of the level, if any: what the tests check for every level.
func problems() -> PackedStringArray:
    var result := PackedStringArray()
    if home() == null:
        result.append("the level has no home")
    if start() == null:
        result.append("the level has no start")
    if not people().any(func(p: Person) -> bool: return p.portrait == "grandmother"):
        result.append("the level has no grandmother, who sends the rider out")
    if herds().is_empty():
        result.append("the level has no animals to find")
    if not landmarks().any(func(l: Landmark) -> bool: return l.kind != null and l.kind.fresh_water):
        result.append("the level has no fresh water, where the horse drinks")
    if not landmarks().any(func(l: Landmark) -> bool: return l.kind != null and l.kind.pasture):
        result.append("the level has no pasture, where the horse grazes")

    var bounds := Rect2(Vector2.ZERO, size).grow(-24.0)
    for herd in herds():
        if herd.animal == null:
            result.append("the herd %s has no kind" % herd.name)
            continue
        for spot in herd.spots():
            var at := herd.position + spot
            if not bounds.has_point(at):
                result.append("the herd %s is outside the steppe" % herd.name)
            for solid in solids():
                if at.distance_to(Vector2(solid.x, solid.y)) < solid.z + 8.0:
                    result.append("the herd %s stands in a landmark" % herd.name)

    var covered := {}
    for person in people():
        if not bounds.has_point(person.position):
            result.append("the person %s is outside the steppe" % person.name)
        for clue in person.clues:
            result.append_array(_clue_problems(person, clue))
            var herd := herd_of(clue)
            if herd != null:
                covered[herd] = true

    for herd in herds():
        if not covered.has(herd) and herd.animal != null:
            result.append("no clue points to the herd %s" % herd.name)
    for what in unreachable():
        result.append("the rider cannot reach %s from the start" % what)
    return result


## What the rider cannot reach from the start: the names of the herds and the
## people, and "the gate" of the pen; found by flooding a grid of the steppe
## from the start around what blocks the horse.
func unreachable() -> PackedStringArray:
    var result := PackedStringArray()
    if start() == null:
        return result
    var step := 12.0
    var cells := Vector2i((size / step).floor())
    var blocked := solids()
    var is_free := func(point: Vector2) -> bool:
        if not Rect2(Vector2.ZERO, size).grow(-Rider.EDGE).has_point(point):
            return false
        for solid in blocked:
            if point.distance_to(Vector2(solid.x, solid.y)) < solid.z + Rider.RADIUS:
                return false
        return true
    var seen := {}
    var first := Vector2i((start().position / step).round())
    var stack: Array[Vector2i] = [first]
    seen[first] = true
    while not stack.is_empty():
        var cell: Vector2i = stack.pop_back()
        for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
            var next: Vector2i = cell + direction
            if next.x < 0 or next.y < 0 or next.x >= cells.x or next.y >= cells.y:
                continue
            if seen.has(next) or not is_free.call(Vector2(next) * step):
                continue
            seen[next] = true
            stack.append(next)
    var reached := func(point: Vector2) -> bool:
        var center := Vector2i((point / step).round())
        for dx in range(-3, 4):
            for dy in range(-3, 4):
                if seen.has(center + Vector2i(dx, dy)):
                    return true
        return false
    for herd in herds():
        if not reached.call(herd.position):
            result.append(herd.name)
    for person in people():
        if not reached.call(person.position):
            result.append(person.name)
    if home() != null and not reached.call(home().gate() + Vector2(0, -20)):
        result.append("the gate")
    return result


func _clue_problems(person: Person, clue: Clue) -> PackedStringArray:
    var result := PackedStringArray()
    var where := "the clue of %s (%s)" % [person.name, clue.form]
    if clue.animal == null:
        result.append("%s has no animal" % where)
        return result
    if landmark(clue.landmark) == null:
        result.append("%s names the missing landmark '%s'" % [where, clue.landmark])
        return result
    if clue.form == "between" and landmark(clue.other) == null:
        result.append("%s names the missing landmark '%s'" % [where, clue.other])
        return result
    var herd := herd_of(clue)
    if herd == null:
        result.append("%s points to no herd of its animals" % where)
    elif herd.count != clue.count:
        result.append("%s counts %d, but the herd has %d" % [where, clue.count, herd.count])
    return result


func _draw() -> void:
    draw_texture_rect(_ground_texture(), Rect2(Vector2.ZERO, size), true)
    _draw_edge()


## The edge of the steppe, where the horse stops: a band of tall dark grass
## with stones (see Rider.EDGE).
func _draw_edge() -> void:
    var band := 16.0
    for rect in [
        Rect2(0, 0, size.x, band),
        Rect2(0, size.y - band, size.x, band),
        Rect2(0, 0, band, size.y),
        Rect2(size.x - band, 0, band, size.y),
    ]:
        draw_rect(rect, Palette.GRASS_DARK)
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    var perimeter := int(2.0 * (size.x + size.y) / 10.0)
    for i in range(perimeter):
        var along := rng.randf() * 2.0 * (size.x + size.y)
        var inward := rng.randf_range(2.0, band + 4.0)
        var at := Vector2.ZERO
        if along < size.x:
            at = Vector2(along, inward)
        elif along < 2.0 * size.x:
            at = Vector2(along - size.x, size.y - inward)
        elif along < 2.0 * size.x + size.y:
            at = Vector2(inward, along - 2.0 * size.x)
        else:
            at = Vector2(size.x - inward, along - 2.0 * size.x - size.y)
        if rng.randf() < 0.25:
            draw_circle(at.round(), 3.0, Palette.OUTLINE)
            draw_circle(at.round(), 2.5, Palette.STONE)
            draw_circle(at.round() - Vector2(0.5, 0.5), 1.0, Palette.STONE_LIGHT)
        else:
            draw_rect(Rect2(at.round(), Vector2(0.5, 4)), Palette.HORSE_BAY)
            draw_rect(Rect2(at.round() + Vector2(1, 1), Vector2(0.5, 3)), Palette.OUTLINE)
            draw_rect(Rect2(at.round() + Vector2(-1, 1.5), Vector2(0.5, 2.5)), Palette.HORSE_BAY)


## The painted ground of the steppe, a seamless tile of feather grass and
## wild flowers, [constant _GROUND_TILE] logical pixels wide, at two pixels of
## the screen per logical pixel.
static func _ground_texture() -> ImageTexture:
    if _ground != null:
        return _ground
    var painted: Texture2D = load(_GROUND_PAINTING)
    _ground = ImageTexture.create_from_image(painted.get_image())
    _ground.set_size_override(Vector2i(_GROUND_TILE, _GROUND_TILE))
    return _ground
