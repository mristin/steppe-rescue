extends "res://tests/godot/end2end/contract_book.gd"
## Check the contracts of the screens besides the levels (see
## level_contracts.gd for the levels): no text runs out of its button or off the screen, no two
## elements overlap (see layout.gd), no placeholder is left in a text, every
## text is in Unifont and in the language of the game, and one hand cursor
## draws over the buttons. Also, what the screens show and lead to: the
## journey in memory is the one on the disk; the levels are finished one
## after the other, the stars never decrease, and each level gives its gifts
## once, one to each rider; the riders have names of letters and never ride
## the same; the level select marks the next level and locks the rest; the
## reward offers the next steps of the finery, the better for more stars;
## and the flow leads only to the screens which it may.
##
## Not a test itself (its name does not start with test_), it is preloaded by
## the tests.

## The stars and the rewarded levels seen last, by the id of the journey.
var _progress := {}

## The texts of each language: the msgids for the source language, the
## msgstrs for the others; built once.
var _texts := {}


## Check the screen (not a level): its layout.
func check_screen(screen: Node, tag: String) -> void:
    _checks += 1
    var allowed := []
    var skip := []
    var panels := {}
    if screen is RiderCreator:
        # NOTE (mristin):
        # The name of the other player stands on the card of her rider, on
        # purpose.
        var creator := screen as RiderCreator
        for card in creator._rider_cards:
            allowed.append([creator._taken_label, card])
    if screen is Sessions:
        var question := (screen as Sessions).question()
        if question != null:
            # NOTE (mristin):
            # The question stands over the screen: its panel holds the text
            # and the buttons.
            var panel: DwellButton = question.find_children("*", "DwellButton", false, false)[0]
            skip.append(panel)
            panels[question] = Layout.global_rect(panel)
            for other in screen.get_children():
                if other != question:
                    allowed.append([question, other])
    var items := Layout.elements(screen, {}, skip)
    var where := "%s (%s)" % [tag, TranslationServer.get_locale()]
    if items.is_empty():
        _report("%s shows nothing" % tag, where)
    for item in items:
        var problems := Layout.overflows([item])
        if not problems.is_empty():
            _report(
                "%s: %s does not fit" % [tag, Layout.describe(item["node"])],
                where + ": " + problems[0]
            )
    _overlaps(items, allowed, tag, where, -1.0)
    for panel in panels:
        for problem in Layout.outside(items, panel, panels[panel]):
            _report("%s: something stands out of its panel" % tag, where + ": " + problem)
    _check_texts(screen, tag, where)
    _check_cursor(screen, tag, where)
    _check_saved(screen, tag)
    _check_progress(screen, tag)
    _check_gifts(screen, tag)
    _check_riders(screen, tag)
    _check_level_select(screen, tag)
    _check_reward(screen, tag)
    _check_flow(screen, tag)
    _check_language(screen, tag)


## The journey in memory is the journey on the disk, and the settings
## remember it as the last one.
func _check_saved(screen: Node, tag: String) -> void:
    var profile := screen.get_node("/root/Profile")
    var current: String = profile.session_id
    var last: String = profile.last_id()
    if last != current:
        _report(
            "%s: the settings remember another journey as the last one" % tag,
            "%s: the last %s, the current %s" % [tag, JSON.stringify(last), JSON.stringify(current)]
        )
    if current == "":
        return
    var saved: Variant = profile.read(current)
    if saved == null:
        _report("%s: the current journey is not saved" % tag, "%s: %s" % [tag, current])
        return
    var disk: Dictionary = saved
    # NOTE (mristin):
    # The round trip through JSON turns the numbers into floats, as on the disk.
    var memory: Dictionary = JSON.parse_string(JSON.stringify(profile.to_data()))
    var differ: Array[String] = []
    for key in memory:
        if key == "updated":
            continue
        if JSON.stringify(memory[key]) != JSON.stringify(disk.get(key)):
            differ.append(
                (
                    "%s: %s in memory, %s on the disk"
                    % [key, JSON.stringify(memory[key]), JSON.stringify(disk.get(key))]
                )
            )
    if not differ.is_empty():
        _report(
            "%s: the journey in memory differs from its save" % tag,
            "%s (%s): %s" % [tag, current, "; ".join(differ)]
        )


## The progress of the journey: the finished levels come one after the
## other from the first, each with 1 to 3 stars which never decrease; the
## levels which gave their gifts were finished, each listed once, and never
## forgotten.
func _check_progress(screen: Node, tag: String) -> void:
    var profile := screen.get_node("/root/Profile")
    var ids: Array[String] = []
    for path in LevelList.paths():
        ids.append(LevelList.id(path))
    var gap := ""
    for id in ids:
        if not profile.has_finished(id):
            if gap == "":
                gap = id
            continue
        var won := int(profile.stars[id])
        if won < 1 or won > 3:
            _report(
                "%s: a level is finished with stars out of [1, 3]" % tag,
                "%s: %s: %d" % [tag, id, won]
            )
        if gap != "":
            _report(
                "%s: a level is finished, but the one before it is not" % tag,
                "%s: %s finished, %s not" % [tag, id, gap]
            )
    for id in profile.stars:
        if id not in ids:
            _report("%s: the journey has the stars of an unknown level" % tag, "%s: %s" % [tag, id])
    var seen := {}
    for id in profile.rewarded:
        if seen.has(id):
            _report("%s: a level gave its gifts twice" % tag, "%s: %s" % [tag, id])
        seen[id] = true
        if not profile.has_finished(id):
            _report("%s: a level gave its gifts, but is not finished" % tag, "%s: %s" % [tag, id])
    if profile.session_id == "":
        return
    var before: Dictionary = _progress.get(profile.session_id, {"stars": {}, "rewarded": []})
    for id in before["stars"]:
        if int(profile.stars.get(id, 0)) < int(before["stars"][id]):
            _report(
                "%s: the stars of a level decrease" % tag,
                "%s: %s from %d to %d" % [tag, id, before["stars"][id], profile.stars.get(id, 0)]
            )
    for id in before["rewarded"]:
        if not profile.was_rewarded(id):
            _report("%s: a level forgot that it gave its gifts" % tag, "%s: %s" % [tag, id])
    _progress[profile.session_id] = {
        "stars": profile.stars.duplicate(), "rewarded": profile.rewarded.duplicate()
    }


## Every rider has one gift from each level which gave its gifts (until
## she won all the finery), and one more only while the players of the
## level just finished choose theirs; every step of her finery is a step of
## its piece, and she takes off only what she won.
func _check_gifts(screen: Node, tag: String) -> void:
    var profile := screen.get_node("/root/Profile")
    if profile.session_id == "" or profile.players == 0:
        return
    var all := 0
    for piece in Finery.PIECES:
        for at in range(1, int(Finery.PIECES[piece]["steps"]) + 1):
            if Finery.has_picture(piece, at):
                all += 1
    var given: int = profile.rewarded.size()
    var choosing: bool = (
        Flow.reward_level != ""
        and profile.has_finished(Flow.reward_level)
        and not profile.was_rewarded(Flow.reward_level)
        and (screen is Reward or (screen is Wardrobe and Flow.back == Flow.REWARD))
    )
    for i in range(profile.players):
        var each: RiderProfile = profile.rider(i)
        var won := 0
        for piece in each.finery:
            var at := int(each.finery[piece])
            won += at
            if not Finery.PIECES.has(piece) or at < 1 or at > int(Finery.PIECES[piece]["steps"]):
                _report(
                    "%s: a rider has a step of finery which its piece does not have" % tag,
                    "%s, the rider %d: %s %d" % [tag, i + 1, piece, at]
                )
        var low := mini(given, all)
        var high := mini(given + (1 if choosing else 0), all)
        if won < low or won > high:
            _report(
                "%s: a rider has more or fewer gifts than the levels gave" % tag,
                (
                    "%s, the rider %d: %d steps of finery, %d levels gave their gifts%s"
                    % [tag, i + 1, won, given, " (choosing now)" if choosing else ""]
                )
            )
        var off := {}
        for piece in each.taken_off:
            if off.has(piece) or not each.finery.has(piece):
                _report(
                    "%s: a rider took off a piece twice, or one she did not win" % tag,
                    "%s, the rider %d: %s of %s" % [tag, i + 1, piece, each.taken_off]
                )
            off[piece] = true


## The riders: as many as the players, their names (and the names of their
## horses) at most Profile.MAX_NAME letters of the alphabets of the game, and
## two players never ride the same painted rider nor the same painted horse.
func _check_riders(screen: Node, tag: String) -> void:
    var profile := screen.get_node("/root/Profile")
    if profile.session_id != "" and profile.riders.size() != maxi(1, profile.players):
        _report(
            "%s: the journey has more or fewer riders than players" % tag,
            "%s: %d riders, %d players" % [tag, profile.riders.size(), profile.players]
        )
    var letters := ""
    for language in screen.get_node("/root/Languages").languages:
        letters += str(language["alphabet"])
    for i in range(profile.riders.size()):
        var each: RiderProfile = profile.riders[i]
        for written in [each.name_written, each.horse_name_written]:
            var bad: bool = (written as String).length() > profile.MAX_NAME
            for letter in written:
                bad = bad or letter.to_upper() not in letters
            if bad:
                _report(
                    "%s: a name is too long or has a sign which is not a letter" % tag,
                    "%s, the rider %d: %s" % [tag, i + 1, JSON.stringify(written)]
                )
        for feature in Looks.OPTIONS:
            if each.looks.get(feature, "") not in Looks.OPTIONS[feature]:
                _report(
                    "%s: a rider has looks which the game does not know" % tag,
                    "%s, the rider %d: %s" % [tag, i + 1, each.looks]
                )
                break
    if profile.players == 2 and profile.rider(0).created and profile.rider(1).created:
        for feature in ["rider", "steed"]:
            if profile.rider(0).looks.get(feature) == profile.rider(1).looks.get(feature):
                _report(
                    "%s: the two players ride the same painted %s" % [tag, feature],
                    "%s: %s" % [tag, profile.rider(0).looks.get(feature)]
                )


## The level select lists every level in its order; exactly the next
## level to play is marked, and exactly the levels after one not finished
## are locked.
func _check_level_select(screen: Node, tag: String) -> void:
    if not (screen is LevelSelect):
        return
    var select := screen as LevelSelect
    var profile := screen.get_node("/root/Profile")
    var all := LevelList.paths()
    if select.paths() != all or select.rows().size() != all.size():
        _report(
            "%s: the level select does not list every level in its order" % tag,
            "%s: %d rows for %d levels" % [tag, select.rows().size(), all.size()]
        )
    var next := -1
    for i in range(all.size()):
        if not profile.has_finished(LevelList.id(all[i])):
            next = i
            break
    for i in range(mini(select.rows().size(), all.size())):
        var row := select.rows()[i]
        var open: bool = i == 0 or profile.has_finished(LevelList.id(all[i - 1]))
        if row.disabled == open:
            _report(
                "%s: a level is locked but open, or the other way" % tag,
                "%s: the level %d, open: %s, disabled: %s" % [tag, i + 1, open, row.disabled]
            )
        if row.primary != (i == next):
            _report(
                "%s: a level is marked as the next, but is not, or the other way" % tag,
                "%s: the level %d, the next: %d" % [tag, i + 1, next + 1]
            )


## The reward offers the next steps of different pieces, as many as there
## are (at most Finery.OFFERED), the more splendid ones for more stars, to
## the player whose turn it is, and nothing for a level ridden again.
func _check_reward(screen: Node, tag: String) -> void:
    if not (screen is Reward):
        return
    var reward := screen as Reward
    var profile := screen.get_node("/root/Profile")
    var level := Flow.reward_level
    if level != "" and not profile.has_finished(level):
        _report("%s: a reward for a level not finished" % tag, "%s: %s" % [tag, level])
    if reward.stars < 1 or reward.stars > 3 or reward.stars > int(profile.stars.get(level, 0)):
        _report(
            "%s: the reward shows other stars than the level gave" % tag,
            "%s: %d, kept %d" % [tag, reward.stars, profile.stars.get(level, 0)]
        )
    if reward.player != Flow.reward_player or reward.player >= profile.players:
        _report(
            "%s: the reward is for another player" % tag,
            (
                "%s: %d, the turn of %d of %d"
                % [tag, reward.player, Flow.reward_player, profile.players]
            )
        )
    if reward.cards().size() != reward.offered.size():
        _report("%s: the reward shows other cards than it offers" % tag, tag)
    if reward.replayed:
        if not reward.offered.is_empty():
            _report("%s: a level ridden again offers gifts" % tag, "%s: %s" % [tag, level])
        return
    var rider: RiderProfile = profile.rider(reward.player)
    var before := rider.finery.duplicate()
    if reward.chosen != "":
        before[reward.chosen] = int(before.get(reward.chosen, 0)) - 1
    var offered := {}
    for pair in reward.offered:
        var piece: String = pair[0]
        var at: int = pair[1]
        if offered.has(piece) or at != int(before.get(piece, 0)) + 1:
            _report(
                "%s: the reward offers a piece twice, or not its next step" % tag,
                "%s: %s, she has %s" % [tag, reward.offered, before]
            )
        offered[piece] = at
    if reward.chosen != "" and not offered.has(reward.chosen):
        _report(
            "%s: the rider won a piece which was not offered" % tag, "%s: %s" % [tag, reward.chosen]
        )
    var others: Array[int] = []
    for piece in Finery.PIECES:
        var next := int(before.get(piece, 0)) + 1
        if (
            not offered.has(piece)
            and next <= Finery.PIECES[piece]["steps"]
            and Finery.has_picture(piece, next)
        ):
            others.append(next)
    if offered.size() < Finery.OFFERED and not others.is_empty():
        _report(
            "%s: the reward offers fewer pieces than it could" % tag,
            "%s: %s" % [tag, reward.offered]
        )
    if offered.is_empty() or others.is_empty():
        return
    var steps: Array = offered.values()
    var better: bool = (
        others.max() <= steps.min() if reward.stars >= 2 else others.min() >= steps.max()
    )
    if not better:
        _report(
            "%s: the reward does not offer the steps which its stars give" % tag,
            (
                "%s: %d stars, offered %s, not offered steps %s"
                % [tag, reward.stars, reward.offered, others]
            )
        )


## The screen is one which the flow leads to now (see Flow.next).
func _check_flow(screen: Node, tag: String) -> void:
    var profile := screen.get_node("/root/Profile")
    var problems: Array[String] = []
    if Flow.back not in [Flow.INTRO, Flow.SETTINGS, Flow.SESSIONS, Flow.REWARD, Flow.LEVEL_SELECT]:
        problems.append("Flow.back is %s" % Flow.back)
    if Flow.level != "" and Flow.level not in LevelList.paths():
        problems.append("Flow.level is %s" % Flow.level)
    var journey: bool = profile.session_id != ""
    if screen is Intro and (Flow.playing or Flow.choosing):
        problems.append("the intro on the way from Play or Levels")
    if screen is LanguageSelect and Flow.playing and screen.get_node("/root/Languages").has_chosen:
        problems.append("the language asked again on the way from Play")
    if screen is PlayerCount and not (journey and profile.players == 0):
        problems.append("how many ride asked without a new journey")
    if screen is RiderCreator:
        var creator := screen as RiderCreator
        if not journey or profile.players == 0 or creator.player >= profile.players:
            problems.append("a rider created without a journey of her player")
        elif Flow.playing and profile.rider(creator.player).created:
            problems.append("a rider created again on the way from Play")
    if (
        screen is Instruction
        and Flow.playing
        and not (profile.has_riders() and not profile.has_seen_instruction)
    ):
        problems.append("How to Play shown again on the way from Play")
    if (
        (screen is LevelSelect or screen is Reward or screen is FreeSpace)
        and not (journey and profile.has_riders())
    ):
        problems.append("a screen of the journey without a journey and its riders")
    if (screen is Reward or screen is FreeSpace) and not profile.has_seen_instruction:
        problems.append("ridden before How to Play")
    for problem in problems:
        _report(
            "%s: the flow leads to a screen it must not: %s" % [tag, problem],
            (
                "%s: playing %s, choosing %s, back %s, journey %s, %d players"
                % [
                    tag,
                    Flow.playing,
                    Flow.choosing,
                    Flow.back,
                    JSON.stringify(profile.session_id),
                    profile.players
                ]
            )
        )


## Every text on the screen is in the language of the game: none is a
## text of another language which is not also one of the language of the
## game (an English text untranslated, or one left from the language before).
func _check_language(screen: Node, tag: String) -> void:
    if _texts.is_empty():
        var languages := screen.get_node("/root/Languages")
        var source := {}
        for code in languages.codes():
            var translation := TranslationServer.get_translation_object(code)
            if translation == null or code == languages.SOURCE_LANGUAGE:
                continue
            var own := {}
            for message in translation.get_translated_message_list():
                own[message] = true
            _texts[code] = own
            for message in translation.get_message_list():
                # NOTE (mristin):
                # A message with a context is listed as "context\u0004msgid".
                source[message.get_slice(char(4), message.get_slice_count(char(4)) - 1)] = true
        _texts[languages.SOURCE_LANGUAGE] = source
    var current: String = screen.get_node("/root/Languages").current()
    var own: Dictionary = _texts.get(current, {})
    for item in Layout.elements(screen):
        var node: Node = item["node"]
        var text := ""
        if node is Label:
            text = (node as Label).atr((node as Label).text)
        elif node is DwellButton:
            text = (node as DwellButton).text
        for line in text.split("\n"):
            var shown := line.strip_edges()
            if shown == "" or own.has(shown):
                continue
            for code in _texts:
                if code != current and (_texts[code] as Dictionary).has(shown):
                    _report(
                        "%s: a text is not in the language of the game" % tag,
                        "%s (%s): %s is %s" % [tag, current, JSON.stringify(shown), code]
                    )
                    break
