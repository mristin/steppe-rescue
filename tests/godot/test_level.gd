extends SceneTree
## Play the first level with the keyboard: Grandmother sends the rider out with
## a clue, a squat rides on, the lamb joins the rider who stays next to it, it
## runs into the pen at the gate, and Grandmother thanks the rider with stars.
## Also check every level as data, and the clues in every language.

const _LEVELS_DIR := "res://data/levels"

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


func _run() -> void:
    _check_levels()

    var level: Level = (load("res://scenes/level/level.tscn") as PackedScene).instantiate()
    root.add_child(level)
    await process_frame
    await process_frame
    _check_clue_texts(level)

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
        service.SquatByKeyboard()
        await _wait(2.0)
    _check(level.talking_to() == null, "a squat ends the conversation")
    _check(rider.position.y < start.y - 100.0, "the squats ride north, got %s" % rider.position)

    # NOTE (mristin):
    # Let the horse stop, then stand next to the lamb.
    await _wait(14.0)
    _check(service.GetGait() == 0, "the horse stops")
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
    service.SquatByKeyboard()
    await _wait(1.0)
    _check(current_scene is Reward, "a squat after the thanks goes to the reward")

    if _failures.is_empty():
        print("RESULT: OK")
        quit(0)
    else:
        print("RESULT: FAILED (%d)" % _failures.size())
        quit(1)
