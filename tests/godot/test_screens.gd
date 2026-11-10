extends SceneTree
## Go through the screens before the level, as a new player does: the intro,
## Play, the language (Kazakh), the creator of the rider (a new name written
## on the keys of the screen, a hat and a horse chosen with the arrows,
## Ready!), the instruction, and the level, which greets the rider by her name
## and shows her looks. Then the intro again, whose Play goes straight to the
## level, and whose Levels, How to Play and Settings open their screens; the
## language changed in the settings goes back to the settings. Finishing the
## level keeps its stars, and then Play goes to the level select.
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


func _run() -> void:
    var languages := root.get_node("Languages")
    var profile := root.get_node("Profile")
    var path: String = languages.settings_path()
    _check(path != "user://settings.cfg", "the test runs with -- --settings=<its own file>")
    DirAccess.remove_absolute(path)
    languages.has_chosen = false
    profile.has_rider = false
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

    _check(profile.has_rider, "the rider is kept")
    _check(profile.rider_name() == "Әсел", "the rider's name is kept")
    _check(profile.horse_name() == "Тұлпар", "the horse keeps its default name in Kazakh")
    _check(current_scene is Instruction, "then the new player sees how to ride")
    var instruction := current_scene as Instruction
    _check(Instruction.pose(9.0)["squat"] > 0.0, "the rider squats in the instruction")
    _check(
        Instruction.pose(13.0)["speed"] > Instruction.pose(5.0)["speed"],
        "the faster squats make the horse faster"
    )
    _check(Instruction.pose(20.0)["reach"] == 1.0, "then she pulls the reins to the left")
    _check(Instruction.pose(25.0)["reach"] == -1.0, "and to the right")
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
    _check(saved.get_value("rider", "name", "") == "Әсел", "the name is saved")
    _check(saved.get_value("progress", "instruction_seen", false), "the instruction is saved")

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
    # A second child creates her own rider; then Play asks who rides.
    _check(profile.riders().size() == 1, "one rider shares the computer")
    _check(profile.new_rider(), "a new rider starts")
    _check(not profile.has_rider and profile.index == 1, "the new rider is still to create")
    profile.save("Дана", "", Looks.preset(Looks.DEFAULT, "4"))
    _check(profile.riders().size() == 2, "two riders share the computer")
    Flow.rider_asked = false
    Flow.play(self)
    await _frames(3)
    _check(current_scene is Riders, "Play asks who rides")
    var riders := current_scene as Riders
    _check(riders.cards().size() == 2, "a card for each rider")
    riders.choose(0)
    await _frames(3)
    _check(profile.index == 0 and profile.rider_name() == "Әсел", "the first rider rides again")
    _check(profile.has_seen_instruction, "with her own progress")
    profile.choose_rider(1)
    _check(profile.rider_name() == "Дана", "the second rider is kept")
    _check(profile.stars.is_empty(), "with her own stars")
    profile.choose_rider(0)
    Flow.rider_asked = true

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

    DirAccess.remove_absolute(path)
    if _failures.is_empty():
        print("RESULT: OK")
        quit(0)
    else:
        print("RESULT: FAILED (%d)" % _failures.size())
        quit(1)
