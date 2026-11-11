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


## With two players, each chooses her own gift, one after the other, and has
## her own wardrobe.
func _check_two_players(profile: Node) -> void:
    profile.start_session("two")
    profile.set_players(2)
    profile.save("", "", Looks.DEFAULT, 0)
    profile.save("", "", RiderProfile.default_looks(1), 1)
    _check(profile.has_riders(), "both riders are created")

    Flow.reward(self, 3, "01_the_lamb_by_the_spring")
    await _frames(3)
    var first := current_scene as Reward
    _check(first != null and first.player == 0, "the first player chooses her gift first")
    var first_piece: String = first.offered[0][0]
    first.choose(0)
    _check(not profile.was_rewarded("01_the_lamb_by_the_spring"), "the second still chooses")
    first.go_on()
    await _frames(3)
    var second := current_scene as Reward
    _check(second != null and second.player == 1, "then the second player chooses hers")
    _check(not second.cards().is_empty(), "and she is offered gifts, too")
    var second_piece: String = second.offered[0][0]
    second.choose(0)
    _check(profile.was_rewarded("01_the_lamb_by_the_spring"), "the level gave its gifts")
    _check(profile.rider(0).finery.has(first_piece), "the first rider wins her piece")
    _check(profile.rider(1).finery.has(second_piece), "the second rider wins hers")
    _check(
        first_piece == second_piece or not profile.rider(0).finery.has(second_piece),
        "each into her own wardrobe"
    )
    second.go_on()
    await _frames(3)
    _check(current_scene is LevelSelect, "then the level select")

    Flow.wardrobe_player = 1
    Flow.open(self, Flow.WARDROBE)
    await _frames(3)
    var wardrobe := current_scene as Wardrobe
    _check(wardrobe.player == 1, "the wardrobe of the second rider opens")
    _check(
        wardrobe.pieces().size() == 1 and wardrobe.pieces()[0] == second_piece,
        "with her own finery"
    )
    wardrobe.toggle(second_piece)
    _check(not profile.rider(1).wears(second_piece), "she takes her piece off")
    _check(
        first_piece != second_piece or profile.rider(0).wears(first_piece),
        "which leaves the first rider dressed"
    )

    var saved: Dictionary = profile.read(profile.session_id)
    _check(int(saved["players"]) == 2, "the journey keeps two players")
    _check(saved["riders"].size() == 2, "and both riders")


func _run() -> void:
    var profile := root.get_node("Profile")
    var path: String = root.get_node("Languages").settings_path()
    _check(path != "user://settings.cfg", "the test runs with -- --settings=<its own file>")
    DirAccess.remove_absolute(path)
    if DirAccess.dir_exists_absolute(profile.saves_dir()):
        for file in DirAccess.get_files_at(profile.saves_dir()):
            DirAccess.remove_absolute(profile.saves_dir().path_join(file))
    profile.start_session("test")
    profile.set_players(1)
    var finery: Dictionary = profile.rider(0).finery

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
    _check(finery.get(piece, 0) == 1, "the chosen piece is won")
    _check(Finery.step(profile.rider().dressed(), piece) == 1, "and worn")
    _check(not reward.cards()[0].visible, "the other cards go")
    reward.choose(0)
    _check(finery.size() == 1, "only one piece is won")
    reward.go_on()
    await _frames(3)
    _check(current_scene is LevelSelect, "then the level select")

    var saved: Dictionary = profile.read(profile.session_id)
    _check(int(saved["riders"][0]["finery"].get(piece, 0)) == 1, "the finery is saved")

    # NOTE (mristin):
    # Riding the level again gives no gift, so that it is no mine of finery.
    change_scene_to_file(Flow.REWARD)
    await _frames(3)
    _check((current_scene as Reward).replayed, "the level gave its gift already")
    _check((current_scene as Reward).cards().is_empty(), "a level ridden again gives no gift")
    Flow.reward_level = ""

    for each in Finery.PIECES:
        finery[each] = Finery.PIECES[each]["steps"]
    _check(Finery.offer(finery, 3, rng).is_empty(), "nothing more when all is won")
    change_scene_to_file(Flow.REWARD)
    await _frames(3)
    _check((current_scene as Reward).cards().is_empty(), "the reward offers nothing more")

    profile.save("", "", profile.rider().dressed())
    _check(not profile.rider(0).looks.has("finery"), "the looks are saved without the finery")

    Flow.open(self, Flow.RIDER_CREATOR)
    await _frames(3)
    var creator := current_scene as RiderCreator
    creator._step("hat", 1)
    await _frames(2)
    _check(creator.camera_panel().looks == creator.looks, "the camera dresses her as she chooses")
    _check(Finery.step(creator.looks, "saddle") == 2, "the creator shows the rider in her finery")

    # NOTE (mristin):
    # The wardrobe: she takes a piece off and puts it on again.
    profile.rider(0).finery = {"saddle": 1, "earrings": 1}
    profile.rider(0).taken_off = []
    Flow.wardrobe_player = 0
    Flow.open(self, Flow.WARDROBE)
    await _frames(3)
    var wardrobe := current_scene as Wardrobe
    _check(wardrobe.cards().size() == 2, "the wardrobe shows the pieces she won")
    _check(wardrobe.in_worn_panel("earrings"), "what she wears is in the panel of the worn")
    wardrobe.toggle("earrings")
    _check(not profile.rider().wears("earrings"), "she takes the earrings off")
    _check(not wardrobe.in_worn_panel("earrings"), "and they move to the other panel")
    _check(not profile.rider().dressed()["finery"].has("earrings"), "and does not wear them")
    _check(profile.rider().dressed()["finery"].has("saddle"), "but still the saddle")
    saved = profile.read(profile.session_id)
    _check("earrings" in saved["riders"][0]["taken_off"], "what she took off is saved")
    wardrobe.toggle("earrings")
    _check(profile.rider().wears("earrings"), "she puts them on again")
    var all_but_home := {}
    for each in Finery.PIECES:
        if Finery.PIECES[each]["for"] != "home":
            all_but_home[each] = Finery.PIECES[each]["steps"]
    for entry in Finery.offer(all_but_home, 3, rng):
        _check(
            Finery.has_picture(entry[0], entry[1]),
            "a piece of the home is offered only once it is painted: %s" % entry[0]
        )

    await _check_two_players(profile)

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
