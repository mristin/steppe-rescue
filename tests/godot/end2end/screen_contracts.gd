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

## Where each piece of the finery shows, as the player sees her rider (see
## section 8 of DESIGN.md: "dressed that way while riding, in the face
## overlay, and in the level select"): from above while riding, the tack of
## the horse, the owl feathers on her hat and the coat over her shoulders (her
## earrings, bracelets, belt and boots are too small or hidden from above); in
## the face overlay over the camera picture, what she wears on her head; and
## standing at home and in the level select, all but her earrings (the
## painted girls wear their own), the mane only braided with the owl feather
## (its first steps are close-ups, for the cards).
const _SHOWN := {
    "from above while riding":
    ["saddle", "saddle_cloth", "bridle", "breastplate", "stirrups", "mane", "feathers", "coat"],
    "in the face overlay": ["feathers", "earrings"],
    "standing at home and in the level select":
    [
        "saddle",
        "saddle_cloth",
        "bridle",
        "breastplate",
        "stirrups",
        "mane",
        "feathers",
        "belt",
        "bracelets",
        "boots",
        "coat",
    ],
}

## The steps of the pieces which show only from the step on, standing.
const _STANDING_FROM := {"mane": 3}

## The stars and the rewarded levels seen last, by the id of the journey.
var _progress := {}

## The texts of each language: the msgids for the source language, the
## msgstrs for the others; built once.
var _texts := {}

## The looks whose finery was checked, the images of the paintings, and the
## views of the looks.
var _finery_checked := {}
var _images := {}
var _views := {}


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
    _check_reward_cards(screen, tag)
    _check_wardrobe_cards(screen, tag)
    _check_settings_rows(screen, tag)
    _check_journey_cards(screen, tag)
    _check_finery_shows(screen, tag)
    _check_tree(screen, tag, false)
    _check_sounds(screen, tag, false)
    _check_vision(screen, tag, screen.get_node("/root/Profile").players)
    _check_resting(screen, tag)


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


## The cards of the reward show the paintings and the names of the pieces
## offered; once she chose, only the chosen card shows, marked; Go on and
## Wardrobe show exactly when there is nothing (more) to choose (see section
## 8 of DESIGN.md).
func _check_reward_cards(screen: Node, tag: String) -> void:
    if not (screen is Reward):
        return
    var reward := screen as Reward
    var cards := reward.cards()
    for i in range(mini(cards.size(), reward.offered.size())):
        var piece: String = reward.offered[i][0]
        var at: int = reward.offered[i][1]
        var card := cards[i]
        if (
            card.picture == null
            or card.picture != Reward.preview(piece, at)
            or card.text != reward.piece_name(piece, at)
        ):
            _report(
                "%s: a card of the reward shows another piece than it offers" % tag,
                "%s: %s %d, the card %s" % [tag, piece, at, JSON.stringify(card.text)]
            )
        var chosen := reward.chosen == piece
        if card.visible != (reward.chosen == "" or chosen) or card.selected != chosen:
            _report(
                "%s: the reward marks another card than the chosen one" % tag,
                (
                    "%s: %s, chosen %s, visible %s, marked %s"
                    % [tag, piece, JSON.stringify(reward.chosen), card.visible, card.selected]
                )
            )
    var done := reward.chosen != "" or reward.offered.is_empty()
    if reward._go_on.visible != done or reward._wardrobe.visible != done:
        _report(
            "%s: the reward lets her go on before she chose, or not after" % tag,
            (
                "%s: chosen %s, %d offered"
                % [tag, JSON.stringify(reward.chosen), reward.offered.size()]
            )
        )


## The wardrobe of the rider asked for has a card for each piece she won
## (with its painting, in the order of the pieces), in the panel of what she
## wears and marked exactly when she wears it.
func _check_wardrobe_cards(screen: Node, tag: String) -> void:
    if not (screen is Wardrobe):
        return
    var wardrobe := screen as Wardrobe
    var profile := screen.get_node("/root/Profile")
    if wardrobe.player != clampi(Flow.wardrobe_player, 0, profile.riders.size() - 1):
        _report("%s: the wardrobe of another rider" % tag, "%s: %d" % [tag, wardrobe.player])
    var rider: RiderProfile = profile.rider(wardrobe.player)
    var won: Array[String] = []
    for piece in Finery.PIECES:
        if rider.finery.has(piece) and Finery.has_picture(piece, int(rider.finery[piece])):
            won.append(piece)
    if wardrobe.pieces() != won:
        _report(
            "%s: the wardrobe shows other pieces than she won" % tag,
            "%s: %s, she won %s" % [tag, wardrobe.pieces(), rider.finery]
        )
        return
    for i in range(won.size()):
        var piece := won[i]
        var card := wardrobe.cards()[i]
        var picture := Painting.fitted(
            Finery.PICTURES % [piece, int(rider.finery[piece])], card.size - Vector2(16, 14)
        )
        var worn := rider.wears(piece)
        if (
            card.selected != worn
            or wardrobe.in_worn_panel(piece) != worn
            or card.picture != picture
        ):
            _report(
                "%s: a card of the wardrobe shows otherwise than she wears it" % tag,
                (
                    "%s: %s, worn %s, marked %s, in the panel of the worn %s"
                    % [tag, piece, worn, card.selected, wardrobe.in_worn_panel(piece)]
                )
            )
    if (wardrobe._empty.text != "") != won.is_empty():
        _report("%s: the wardrobe says she won nothing, or not" % tag, tag)


## The rows of the settings show the language of the game, the journey with
## its riders, a wardrobe for each rider, and whether the sound is on.
func _check_settings_rows(screen: Node, tag: String) -> void:
    if not (screen is Settings):
        return
    var settings := screen as Settings
    var languages := screen.get_node("/root/Languages")
    var profile := screen.get_node("/root/Profile")
    var problems: Array[String] = []
    var language := ""
    for each in languages.languages:
        if each["code"] == languages.current():
            language = each["name"]
    if settings._language.text != language:
        problems.append("the language %s, not %s" % [settings._language.text, language])
    var on: bool = screen.get_node("/root/Sounds").enabled
    var sound := screen.tr("On", "sound") if on else screen.tr("Off", "sound")
    if settings._sound.text != sound:
        problems.append("the sound %s, not %s" % [settings._sound.text, sound])
    var journey := settings._rider.text
    if not journey.begins_with(profile.session_name + "\n"):
        problems.append("the journey %s, not %s" % [JSON.stringify(journey), profile.session_name])
    for i in range(maxi(1, profile.players)):
        if profile.rider_name(i) not in journey.get_slice("\n", 1):
            problems.append("the journey %s without %s" % [journey, profile.rider_name(i)])
    if settings._second_wardrobe.visible != (profile.players > 1):
        problems.append("the second wardrobe shows: %s" % settings._second_wardrobe.visible)
    for problem in problems:
        _report(
            "%s: a row of the settings shows another state than the game's" % tag,
            "%s: %s" % [tag, problem]
        )


## The journeys show a card for each save (at most Sessions.OTHERS + 1), the
## current one first, each with the stars of its save, its name and riders.
func _check_journey_cards(screen: Node, tag: String) -> void:
    if not (screen is Sessions):
        return
    var sessions := screen as Sessions
    var profile := screen.get_node("/root/Profile")
    var shown := sessions.shown()
    var saved: Array[Dictionary] = profile.sessions()
    if shown.size() != mini(saved.size(), Sessions.OTHERS + 1):
        _report(
            "%s: the journeys show more or fewer cards than there are saves" % tag,
            "%s: %d cards, %d saves" % [tag, shown.size(), saved.size()]
        )
    var last: String = profile.session_id if profile.session_id != "" else profile.last_id()
    if last != "" and (shown.is_empty() or shown[0]["id"] != last):
        _report("%s: the journeys do not show the current one first" % tag, "%s: %s" % [tag, last])
    for i in range(shown.size()):
        var card: DwellButton = sessions._continue if i == 0 else sessions._others[i - 1]
        var data: Variant = profile.read(shown[i]["id"])
        var stars := 0
        if data != null:
            for won in (data as Dictionary).get("progress", {}).get("stars", {}).values():
                stars += int(won)
        var label: String = sessions._names[i].text
        if (
            not card.text.ends_with("★%d" % stars)
            or not label.begins_with(str(shown[i]["name"]) + "\n")
        ):
            _report(
                "%s: a card of a journey shows other stars or another name than its save" % tag,
                (
                    "%s: %s, %s; saved %s with %d stars"
                    % [
                        tag,
                        JSON.stringify(card.text),
                        JSON.stringify(label),
                        shown[i]["name"],
                        stars
                    ]
                )
            )


## The rider is not pixel-identical when she wears her finery: every piece
## she wears (at its step) changes how she looks in each view where it shows
## (see [constant _SHOWN]), against the same looks with that piece one step
## lower (or off). The views are put together as the game paints them (see
## [PaintedTopDown], [FrontView] and [method Reward.draw_pair]).
func _check_finery_shows(screen: Node, tag: String) -> void:
    if not (screen is Reward or screen is Wardrobe or screen is LevelSelect):
        return
    var profile := screen.get_node("/root/Profile")
    for i in range(maxi(1, profile.players)):
        var looks: Dictionary = profile.rider(i).dressed()
        var key := JSON.stringify(looks)
        if _finery_checked.has(key):
            continue
        _finery_checked[key] = true
        for piece in Finery.PIECES:
            var at := Finery.step(looks, piece)
            if at < 1 or Finery.PIECES[piece]["for"] == "home":
                continue
            var less := looks.duplicate(true)
            var finery: Dictionary = (less.get("finery", {}) as Dictionary).duplicate()
            if at == 1:
                finery.erase(piece)
            else:
                finery[piece] = at - 1
            less["finery"] = finery
            for view in _SHOWN:
                if piece not in _SHOWN[view]:
                    continue
                if view.begins_with("standing") and at < int(_STANDING_FROM.get(piece, 1)):
                    continue
                var dressed := _view(view, looks, piece)
                var plainer := _view(view, less, piece)
                if dressed == null or plainer == null:
                    continue
                if dressed.get_data() == plainer.get_data():
                    _report(
                        "the %s at its step %d does not show %s" % [piece, at, view],
                        "%s, the rider %d: %s" % [tag, i + 1, looks]
                    )


## The rider (or her horse, for a piece of the horse) as the view shows her;
## null if the view does not show her in these looks.
func _view(view: String, looks: Dictionary, piece: String) -> Image:
    var who: String = Finery.PIECES[piece]["for"]
    var key := "%s|%s|%s" % [view, who, JSON.stringify(looks)]
    if not _views.has(key):
        var image: Image = null
        if view.begins_with("from above"):
            image = _from_above(looks)
        elif view.begins_with("in the face"):
            var overlay := FrontView.painted_overlay(looks)
            image = overlay.get_image() if overlay != null else null
        else:
            image = _standing(looks, who)
        _views[key] = image
    return _views[key]


func _image(path: String) -> Image:
    if not _images.has(path):
        var image := (load(path) as Texture2D).get_image()
        image.decompress()
        image.convert(Image.FORMAT_RGBA8)
        _images[path] = image
    return _images[path]


## Lay the picture over the middle of the canvas, at the size.
static func _lay(canvas: Image, picture: Image, size: Vector2) -> void:
    var shown := Vector2i(maxi(1, roundi(size.x)), maxi(1, roundi(size.y)))
    var resized := picture.duplicate() as Image
    resized.resize(shown.x, shown.y, Image.INTERPOLATE_BILINEAR)
    canvas.blend_rect(resized, Rect2i(Vector2i.ZERO, shown), (canvas.get_size() - shown) / 2)


## The rider on her horse from above, standing, as [method
## PaintedTopDown.draw_rider] paints her, at two pixels per logical pixel: the
## horse and its finery on the square of the horse, the girl and her finery
## smaller, over the seat.
func _from_above(looks: Dictionary) -> Image:
    var root := "res://assets/pictures/top_down/"
    var canvas := _image(root + "horses/%s/0.png" % looks.get("steed", "1")).duplicate() as Image
    var size := Vector2(canvas.get_size())
    _lay_finery_above(canvas, looks, "horse", size)
    var girl := _image(root + "girls/%s.png" % looks.get("rider", "1"))
    _lay(canvas, girl, Vector2(girl.get_size()) * PaintedTopDown.GIRL_SCALE)
    _lay_finery_above(canvas, looks, "rider", size * PaintedTopDown.GIRL_SCALE)
    return canvas


## Lay the finery of the horse (or the rider) from above, as [method
## PaintedTopDown._dress] does: a step without its picture shows the one
## before.
func _lay_finery_above(canvas: Image, looks: Dictionary, who: String, size: Vector2) -> void:
    for piece in Finery.PIECES:
        if Finery.PIECES[piece]["for"] != who:
            continue
        for step in range(Finery.step(looks, piece), 0, -1):
            var path := "res://assets/pictures/top_down/finery/%s_%d.png" % [piece, step]
            if ResourceLoader.exists(path):
                _lay(canvas, _image(path), size)
                break


## The painted horse (or rider) standing, in the finery she wears, as [method
## Reward.dress] lays it at home and in the level select.
func _standing(looks: Dictionary, who: String) -> Image:
    var painting := (
        Painting.horse(looks.get("steed", "1")) if who == "horse" else Painting.dressed_rider(looks)
    )
    # NOTE (mristin):
    # A copy: the painting keeps its image.
    var canvas := painting.get_image().duplicate() as Image
    canvas.convert(Image.FORMAT_RGBA8)
    var size := Vector2(canvas.get_size())
    for place in Reward._ON_HORSE if who == "horse" else Reward._ON_RIDER:
        var piece: String = place[0]
        var at := Finery.step(looks, piece)
        if at < 1 or (place.size() > 4 and at != place[4]):
            continue
        var path := Finery.PICTURES % [piece, at]
        if not ResourceLoader.exists(path):
            continue
        var picture := _image(path)
        var width: float = place[3] * size.x
        var shown := Vector2(width, width * picture.get_height() / picture.get_width())
        var resized := picture.duplicate() as Image
        resized.resize(maxi(1, roundi(shown.x)), maxi(1, roundi(shown.y)))
        var center := Vector2(place[1], place[2]) * size
        canvas.blend_rect(
            resized,
            Rect2i(Vector2i.ZERO, resized.get_size()),
            Vector2i((center - shown * 0.5).round())
        )
    return canvas
