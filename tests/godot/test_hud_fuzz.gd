extends SceneTree
## Fuzz the HUD of every level: put the rider at random places of the steppe
## (also at its edges and corners, where the view stops following her and she
## rides off its middle, and next to every person, where a conversation
## opens), with one and with two players, and check that no element of the
## HUD covers her on the screen (see layout.gd for what counts as the HUD).
## The camera picture counts as if the camera were on, so it must give way to
## her in time (see [method Level._give_way]).
##
## The places come from a fixed seed, so that a failure repeats; pass
## `-- --seed=<n>` to try others, and `-- --places=<n>` to try more.
##
## Run it with `-- --settings=user://<file>`, so that it does not change the
## settings and the journeys of the player (see the autoload Languages).

const Layout := preload("res://tests/godot/layout.gd")

const DEFAULT_SEED := 20261113

## How many random places each level tries, with each count of players.
const DEFAULT_PLACES := 16

## How long to wait at a place before checking: the camera picture glides
## out of the way meanwhile.
const SETTLE_SECONDS := Level.GIVE_WAY_SECONDS + 0.3

var _failures: Array[String] = []

## The problems found, by the level, the players and what covers the rider,
## each with its first example and how often it happened.
var _found := {}
var _rng := RandomNumberGenerator.new()


func _check(condition: bool, message: String) -> void:
    if not condition:
        print("FAIL ", message)
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


func _frames(count: int) -> void:
    for i in range(count):
        await process_frame


func _argument(name: String, default: int) -> int:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--%s=" % name):
            return int(arg.get_slice("=", 1))
    return default


## A random place in the steppe of the level: anywhere, or at its edges and
## corners, where the view no longer keeps the rider in its middle.
func _random_place(level: Level) -> Vector2:
    var low := Vector2.ONE * Rider.EDGE
    var high := level.map.size - low
    var at := Vector2(_rng.randf_range(low.x, high.x), _rng.randf_range(low.y, high.y))
    match _rng.randi_range(0, 3):
        0:
            at.x = low.x if _rng.randf() < 0.5 else high.x
        1:
            at.y = low.y if _rng.randf() < 0.5 else high.y
        2:
            at = Vector2(
                low.x if _rng.randf() < 0.5 else high.x, low.y if _rng.randf() < 0.5 else high.y
            )
    return at


## Stop every conversation, so that the riders can be put anywhere.
func _hang_up(level: Level) -> void:
    for i in range(level.players()):
        var view := level.view(i)
        view.talking = null
        view.talked_to = null
        view.conversation.close()


func _put(level: Level, player: int, at: Vector2) -> void:
    var rider := level.rider(player)
    rider.position = rider.slide(at)
    rider.heading = _rng.randf_range(-PI, PI)
    level.view(player).trail = PackedVector2Array([rider.position])


## Check that nothing of the HUD covers any rider, and note what does.
func _check_riders(level: Level, name: String, why: String) -> void:
    var items := Layout.elements(level, Layout.hud_extra(level), Layout.hud_skip(level))
    for i in range(level.players()):
        var rider := Layout.rider_on_screen(level, i)
        for item in items:
            var node: Node = item["node"]
            var rect: Rect2 = item["rect"]
            var common := rider.intersection(rect)
            if common.size.x <= Layout.TOLERANCE or common.size.y <= Layout.TOLERANCE:
                continue
            # NOTE (mristin):
            # The lines of a conversation count as the conversation itself.
            var what := node
            while what != level and not (what is Conversation):
                what = what.get_parent()
            if what == level:
                what = node
            var key := (
                "%s: %s covers the rider of the player %d" % [name, Layout.describe(what), i + 1]
            )
            if not _found.has(key):
                _found[key] = {
                    "count": 0,
                    "example":
                    (
                        "%s, at %s in the steppe, %s on the screen; it stands at %s"
                        % [why, level.rider(i).position.round(), rider, rect]
                    ),
                }
            _found[key]["count"] += 1


func _fuzz_level(path: String, players: int, places: int) -> void:
    var profile := root.get_node("Profile")
    profile.set_players(players)
    for i in range(players):
        profile.save("Әсел" if i == 0 else "Дана", "", Looks.preset(Looks.DEFAULT, str(i + 1)), i)
    Flow.level = path
    change_scene_to_file(Flow.LEVEL)
    await _frames(4)
    var level := current_scene as Level
    var name := "%s (%d players)" % [path.get_file().get_basename(), players]

    for k in range(places):
        _hang_up(level)
        for i in range(players):
            _put(level, i, _random_place(level))
        await create_timer(SETTLE_SECONDS).timeout
        _check_riders(level, name, "placed at random")

    # NOTE (mristin):
    # Next to a person, the rider stops and the conversation opens over the
    # view; it must not cover her either.
    for person in level.map.people():
        _hang_up(level)
        for i in range(players):
            var side := Vector2.from_angle(_rng.randf_range(-PI, PI))
            _put(level, i, person.position + side * Level.TALK_DISTANCE * 0.6)
        await create_timer(SETTLE_SECONDS).timeout
        _check(level.talking_to(0) != null, "%s: the rider talks to %s" % [name, person.speaker])
        _check_riders(level, name, "talking to %s" % person.speaker)
    Flow.level = ""


func _run() -> void:
    var languages := root.get_node("Languages")
    var profile := root.get_node("Profile")
    var path: String = languages.settings_path()
    _check(path != "user://settings.cfg", "the test runs with -- --settings=<its own file>")
    DirAccess.remove_absolute(path)
    profile.start_session("Fuzz")
    profile.see_instruction()
    Flow.session_asked = true

    var seed := _argument("seed", DEFAULT_SEED)
    var places := _argument("places", DEFAULT_PLACES)
    print("Seed %d, %d places" % [seed, places])
    _rng.seed = seed
    for level_path in LevelList.paths():
        for players in [1, 2]:
            await _fuzz_level(level_path, players, places)

    for key in _found:
        _check(
            false, "%s (%d times), e.g., %s" % [key, _found[key]["count"], _found[key]["example"]]
        )

    DirAccess.remove_absolute(path)
    if _failures.is_empty():
        print("RESULT: OK")
        quit(0)
    else:
        print("RESULT: FAILED (%d)" % _failures.size())
        quit(1)
