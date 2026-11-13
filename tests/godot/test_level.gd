extends SceneTree
## Play the first level with the keyboard: Grandmother sends the rider out with
## a clue, a squat rides on, the lamb joins the rider who stays next to it, it
## runs into the pen at the gate, and Grandmother thanks the rider with stars.
## Also check every level as data, the clues in every language, and two
## riders together on a split screen.

const _LEVELS_DIR := "res://data/levels"
const _LEVEL := "res://scenes/level/level.tscn"

var _failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
    if not condition:
        print("FAIL ", message)
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


func _wait(seconds: float) -> void:
    await create_timer(seconds).timeout


func _check_levels() -> void:
    for file in DirAccess.get_files_at(_LEVELS_DIR):
        if not file.ends_with(".tscn"):
            continue
        var map: LevelMap = (load(_LEVELS_DIR + "/" + file) as PackedScene).instantiate()
        for problem in map.problems():
            _check(false, "%s: %s" % [file, problem])
        map.free()


func _check_clue_texts(level: Level) -> void:
    var clue: Clue = level.map.people()[0].clues[0]
    var expected := {
        "en": "I saw a sheep near the spring.",
        "ru": "Видели овцу у родника.",
        "kk": "Бұлақтың жанында бір қой көрдім.",
    }
    var languages := root.get_node("Languages")
    var before: String = languages.current()
    for code in expected:
        TranslationServer.set_locale(code)
        var text := level.map.clue_text(clue)
        _check(
            text == expected[code],
            "the clue in %s: expected %s, got %s" % [code, expected[code], text]
        )
    TranslationServer.set_locale(before)


## Two riders: each has her own half of the screen, talks to the people on
## her own, gathers her own followers, and the mission is over when all the
## animals are home, whoever brought them.
func _check_two_players() -> void:
    var service: Node = root.get_node("Vision").service
    var level: Level = (load(_LEVEL) as PackedScene).instantiate()
    level.player_count = 2
    level.map_scene = load(_LEVELS_DIR + "/02_after_the_storm.tscn")
    Flow.level = ""
    current_scene.queue_free()
    root.add_child(level)
    current_scene = level
    await process_frame
    await process_frame

    _check(level.players() == 2, "two riders ride")
    _check(service.GetPlayerCount() == 2, "the vision splits the picture between them")
    _check(level.view(0).rect == Rect2(0, 0, 480, 540), "the first rides in the left half")
    _check(level.view(1).rect == Rect2(480, 0, 480, 540), "the second in the right half")
    _check(
        level.view(1).viewport.world_2d == level.view(0).viewport.world_2d,
        "both halves show the same steppe"
    )
    _check(level.rider(0).position.distance_to(level.rider(1).position) > 10.0, "side by side")
    var profile := root.get_node("Profile")
    _check(
        profile.players >= 2 or profile.rider_name(1) == tr("Dana"),
        "a journey of one lends the second player the default rider, Dana"
    )
    _check(level.rider(0).looks != level.rider(1).looks, "the riders do not look the same")
    var grandmother := level.talking_to(0)
    _check(grandmother != null and level.talking_to(1) == grandmother, "Grandmother sends both out")

    # NOTE (mristin):
    # Grandmother's long talk in a half has pages: a squat turns each, and the
    # squat on the last page ends it.
    var talk := level.view(1).conversation
    _check(talk.pages() > 1, "the long talk in a half has pages: %d" % talk.pages())
    for page in range(1, talk.pages()):
        await _wait(Level.TALK_SECONDS + 0.2)
        service.SquatByKeyboard(1)
        await _wait(0.3)
        _check(talk.page() == page, "the squat turns the page %d" % page)
        _check(level.talking_to(1) == grandmother, "and the talk goes on")
    await _wait(Level.TALK_SECONDS + 0.2)
    service.SquatByKeyboard(1)
    await _wait(0.3)
    _check(level.talking_to(1) == null, "the second rider's squat ends her conversation")
    _check(level.talking_to(0) == grandmother, "but not the first rider's")
    _check(level.view(0).conversation.visible, "whose conversation still shows")
    _check(not level.view(1).conversation.visible, "while the second one's is closed")

    var person: Person = null
    for each in level.map.people():
        if each != grandmother:
            person = each
    var known := level.revealed().size()
    level.rider(1).position = person.position + Vector2(0, 12)
    await _wait(0.3)
    _check(level.talking_to(1) == person, "the second rider talks to a person on her own")
    _check(level.talking_to(0) == grandmother, "while the first does not hear it")
    _check(level.revealed().size() > known, "what the person tells goes on the map")
    _check(
        level.view(0).map_view.clues.size() == level.revealed().size(),
        "the map of the first rider shows it, too"
    )
    for page in range(8):
        if level.talking_to(0) == null and level.talking_to(1) == null:
            break
        await _wait(Level.TALK_SECONDS + 0.2)
        service.SquatByKeyboard(0)
        service.SquatByKeyboard(1)
        await _wait(0.3)
    _check(level.talking_to(0) == null and level.talking_to(1) == null, "both ride on")
    service.BrakeByKeyboard(0)
    service.BrakeByKeyboard(1)
    await _wait(0.3)
    _check(service.GetSpeed(0) == 0.0 and service.GetSpeed(1) == 0.0, "each brakes her own horse")

    # NOTE (mristin):
    # The animals join the rider who stays near them: every other one the
    # first rider, the rest the second.
    var places: Array[Vector2] = [Vector2(400, 400), level.map.size - Vector2(400, 400)]
    for i in range(level.animals.size()):
        var animal: Animal = level.animals[i]
        var mine := i % 2
        level.rider(mine).position = level.rider(mine).slide(places[mine])
        level.rider(1 - mine).position = level.rider(1 - mine).slide(places[1 - mine])
        animal.position = level.rider(mine).position + Vector2(0, 8)
        await _wait(Animal.JOIN_SECONDS + 0.3)
        _check(level.followers(mine).has(animal), "the animal %d follows its rider" % i)
    var firsts := level.followers(0).size()
    _check(firsts > 0 and level.followers(1).size() > 0, "each rider has her own followers")

    var gate := level.map.home().gate()
    level.rider(1).position = gate + Vector2(0, -20)
    for animal in level.followers(1):
        animal.position = gate + Vector2(0, -40)
    await _wait(6.0)
    _check(level.followers(1).is_empty(), "the second rider brings hers home")
    _check(not level.finished, "the mission goes on while animals are still out")
    level.rider(0).position = gate + Vector2(0, -20)
    for animal in level.followers(0):
        animal.position = gate + Vector2(0, -40)
    await _wait(6.0)
    _check(level.finished, "the mission is over when all the animals are home")
    for i in range(2):
        _check(level.talking_to(i) == grandmother, "Grandmother thanks the rider %d" % i)
        var said := ""
        for label in level.view(i).conversation.find_children("*", "Label", true, false):
            said += (label as Label).text + "\n"
        var rider_name: String = root.get_node("Profile").rider_name(i)
        _check(rider_name in said, "by her own name: %s" % said)
    await _wait(Level.THANKS_SECONDS + 0.2)
    _check(level.ok_button() != null and level.ok_button().visible, "then the button OK shows")
    level.ok_button().press()
    await _wait(1.0)
    _check(current_scene is Reward, "either rider presses OK to go to the reward")
    service.SetPlayerCount(1)


## The dust behind the horse: none at a walk, a little at a trot, all of it
## at a gallop, and none in the air.
func _check_dust() -> void:
    var rider := Rider.new()
    root.add_child(rider)
    var dust: GallopDust = rider.get_node("Dust")
    var expected := {0.0: 0, 0.2: 0, 0.6: 1, 1.0: 2}
    for fraction in expected:
        rider.speed = Rider.MAX_SPEED * fraction
        await process_frame
        await process_frame
        _check(
            dust.raising() == expected[fraction],
            "at %d%% of the speed, the dust is %d" % [int(fraction * 100), expected[fraction]]
        )
    rider.queue_free()


## With one player, the camera picture glides out of the rider's way at the
## bottom right of the steppe, and back once she is away; the conversation
## stays where it is.
func _check_give_way(level: Level) -> void:
    var rider := level.rider()
    var start := rider.position
    var conversation := level.view().conversation.position
    rider.position = level.map.size - Vector2(120, 100)
    await _wait(Level.GIVE_WAY_SECONDS + 0.5)
    _check(level.hud().is_away("camera"), "the camera picture gives way to the rider")
    var panel: Control = level.get_node("Hud/CameraPanel")
    var on_screen := HudLayout.rider_rect(Vector2(960, 540) - Vector2(120, 100))
    _check(
        not Rect2(panel.position, panel.size).intersects(on_screen),
        "it does not cover her any more"
    )
    _check(level.view().conversation.position == conversation, "while the conversation stays")
    rider.position = start
    await _wait(Level.GIVE_WAY_SECONDS + 0.5)
    _check(not level.hud().is_away("camera"), "and comes back once she rode away")


func _run() -> void:
    _check_levels()
    await _check_dust()

    var level: Level = (load(_LEVEL) as PackedScene).instantiate()
    root.add_child(level)
    await process_frame
    await process_frame
    _check_clue_texts(level)
    await _check_give_way(level)

    var service: Node = root.get_node("Vision").service
    var rider := level.rider()
    _check(level.talking_to() != null, "Grandmother talks to the rider at the start")
    _check(level.revealed().size() == 1, "Grandmother gives the clue")
    await _wait(Level.TALK_SECONDS + 0.2)
    _check(level.coach_mode() == Coach.Mode.SQUAT, "the small figure squats to close the talk")
    _check(level.animals.size() == 1, "one lamb is lost")

    var blocked := rider.slide(Vector2(-50.0, 500.0))
    _check(rider.at_edge and blocked.x > 0.0, "the edge of the steppe blocks like a wall")
    rider.slide(rider.position)
    _check(not rider.at_edge, "the steppe inside is open")

    await _wait(1.5)
    var start := rider.position
    for i in range(6):
        service.SquatByKeyboard(0)
        await _wait(2.0)
    _check(level.talking_to() == null, "a squat ends the conversation")
    _check(rider.position.y < start.y - 100.0, "the squats ride north, got %s" % rider.position)

    # NOTE (mristin):
    # Both hands above the head brake: a walking or trotting horse halts, a
    # galloping one rears up and stops at once.
    service.SquatByKeyboard(0)
    await _wait(0.3)
    _check(service.GetSpeed(0) > 0.0, "the horse runs before the brake")
    _check(rider.gait() < 3, "it does not gallop yet")
    service.BrakeByKeyboard(0)
    await _wait(0.3)
    _check(service.GetSpeed(0) == 0.0, "the brake stops the horse at once")
    _check(rider.rearing() == 0.0, "a horse which does not gallop halts without rearing")
    for i in range(12):
        service.SquatByKeyboard(0)
        await _wait(0.5)
    _check(rider.gait() == 3, "brisk squats gallop, got the gait %d" % rider.gait())
    service.BrakeByKeyboard(0)
    await _wait(0.3)
    _check(service.GetSpeed(0) == 0.0, "the brake stops the galloping horse at once")
    _check(rider.rearing() > 0.0, "and it rears up")
    var reared_at := rider.position
    await _wait(0.5)
    _check(rider.position.distance_to(reared_at) < 1.0, "a rearing horse does not go on")
    await _wait(Rider.REAR_SECONDS)
    _check(rider.rearing() == 0.0, "then it stands on all four again")

    # NOTE (mristin):
    # Let the horse stop, then stand next to the lamb.
    await _wait(14.0)
    _check(service.GetGait(0) == 0, "the horse stops")
    _check(level.coach_mode() == Coach.Mode.SQUAT, "the small figure invites a squat")
    var before := rider.position
    rider.position = Vector2(2.0, rider.position.y)
    await _wait(0.2)
    _check(level.coach_mode() == Coach.Mode.REACH, "at the edge, the figure reaches across")
    rider.position = before

    # NOTE (mristin):
    # The impatient horse stamps a hoof; running into the same obstacle twice
    # shows how to turn.
    _check(rider.still_time > Rider.IMPATIENT_SECONDS, "the horse stands still for a while")
    var solid: Vector3 = level.map.solids()[0]
    for bump in range(2):
        # NOTE (mristin):
        # Ride north into the obstacle from just south of it, then away.
        rider.position = Vector2(solid.x, solid.y) + Vector2(0, solid.z + Rider.RADIUS + 1.0)
        rider.heading = 0.0
        rider.ride(0.1, 1.0, 0.0)
        level.note_bumps(0.016)
        rider.position = Vector2(solid.x, solid.y) + Vector2(0, solid.z + 60.0)
        rider.ride(0.016, 1.0, 0.0)
        level.note_bumps(0.016)
    _check(level.turn_hint(), "two runs into the same obstacle show how to turn")
    rider.position = before
    var lamb: Animal = level.animals[0]
    rider.position = lamb.position + Vector2(0, 14)
    await _wait(1.5)
    _check(lamb.state == Animal.State.FOLLOWING, "the lamb follows the rider who stays near")

    rider.position = level.map.home().gate() + Vector2(0, -20)
    await _wait(6.0)
    _check(lamb.state == Animal.State.HOME, "the lamb runs into the pen")
    _check(level.finished, "the level ends when all the animals are home")
    _check(level.talking_to() != null, "Grandmother thanks the rider")
    _check(level.stars() == 3, "a quick ride earns three stars, got %d" % level.stars())
    var profile := root.get_node("Profile")
    _check(profile.stars.get(level.level_id(), 0) == 3, "the stars are kept")

    await _wait(Level.THANKS_SECONDS)
    service.SquatByKeyboard(0)
    await _wait(1.0)
    _check(current_scene is Reward, "a squat after the thanks goes to the reward")

    await _check_two_players()

    if _failures.is_empty():
        print("RESULT: OK")
        quit(0)
    else:
        print("RESULT: FAILED (%d)" % _failures.size())
        quit(1)
