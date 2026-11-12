extends SceneTree
## Go through the screens before the level, as a new player does: the intro,
## Play, the language (Kazakh), the name of the journey, one rider, the creator
## of the rider (a new name written on the keys of the screen, a hat and a horse
## chosen with the arrows, Ready!), the instruction, and the level, which greets
## the rider by her name and shows her looks. Then the intro again, whose Play
## goes straight to the level, and whose Levels, How to Play and Settings open
## their screens; the language changed in the settings goes back to the
## settings. Finishing the level keeps its stars, and then Play goes to the
## level select. A second journey keeps its own rider and progress, and Play
## asks which journey goes on. A third journey of two players creates two
## riders, who can not ride the same, and both ride in the level, each greeted
## by her own name.
##
## Run it with `-- --settings=user://<file>`, so that it starts as a new player
## and does not change the settings of the player (see the autoload Languages).

var _failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
    if not condition:
        print("FAIL ", message)
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


func _frames(count: int) -> void:
    for i in range(count):
        await process_frame


## A journey of two players: each creates her rider, the second can not ride
## the painted rider nor the horse of the first, and both ride in the level,
## each greeted in her own half by her own name.
func _check_two_players(profile: Node) -> void:
    profile.start_session("Екеуміз")
    Flow.session_asked = true
    Flow.play(self)
    await _frames(3)
    _check(current_scene is PlayerCount, "a new journey asks how many ride")
    (current_scene as PlayerCount).choose(2)
    await _frames(3)
    _check(profile.players == 2, "two riders ride")
    var first := current_scene as RiderCreator
    _check(first != null and first.player == 0, "the first player creates her rider first")
    first.choose_rider("2")
    first.choose_horse("3")
    first.finish()
    await _frames(3)
    var second := current_scene as RiderCreator
    _check(second != null and second.player == 1, "then the second player creates hers")
    _check(second.looks["rider"] != "2", "she does not start on the rider of the first")
    _check(second.looks["steed"] != "3", "nor on her horse")
    second.choose_rider("2")
    second.choose_horse("3")
    _check(second.looks["rider"] != "2", "she can not choose the rider of the first")
    _check(second.looks["steed"] != "3", "nor her horse")
    for i in range(3):
        second.randomize_looks()
        _check(
            second.looks["rider"] != "2" and second.looks["steed"] != "3",
            "Random never chooses them either"
        )
    second.choose_rider("4")
    second.finish()
    await _frames(3)
    _check(profile.has_riders(), "both riders are kept")
    _check(profile.rider(1).looks["rider"] == "4", "with their own looks")
    _check(profile.rider_name(1) == "Дана", "the second rider has her own default name")
    _check(current_scene is Instruction, "then they see how to ride")
    (current_scene as Instruction).finish()
    await _frames(3)
    _check(current_scene is Level, "then the level starts")
    var level := current_scene as Level
    _check(level.players() == 2, "both ride in the level")
    _check(level.rider(0).looks["rider"] == "2", "the first rides her rider")
    _check(level.rider(1).looks["rider"] == "4", "the second rides hers")
    await _frames(10)
    for i in range(2):
        var said := ""
        for label in level.view(i).conversation.find_children("*", "Label", true, false):
            said += (label as Label).text + "\n"
        _check(
            profile.rider_name(i) in said,
            "Grandmother greets each rider by her name in her half: %s" % said
        )
    _check(
        (
            level.view(0).conversation.position.x < 480.0
            and level.view(1).conversation.position.x >= 480.0
        ),
        "each conversation is in the half of its rider"
    )


func _run() -> void:
    var languages := root.get_node("Languages")
    var profile := root.get_node("Profile")
    var path: String = languages.settings_path()
    _check(path != "user://settings.cfg", "the test runs with -- --settings=<its own file>")
    DirAccess.remove_absolute(path)
    if DirAccess.dir_exists_absolute(profile.saves_dir()):
        for file in DirAccess.get_files_at(profile.saves_dir()):
            DirAccess.remove_absolute(profile.saves_dir().path_join(file))
    profile.session_id = ""
    Flow.session_asked = false
    languages.has_chosen = false
    profile.has_seen_instruction = false
    profile.stars = {}

    change_scene_to_file(Flow.INTRO)
    await _frames(3)
    _check(current_scene is Intro, "the game starts with the intro")

    Flow.play(self)
    await _frames(3)
    _check(current_scene is LanguageSelect, "a new player chooses the language first")
    var select := current_scene as LanguageSelect
    _check(select.cards().size() == 3, "there are three languages")
    select.cards()[2].press()
    await _frames(3)
    _check(languages.current() == "kk", "Kazakh is chosen")
    _check(current_scene is SessionName, "then the new player names her journey")
    var naming := current_scene as SessionName
    _check(naming.written == profile.default_session_name(), "the name starts as the date")
    var name_keys := {}
    for key in naming.keyboard().keys():
        name_keys[key.text] = key
    _check(
        name_keys.has("7") and name_keys.has(SessionName.SPACE), "the keys have digits and a space"
    )
    for letter in ["Ж", "О", "Л", SessionName.SPACE, "1"]:
        name_keys[letter].press()
    _check(naming.written == "Жол 1", "the journey is named: %s" % naming.written)
    naming.finish()
    await _frames(3)
    _check(profile.session_name == "Жол 1", "the journey keeps its name")
    _check(current_scene is PlayerCount, "then the players choose how many ride")
    (current_scene as PlayerCount).cards()[0].press()
    await _frames(3)
    _check(profile.players == 1, "one rider rides")
    _check(current_scene is RiderCreator, "then the new player creates her rider")

    var creator := current_scene as RiderCreator
    var keyboard := creator.keyboard()
    _check(not keyboard.visible, "the keys show only while a name is written")
    var keys := {}
    for key in keyboard.keys():
        keys[key.text] = key
    _check(keys.has("Ә") and keys.has("Ұ"), "the keyboard has the Kazakh letters")
    for letter in ["Ә", "С", "Е", "Л"]:
        keys[letter].press()
    _check(creator.rider_name == "Әсел", "the name is written: %s" % creator.rider_name)
    _check(keyboard.visible, "the keys show while the name is written")

    # NOTE (mristin):
    # The hand clicks by holding the bird still over a button.
    HandCursor.held = true
    HandCursor.by_hand = true
    var backspace: DwellButton = keys[OnScreenKeyboard.BACKSPACE]
    HandCursor.at = backspace.get_global_rect().get_center()
    await create_timer(DwellButton.DWELL_SECONDS + 0.3).timeout
    HandCursor.by_hand = false
    HandCursor.held = false
    _check(
        creator.rider_name == "Әсе", "the held hand takes a letter back: %s" % creator.rider_name
    )
    keys["Л"].press()

    creator.choose_rider("3")
    _check(creator.looks["hat"] == "scarf", "the third painted rider wears the headscarf")
    creator.choose_rider("1")
    creator.choose_horse("3")
    _check(creator.looks["horse"] == "grey", "the third painted horse is grey")
    creator._step("hat", 1)
    _check(creator.looks["hat"] == "borik", "the arrow chooses the next hat")
    creator.finish()
    await _frames(3)

    _check(profile.has_riders(), "the rider is kept")
    _check(profile.rider_name() == "Әсел", "the rider's name is kept")
    _check(profile.rider().horse_name() == "Тұлпар", "the horse keeps its default name in Kazakh")
    _check(current_scene is Instruction, "then the new player sees how to ride")
    var instruction := current_scene as Instruction
    _check(Instruction.pose(9.0)["squat"] > 0.0, "the rider squats in the instruction")
    _check(
        Instruction.pose(13.0)["speed"] > Instruction.pose(5.0)["speed"],
        "the faster squats make the horse faster"
    )
    _check(Instruction.pose(16.0)["speed"] == 0.0, "when she stops squatting, the horse stops")
    _check(Instruction.pose(20.0)["reach"] == 1.0, "then she pulls the reins to the left")
    _check(Instruction.pose(25.0)["reach"] == -1.0, "and to the right")
    _check(instruction.has_method("_draw"), "the instruction draws its animation")
    _check(Instruction.pose(30.0)["speed"] > 0.8, "then she gallops again")
    var take_off: float = Instruction.TAKE_OFFS[0]
    _check(Instruction.pose(take_off - 0.2)["jump"] >= 0, "then she jumps")
    _check(Instruction.pose(take_off - 0.2)["flight"] < 0.0, "a little before her horse")
    _check(Instruction.pose(take_off + 0.3)["flight"] > 0.0, "and her horse jumps, too")
    _check(Instruction.pose(take_off + 0.3)["speed"] > 0.8, "keeping its gallop")
    _check(instruction.caption(take_off) != instruction.caption(30.0), "a line tells of the jump")
    var brake := Instruction.BRAKE
    _check(Instruction.pose(brake + 1.0)["hands_up"] == 1.0, "and raises both hands: the brake")
    _check(Instruction.pose(brake + 0.7)["rear"] > 0.4, "and the horse rears up")
    _check(Instruction.pose(brake + 1.0)["speed"] == 0.0, "and stops")
    _check(
        instruction.caption(brake + 1.0) != instruction.caption(take_off),
        "a line tells of the brake"
    )
    _check(PaintedGirl.reins_frame(1.0) == 2, "she pulls far to the left in the painted frame")
    _check(PaintedGirl.reins_frame(-1.0) == 5, "and far to the right")
    _check(instruction.caption(20.0) != instruction.caption(9.0), "a line says what she does")
    await create_timer(Instruction.REACH + 2.0 - instruction.time).timeout
    _check(instruction.heading < -0.5, "and the horse turns left: %f" % instruction.heading)
    instruction.finish()
    await _frames(3)
    _check(profile.has_seen_instruction, "the instruction is seen")
    _check(current_scene is Level, "then the level starts")
    var level := current_scene as Level
    _check(level.rider().looks["horse"] == "grey", "the rider rides her own horse")
    await _frames(10)
    var conversation: Conversation = level.find_children("*", "Conversation", true, false)[0]
    var said := ""
    for label in conversation.find_children("*", "Label", true, false):
        said += (label as Label).text + "\n"
    _check("Әсел" in said, "Grandmother greets the rider by her name: %s" % said)

    var saved := ConfigFile.new()
    _check(saved.load(path) == OK, "the settings are saved")
    _check(saved.get_value("general", "language", "") == "kk", "the language is saved")
    _check(
        saved.get_value("general", "last_session", "") == profile.session_id,
        "the journey is remembered"
    )
    var journey: Dictionary = profile.read(profile.session_id)
    _check(journey["name"] == "Жол 1", "the name of the journey is saved")
    _check(journey["riders"][0]["name"] == "Әсел", "the name is saved")
    _check(journey["progress"]["instruction_seen"], "the instruction is saved")

    change_scene_to_file(Flow.INTRO)
    await _frames(3)
    Flow.play(self)
    await _frames(3)
    _check(current_scene is Level, "a known player goes straight from Play to the level")

    change_scene_to_file(Flow.INTRO)
    await _frames(3)
    var buttons := (current_scene as Intro).buttons()
    _check(buttons.size() == 4, "the intro has Play, Levels, How to Play and Settings")
    buttons[1].press()
    await _frames(3)
    _check(current_scene is LevelSelect, "Levels opens the level select")
    var banners := (current_scene as LevelSelect).banners()
    _check(banners.size() == LevelList.paths().size(), "every level has its spot")
    _check(banners[0] != null and banners[0].primary, "the first level is open and next")
    for i in range(1, banners.size()):
        _check(banners[i] == null, "the level %d is not open yet" % (i + 1))
    Flow.cancel(self)
    await _frames(3)
    _check(current_scene is Intro, "the level select goes back to the intro")

    (current_scene as Intro).buttons()[2].press()
    await _frames(3)
    _check(current_scene is Instruction, "How to Play shows the instruction")
    (current_scene as Instruction).finish()
    await _frames(3)
    _check(current_scene is Intro, "and goes back to the intro")

    (current_scene as Intro).buttons()[3].press()
    await _frames(3)
    _check(current_scene is Settings, "Settings opens the settings")
    (current_scene as Settings).buttons()[0].press()
    await _frames(3)
    _check(current_scene is LanguageSelect, "the settings change the language")
    (current_scene as LanguageSelect).cards()[1].press()
    await _frames(3)
    _check(languages.current() == "ru", "Russian is chosen")
    _check(current_scene is Settings, "the language goes back to the settings")
    (current_scene as Settings).buttons()[2].press()
    await _frames(3)
    _check(current_scene is Intro, "Back goes to the intro")

    # NOTE (mristin):
    # A second journey with its own rider; then Play asks which journey goes on.
    _check(profile.sessions().size() == 1, "one journey is saved")
    var first: String = profile.session_id
    profile.start_session("Дана")
    _check(not profile.has_riders(), "the new journey's rider is still to create")
    profile.save("Дана", "", Looks.preset(Looks.DEFAULT, "4"))
    _check(profile.sessions().size() == 2, "two journeys are saved")
    Flow.session_asked = false
    Flow.play(self)
    await _frames(3)
    _check(current_scene is Sessions, "Play asks which journey goes on")
    var journeys := current_scene as Sessions
    _check(journeys.shown()[0]["id"] == profile.session_id, "the last journey continues first")
    var index_of_first := -1
    for i in range(journeys.shown().size()):
        if journeys.shown()[i]["id"] == first:
            index_of_first = i
    journeys.choose(index_of_first)
    await _frames(3)
    _check(
        profile.session_id == first and profile.rider_name() == "Әсел", "the first journey goes on"
    )
    _check(profile.has_seen_instruction, "with its own progress")
    var second := ""
    for session in profile.sessions():
        if session["id"] != first:
            second = session["id"]
    profile.choose_session(second)
    _check(profile.rider_name() == "Дана", "the second journey keeps its rider")
    _check(profile.stars.is_empty(), "and its own stars")
    profile.choose_session(first)
    Flow.session_asked = true

    # NOTE (mristin):
    # Finishing every level keeps the stars, opens the next level, and sends
    # Play to the level select.
    var paths := LevelList.paths()
    for level_path in paths:
        _check(LevelList.is_open(level_path, profile), "the level %s is open" % level_path)
        profile.finish_level(LevelList.id(level_path), 2)
    profile.finish_level(LevelList.id(paths[0]), 1)
    _check(profile.stars[LevelList.id(paths[0])] == 2, "the most stars are kept")
    _check(LevelList.next(profile) == "", "all the levels are finished")
    Flow.play(self)
    await _frames(3)
    _check(current_scene is LevelSelect, "then Play goes to the level select")

    await _check_two_players(profile)

    DirAccess.remove_absolute(path)
    if _failures.is_empty():
        print("RESULT: OK")
        quit(0)
    else:
        print("RESULT: FAILED (%d)" % _failures.size())
        quit(1)
