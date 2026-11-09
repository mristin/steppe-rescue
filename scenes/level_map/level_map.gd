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

## The side of the tile of the ground in pixels.
const _GROUND_TILE := 64

## The animals are near a landmark if they are this much farther than its size.
const _NEAR := 90.0

## The animals on one side of a landmark are this far beyond its size...
const _SIDE_DISTANCE := 130.0

## ... in a circle of this radius.
const _SIDE_RADIUS := 110.0

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


## The circles which block the horse, each as (x, y, radius).
func solids() -> Array[Vector3]:
    var result: Array[Vector3] = []
    for each in landmarks():
        var radius := each.solid_radius()
        if radius > 0.0:
            result.append(Vector3(each.position.x, each.position.y, radius))
    return result


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

    # NOTE (mristin):
    # The tufts of the feather grass and a few tulips; the same in every run.
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(title)
    for i in range(int(size.x * size.y / 1800.0)):
        var at := Vector2(rng.randf() * size.x, rng.randf() * size.y).round()
        var roll := rng.randf()
        if roll < 0.04:
            draw_rect(Rect2(at, Vector2(2, 2)), Palette.CRIMSON)
            draw_rect(Rect2(at + Vector2(0, 2), Vector2(1, 2)), Palette.EMERALD)
        elif roll < 0.55:
            draw_rect(Rect2(at, Vector2(1, 3)), Palette.GRASS_LIGHT)
            draw_rect(Rect2(at + Vector2(-1, 1), Vector2(1, 2)), Palette.GRASS_LIGHT)
            draw_rect(Rect2(at + Vector2(1, 1), Vector2(1, 2)), Palette.GRASS_LIGHT)
        else:
            draw_rect(Rect2(at, Vector2(1, 2)), Palette.GRASS_DARK)
            draw_rect(Rect2(at + Vector2(2, 1), Vector2(1, 2)), Palette.GRASS_DARK)


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
            draw_circle(at.round(), 2.0, Palette.STONE)
        else:
            draw_rect(Rect2(at.round(), Vector2(1, 4)), Palette.HORSE_BAY)
            draw_rect(Rect2(at.round() + Vector2(2, 1), Vector2(1, 3)), Palette.OUTLINE)


static func _ground_texture() -> ImageTexture:
    if _ground != null:
        return _ground
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var image := Image.create_empty(_GROUND_TILE, _GROUND_TILE, false, Image.FORMAT_RGBA8)
    image.fill(Palette.GRASS)
    for i in range(_GROUND_TILE * _GROUND_TILE / 10):
        var x := rng.randi_range(0, _GROUND_TILE - 1)
        var y := rng.randi_range(0, _GROUND_TILE - 1)
        image.set_pixel(x, y, Palette.GRASS_DARK if rng.randf() < 0.6 else Palette.GRASS_LIGHT)
    _ground = ImageTexture.create_from_image(image)
    return _ground
