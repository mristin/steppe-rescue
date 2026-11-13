extends SceneTree
## Check the layout of the texts in every language: on every screen, in its
## dialogs (e.g., the question whether to delete a journey, the keys to write
## a name) and in the levels (every conversation of every person of every
## level, Grandmother's thanks with the button OK, the warning at the edge of
## the steppe, the status of the camera and the hint to quit), with one and
## with two players. No text may run out of its button, out of its dialog or
## off the screen, and no two elements may overlap (see layout.gd).
##
## The names are the longest which the players can write, so that they
## overflow nothing either.
##
## Run it with `-- --settings=user://<file>`, so that it does not change the
## settings and the journeys of the player (see the autoload Languages).

const Layout := preload("res://tests/godot/layout.gd")

## The longest names the players can write (see [constant Profile.MAX_NAME]
## and [constant Profile.MAX_SESSION_NAME]), of wide letters.
const RIDER_NAMES := ["Шолпанайгерім", "Жұлдызайгерім"]
const HORSE_NAME := "Ақбозатшолақ"
const JOURNEY_NAME := "Шолпан мен Жұлдыз жорығы бірінші"

## The statuses of the camera which the levels can show (see [VisionStatus]).
const STATUSES := [
    "Disabled", "SearchingCamera", "LoadingModels", "NoCamera", "ModelsMissing", "Failed"
]


## Stands in for the vision service, to show each of its statuses.
class FakeService:
    extends Node
    var status := "Disabled"

    func GetStatus() -> String:  # gdlint: ignore=function-name
        return status

    func HasPlayer(_index: int) -> bool:  # gdlint: ignore=function-name
        return false


var _failures: Array[String] = []
var _reported := {}


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    # NOTE (mristin):
    # A screen shown again (e.g., at another time of an animation) reports
    # the same problem only once.
    if _reported.has(message):
        return
    _reported[message] = true
    print("FAIL ", message)
    _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


func _frames(count: int) -> void:
    for i in range(count):
        await process_frame


func _language() -> String:
    return root.get_node("Languages").current()


## Check the elements under the node: that they fit into the [param bounds]
## and do not overlap, except the [param allowed] pairs; and that the
## elements of each of the [param panels] (a dictionary of the panel node to
## its rectangle) stay inside it.
func _check_layout(
    tag: String,
    under: Node,
    extra := {},
    skip: Array = [],
    allowed: Array = [],
    bounds := Layout.SCREEN,
    panels := {}
) -> void:
    var items := Layout.elements(under, extra, skip)
    var where := "%s (%s)" % [tag, _language()]
    _check(not items.is_empty(), "%s: there is something to check" % where)
    for problem in Layout.overflows(items, bounds):
        _check(false, "%s: %s" % [where, problem])
    for problem in Layout.overlaps(items, allowed):
        _check(false, "%s: %s" % [where, problem])
    for panel in panels:
        for problem in Layout.outside(items, panel, panels[panel]):
            _check(false, "%s: %s" % [where, problem])


func _open(path: String) -> Node:
    change_scene_to_file(path)
    await _frames(4)
    return current_scene


## A journey of the players, with the longest names.
func _start_journey(players: int) -> void:
    var profile := root.get_node("Profile")
    profile.start_session(JOURNEY_NAME)
    profile.set_players(players)
    for i in range(players):
        profile.save(RIDER_NAMES[i], HORSE_NAME, Looks.preset(Looks.DEFAULT, str(i + 1)), i)
    profile.see_instruction()
    Flow.session_asked = true


func _check_menus() -> void:
    var intro: Intro = await _open(Flow.INTRO)
    _check_layout("the intro", intro)
    var hint: QuitHint = intro.find_children("*", "QuitHint", true, false)[0]
    hint.text = tr("Press Esc again to quit.")
    hint.visible = true
    _check_layout("the intro with the hint to quit", intro)
    hint.visible = false

    _check_layout("the language select", await _open(Flow.LANGUAGE_SELECT))

    var naming: SessionName = await _open(Flow.SESSION_NAME)
    _check_layout("the name of the journey", naming)
    for letter in JOURNEY_NAME:
        naming._type(SessionName.SPACE if letter == " " else letter)
    _check_layout("the longest name of the journey", naming)

    _check_layout("the number of the players", await _open(Flow.PLAYER_COUNT))
    _check_layout("the level select", await _open(Flow.LEVEL_SELECT))
    _check_layout("the free space", await _open(Flow.FREE_SPACE))
    _check_layout("the movement test", await _open("res://scenes/movement_test/movement_test.tscn"))


func _check_instruction() -> void:
    var instruction: Instruction = await _open(Flow.INSTRUCTION)
    var at := 0.25
    while at < Instruction.LOOP:
        instruction.time = at
        await _frames(1)
        _check_layout("How to Play at %.1f s" % at, instruction)
        at += 0.5


func _check_rider_creator(players: int) -> void:
    for player in range(players):
        Flow.wardrobe_player = player
        var creator: RiderCreator = await _open(Flow.RIDER_CREATOR)
        if players > 1:
            # NOTE (mristin):
            # The second player creates her rider after the first.
            creator.player = player
            creator._update()
        creator.rider_name = RIDER_NAMES[player]
        creator.horse_name = HORSE_NAME
        creator._update()
        var tag := "the creator of the rider %d of %d" % [player + 1, players]
        # NOTE (mristin):
        # The name of the other player stands on the card of her rider, on
        # purpose.
        var allowed := []
        for card in creator._rider_cards:
            allowed.append([creator._taken_label, card])
        _check_layout(tag, creator, {}, [], allowed)
        for which in ["rider", "horse"]:
            creator._edit(which)
            await _frames(1)
            _check_layout("%s, writing the name of the %s" % [tag, which], creator, {}, [], allowed)
        creator._edit("")


func _check_settings_and_wardrobe(players: int) -> void:
    var tag := " (%d players)" % players
    _check_layout("the settings" + tag, await _open(Flow.SETTINGS))

    var profile := root.get_node("Profile")
    Flow.wardrobe_player = 0
    _check_layout("the empty wardrobe" + tag, await _open(Flow.WARDROBE))
    for piece in Finery.PIECES:
        for step in range(Finery.PIECES[piece]["steps"]):
            profile.win(piece, 0)
    var wardrobe: Wardrobe = await _open(Flow.WARDROBE)
    _check_layout("the full wardrobe" + tag, wardrobe)
    for piece in wardrobe.pieces():
        wardrobe.toggle(piece)
    await _frames(1)
    _check_layout("the full wardrobe, all taken off" + tag, wardrobe)


func _check_sessions() -> void:
    var profile := root.get_node("Profile")
    var current: String = profile.session_id
    for i in range(Sessions.OTHERS + 1):
        _start_journey(1 + i % 2)
    profile.choose_session(current)
    Flow.session_asked = false
    var sessions: Sessions = await _open(Flow.SESSIONS)
    _check_layout("the journeys", sessions)
    sessions.set_deleting(true)
    await _frames(1)
    _check_layout("the journeys, deleting", sessions)
    sessions.choose(1)
    await _frames(2)
    var question := sessions.question()
    _check(question != null, "choosing a journey to delete asks first")
    if question == null:
        return
    # NOTE (mristin):
    # The question stands over the screen: its panel holds the text and the
    # buttons, which must stay inside it and apart.
    var panel: DwellButton = question.find_children("*", "DwellButton", false, false)[0]
    _check_layout(
        "the question whether to delete a journey",
        question,
        {},
        [panel],
        [],
        Layout.SCREEN,
        {question: Layout.global_rect(panel)}
    )
    Flow.session_asked = true


func _check_reward(players: int) -> void:
    var profile := root.get_node("Profile")
    var tag := " (%d players)" % players
    for stars in range(1, 4):
        Flow.reward(self, stars, "")
        Flow.reward_player = players - 1
        var reward: Reward = await _open(Flow.REWARD)
        _check_layout("the reward of %d stars%s" % [stars, tag], reward)

    # NOTE (mristin):
    # Every piece can be offered on any card: show the name of each on them.
    var reward: Reward = await _open(Flow.REWARD)
    var cards := reward.cards()
    var names: Array[String] = []
    for piece in Finery.PIECES:
        for step in range(1, Finery.PIECES[piece]["steps"] + 1):
            names.append(reward.piece_name(piece, step))
    for i in range(names.size()):
        for j in range(cards.size()):
            cards[j].text = names[(i + j) % names.size()]
        _check_layout("the reward offering %s%s" % [names[i], tag], reward)

    reward.choose(0)
    await _frames(2)
    _check_layout("the reward chosen" + tag, reward)

    for piece in Finery.PIECES:
        for step in range(Finery.PIECES[piece]["steps"]):
            profile.win(piece, players - 1)
    _check_layout("the reward with all the finery won" + tag, await _open(Flow.REWARD))

    var level_id := LevelList.id(LevelList.paths()[0])
    profile.reward(level_id)
    Flow.reward(self, 3, level_id)
    Flow.reward_player = players - 1
    _check_layout("the reward of a level ridden again" + tag, await _open(Flow.REWARD))


func _check_hud(tag: String, level: Level) -> void:
    var panels := {}
    for i in range(level.players()):
        var view := level.view(i)
        if view.conversation.is_visible_in_tree():
            panels[view.conversation] = Layout.global_rect(view.conversation)
    _check_layout(
        tag, level, Layout.hud_extra(level), Layout.hud_skip(level), [], Layout.SCREEN, panels
    )
    for i in range(level.players()):
        var view := level.view(i)
        if not view.half:
            continue
        # NOTE (mristin):
        # With two players, each sees her conversation in her own half.
        var items := Layout.elements(view.conversation)
        for problem in Layout.overflows(items, view.rect):
            _check(false, "%s, the conversation of the player %d: %s" % [tag, i + 1, problem])


## Wait until the HUD glided out of the riders' way (see [HudLayout]).
func _settle() -> void:
    await create_timer(Level.GIVE_WAY_SECONDS + 0.2).timeout


## Let the player talk to the person, and wait until the conversation shows,
## and the HUD made room for it.
func _talk(level: Level, player: int, person: Person) -> void:
    level._talk(level.view(player), person)
    await _frames(2)


func _check_level(path: String, players: int) -> void:
    var profile := root.get_node("Profile")
    Flow.level = path
    var level: Level = await _open(Flow.LEVEL)
    var name := "%s (%d players)" % [path.get_file().get_basename(), players]
    var people := level.map.people()

    # NOTE (mristin):
    # The HUD moves out of the way of a rider at the edges of the steppe (see
    # [HudLayout]): check it with the rider in the middle of the view, and at
    # the bottom right corner of the steppe, where the camera picture leaves.
    var places := ["home"] if players > 1 else ["home", "away"]
    for code in root.get_node("Languages").codes():
        TranslationServer.set_locale(code)
        await _frames(1)
        for place in places:
            if players == 1:
                var away: bool = place == "away"
                level.rider().position = (
                    level.map.size - Vector2.ONE * (Rider.EDGE + 2.0)
                    if away
                    else level.map.start().position
                )
                await _settle()
                _check(
                    level.hud().is_away("camera") == away,
                    "%s: the camera picture is %s" % [name, place]
                )
            for person in people:
                for i in range(players):
                    await _talk(level, i, person)
                await _settle()
                _check_hud("%s, talking to %s at %s" % [name, person.speaker, place], level)

            for i in range(players):
                var view := level.view(i)
                view.edge_label.text = tr("Don't ride too far away!")
                view.edge_label.visible = true
            var status: Label = level.get_node("Hud/StatusLabel")
            var hint: QuitHint = level.get_node("Hud/QuitHint")
            hint.text = tr("Press Esc again to quit.")
            hint.visible = true
            await _settle()
            var service := FakeService.new()
            for each in STATUSES:
                service.status = each
                # NOTE (mristin):
                # The level writes its own status on every frame: check this
                # one before it does.
                status.text = VisionStatus.new().text(service, false)
                _check_hud("%s, the status %s at %s" % [name, each, place], level)
            service.free()
            hint.visible = false
            for i in range(players):
                level.view(i).edge_label.visible = false

            # NOTE (mristin):
            # At the end, Grandmother thanks the riders, and OK shows.
            level._finish()
            level._show_ok()
            await _settle()
            _check_hud("%s, the thanks at %s" % [name, place], level)
            level.finished = false
            level.ok_button().get_parent().free()
            level._ok = null

    Flow.level = ""
    profile.stars = {}


func _run() -> void:
    var languages := root.get_node("Languages")
    var profile := root.get_node("Profile")
    var path: String = languages.settings_path()
    _check(path != "user://settings.cfg", "the test runs with -- --settings=<its own file>")
    DirAccess.remove_absolute(path)
    if DirAccess.dir_exists_absolute(profile.saves_dir()):
        for file in DirAccess.get_files_at(profile.saves_dir()):
            DirAccess.remove_absolute(profile.saves_dir().path_join(file))

    for code in languages.codes():
        languages.choose(code)
        _start_journey(1)
        await _check_menus()
        await _check_instruction()
        for players in [1, 2]:
            _start_journey(players)
            await _check_rider_creator(players)
            await _check_settings_and_wardrobe(players)
            _start_journey(players)
            await _check_reward(players)
        await _check_sessions()

    for level_path in LevelList.paths():
        for players in [1, 2]:
            _start_journey(players)
            await _check_level(level_path, players)

    DirAccess.remove_absolute(path)
    if _failures.is_empty():
        print("RESULT: OK")
        quit(0)
    else:
        print("RESULT: FAILED (%d)" % _failures.size())
        quit(1)
