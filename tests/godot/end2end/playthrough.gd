extends SceneTree
## Play the whole game, from the start to the end and once more after a
## restart, as players do, much faster than in real time, and check its
## contracts all the way (see screen_contracts.gd and level_contracts.gd): a
## property-based test, whose
## random choices come from a seed. The tests test_one_player.gd and
## test_two_players.gd play it with one and with two players (see
## [member players]).
##
## New players start at the intro, choose their language, name their
## journey, choose how many ride, create their riders and see how to ride.
## Then they play every level, one after the other (see rider_bot.gd): they
## talk to every person and turn every page of every conversation, find
## every animal and bring it home, let their horses drink and graze, and
## choose their gifts at the end of each level. They click the buttons with
## the mouse (and sometimes hold the hand still over them), and ride only
## with the keys. On their way, they take detours: they open How to Play,
## the settings and the wardrobe, change the language, write names, try
## other looks, ride a level again from the start, and play tricks in the
## level (the map, the language, Escape).
##
## At the end, every level must be finished with its stars and every rider
## must have her gift of every level, and Play leads to the level select.
## Then the game starts again (as if quit and started): the journey must come
## back from the disk as it was, and the players start a new journey, which
## keeps its own progress, and play its first levels.
##
## The test runs the game [constant DEFAULT_TIME_SCALE] times faster than
## the fixed frame rate (with which the tests run) gives. Pass `-- --seed=<n>`
## to try other choices, `-- --time-scale=<x>` for another speed, and
## `-- --new-journey-levels=<n>` for more levels of the new journey.
##
## Not a test itself (its name does not start with test_): the tests extend
## it. Run them with `-- --settings=user://<file>`, so that they do not change
## the settings and the journeys of the player (see the autoload Languages).

const LevelContracts := preload("res://tests/godot/end2end/level_contracts.gd")
const Keys := preload("res://tests/godot/end2end/keys.gd")
const Layout := preload("res://tests/godot/layout.gd")
const Navigator := preload("res://tests/godot/end2end/navigator.gd")
const RiderBot := preload("res://tests/godot/end2end/rider_bot.gd")
const ScreenContracts := preload("res://tests/godot/end2end/screen_contracts.gd")

const DEFAULT_SEED := 20261113

## How much faster the game runs than the fixed frame rate gives: one frame
## of 1/60 s plays this many 60ths of a second.
const DEFAULT_TIME_SCALE := 3.0

## How many levels the players of the new journey play after the restart.
const DEFAULT_NEW_JOURNEY_LEVELS := 2

## A level which takes longer than this, in seconds of the game, is stuck.
const LEVEL_SECONDS := 1500.0

## The screens between the levels may take at most this many actions in all.
const MAX_ACTIONS := 1500

## The contracts of a level are checked on every this many frames...
const CHECK_EVERY := 2

## ... and what the players see (the HUD, the texts) on every this many
## checks, since it is slower to check and counts only if it lasts.
const FULL_EVERY := 3

## The chance that a rider rides a level again from the start (R), once.
const RESTART_CHANCE := 0.2

## The chance on each frame of a talk that a player switches the language.
const LANGUAGE_IN_TALK_CHANCE := 0.01

## The chance that a click is a hand held still over the button.
const DWELL_CHANCE := 0.1

## How many players ride: 1 or 2; the tests set it.
var players := 1

var _failures: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _screen_contracts := ScreenContracts.new()
var _level_contracts := LevelContracts.new()
var _time_scale := DEFAULT_TIME_SCALE

## The seconds of the game played so far.
var _clock := 0.0

## The phase: "first", the journey through every level; then "second", the
## new journey after the restart.
var _phase := "first"
var _new_journey_levels := DEFAULT_NEW_JOURNEY_LEVELS
var _first_session := ""
var _second_session := ""

## The screens seen, by their class, in each phase.
var _seen := {}

## The people who talked to the riders, by the level and the phase.
var _talked := {}

## The levels ridden again from the start, by their id and the phase.
var _restarted := {}

## The levels left by squatting, by OK and by Enter.
var _leaves := {}

## What happened on the current screen: e.g., the detours taken.
var _screen: Node = null
var _here := {}
var _actions := 0
var _levels_played := 0
var _pages_turned := 0
var _conversations := 0


func _check(condition: bool, message: String) -> void:
    if not condition:
        print("FAIL ", message)
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


func _argument(name: String, default: String) -> String:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--%s=" % name):
            return arg.get_slice("=", 1)
    return default


## Let the frames pass, counting the time of the game.
func _frames(count: int) -> void:
    for i in range(count):
        await process_frame
        _clock += _time_scale / 60.0


func _wait(seconds: float) -> void:
    var until := _clock + seconds
    while _clock < until:
        await _frames(1)


func _profile() -> Node:
    return root.get_node("Profile")


func _name(screen: Node) -> String:
    if screen == null:
        return "no screen"
    var script := screen.get_script() as Script
    if script != null and script.get_global_name() != "":
        return script.get_global_name()
    return screen.get_class()


## Click the button as a player does: mostly with the mouse in its middle,
## which checks that nothing else catches the click there, sometimes with the
## hand held still over it.
func _click(button: DwellButton, what: String) -> void:
    if button == null or not is_instance_valid(button):
        _check(false, "%s: the button %s is missing" % [_phase, what])
        return
    _check(
        button.is_visible_in_tree() and not button.disabled,
        "%s: the button %s shows and can be pressed" % [_phase, what]
    )
    var pressed := [false]
    var on_press := func() -> void: pressed[0] = true
    button.pressed.connect(on_press)
    var at := button.get_global_rect().get_center()
    if _rng.randf() < DWELL_CHANCE:
        HandCursor.held = true
        HandCursor.by_hand = true
        HandCursor.at = at
        var until := _clock + DwellButton.DWELL_SECONDS + 1.0
        while not pressed[0] and _clock < until and is_instance_valid(button):
            await _frames(1)
        HandCursor.held = false
        HandCursor.by_hand = false
        _check(pressed[0], "%s: the hand held over %s clicks it" % [_phase, what])
    else:
        var motion := InputEventMouseMotion.new()
        motion.position = at
        motion.global_position = at
        Input.parse_input_event(motion)
        for down in [true, false]:
            var event := InputEventMouseButton.new()
            event.button_index = MOUSE_BUTTON_LEFT
            event.pressed = down
            event.position = at
            event.global_position = at
            Input.parse_input_event(event)
        await _frames(1)
        _check(
            pressed[0],
            "%s: the mouse clicks %s in its middle, on %s" % [_phase, what, _name(current_scene)]
        )
    if is_instance_valid(button) and button.pressed.is_connected(on_press):
        button.pressed.disconnect(on_press)
    if not pressed[0] and is_instance_valid(button):
        button.press()


## The buttons on the screen which the player can press now, except those
## listed.
func _buttons(screen: Node, except: Array = []) -> Array[DwellButton]:
    var result: Array[DwellButton] = []
    for node in screen.find_children("*", "DwellButton", true, false):
        var button := node as DwellButton
        if button.is_visible_in_tree() and not button.disabled and button not in except:
            result.append(button)
    return result


func _pick(buttons: Array[DwellButton]) -> DwellButton:
    return buttons[_rng.randi_range(0, buttons.size() - 1)]


## Whether to take a detour of this name now: by chance, and surely the
## first time in the phase, so that every screen is seen.
func _detour(name: String, chance: float) -> bool:
    var key := "%s %s" % [_phase, name]
    if _here.has(name):
        return false
    if not _seen.has(key) or _rng.randf() < chance:
        _here[name] = true
        _seen[key] = true
        return true
    return false


func _run() -> void:
    var languages := root.get_node("Languages")
    var profile := _profile()
    var path: String = languages.settings_path()
    _check(path != "user://settings.cfg", "the test runs with -- --settings=<its own file>")
    DirAccess.remove_absolute(path)
    if DirAccess.dir_exists_absolute(profile.saves_dir()):
        for file in DirAccess.get_files_at(profile.saves_dir()):
            DirAccess.remove_absolute(profile.saves_dir().path_join(file))
    profile.session_id = ""
    profile.players = 0
    profile.stars = {}
    profile.has_seen_instruction = false
    profile.rewarded = []
    languages.has_chosen = false
    Flow.session_asked = false

    var seed := int(_argument("seed", str(DEFAULT_SEED)))
    _time_scale = float(_argument("time-scale", str(DEFAULT_TIME_SCALE)))
    _new_journey_levels = int(_argument("new-journey-levels", str(DEFAULT_NEW_JOURNEY_LEVELS)))
    print("%d players, seed %d, the time %.1f times faster" % [players, seed, _time_scale])
    _rng.seed = seed
    Engine.time_scale = _time_scale
    var started := Time.get_ticks_msec()

    change_scene_to_file(Flow.INTRO)
    await _frames(3)
    _check(current_scene is Intro, "the game starts with the intro")
    await _drive(_all_finished)
    await _check_the_end()

    await _restart()
    _phase = "second"
    await _drive(_second_finished)
    _check_second()

    Keys.release_all()
    Engine.time_scale = 1.0
    for violation in _screen_contracts.violations() + _level_contracts.violations():
        _check(false, "the contract is broken: %s" % violation)
    print("Screens seen: %s" % [_seen.keys()])
    print(
        (
            (
                "Played %d levels and %d conversations (%d pages turned) in %.0f s of the game, "
                + "%.1f s in all, with %d checks of the contracts"
            )
            % [
                _levels_played,
                _conversations,
                _pages_turned,
                _clock,
                (Time.get_ticks_msec() - started) / 1000.0,
                _screen_contracts.checks() + _level_contracts.checks(),
            ]
        )
    )

    DirAccess.remove_absolute(path)
    if _failures.is_empty():
        print("RESULT: OK")
        quit(0)
    else:
        print("RESULT: FAILED (%d)" % _failures.size())
        quit(1)


## Whether the first journey finished every level, and its player looks at
## the level select.
func _all_finished() -> bool:
    return current_scene is LevelSelect and LevelList.next(_profile()) == ""


## Whether the players of the new journey finished their levels, and look at
## the level select.
func _second_finished() -> bool:
    if not (current_scene is LevelSelect) or _profile().session_id != _second_session:
        return false
    return _finished_count() >= _new_journey_levels


func _finished_count() -> int:
    var count := 0
    for each in LevelList.paths():
        if _profile().has_finished(LevelList.id(each)):
            count += 1
    return count


## Play on from screen to screen until [param done].
func _drive(done: Callable) -> void:
    while not done.call():
        var screen := current_scene
        if screen == null or screen.is_queued_for_deletion():
            await _frames(1)
            continue
        if screen != _screen:
            _screen = screen
            _here = {}
            _seen["%s %s" % [_phase, _name(screen)]] = true
            await _frames(2)
            if screen != current_scene:
                continue
        if screen is Level:
            await _play_level(screen as Level)
            continue
        _actions += 1
        if _actions > MAX_ACTIONS:
            _check(false, "%s: the screens took more than %d actions" % [_phase, MAX_ACTIONS])
            return
        _screen_contracts.check_screen(screen, "%s %s" % [_phase, _name(screen)])
        await _act(screen)
        await _frames(2)


## Do one thing on the screen: a detour, or what leads on.
func _act(screen: Node) -> void:
    var profile := _profile()
    if screen is Intro:
        var buttons := (screen as Intro).buttons()
        if _phase == "first" and _levels_played > 0 and _detour("settings", 0.1):
            await _click(buttons[3], "Settings")
        elif _detour("how to play", 0.05):
            await _click(buttons[2], "How to Play")
        elif _levels_played > 0 and _rng.randf() < 0.2:
            await _click(buttons[1], "Levels")
        else:
            await _click(buttons[0], "Play")
    elif screen is LanguageSelect:
        var cards := (screen as LanguageSelect).cards()
        await _click(cards[_rng.randi_range(0, cards.size() - 1)], "a language")
    elif screen is SessionName:
        await _act_session_name(screen as SessionName)
    elif screen is Sessions:
        await _act_sessions(screen as Sessions)
    elif screen is PlayerCount:
        if _phase == "second":
            _second_session = profile.session_id
        await _click((screen as PlayerCount).cards()[players - 1], "%d riders" % players)
    elif screen is RiderCreator:
        await _act_rider_creator(screen as RiderCreator)
    elif screen is Instruction:
        if not _here.has("watched"):
            _here["watched"] = true
            await _wait(_rng.randf_range(0.2, 4.0))
            return
        await _click(screen._ready_button, "Ready in How to Play")
    elif screen is Settings:
        await _act_settings(screen as Settings)
    elif screen is Wardrobe:
        var wardrobe := screen as Wardrobe
        if (
            int(_here.get("toggles", 0)) < _rng.randi_range(0, 4)
            and not wardrobe.cards().is_empty()
        ):
            _here["toggles"] = int(_here.get("toggles", 0)) + 1
            await _click(_pick(wardrobe.cards()), "a piece in the wardrobe")
        else:
            await _click(wardrobe._back, "Back in the wardrobe")
    elif screen is Reward:
        await _act_reward(screen as Reward)
    elif screen is LevelSelect:
        await _act_level_select(screen as LevelSelect)
    elif screen is FreeSpace:
        (screen as FreeSpace).finish()
    else:
        _check(false, "%s: the bot does not know the screen %s" % [_phase, _name(screen)])
        Flow.cancel(self)


func _act_session_name(naming: SessionName) -> void:
    var typed := int(_here.get("typed", 0))
    if typed < int(_here.get("letters", -1)):
        var keys := naming.keyboard().keys()
        _here["typed"] = typed + 1
        await _click(keys[_rng.randi_range(0, keys.size() - 1)], "a key of the journey's name")
        return
    if not _here.has("letters"):
        _here["letters"] = _rng.randi_range(0, 10)
        return
    await _click(naming._ok, "OK for the journey's name")
    if is_instance_valid(naming) and current_scene == naming:
        # NOTE (mristin):
        # A name of spaces only is no name: write a letter.
        _here["letters"] = int(_here["letters"]) + 1


func _act_sessions(sessions: Sessions) -> void:
    if _phase == "second" and _second_session == "":
        await _click(sessions._new, "New journey")
    elif _phase == "first" and sessions.shown().size() > 0:
        for i in range(sessions.shown().size()):
            if sessions.shown()[i]["id"] == _profile().session_id:
                sessions.choose(i)
                return
        sessions.choose(0)
    else:
        sessions.choose(0)


func _act_rider_creator(creator: RiderCreator) -> void:
    if _phase == "second" and creator.player == 0 and not _here.has("named"):
        # NOTE (mristin):
        # A name which is also a message of the game (the default name of the
        # second rider) stands as written, never translated.
        _here["named"] = true
        await _click(creator._rider_field, "the name of the rider")
        for i in range(creator.rider_name.length()):
            Keys.tap(KEY_BACKSPACE)
        Keys.write("Dana")
        await _frames(1)
        _check(creator.rider_name == "Dana", "the rider is named Dana: %s" % creator.rider_name)
        await _click(creator._done_button, "Done with the name")
        # NOTE (mristin):
        # She keeps the name: no more random tries.
        _here["tries 0"] = 0
        return
    var key := "tries %d" % creator.player
    if not _here.has(key):
        _here[key] = _rng.randi_range(0, 12)
    if int(_here[key]) > 0:
        _here[key] = int(_here[key]) - 1
        var buttons := _buttons(creator, [creator._ready_button])
        await _click(_pick(buttons), "a button of the creator of the rider")
        return
    if creator.editing != "":
        await _click(creator._done_button, "Done with the name")
        return
    await _click(creator._ready_button, "Ready in the creator of the rider")


func _act_settings(settings: Settings) -> void:
    var buttons := settings.buttons()
    if _detour("language", 0.3):
        await _click(buttons[0], "the language in the settings")
    elif _detour("wardrobe", 0.3):
        await _click(buttons[3], "the wardrobe in the settings")
    elif _detour("sound", 0.3):
        await _click(buttons[4], "the sound in the settings")
        await _click(buttons[4], "the sound in the settings, back on")
    elif _detour("journeys", 0.2):
        await _click(buttons[1], "the journeys in the settings")
    else:
        await _click(buttons[2], "Back in the settings")


func _act_reward(reward: Reward) -> void:
    var cards := reward.cards()
    if reward.chosen == "" and not cards.is_empty():
        _check(not reward.replayed, "%s: a level ridden again gives no gift" % _phase)
        var i := _rng.randi_range(0, cards.size() - 1)
        await _click(cards[i], "a gift")
        await _wait(_rng.randf_range(0.0, Reward.SPARKLE_SECONDS))
        return
    if _detour("wardrobe after the reward", 0.15):
        await _click(reward._wardrobe, "the wardrobe after the reward")
    else:
        await _click(reward._go_on, "Go on after the reward")


func _act_level_select(select: LevelSelect) -> void:
    var rows := select.rows()
    var profile := _profile()
    # NOTE (mristin):
    # Sometimes, the player rides the first level again, which gives no gift
    # the second time.
    var first := LevelList.paths()[0]
    if (
        _phase == "first"
        and profile.has_finished(LevelList.id(first))
        and not _seen.has("first replay")
        and _rng.randf() < 0.15
    ):
        _seen["first replay"] = true
        await _click(rows[0], "the first level, again")
        return
    if _levels_played > 0 and _detour("back to the intro", 0.05):
        await _click(select._back, "Back in the level select")
        return
    var next := LevelList.next(profile)
    for i in range(rows.size()):
        if select.paths()[i] == next:
            _check(rows[i].primary, "%s: the next level is marked in the level select" % _phase)
            await _click(rows[i], "the next level")
            return
    _check(false, "%s: the level select offers no level" % _phase)
    Flow.cancel(self)


## Play the level until it is left: the riders ride on their own (see
## rider_bot.gd), and at the end, one of them goes on with a squat, OK or
## Enter.
func _play_level(level: Level) -> void:
    var id := level.level_id()
    var tag := "%s %s (%d players)" % [_phase, id, level.players()]
    var people: Array[Person] = []
    for person in level.map.people():
        if person.portrait != "grandmother":
            people.append(person)
    var nav := Navigator.new(level.map)
    var bots: Array = []
    for i in range(level.players()):
        var mine_people: Array[Person] = []
        for k in range(people.size()):
            if k % level.players() == i:
                mine_people.append(people[k])
        var mine_animals: Array[Animal] = []
        var herds := level.map.herds()
        for animal in level.animals:
            if herds.find(animal.herd) % level.players() == i:
                mine_animals.append(animal)
        var bot = RiderBot.new(level, i, nav, _rng, mine_people, mine_animals)
        bot.tricky = i == 0
        bots.append(bot)

    var restart_at := INF
    var restart_key := "%s %s" % [_phase, id]
    if not _restarted.has(restart_key) and _rng.randf() < RESTART_CHANCE:
        restart_at = _rng.randf_range(2.0, 60.0)
    _restarted[restart_key] = true

    var instance := level.get_instance_id()
    var talked: Dictionary = _talked.get(restart_key, {})
    _talked[restart_key] = talked
    for bot in bots:
        bot.talked = talked
    var started := _clock
    var finished_at := -1.0
    var leave_after := Level.THANKS_SECONDS + _rng.randf_range(0.1, 1.5)
    var left := false
    var frame := 0
    var forced := false
    while current_scene == level and is_instance_valid(level):
        frame += 1
        # NOTE (mristin):
        # The contracts check the frame which the game just played, before the
        # riders press their keys for the next one.
        if frame % CHECK_EVERY == 0 and not forced:
            _level_contracts.check_level(
                level, _clock, tag, frame % (CHECK_EVERY * FULL_EVERY) == 0
            )
        forced = false
        var playing := _clock - started
        if not level.finished:
            for bot in bots:
                bot.tricky = (
                    bot.index == 0
                    and range(level.players()).all(
                        func(i: int) -> bool: return level.talking_to(i) == null
                    )
                )
                bot.tick(_time_scale / 60.0)
            # NOTE (mristin):
            # Sometimes, a player switches the language during a talk, but not
            # while a rider waits to see her squat turn its page.
            var talks := range(level.players()).any(
                func(i: int) -> bool: return level.talking_to(i) != null
            )
            if (
                talks
                and not bots.any(func(bot) -> bool: return bot.checks_page())
                and _rng.randf() < LANGUAGE_IN_TALK_CHANCE
            ):
                Keys.tap(KEY_L)
            if playing > restart_at:
                restart_at = INF
                print("%s: ride again from the start at %.0f s" % [tag, playing])
                Keys.tap(KEY_R)
            if playing > LEVEL_SECONDS:
                _check(false, "%s: the riders did not finish in %d s" % [tag, LEVEL_SECONDS])
                # NOTE (mristin):
                # Bring the animals home, so that the rest of the game is
                # still played; the level finishes on its next frame.
                for animal in level.animals:
                    animal.state = Animal.State.HOME
                    animal.position = level.map.home().position
                forced = true
        else:
            if finished_at < 0.0:
                finished_at = _clock
                for bot in bots:
                    bot.stop()
                print(
                    (
                        "%s: finished in %.0f s of riding (%.0f s in all) with %d stars"
                        % [tag, level.elapsed, playing, level.stars()]
                    )
                )
            var since := _clock - finished_at
            if since > Level.THANKS_SECONDS + 0.5:
                _check(
                    level.ok_button() != null and level.ok_button().is_visible_in_tree(),
                    "%s: the button OK shows after the thanks" % tag
                )
            if since > leave_after and not left:
                left = true
                # NOTE (mristin):
                # Every way to go on is tried first, then any.
                var ways := [0, 1, 2].filter(func(way: int) -> bool: return not _leaves.has(way))
                if ways.is_empty():
                    ways = [0, 1, 2]
                var how: int = ways[_rng.randi_range(0, ways.size() - 1)]
                _leaves[how] = true
                match how:
                    0:
                        Keys.tap(bots[_rng.randi_range(0, bots.size() - 1)].keys["squat"])
                    1:
                        await _click(level.ok_button(), "OK at the end of the level")
                    2:
                        Keys.tap(KEY_ENTER)
            if since > leave_after + 5.0:
                _check(false, "%s: the level does not go on to the reward" % tag)
                level._leave()
                left = true
        await _frames(1)

    for bot in bots:
        bot.stop()
        for failure in bot.failures:
            _check(false, failure)
        _pages_turned += bot.turned
        _conversations += bot.closed
    Keys.release_all()
    _level_contracts.forget(instance)
    if finished_at >= 0.0:
        _levels_played += 1


## The end of the game: every level is finished with its stars and its gift,
## every person of every level talked to the rider, the level select shows
## them all open, and Play leads there.
func _check_the_end() -> void:
    var profile := _profile()
    _first_session = profile.session_id
    var select := current_scene as LevelSelect
    _check(select != null, "the end of the game shows the level select")
    if select != null:
        _screen_contracts.check_screen(select, "the end of the game")
        for i in range(select.rows().size()):
            _check(select.is_open(i), "at the end, the level %d is open" % (i + 1))
    for path in LevelList.paths():
        var id := LevelList.id(path)
        var stars: int = profile.stars.get(id, 0)
        _check(stars >= 1 and stars <= 3, "the level %s is finished with stars: %d" % [id, stars])
        _check(profile.was_rewarded(id), "the level %s gave its gift" % id)
        var map: LevelMap = (load(path) as PackedScene).instantiate()
        var talked: Dictionary = _talked.get("first %s" % id, {})
        for person in map.people():
            _check(
                talked.has(person.name),
                "every person of %s talked to the rider: %s did not" % [id, person.name]
            )
        map.free()
    _check(profile.players == players, "%d players ride in the journey" % players)
    _check_gifts(LevelList.paths().size())
    for screen in [
        "Intro",
        "LanguageSelect",
        "SessionName",
        "PlayerCount",
        "RiderCreator",
        "Instruction",
        "LevelSelect",
        "Level",
        "Reward",
        "Settings",
        "Wardrobe",
    ]:
        _check(_seen.has("first %s" % screen), "the players saw the screen %s" % screen)
    _check(_leaves.size() == 3, "the levels were left with a squat, OK and Enter: %s" % [_leaves])

    Flow.cancel(self)
    await _frames(3)
    _check(current_scene is Intro, "the level select goes back to the intro")
    await _click((current_scene as Intro).buttons()[0], "Play at the end")
    await _frames(3)
    _check(current_scene is LevelSelect, "at the end, Play goes to the level select")


## Start the game again, as if quit and started: what the journey keeps must
## come back from the disk as it was.
func _restart() -> void:
    var profile := _profile()
    var before: Dictionary = profile.to_data()
    before.erase("updated")
    Flow.session_asked = false
    Flow.room_asked = false
    Flow.playing = false
    Flow.choosing = false
    Flow.level = ""
    Flow.back = Flow.INTRO
    profile.session_id = ""
    profile.stars = {}
    profile.rewarded = []
    profile.has_seen_instruction = false
    profile._ready()
    var after: Dictionary = profile.to_data()
    after.erase("updated")
    _check(
        JSON.stringify(after) == JSON.stringify(before),
        "the journey comes back from the disk as it was:\n%s\n%s" % [before, after]
    )
    var saved := ConfigFile.new()
    _check(saved.load(root.get_node("Languages").settings_path()) == OK, "the settings are saved")
    _check(
        saved.get_value("general", "language", "") == root.get_node("Languages").current(),
        "the language is saved"
    )
    change_scene_to_file(Flow.INTRO)
    await _frames(3)
    _screen = null


## Every rider chose one gift in each of the levels.
func _check_gifts(levels: int) -> void:
    var profile := _profile()
    for i in range(profile.players):
        var won := 0
        for piece in profile.rider(i).finery:
            won += int(profile.rider(i).finery[piece])
        _check(
            won == levels,
            "the rider %d chose a gift in every level: %d for %d levels" % [i + 1, won, levels]
        )


## The new journey: its own riders and progress, and the first journey kept
## as it was.
func _check_second() -> void:
    var profile := _profile()
    _check(_second_session != "" and _second_session != _first_session, "a new journey starts")
    _check(profile.players == players, "%d players ride in the new journey" % players)
    for i in range(players):
        _check(profile.rider_name(i) != "", "the rider %d has a name" % (i + 1))
    _check(profile.rider_name(0) == "Dana", "the first rider keeps her name Dana")
    if players > 1:
        _check(
            profile.rider(0).looks.get("rider") != profile.rider(1).looks.get("rider"),
            "the two riders do not ride the same"
        )
    for i in range(LevelList.paths().size()):
        var id := LevelList.id(LevelList.paths()[i])
        if i >= _new_journey_levels:
            _check(not profile.has_finished(id), "the new journey did not finish %s yet" % id)
            continue
        _check(profile.has_finished(id), "the new journey finished %s" % id)
        var map: LevelMap = (load(LevelList.paths()[i]) as PackedScene).instantiate()
        var talked: Dictionary = _talked.get("second %s" % id, {})
        for person in map.people():
            _check(
                talked.has(person.name),
                "every person of %s talked to a rider: %s did not" % [id, person.name]
            )
        map.free()
    _check_gifts(_new_journey_levels)
    var first: Dictionary = profile.read(_first_session)
    _check(
        first["progress"]["stars"].size() == LevelList.paths().size(),
        "the first journey keeps its stars"
    )
    for screen in ["Sessions", "SessionName", "PlayerCount", "RiderCreator", "Instruction"]:
        _check(_seen.has("second %s" % screen), "the players saw the screen %s" % screen)
