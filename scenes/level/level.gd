class_name Level
extends Node2D

## Play a level (see section 4 of DESIGN.md): Grandmother sends the rider out,
## the people tell her where they saw the animals, she hears them before she
## sees them, they follow her once she comes close, and they run into the pen
## when she rides up to its gate. When all the animals are home, Grandmother
## thanks her and she gets her stars, which the profile keeps; the next squat
## goes on to the reward.
##
## The level is the one chosen in [member Flow.level], else [member map_scene].
##
## Keys: Space or Up is a squat, Left and Right turn, C opens and closes the
## map, L switches the language, R rides the level again, Enter goes on after
## the end, Escape twice quits.

## The rider talks to a person who is this close, in pixels...
const TALK_DISTANCE := 34.0

## ... and talks to them again only after she rode this far away.
const TALK_AGAIN_DISTANCE := 70.0

## A conversation stays open at least this long, in seconds; then the next
## squat closes it, and the rider rides on.
const TALK_SECONDS := 1.0

## Grandmother's thanks stay at least this long, in seconds; then the next
## squat goes on to the reward.
const THANKS_SECONDS := 3.0

## A galloping horse scares the shy animals within this distance, in pixels.
const SCARE_DISTANCE := 48.0

## The followers walk this far apart behind the rider, in pixels.
const FOLLOW_SPACING := 20.0

## The warning at the edge of the steppe stays this long, in seconds.
const EDGE_SECONDS := 2.5

## The small figure invites the rider to squat when the horse stood still
## this long, in seconds.
const STILL_SECONDS := 3.0

## The animals run into the pen when the rider is this close to its gate.
const GATE_DISTANCE := 60.0

## The level to play.
@export var map_scene: PackedScene

var map: LevelMap
var animals: Array[Animal] = []

## Whether all the animals are home.
var finished := false

## How long the rider took, in seconds, from her first stride.
var elapsed := 0.0

## The water and the food of the horse.
var needs := HorseNeeds.new()

var _service: Node = null
var _people: Array[Person] = []
var _grandmother: Person = null
var _followers: Array[Animal] = []
var _trail := PackedVector2Array()
var _revealed: Array[Clue] = []
var _started := false
var _edge_time := 0.0

var _coach: Coach
var _wildlife: Wildlife
var _still_time := 0.0
var _squats_seen := 0

var _talking: Person = null
var _talked_to: Person = null
var _talk_time := 0.0
var _talk_squats := 0

@onready var _world: Node2D = $World
@onready var _animals: Node2D = $World/Animals
@onready var _rider: Rider = $World/Rider
@onready var _camera: Camera2D = $World/Rider/Camera
@onready var _slots: Slots = $Hud/Slots
@onready var _hearing: Hearing = $Hud/Hearing
@onready var _map_view: MapView = $Hud/MapView
@onready var _speed_bar: SpeedBar = $Hud/SpeedBar
@onready var _needs_bars: NeedsBars = $Hud/NeedsBars
@onready var _camera_panel: CameraPanel = $Hud/CameraPanel
@onready var _conversation: Conversation = $Hud/Conversation
@onready var _status_label: Label = $Hud/StatusLabel
@onready var _quit_hint: QuitHint = $Hud/QuitHint
@onready var _edge_label: Label = $Hud/EdgeLabel


func _ready() -> void:
    _service = get_node("/root/Vision").service
    _service.ResetRiding()

    if Flow.level != "":
        map_scene = load(Flow.level)
    map = map_scene.instantiate()
    _world.add_child(map)
    _world.move_child(map, 0)

    _wildlife = Wildlife.new()
    _world.add_child(_wildlife)
    _world.move_child(_wildlife, 1)

    var start := map.start()
    _rider.position = start.position
    _rider.heading = start.rotation
    _rider.set_obstacles(map.solids(), map.size)
    _wildlife.populate(
        map.size, map.solids(), [start.position, map.home().position], hash(map.title)
    )
    _trail.append(_rider.position)
    _camera.limit_left = 0
    _camera.limit_top = 0
    _camera.limit_right = int(map.size.x)
    _camera.limit_bottom = int(map.size.y)

    var count := 0
    for herd in map.herds():
        for spot in herd.spots():
            var animal := Animal.new()
            animal.setup(herd.animal, herd, herd.position + spot, count)
            _animals.add_child(animal)
            animals.append(animal)
            count += 1

    _people = map.people()
    for person in _people:
        if person.portrait == "grandmother":
            _grandmother = person

    _slots.animals = animals
    _map_view.map = map
    _speed_bar.thresholds = _service.GetGaitThresholds()
    _rider.looks = get_node("/root/Profile").looks
    _needs_bars.needs = needs
    _coach = Coach.new()
    _coach.position = _camera_panel.position - Vector2(68, 0)
    _coach.size = Vector2(64, _camera_panel.size.y)
    $Hud.add_child(_coach)

    var bubble := NeedsBubble.new()
    bubble.needs = needs
    _rider.add_child(bubble)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE:
                _quit_hint.press()
            KEY_C:
                _map_view.large = not _map_view.large
            KEY_R:
                get_tree().reload_current_scene()
            KEY_L:
                _next_language()
            KEY_ENTER, KEY_KP_ENTER:
                if finished:
                    _leave()


func _process(delta: float) -> void:
    # NOTE (mristin):
    # A tired horse walks however fast the player squats (see [HorseNeeds]),
    # so the gait is the slower of the squats and the horse.
    var gait: int = mini(_service.GetGait(), _rider.gait())
    _update_conversation(delta, gait)

    var standing := _talking != null or finished
    var speed: float = 0.0 if standing else needs.cap(_service.GetSpeed())
    _rider.ride(delta, speed, 0.0 if standing else _service.GetTurn())
    needs.update(delta, speed, map.at_fresh_water(_rider.position), map.on_pasture(_rider.position))
    if _rider.speed > 0.0:
        _started = true

    # NOTE (mristin):
    # The edge of the steppe blocks the horse like a wall, and Grandmother's
    # word reminds the rider to stay near.
    _edge_time = EDGE_SECONDS if _rider.at_edge else maxf(0.0, _edge_time - delta)
    _edge_label.visible = _edge_time > 0.0
    _edge_label.text = tr("Don't ride too far away!")
    if _started and not finished:
        elapsed += delta
    if _trail[_trail.size() - 1].distance_to(_rider.position) >= 3.0:
        _trail.append(_rider.position)
        if _trail.size() > 1500:
            _trail = _trail.slice(500)

    _update_animals(delta, gait)
    _wildlife.update(delta, _rider.position, _rider.gait())

    _update_hud(speed)


## How many stars the ride earned so far: three within the par time of the
## level, two within twice as long, and one later.
func stars() -> int:
    if elapsed <= map.par_seconds:
        return 3
    if elapsed <= map.par_seconds * 2.0:
        return 2
    return 1


## The person the rider talks to now, or null.
func talking_to() -> Person:
    return _talking


## The clues which the rider heard so far.
func revealed() -> Array[Clue]:
    return _revealed


func rider() -> Rider:
    return _rider


## The wild creatures of the steppe.
func wildlife() -> Wildlife:
    return _wildlife


func _update_conversation(delta: float, gait: int) -> void:
    var squats: int = _service.GetSquatCount()
    if finished:
        _talk_time += delta
        if _talk_time >= THANKS_SECONDS and squats > _talk_squats:
            _leave()
        return
    if _talking != null:
        _talk_time += delta
        if _talk_time >= TALK_SECONDS and squats > _talk_squats:
            _talked_to = _talking
            _talking = null
            _conversation.close()
        return

    if _talked_to != null:
        if _rider.position.distance_to(_talked_to.position) > TALK_AGAIN_DISTANCE:
            _talked_to = null

    if gait > 1:
        return
    for person in _people:
        if person != _talked_to and _rider.position.distance_to(person.position) < TALK_DISTANCE:
            _talk(person)
            return


func _talk(person: Person) -> void:
    _talking = person
    _talk_time = 0.0
    _talk_squats = _service.GetSquatCount()
    for clue in person.clues:
        if clue not in _revealed:
            _revealed.append(clue)
    _show_conversation()


## Show (again, e.g., in another language) what the person says now.
func _show_conversation() -> void:
    if _talking == null:
        return
    var rider_name: String = get_node("/root/Profile").rider_name()
    var lines: Array[Dictionary] = []
    if finished:
        lines.append({"text": Grammar.format(tr(map.thanks), {"rider": rider_name})})
        var icons: Array = []
        for i in range(3):
            var color := Color.WHITE if i < stars() else Color(0.2, 0.15, 0.1, 0.5)
            icons.append([Icons.star(2.0), color])
        lines.append({"icons": icons})
        lines.append({"text": tr("R: ride again · Esc: quit")})
    else:
        lines.append({"text": Grammar.format(tr(_talking.greeting), {"rider": rider_name})})
        for clue in _talking.clues:
            lines.append({"icons": _clue_icons(clue), "text": map.clue_text(clue)})
    _conversation.open(Icons.portrait(_talking.portrait), tr(_talking.speaker), lines)


## The pictures of a clue: the animals, then the landmarks.
func _clue_icons(clue: Clue) -> Array:
    var icons: Array = []
    for i in range(clue.count):
        icons.append([Icons.animal(clue.animal.id, 2.0), Color.WHITE])
    for landmark_name in [clue.landmark, clue.other]:
        var landmark := map.landmark(landmark_name)
        if landmark != null:
            icons.append([Icons.landmark(landmark.kind_id(), 2.0), Color.WHITE])
    return icons


func _update_animals(delta: float, gait: int) -> void:
    for animal in animals:
        match animal.state:
            Animal.State.LOST:
                _update_lost(animal, delta, gait)
            Animal.State.FOLLOWING:
                var target := _trail_point(FOLLOW_SPACING * (_followers.find(animal) + 1))
                animal.walk_to(target, animal.kind.speed, delta)
            Animal.State.ENTERING:
                if animal.walk_to(animal.spot, animal.kind.speed, delta) < 2.0:
                    animal.state = Animal.State.HOME
            Animal.State.HOME:
                animal.graze(delta)

    var home := map.home()
    if not _followers.is_empty() and _rider.position.distance_to(home.gate()) < GATE_DISTANCE:
        var pen := home.pen().grow(-12.0)
        for animal in _followers:
            animal.state = Animal.State.ENTERING
            var spot := pen.position + Vector2(randf(), randf()) * pen.size
            animal.settle(spot.round(), 10.0)
        _followers.clear()

    if not finished and animals.all(func(a: Animal) -> bool: return a.state == Animal.State.HOME):
        _finish()


func _update_lost(animal: Animal, delta: float, gait: int) -> void:
    var distance := animal.position.distance_to(_rider.position)
    if animal.kind.shy and gait >= 2 and distance < SCARE_DISTANCE:
        animal.flee_from(_rider.position)
        animal.near_time = 0.0
    elif distance < Animal.JOIN_DISTANCE:
        animal.near_time += delta
        if animal.near_time >= Animal.JOIN_SECONDS:
            animal.state = Animal.State.FOLLOWING
            animal.heart_time = Animal.HEART_SECONDS
            _followers.append(animal)
    else:
        animal.near_time = maxf(0.0, animal.near_time - delta)
    animal.graze(delta)


## The point on the rider's trail this far behind her.
func _trail_point(distance: float) -> Vector2:
    var previous := _rider.position
    var remaining := distance
    for i in range(_trail.size() - 1, -1, -1):
        var segment := previous.distance_to(_trail[i])
        if segment >= remaining and segment > 0.0:
            return previous.lerp(_trail[i], remaining / segment)
        remaining -= segment
        previous = _trail[i]
    return previous


func _finish() -> void:
    finished = true
    _map_view.large = false
    get_node("/root/Profile").finish_level(level_id(), stars())
    _talk_time = 0.0
    _talk_squats = _service.GetSquatCount()
    if _grandmother != null:
        _talking = _grandmother
        _show_conversation()


## The id of the level (see [LevelList]).
func level_id() -> String:
    return LevelList.id(Flow.level if Flow.level != "" else map_scene.resource_path)


## Go on to the reward after the end of the level.
func _leave() -> void:
    Flow.reward(get_tree(), stars())


func _update_hud(speed: float) -> void:
    _speed_bar.speed = speed

    var heard: Array[Dictionary] = []
    for herd in map.herds():
        var nearest: Animal = null
        for animal in animals:
            if animal.herd == herd and animal.is_lost():
                if (
                    nearest == null
                    or (
                        animal.position.distance_to(_rider.position)
                        < nearest.position.distance_to(_rider.position)
                    )
                ):
                    nearest = animal
        if nearest == null:
            continue
        var distance := nearest.position.distance_to(_rider.position)
        if distance < Hearing.RADIUS and not _hearing.on_screen(nearest.position):
            (
                heard
                . append(
                    {
                        "id": nearest.kind.id,
                        "at": nearest.position,
                        "closeness": 1.0 - distance / Hearing.RADIUS,
                    }
                )
            )
    _hearing.heard = heard
    _hearing.rider_at = _rider.position

    _map_view.rider_at = _rider.position
    _map_view.rider_heading = _rider.heading
    _map_view.clues = _revealed
    for clue in _revealed:
        var herd := map.herd_of(clue)
        _map_view.found[clue] = (
            herd != null
            and not animals.any(func(a: Animal) -> bool: return a.herd == herd and a.is_lost())
        )

    _camera_panel.visible = _service.IsRunning()
    _update_coach(get_process_delta_time())
    _status_label.text = VisionStatus.new().text(_service, false)


## Let the small figure show what the game waits for: a squat when the horse
## stands still or a conversation waits for one, the reach across after the
## edge of the steppe, else the echo of the player's squats.
func _update_coach(delta: float) -> void:
    _still_time = _still_time + delta if _rider.speed <= 0.0 else 0.0
    var squats: int = _service.GetSquatCount()
    if squats > _squats_seen:
        _coach.echo()
    _squats_seen = squats
    var waiting := _talk_time >= (THANKS_SECONDS if finished else TALK_SECONDS)
    if _talking != null or finished:
        _coach.mode = Coach.Mode.SQUAT if waiting else Coach.Mode.STAND
    elif _edge_time > 0.0:
        _coach.mode = Coach.Mode.REACH
    elif _still_time >= STILL_SECONDS:
        _coach.mode = Coach.Mode.SQUAT
    else:
        _coach.mode = Coach.Mode.STAND


## What the small figure next to the camera picture does now.
func coach_mode() -> Coach.Mode:
    return _coach.mode


func _next_language() -> void:
    var languages := get_node("/root/Languages")
    var codes: Array[String] = languages.codes()
    var index := codes.find(languages.current())
    languages.choose(codes[(index + 1) % codes.size()])
    _show_conversation()
