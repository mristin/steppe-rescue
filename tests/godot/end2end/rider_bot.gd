extends RefCounted
## Ride one rider of a level as a player does, only with the keys (see
## keys.gd): squat to go (more often to go faster), hold an arrow to turn,
## brake, and jump over the creeks. The rider talks to every person of the
## level and turns every page of every conversation, gathers the lost animals,
## brings them home, and lets her horse drink and graze when it runs low.
##
## The choices come from the random number generator of the test: which
## task is next (often the nearest, sometimes any), how many animals she
## gathers before she brings them home, when the horse drinks, and the keys
## she uses.
##
## The rider knows where the animals are (unlike a player), so that she
## checks that every one of them can be found and brought home. What goes
## wrong on the way is noted in [member failures]: a rider who can not get on
## is put where she wanted to go, so that the rest of the game is still
## played.
##
## Not a test itself (its name does not start with test_), it is preloaded by
## the tests.

const Keys := preload("res://tests/godot/end2end/keys.gd")
const Navigator := preload("res://tests/godot/end2end/navigator.gd")

## The speeds the rider asks for, in [0, 1] (see [method SquatMeter.GaitOf]).
const WALK := 0.25
const TROT := 0.6
const GALLOP := 1.0

## A squat from the keys every this many seconds walks, trots or gallops
## (see [member SquatMeter.KeyboardEffort]).
const _WALK_EVERY := 1.9
const _TROT_EVERY := 0.95
const _GALLOP_EVERY := 0.45

## The keys of the first and the second player with two players (see
## [VisionService]); alone, a player rides with either.
const KEYS_LEFT := {"squat": KEY_W, "left": KEY_A, "right": KEY_D, "brake": KEY_S, "jump": KEY_J}
const KEYS_RIGHT := {
    "squat": KEY_UP, "left": KEY_LEFT, "right": KEY_RIGHT, "brake": KEY_DOWN, "jump": KEY_KP_0
}

## Without getting closer to where she goes for this long, in seconds, the
## rider tries another way...
const _STUCK_SECONDS := 5.0

## ... and after this long in all, she is stuck.
const _GIVE_UP_SECONDS := 90.0

## A task may take at most this long, in seconds.
const _TASK_SECONDS := 240.0

## A rider who stands next to a person or an animal waits this long, in
## seconds, for the talk or for the animal to join.
const _WAIT_SECONDS := 6.0

var level: Level
var index := 0
var keys: Dictionary

## What went wrong, as messages.
var failures: Array[String] = []

## The people who talked to the riders, by their names, and how many pages
## each talk had; the riders of a level share it.
var talked: Dictionary = {}

## How many conversations this rider closed, and how many pages she turned.
var closed := 0
var turned := 0

## Whether the rider plays tricks now and then (see [method _tricks]): opens
## the map, switches the language, presses Escape once, jumps for fun.
var tricky := true

var _nav: Navigator
var _rng: RandomNumberGenerator
var _service: Node
var _people: Array[Person] = []
var _animals: Array[Animal] = []
var _task := {}
var _task_time := 0.0
var _way := PackedVector2Array()
var _way_index := 0
var _way_age := 0.0
var _best := INF
var _no_progress := 0.0
var _stuck := 0.0
var _wiggle := 0.0
var _wiggle_turn := 0
var _waited := 0.0
var _since_squat := 99.0
var _since_jump := 99.0
var _since_brake := 99.0
var _braking := 0.0
var _home_after := 1
var _thirst := 0.2
var _hunger := 0.2
var _talking: Person = null
var _page := -1
var _page_wait := 0.0
var _page_after := 1.0
var _expect := {}
var _map_open := 0.0
var _since_escape := 99.0
var _clock := 0.0

## Whether the rider still rides into the edge of the steppe, and twice into
## the same obstacle, on purpose in this level, to see the hints.
var _edge_left := false
var _bump_left := false


func _init(
    a_level: Level,
    an_index: int,
    nav: Navigator,
    rng: RandomNumberGenerator,
    people: Array[Person],
    animals: Array[Animal]
) -> void:
    level = a_level
    index = an_index
    _nav = nav
    _rng = rng
    _service = level.get_node("/root/Vision").service
    _people = people
    _animals = animals
    if level.players() > 1:
        keys = KEYS_LEFT if index == 0 else KEYS_RIGHT
    else:
        # NOTE (mristin):
        # Alone, a player rides with the arrows or with W, A, D and S, and
        # squats with Space, W or Up.
        keys = (KEYS_LEFT if _rng.randf() < 0.5 else KEYS_RIGHT).duplicate()
        keys["squat"] = [KEY_SPACE, KEY_W, KEY_UP][_rng.randi_range(0, 2)]
        keys["jump"] = KEY_J if _rng.randf() < 0.7 else KEY_KP_0
    _home_after = _rng.randi_range(1, 4)
    _thirst = _rng.randf_range(0.1, 0.5)
    _hunger = _rng.randf_range(0.1, 0.5)
    tricky = index == 0
    _edge_left = _rng.randf() < 0.7
    _bump_left = _rng.randf() < 0.7


func _fail(message: String) -> void:
    failures.append("%s, the rider %d: %s" % [level.level_id(), index + 1, message])


func _rider() -> Rider:
    return level.rider(index)


## Ride for a moment of [param delta] seconds.
func tick(delta: float) -> void:
    _clock += delta
    _since_squat += delta
    _since_jump += delta
    _since_brake += delta
    _since_escape += delta
    _check_expected()
    if _braking > 0.0:
        _braking -= delta
        if _braking <= 0.0:
            Keys.release(keys["brake"])
    if tricky:
        _tricks(delta)

    var talking := level.talking_to(index)
    if talking != null:
        _talk(talking, delta)
        return
    if _talking != null:
        _talking = null
        closed += 1

    if _task.is_empty() or _done(_task):
        _next_task()
    _task_time += delta
    if _task.is_empty():
        _drive(Vector2.ZERO, 0.0, delta)
        return
    _ride_task(delta)


## Whether the rider waits to see whether her squat turned the page of a talk.
func checks_page() -> bool:
    return not _expect.is_empty()


## Let all the keys of the rider go.
func stop() -> void:
    for name in ["left", "right", "brake"]:
        Keys.release(keys[name])


func _squat() -> void:
    Keys.tap(keys["squat"])
    _since_squat = 0.0


func _brake() -> void:
    Keys.press(keys["brake"])
    _braking = 0.3
    _since_brake = 0.0


## Listen to the person, and squat once each page has shown for a while, to
## turn it or, on the last one, to close the talk.
func _talk(person: Person, delta: float) -> void:
    _steer(0)
    var conversation := level.view(index).conversation
    if person != _talking:
        _talking = person
        _page = -1
        talked[person.name] = conversation.pages()
        if _task.get("person") == person:
            _task = {}
    if conversation.page() != _page:
        _page = conversation.page()
        _page_wait = 0.0
        _page_after = Level.TALK_SECONDS + _rng.randf_range(0.05, 0.8)
    _page_wait += delta
    if _page_wait >= _page_after and _expect.is_empty():
        _expect = {
            "person": person,
            "page": conversation.page(),
            "pages": conversation.pages(),
            "frames": 0,
        }
        _page_after = INF
        _squat()


## Check that the squat in a conversation turned its page, or closed it on
## the last page.
func _check_expected() -> void:
    if _expect.is_empty():
        return
    _expect["frames"] += 1
    var conversation := level.view(index).conversation
    var person: Person = _expect["person"]
    var page: int = _expect["page"]
    var last: bool = page + 1 >= int(_expect["pages"])
    if last and level.talking_to(index) != person:
        _expect = {}
        return
    if not last and level.talking_to(index) == person and conversation.page() == page + 1:
        turned += 1
        _expect = {}
        return
    if _expect["frames"] > 30:
        _fail(
            (
                "the squat on the page %d of %d of %s did not %s"
                % [page + 1, _expect["pages"], person.name, "close it" if last else "turn it"]
            )
        )
        _expect = {}


func _done(task: Dictionary) -> bool:
    var needs := level.view(index).needs
    var done := true
    match task["kind"]:
        "person":
            done = talked.has((task["person"] as Person).name)
        "animal":
            done = (task["animal"] as Animal).state != Animal.State.LOST
        "home":
            done = level.followers(index).is_empty()
        "drink":
            done = needs.water >= 0.95
        "graze":
            done = needs.food >= 0.95
        "edge":
            done = level.view(index).edge_time > 0.0
        "bump":
            done = level.turn_hint(index)
    return done


func _next_task() -> void:
    _task = {}
    _task_time = 0.0
    _way = PackedVector2Array()
    _best = INF
    _no_progress = 0.0
    _stuck = 0.0
    _waited = 0.0
    var rider := _rider()
    var needs := level.view(index).needs
    if needs.water < _thirst and not _nav.water.is_empty():
        _task = {"kind": "drink", "at": _nearest(_nav.water, rider.position)}
        _thirst = _rng.randf_range(0.1, 0.5)
        return
    # NOTE (mristin):
    # Now and then, she rides into the edge of the steppe, or twice into the
    # same obstacle, as a child does, to see the hints.
    if _edge_left and _rng.randf() < 0.3:
        _edge_left = false
        _task = _edge_task()
        return
    if _bump_left and _rng.randf() < 0.3:
        _bump_left = false
        _task = _bump_task()
        if not _task.is_empty():
            return
    if needs.food < _hunger and not _nav.pasture.is_empty():
        _task = {"kind": "graze", "at": _nearest(_nav.pasture, rider.position)}
        _hunger = _rng.randf_range(0.1, 0.5)
        return

    var lost: Array[Animal] = []
    for animal in _animals:
        if animal.state == Animal.State.LOST:
            lost.append(animal)
    if lost.is_empty():
        # NOTE (mristin):
        # Her own animals are found: she helps with the rest.
        for animal in level.animals:
            if animal.state == Animal.State.LOST:
                lost.append(animal)
    var choices: Array[Dictionary] = []
    for person in _people:
        if not talked.has(person.name):
            choices.append({"kind": "person", "person": person, "at": person.position})
    # NOTE (mristin):
    # The level ends when the last animal is home, and an animal may join her
    # on her way home: she brings them home only once everybody was asked,
    # and asks those whom nobody asked yet, too.
    var unasked := false
    for person in level.map.people():
        if not talked.has(person.name):
            unasked = true
            if lost.is_empty() and person not in _people:
                choices.append({"kind": "person", "person": person, "at": person.position})
    var followers := level.followers(index).size()
    if followers > 0 and not unasked and (followers >= _home_after or lost.is_empty()):
        _task = {"kind": "home"}
        _home_after = _rng.randi_range(1, 4)
        return
    for animal in lost:
        choices.append({"kind": "animal", "animal": animal, "at": animal.position})
    if choices.is_empty():
        return
    if _rng.randf() < 0.7:
        var best := 0
        for i in range(choices.size()):
            var distance := rider.position.distance_to(choices[i]["at"])
            if distance < rider.position.distance_to(choices[best]["at"]):
                best = i
        _task = choices[best]
    else:
        _task = choices[_rng.randi_range(0, choices.size() - 1)]


## Ride into the nearest edge of the steppe.
func _edge_task() -> Dictionary:
    var at := _rider().position
    var inner := Rect2(Vector2.ZERO, level.map.size).grow(-Rider.EDGE)
    var sides := [
        [at.x - inner.position.x, Vector2(inner.position.x, at.y), Vector2.LEFT],
        [inner.end.x - at.x, Vector2(inner.end.x, at.y), Vector2.RIGHT],
        [at.y - inner.position.y, Vector2(at.x, inner.position.y), Vector2.UP],
        [inner.end.y - at.y, Vector2(at.x, inner.end.y), Vector2.DOWN],
    ]
    sides.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
    var edge: Vector2 = sides[0][1]
    var out: Vector2 = sides[0][2]
    return {"kind": "edge", "at": edge - out * 40.0, "out": edge + out * 40.0}


## Ride twice into the nearest obstacle with room before it; empty if none is
## near.
func _bump_task() -> Dictionary:
    var at := _rider().position
    var best := {}
    var nearest := 700.0
    for solid in level.map.solids():
        var center := Vector2(solid.x, solid.y)
        var away := (at - center).normalized()
        if away == Vector2.ZERO:
            continue
        var before := center + away * (solid.z + Rider.RADIUS + 40.0)
        var distance := at.distance_to(center) - solid.z
        if distance < nearest and _nav.is_free(before):
            nearest = distance
            best = {
                "kind": "bump",
                "center": center,
                "reach": solid.z + Rider.RADIUS,
                "at": before,
                "phase": "approach"
            }
    return best


## Ride into the edge, or twice into the obstacle, until the hint shows.
func _ride_trick(delta: float) -> void:
    var rider := _rider()
    if _task_time > 60.0:
        _fail("riding into %s did not show its hint" % _describe())
        _task = {}
        return
    if _task["kind"] == "edge":
        var at: Vector2 = _task["at"]
        if rider.position.distance_to(at) > 30.0 and not _task.has("near"):
            _drive(at, TROT, delta)
        else:
            _task["near"] = true
            _drive(_task["out"], WALK, delta, true)
        return
    var center: Vector2 = _task["center"]
    var before: Vector2 = _task["at"]
    match _task["phase"]:
        "approach", "back":
            _drive(before, TROT if _task["phase"] == "approach" else WALK, delta)
            if rider.position.distance_to(before) < 16.0:
                _task["phase"] = "hit"
        "hit":
            _drive(center, WALK, delta, true)
            if rider.position.distance_to(center) <= float(_task["reach"]) + 1.5:
                _task["phase"] = "back"


## The spot of the few nearest which is the shortest ride away (e.g., not
## across the river).
func _nearest(spots: Array[Vector2], at: Vector2) -> Vector2:
    var sorted := spots.duplicate()
    sorted.sort_custom(
        func(a: Vector2, b: Vector2) -> bool: return a.distance_to(at) < b.distance_to(at)
    )
    var best: Vector2 = sorted[0]
    var shortest := INF
    for spot: Vector2 in sorted.slice(0, 8):
        var way := _nav.way(at, spot)
        if way.is_empty():
            continue
        var length := 0.0
        for i in range(1, way.size()):
            length += way[i - 1].distance_to(way[i])
        if length < shortest:
            shortest = length
            best = spot
    return best


## Where the task leads now.
func _target() -> Vector2:
    match _task["kind"]:
        "person":
            return (_task["person"] as Person).position
        "animal":
            return (_task["animal"] as Animal).position
        "home":
            return level.map.home().gate() + Vector2(0, -20)
    return _task["at"]


## Ride to the place of the task, slowing down near it, and stop there.
func _ride_task(delta: float) -> void:
    var rider := _rider()
    var target := _target()
    var distance := rider.position.distance_to(target)
    var kind: String = _task["kind"]
    if kind in ["edge", "bump"]:
        _ride_trick(delta)
        return
    var stop_at := 6.0
    var slow_at := 90.0
    var fast := GALLOP
    match kind:
        "person":
            stop_at = 18.0
            slow_at = 140.0
        "animal":
            stop_at = 14.0
            var shy := (_task["animal"] as Animal).kind.shy
            slow_at = 220.0 if shy else 140.0
        "home":
            stop_at = 30.0
            slow_at = 150.0
            # NOTE (mristin):
            # The rider sometimes trots home, so that her followers keep up.
            fast = TROT if _rng.randf() < 0.002 else fast

    if _task_time > _TASK_SECONDS:
        _fail("could not finish the task %s in %d s" % [_describe(), _TASK_SECONDS])
        _put(target)
        return

    # NOTE (mristin):
    # The horse drinks and grazes only right at the water or on the grass.
    var arrived := distance <= stop_at
    if kind == "drink":
        arrived = level.map.at_fresh_water(rider.position)
    elif kind == "graze":
        arrived = level.map.on_pasture(rider.position)
    if arrived:
        _drive(target, 0.0, delta)
        _waited += delta
        _no_progress = 0.0
        if kind in ["drink", "graze"] and _waited > _WAIT_SECONDS * 4.0:
            var needs := level.view(index).needs
            if not (needs.drinking or needs.grazing):
                _fail("the horse does not %s where it stands" % kind)
            _task = {}
        elif kind in ["person", "animal"] and _waited > _WAIT_SECONDS:
            if kind == "person":
                _fail("%s does not talk to the rider standing next to them" % _describe())
                talked[(_task["person"] as Person).name] = 0
            else:
                _fail("%s does not join the rider standing next to it" % _describe())
            _task = {}
        return
    _waited = 0.0

    var want := fast
    if distance < slow_at:
        want = WALK
    _drive(target, want, delta)

    if distance < _best - 8.0:
        _best = distance
        _no_progress = 0.0
    else:
        _no_progress += delta
    if _no_progress > _STUCK_SECONDS:
        _no_progress = 0.0
        _stuck += _STUCK_SECONDS
        _best = distance
        _way = PackedVector2Array()
        _wiggle = _rng.randf_range(0.5, 1.5)
        _wiggle_turn = -1 if _rng.randf() < 0.5 else 1
        if _stuck >= _GIVE_UP_SECONDS:
            _fail(
                (
                    "got stuck at %s on the way to %s at %s"
                    % [rider.position.round(), _describe(), target.round()]
                )
            )
            _put(target)


func _describe() -> String:
    var described := "nothing"
    match _task.get("kind", ""):
        "person":
            described = "the person %s" % (_task["person"] as Person).name
        "animal":
            var animal: Animal = _task["animal"]
            described = "the %s of %s" % [animal.kind.id, animal.herd.name]
        "home":
            described = "the gate of the pen"
        "drink":
            described = "the water"
        "graze":
            described = "the pasture"
        "edge":
            described = "the edge of the steppe"
        "bump":
            described = "the obstacle at %s twice" % (_task["center"] as Vector2).round()
    return described


## Put the rider at the point, since she could not get there herself.
func _put(target: Vector2) -> void:
    var rider := _rider()
    rider.position = rider.slide(_nav.point(_nav.free_cell(target)))
    _way = PackedVector2Array()
    _best = INF
    _stuck = 0.0
    _task_time = 0.0


## Ride towards the target at the speed in [0, 1] (straight at it if
## [param direct], else along the way around what blocks the horse); stop at
## zero.
func _drive(target: Vector2, want: float, delta: float, direct := false) -> void:
    var rider := _rider()
    var speed: float = _service.GetSpeed(index)
    if want <= 0.0:
        _steer(0)
        if speed > 0.02 and _since_brake > 0.6:
            _brake()
        return

    if _wiggle > 0.0:
        _wiggle -= delta
        _steer(_wiggle_turn)
        if _since_squat >= _TROT_EVERY:
            _squat()
        return

    var aim := target
    if not direct and rider.position.distance_to(target) > 48.0:
        _way_age += delta
        if _way.is_empty() or _way_age > 3.0:
            _way = _nav.way(rider.position, target)
            _way_index = 0
            _way_age = 0.0
        while _way_index < _way.size() - 1 and rider.position.distance_to(_way[_way_index]) < 30.0:
            _way_index += 1
        if _way_index < _way.size():
            aim = _way[_way_index]

    var away := aim - rider.position
    var heading := atan2(away.x, -away.y)
    var error := wrapf(heading - rider.heading, -PI, PI)
    _steer(0 if absf(error) < 0.08 else (1 if error > 0.0 else -1))
    if absf(error) > 1.2:
        want = minf(want, WALK)
    elif absf(error) > 0.5:
        want = minf(want, TROT)

    # NOTE (mristin):
    # At a creek, the horse trots at least, and jumps.
    if _nav.near_creek(rider.position, 40.0):
        want = maxf(want, TROT)
        var ahead := rider.position + Vector2.UP.rotated(rider.heading) * 14.0
        if (
            (rider.at_creek() or (_nav.near_creek(ahead, 0.0) and speed >= 0.4))
            and _since_jump > 1.2
            and rider.jumping() < 0.0
        ):
            Keys.tap(keys["jump"])
            _since_jump = 0.0

    var every := _WALK_EVERY
    if want >= GALLOP:
        every = _GALLOP_EVERY
    elif want >= TROT:
        every = _TROT_EVERY
    if _since_squat >= every:
        _squat()
    # NOTE (mristin):
    # Coming up too fast, she brakes (a galloping horse rears up).
    if speed > want + 0.3 and want <= WALK and _since_brake > 2.0:
        _brake()


## Hold the arrow to the left (-1), to the right (1), or none (0).
func _steer(turn: int) -> void:
    Keys.hold(keys["left"], turn < 0)
    Keys.hold(keys["right"], turn > 0)


## Now and then, open the map and close it again, switch the language, press
## Escape once (twice would quit), or jump for fun.
func _tricks(delta: float) -> void:
    if _map_open > 0.0:
        _map_open -= delta
        if _map_open <= 0.0:
            Keys.tap(KEY_C)
        return
    var chance := delta / 60.0
    if _rng.randf() < chance * 1.5:
        Keys.tap(KEY_C)
        _map_open = _rng.randf_range(0.3, 2.5)
    elif _rng.randf() < chance * 1.5:
        Keys.tap(KEY_L)
    elif _rng.randf() < chance and _since_escape > 3.0 * QuitHint.WINDOW:
        Keys.tap(KEY_ESCAPE)
        _since_escape = 0.0
    elif _rng.randf() < chance * 3.0 and _since_jump > 2.0:
        Keys.tap(keys["jump"])
        _since_jump = 0.0
