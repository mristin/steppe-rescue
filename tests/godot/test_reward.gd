extends SceneTree
## Check the reward and the screens around it: after a level, three pieces of
## finery are offered, the more splendid ones for more stars; the chosen one is
## won, kept and worn; when all is won, nothing more is offered. The creator
## dresses the player in the camera picture in the looks she chooses, and the
## request for room goes on once the player is ready.
##
## Run it with `-- --settings=user://<file>`, so that it does not change the
## settings of the player.

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
    var profile := root.get_node("Profile")
    var path: String = root.get_node("Languages").settings_path()
    _check(path != "user://settings.cfg", "the test runs with -- --settings=<its own file>")
    DirAccess.remove_absolute(path)
    profile.finery = {}

    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var offer := Finery.offer({}, 1, rng)
    _check(offer.size() == Finery.OFFERED, "three pieces are offered")
    var pieces := {}
    for entry in offer:
        pieces[entry[0]] = true
        _check(entry[1] == 1, "a new piece starts with its first step")
    _check(pieces.size() == Finery.OFFERED, "the pieces on offer differ")
    offer = Finery.offer({"mane": 2, "saddle": 1}, 3, rng)
    _check(offer[0] == ["mane", 3], "three stars offer the most splendid step first: %s" % [offer])

    Flow.reward_stars = 3
    Flow.reward_level = "01_the_lamb_by_the_spring"
    change_scene_to_file(Flow.REWARD)
    await _frames(3)
    _check(current_scene is Reward, "the reward shows")
    var reward := current_scene as Reward
    _check(reward.cards().size() == 3, "three cards are offered")
    for card in reward.cards():
        _check(card.picture != null, "each card shows its piece")
    var piece: String = reward.offered[1][0]
    reward.choose(1)
    _check(profile.finery.get(piece, 0) == 1, "the chosen piece is won")
    _check(Finery.step(profile.dressed(), piece) == 1, "and worn")
    _check(not reward.cards()[0].visible, "the other cards go")
    reward.choose(0)
    _check(profile.finery.size() == 1, "only one piece is won")
    reward.go_on()
    await _frames(3)
    _check(current_scene is LevelSelect, "then the level select")

    var saved := ConfigFile.new()
    saved.load(path)
    _check(saved.get_value("progress", "finery", {}).get(piece, 0) == 1, "the finery is saved")

    # NOTE (mristin):
    # Riding the level again gives no gift, so that it is no mine of finery.
    change_scene_to_file(Flow.REWARD)
    await _frames(3)
    _check((current_scene as Reward).replayed, "the level gave its gift already")
    _check((current_scene as Reward).cards().is_empty(), "a level ridden again gives no gift")
    Flow.reward_level = ""

    for each in Finery.PIECES:
        profile.finery[each] = Finery.PIECES[each]["steps"]
    _check(Finery.offer(profile.finery, 3, rng).is_empty(), "nothing more when all is won")
    change_scene_to_file(Flow.REWARD)
    await _frames(3)
    _check((current_scene as Reward).cards().is_empty(), "the reward offers nothing more")

    profile.save("", "", profile.dressed())
    _check(not profile.looks.has("finery"), "the looks are saved without the finery")

    Flow.open(self, Flow.RIDER_CREATOR)
    await _frames(3)
    var creator := current_scene as RiderCreator
    creator._step("hat", 1)
    await _frames(2)
    _check(creator.camera_panel().looks == creator.looks, "the camera dresses her as she chooses")
    _check(Finery.step(creator.looks, "saddle") == 2, "the creator shows the rider in her finery")

    # NOTE (mristin):
    # The wardrobe: she takes a piece off and puts it on again.
    profile.finery = {"saddle": 1, "earrings": 1}
    profile.taken_off = []
    Flow.open(self, Flow.WARDROBE)
    await _frames(3)
    var wardrobe := current_scene as Wardrobe
    _check(wardrobe.cards().size() == 2, "the wardrobe shows the pieces she won")
    wardrobe.toggle("earrings")
    _check(not profile.wears("earrings"), "she takes the earrings off")
    _check(not profile.dressed()["finery"].has("earrings"), "and does not wear them")
    _check(profile.dressed()["finery"].has("saddle"), "but still the saddle")
    saved = ConfigFile.new()
    saved.load(path)
    _check("earrings" in saved.get_value("progress", "taken_off", []), "what she took off is saved")
    wardrobe.toggle("earrings")
    _check(profile.wears("earrings"), "she puts them on again")
    var all_but_home := {}
    for each in Finery.PIECES:
        if Finery.PIECES[each]["for"] != "home":
            all_but_home[each] = Finery.PIECES[each]["steps"]
    for entry in Finery.offer(all_but_home, 3, rng):
        _check(
            Finery.has_picture(entry[0], entry[1]),
            "a piece of the home is offered only once it is painted: %s" % entry[0]
        )

    Flow.room_asked = false
    Flow.open(self, Flow.FREE_SPACE)
    await _frames(3)
    _check(current_scene is FreeSpace, "the game asks for room")
    (current_scene as FreeSpace).finish()
    await _frames(3)
    _check(Flow.room_asked, "it asks once")
    _check(current_scene is Intro, "and goes back")

    DirAccess.remove_absolute(path)
    if _failures.is_empty():
        print("RESULT: OK")
        quit(0)
    else:
        print("RESULT: FAILED (%d)" % _failures.size())
        quit(1)
