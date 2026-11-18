extends "res://tests/godot/end2end/level_view_contracts.gd"
## Check the contracts of the game while the tests play it (design by
## contract, in the tests only, so that the game never pays for them): what
## must hold on every screen and on every frame of a level, whatever the
## player does.
##
## On the screens besides the levels, see screen_contracts.gd; on top of it,
## in a level:
##
## * the riders stay in the steppe and out of what blocks the horse (a horse
##   in the air flies over a creek), and every rider shows on her view;
## * nothing of the HUD covers a rider, no two elements of the HUD overlap,
##   and no text runs out of its place (a conversation stays inside its
##   panel, and in the half of its player);
## * the lost animals stay in the steppe and out of what blocks the horse, so
##   that they can be found;
## * every animal is either lost, follows exactly one rider, runs into the
##   pen or is home, and the animals at home stay home, in the pen;
## * the level is finished exactly when all the animals are home, and then
##   gives one to three stars, which the journey keeps;
## * a rider talks to a person only when she stands close to them (except
##   Grandmother, at the start and at the end), and her horse stands still
##   meanwhile (once it landed from a jump); the conversation shows exactly
##   while she talks;
## * the water and the food of the horses stay within [0, 1], a horse drinks
##   and grazes only standing at fresh water and on a pasture, a tired horse
##   only walks, and the speed bar shows the speed of the horse;
## * a horse in the air keeps its speed and does not rear, and a rearing
##   horse neither moves nor turns;
## * the animals go only forward: lost, following, into the pen, home; they
##   join a rider near them, and run into the pen only with a rider at the
##   gate; the time of the ride never runs backwards, and stops at the end;
## * every rider hears every lost animal (and every follower which fell far
##   behind and calls out) which is off her screen and within hearing, and
##   only those; the maps show exactly the clues told and whom
##   to ask, so that every herd is marked; and the small figure does what the
##   player does, so that she sees that her body is understood;
## * a conversation is titled by its speaker and calls the rider by her
##   name (as she wrote it, never translated), and switching the language
##   keeps its page; the HUD of a rider stays in her half, on whole pixels,
##   and under the big map (but the conversations, the warnings, the hint to quit and
##   the button OK); the wild creatures stay in the steppe and out of the
##   lakes.
##
## The layout of a level counts only if it lasts longer than [constant
## GRACE_SECONDS]: the HUD glides out of the riders' way meanwhile (see
## [HudLayout]). Each problem is reported once, with its first example and
## how often it happened.
##
## Not a test itself (its name does not start with test_), it is preloaded by
## the tests.

## What the last check of each level saw, by the id of the level's instance.
var _last := {}


## Check the level on this frame, at [param now] seconds of the game; only
## what the riders do, unless [param full], also what the players see.
func check_level(level: Level, now: float, tag: String, full := true) -> void:
    _checks += 1
    var map := level.map
    var where := "%s at %.1f s (%s)" % [tag, level.elapsed, TranslationServer.get_locale()]
    var service: Node = level.get_node("/root/Vision").service
    var last: Dictionary = _last.get(level.get_instance_id(), {})
    var lasting := {}
    var steppe := Rect2(Vector2.ZERO, map.size)
    var walls := Rect2(Vector2.ZERO, map.size).grow(-Rider.EDGE + _SLACK)
    var solids := map.solids()
    var jumpable := map.jumpable()

    # NOTE (mristin):
    # The riders.
    var large := false
    for i in range(level.players()):
        var view := level.view(i)
        var rider := view.rider
        var who := "%s, the rider %d" % [where, i + 1]
        large = large or view.map_view.large
        if not walls.has_point(rider.position):
            _report("%s: a rider leaves the steppe" % tag, "%s at %s" % [who, rider.position])
        var blocking := solids if rider.jumping() >= 0.0 else solids + jumpable
        for solid in blocking:
            var center := Vector2(solid.x, solid.y)
            if rider.position.distance_to(center) < solid.z + Rider.RADIUS - _SLACK:
                _report(
                    "%s: a rider stands in what blocks the horse" % tag,
                    "%s at %s, in %s" % [who, rider.position, solid]
                )
        if not rider.is_visible_in_tree() or rider.modulate.a <= 0.0:
            _report("%s: a rider is hidden" % tag, who)
        var shown := Layout.rider_on_screen(level, i)
        if not view.rect.has_point(shown.get_center()):
            _report(
                "%s: a rider is out of her view" % tag,
                "%s at %s on the screen, the view %s" % [who, shown, view.rect]
            )
        var needs := view.needs
        if needs.water < 0.0 or needs.water > 1.0 or needs.food < 0.0 or needs.food > 1.0:
            _report(
                "%s: the water or the food is out of [0, 1]" % tag,
                "%s: %f, %f" % [who, needs.water, needs.food]
            )

        # NOTE (mristin):
        # The conversations.
        var person := view.talking
        var conversation := view.conversation
        if level.finished:
            pass
        elif person != null and not conversation.visible:
            _report("%s: a talk does not show" % tag, "%s, talking to %s" % [who, person.name])
        elif person == null and conversation.visible:
            _report("%s: a conversation shows without a talk" % tag, who)
        if person != null and not level.finished:
            # NOTE (mristin):
            # A horse in the air lands first.
            if rider.speed > 0.0 and rider.jumping() < 0.0:
                _report(
                    "%s: a horse runs during a talk" % tag, "%s, at %f px/s" % [who, rider.speed]
                )
            var before: Person = last.get("talking %d" % i, null)
            var opening: bool = last.has("talking %d" % i) and before != person
            if (
                opening
                and person.portrait != "grandmother"
                and rider.position.distance_to(person.position) >= Level.TALK_DISTANCE
            ):
                _report(
                    "%s: a rider talks to a person far away" % tag,
                    "%s, to %s at %s" % [who, person.name, person.position]
                )
        if conversation.visible:
            if conversation.page() < 0 or conversation.page() >= conversation.pages():
                _report(
                    "%s: a conversation shows a page it does not have" % tag,
                    "%s: the page %d of %d" % [who, conversation.page(), conversation.pages()]
                )
            if conversation.size.y > Level.CONVERSATION_HEIGHT + Layout.TOLERANCE:
                _report(
                    "%s: a conversation is too high" % tag, "%s: %d px" % [who, conversation.size.y]
                )
            var items := Layout.elements(conversation)
            var panel := Layout.global_rect(conversation)
            for problem in Layout.outside(items, conversation, panel):
                lasting["%s: a line stands out of its conversation" % tag] = (
                    "%s: %s" % [who, problem]
                )
            if not view.rect.grow(Layout.TOLERANCE).encloses(panel):
                lasting["%s: a conversation stands out of the view of its rider" % tag] = (
                    "%s: %s in %s" % [who, panel, view.rect]
                )
        # NOTE (mristin):
        # Switching the language shows the talk again on its page (or its last
        # page, if it has fewer in the language).
        var page_key := "page %d" % i
        if (
            person != null
            and conversation.visible
            and last.get("talking %d" % i) == person
            and last.has("locale")
            and last["locale"] != TranslationServer.get_locale()
            and int(last.get("squats %d" % i, -1)) == view.squats_seen
        ):
            var expected := mini(int(last.get(page_key, 0)), conversation.pages() - 1)
            if conversation.page() != expected:
                _report(
                    "%s: switching the language turns the page of a talk" % tag,
                    "%s: the page %d, not %d" % [who, conversation.page() + 1, expected + 1]
                )
        last[page_key] = conversation.page() if conversation.visible else 0
        last["talking %d" % i] = person

        # NOTE (mristin):
        # A conversation is titled by its speaker in the language of the game,
        # and on its first page calls the rider by her name (see section 6 of
        # DESIGN.md).
        if person != null and conversation.visible:
            var lines: Array[String] = []
            for node in conversation.find_children("*", "Label", true, false):
                if (node as Label).is_visible_in_tree():
                    lines.append((node as Label).text)
            var speaker := String(TranslationServer.translate(person.speaker))
            if lines.is_empty() or lines[0] != speaker:
                _report(
                    "%s: a conversation is not titled by its speaker" % tag,
                    "%s: %s, not %s" % [who, lines.slice(0, 1), JSON.stringify(speaker)]
                )
            var rider_name: String = level.get_node("/root/Profile").rider_name(i)
            if (
                conversation.page() == 0
                and not lines.any(func(line: String) -> bool: return rider_name in line)
            ):
                _report(
                    "%s: a conversation does not call the rider by her name" % tag,
                    "%s: %s not in %s" % [who, JSON.stringify(rider_name), lines]
                )

        # NOTE (mristin):
        # The pieces of the HUD of a rider stay in her half, and her map stands
        # where it belongs: large while open, small (where the HUD moved it)
        # while closed.
        if view.half:
            for control: Control in [view.speed_bar, view.needs_bars, view.map_view]:
                var rect := Layout.global_rect(control)
                if (
                    control.is_visible_in_tree()
                    and not view.rect.grow(Layout.TOLERANCE).encloses(rect)
                ):
                    _report(
                        "%s: %s stands out of the half of its rider" % [tag, _kind(control)],
                        "%s: %s in %s" % [who, rect, view.rect]
                    )
            if view.edge_label.is_visible_in_tree():
                var text := Layout.text_rect(view.edge_label)
                if not view.rect.grow(Layout.TOLERANCE).encloses(text):
                    _report(
                        "%s: the warning at the edge stands out of the half of its rider" % tag,
                        "%s: %s in %s" % [who, text, view.rect]
                    )
        var map_rect := Layout.global_rect(view.map_view)
        var placed := view.map_view.large_rect if view.map_view.large else view.map_view.small_rect
        if not map_rect.is_equal_approx(placed):
            _report(
                "%s: the map stands off its place" % tag,
                "%s: %s, not %s (large: %s)" % [who, map_rect, placed, view.map_view.large]
            )

    # NOTE (mristin):
    # What the players see is checked on every few checks only (see
    # [param full]): it counts only if it lasts, anyway.
    if full:
        # NOTE (mristin):
        # The HUD, unless the big map covers the steppe on purpose.
        if not large:
            var items := Layout.elements(level, Layout.hud_extra(level), Layout.hud_skip(level))
            for item in items:
                var problems := Layout.overflows([item])
                if not problems.is_empty():
                    lasting["%s: %s does not fit" % [tag, Layout.describe(item["node"])]] = (
                        where + ": " + problems[0]
                    )
            lasting.merge(_overlaps(items, [], tag, where, now))
            for i in range(level.players()):
                var rider := Layout.rider_on_screen(level, i)
                for item in items:
                    var common := rider.intersection(item["rect"])
                    if common.size.x <= Layout.TOLERANCE or common.size.y <= Layout.TOLERANCE:
                        continue
                    var node: Node = item["node"]
                    # NOTE (mristin):
                    # The lines of a conversation count as the conversation.
                    var what := node
                    while what != level and not (what is Conversation):
                        what = what.get_parent()
                    if what == level:
                        what = node
                    lasting["%s: %s covers a rider" % [tag, Layout.describe(what)]] = (
                        "%s, the rider %d at %s on the screen, it at %s"
                        % [where, i + 1, rider, item["rect"]]
                    )
        # NOTE (mristin):
        # The wild creatures stay in the steppe, and those on the ground out of
        # what blocks the horse (the eagles and the falcons circle high in the
        # sky, also beyond the edge).
        for creature in level.wildlife().creatures:
            if creature.kind in ["eagle", "falcon"]:
                continue
            if not steppe.has_point(creature.position):
                lasting["%s: a %s leaves the steppe" % [tag, creature.kind]] = (
                    "%s at %s" % [where, creature.position]
                )
            if not creature.on_ground():
                continue
            for solid in solids:
                if creature.position.distance_to(Vector2(solid.x, solid.y)) < solid.z - _SLACK:
                    lasting["%s: a %s stands in what blocks the horse" % [tag, creature.kind]] = (
                        "%s at %s, in %s" % [where, creature.position, solid]
                    )

        # NOTE (mristin):
        # The big map covers the HUD of its half, except what the rider must still
        # see: the conversations, the warnings, the hint to quit and the button OK.
        if large:
            var hud := Layout.elements(level, Layout.hud_extra(level), Layout.hud_skip(level))
            for i in range(level.players()):
                var map_view := level.view(i).map_view
                if not map_view.large:
                    continue
                var map_rect := Layout.global_rect(map_view)
                for item in hud:
                    var node: Node = item["node"]
                    if node == map_view:
                        continue
                    var common := map_rect.intersection(item["rect"])
                    if common.size.x <= Layout.TOLERANCE or common.size.y <= Layout.TOLERANCE:
                        continue
                    var above := node is QuitHint or node == level.ok_button()
                    for j in range(level.players()):
                        var other := level.view(j)
                        above = (
                            above
                            or node == other.edge_label
                            or node == other.conversation
                            or other.conversation.is_ancestor_of(node)
                        )
                    if above != _draws_over(node as CanvasItem, map_view):
                        _report(
                            (
                                "%s: %s draws %s the big map"
                                % [tag, _kind(node), "under" if above else "over"]
                            ),
                            (
                                "%s, the map of the rider %d at %s, it at %s"
                                % [where, i + 1, map_rect, item["rect"]]
                            )
                        )

        # NOTE (mristin):
        # The HUD stands on whole logical pixels (see CONTRIBUTING.md), but the
        # hand cursor, which follows the mouse or the hand.
        for node in level.find_children("*", "Control", true, false):
            var control := node as Control
            if not control.is_visible_in_tree() or control is HandCursor:
                continue
            var origin := control.get_global_transform().origin
            if not origin.is_equal_approx(origin.round()):
                _report(
                    "%s: %s stands between the pixels" % [tag, _kind(control)],
                    "%s: %s at %s" % [where, Layout.describe(control), origin]
                )
        _check_texts(level, tag, where)
        if level.ok_button() != null:
            _check_cursor(level, tag, where)

        # NOTE (mristin):
        # With two players, the status of the camera stays in the left half, so
        # that the line between the halves does not cross it.
        if level.players() > 1:
            var status: Label = level.get_node("Hud/StatusLabel")
            var status_rect := Layout.text_rect(status)
            if status.is_visible_in_tree() and status_rect.intersects(Rect2(479, 0, 2, 540)):
                var crossing := "the status of the camera crosses the line between the halves"
                lasting["%s: %s" % [tag, crossing]] = "%s: %s" % [where, status_rect]
        _lasting(lasting, now)

    # NOTE (mristin):
    # The animals.
    var following := {}
    for i in range(level.players()):
        for animal in level.followers(i):
            if following.has(animal):
                _report("%s: an animal follows two riders" % tag, where)
            following[animal] = i
    var pen := map.home().pen().grow(Layout.TOLERANCE)
    var home := 0
    for animal in level.animals:
        var what := (
            "%s, the %s of %s at %s" % [where, animal.kind.id, animal.herd.name, animal.position]
        )
        if (animal.state == Animal.State.FOLLOWING) != following.has(animal):
            _report("%s: an animal follows nobody, or follows but is not following" % tag, what)
        if animal.state == Animal.State.LOST:
            if not steppe.grow(-Rider.EDGE).has_point(animal.position):
                _report("%s: a lost animal leaves the steppe" % tag, what)
            for solid in solids:
                var center := Vector2(solid.x, solid.y)
                if animal.position.distance_to(center) < solid.z - _SLACK:
                    _report(
                        "%s: a lost animal stands in what blocks the horse" % tag,
                        "%s, in %s" % [what, solid]
                    )
        if animal.state == Animal.State.HOME:
            home += 1
            if not pen.has_point(animal.position):
                _report("%s: an animal at home stands out of the pen" % tag, what)
    if home < int(last.get("home", 0)):
        _report(
            "%s: an animal left home" % tag, "%s: %d at home, then %d" % [where, last["home"], home]
        )
    last["home"] = home

    # NOTE (mristin):
    # The end of the level.
    var all_home := home == level.animals.size()
    if level.finished != all_home:
        _report(
            "%s: the level is finished, but not all the animals are home, or the other way" % tag,
            (
                "%s: %d of %d at home, finished: %s"
                % [where, home, level.animals.size(), level.finished]
            )
        )
    if level.finished:
        var stars := level.stars()
        var kept: int = level.get_node("/root/Profile").stars.get(level.level_id(), 0)
        if stars < 1 or stars > 3:
            _report("%s: the level gives %d stars" % [tag, stars], where)
        if kept < stars:
            _report(
                "%s: the journey does not keep the stars" % tag,
                "%s: %d < %d" % [where, kept, stars]
            )
        for i in range(level.players()):
            if level.talking_to(i) == null or not level.view(i).conversation.visible:
                _report(
                    "%s: Grandmother does not thank a rider" % tag,
                    "%s, the rider %d" % [where, i + 1]
                )
    # NOTE (mristin):
    # A horse in the air keeps its speed and its heading, and does not rear;
    # a rearing horse on the ground stands still and does not turn.
    for i in range(level.players()):
        var rider := level.view(i).rider
        var who := "%s, the rider %d at %s" % [where, i + 1, rider.position]
        var rearing_key := "rearing %d" % i
        if rider.jumping() >= 0.0:
            if rider.rear_time >= 0.0:
                _report("%s: a horse rears in the air" % tag, who)
            var flying := rider._jump_speed * Rider.MAX_SPEED
            if absf(rider.speed - flying) > 0.01:
                _report(
                    "%s: a horse in the air does not keep its speed" % tag,
                    "%s: %f px/s, took off at %f px/s" % [who, rider.speed, flying]
                )
            last.erase(rearing_key)
        elif rider.rear_time >= 0.0:
            var before: Array = last.get(rearing_key, [])
            if (
                not before.is_empty()
                and float(before[0]) < rider.rear_time
                and (
                    not (before[1] as Vector2).is_equal_approx(rider.position)
                    or not is_equal_approx(float(before[2]), rider.heading)
                )
            ):
                _report(
                    "%s: a rearing horse moves or turns" % tag,
                    (
                        "%s: from %s heading %f, now heading %f"
                        % [who, before[1], before[2], rider.heading]
                    )
                )
            last[rearing_key] = [rider.rear_time, rider.position, rider.heading]
        else:
            last.erase(rearing_key)

    # NOTE (mristin):
    # Each rider hears every lost animal (and every follower which lags far
    # behind, calling) within the radius which is not on her screen, each with
    # its own picture at the edge, and nothing else (the
    # screen is where her view looks, give or take the 4 px inset of [method
    # Hearing.on_screen] and the rounding of the view).
    for i in range(level.players()):
        var view := level.view(i)
        var at := view.rider.position
        var seen := view.seen(map.size)
        var who := "%s, the rider %d at %s, the view %s" % [where, i + 1, at, seen]
        var sounds: Array[Dictionary] = view.hearing.heard.duplicate()
        for animal in level.animals:
            var found := -1
            for k in range(sounds.size()):
                if (
                    (sounds[k]["at"] as Vector2).is_equal_approx(animal.position)
                    and sounds[k]["id"] == animal.kind.id
                ):
                    found = k
                    break
            var heard := found >= 0
            if heard:
                sounds.remove_at(found)
            var what := (
                "%s: the %s of %s at %s" % [who, animal.kind.id, animal.herd.name, animal.position]
            )
            var distance := animal.position.distance_to(at)
            var audible := (
                animal.is_lost() or (animal.state == Animal.State.FOLLOWING and animal.lagging)
            )
            if (
                heard
                and (
                    not audible
                    or distance >= Hearing.RADIUS
                    or seen.grow(-5.0).has_point(animal.position)
                )
            ):
                _report(
                    (
                        "%s: a rider hears an animal which does not call, on her screen or too far"
                        % tag
                    ),
                    what
                )
            if (
                not heard
                and audible
                and distance < Hearing.RADIUS - 0.5
                and not seen.grow(-3.0).has_point(animal.position)
            ):
                _report("%s: a rider does not hear a calling animal off her screen" % tag, what)
        for sound in sounds:
            _report(
                "%s: a rider hears an animal which is not there" % tag,
                "%s: %s at %s" % [who, sound["id"], sound["at"]]
            )

    # NOTE (mristin):
    # What the maps know: the clues of exactly the people talked to (the
    # clues never vanish), the people still to ask (never one talked to
    # already, never Grandmother), so that every herd is either marked by a
    # clue or by whom to ask; each map ticks exactly the clues whose animals
    # are no longer lost.
    var revealed := level.revealed()
    var talked: Dictionary = level._people_talked
    for person in talked:
        for clue in (person as Person).clues:
            if clue not in revealed:
                _report(
                    "%s: a clue of a person talked to is not on the maps" % tag,
                    "%s: %s" % [where, (person as Person).name]
                )
    for clue in revealed:
        if not talked.keys().any(func(p: Person) -> bool: return clue in p.clues):
            _report("%s: the maps show a clue nobody told" % tag, "%s: %s" % [where, clue.form])
    if revealed.size() < int(last.get("revealed", 0)):
        _report("%s: a clue vanished from the maps" % tag, where)
    last["revealed"] = revealed.size()
    var people := map.people()
    for person in level.referred():
        if person not in people or person.portrait == "grandmother" or talked.has(person):
            _report(
                "%s: the maps ring a person who is not to be asked" % tag,
                "%s: %s" % [where, person.name]
            )
    for herd in map.herds():
        if herd.animal == null:
            continue
        var marked := func(c: Clue) -> bool: return map.herd_of(c) == herd
        if not (
            revealed.any(marked)
            or level.referred().any(func(p: Person) -> bool: return p.clues.any(marked))
        ):
            _report("%s: the maps tell nothing about a herd" % tag, "%s: %s" % [where, herd.name])
    for i in range(level.players()):
        var map_view := level.view(i).map_view
        if map_view.clues != revealed or map_view.referred != level.referred():
            _report(
                "%s: a map shows other clues or people than the riders heard" % tag,
                "%s, the rider %d" % [where, i + 1]
            )
        for clue in revealed:
            var herd := map.herd_of(clue)
            var done := (
                herd != null
                and not level.animals.any(
                    func(a: Animal) -> bool: return a.herd == herd and a.is_lost()
                )
            )
            if bool(map_view.found.get(clue, false)) != done:
                _report(
                    "%s: a map ticks a clue whose animals are lost, or the other way" % tag,
                    "%s, the rider %d: %s" % [where, i + 1, clue.form]
                )

    # NOTE (mristin):
    # The speed bar shows the speed of the horse (but in the air, where the
    # horse keeps the speed of its take-off, and while it rears); a tired horse
    # (no water or no food) only walks slowly; the bar is empty while the rider
    # talks (the thanks at the end stop the horse on the next frame).
    for i in range(level.players()):
        var view := level.view(i)
        var rider := view.rider
        var shown := view.speed_bar.speed
        var who := "%s, the rider %d" % [where, i + 1]
        if (
            rider.jumping() < 0.0
            and rider.rear_time < 0.0
            and absf(rider.speed - shown * Rider.MAX_SPEED) > 0.01
        ):
            _report(
                "%s: the speed bar does not show the speed of the horse" % tag,
                "%s: %f px/s, the bar %f" % [who, rider.speed, shown]
            )
        var tired := view.needs.water <= 0.0 or view.needs.food <= 0.0
        if tired and bool(last.get("tired %d" % i, false)) and shown > HorseNeeds.TIRED_SPEED:
            _report(
                "%s: a tired horse runs faster than a slow walk" % tag,
                (
                    "%s: %f, the water %f, the food %f"
                    % [who, shown, view.needs.water, view.needs.food]
                )
            )
        last["tired %d" % i] = tired
        var standing := (
            view.talking != null if not level.finished else bool(last.get("finished", false))
        )
        if standing and shown > 0.0:
            _report(
                "%s: the speed bar shows a speed while the horse stands" % tag,
                "%s: %f" % [who, shown]
            )

    # NOTE (mristin):
    # A horse drinks (its water rises) only standing at fresh water (a
    # spring, a lake, a well, a river or a creek; never at the salt lake),
    # and grazes (its food rises) only standing on a pasture; give or take
    # how far it moved between two checks.
    for i in range(level.players()):
        var view := level.view(i)
        var needs := view.needs
        var at := view.rider.position
        var who := "%s, the rider %d at %s" % [where, i + 1, at]
        var fresh := false
        var pasture := false
        for landmark in map.landmarks():
            var beyond := at.distance_to(landmark.position) - landmark.size()
            if landmark is River:
                fresh = fresh or absf(at.y - landmark.position.y) <= landmark.size() + 16.0
            elif landmark.kind != null and landmark.kind.fresh_water:
                fresh = fresh or beyond <= 16.0
            if landmark.kind != null and landmark.kind.pasture:
                pasture = pasture or beyond <= 4.0
        var water_rose := needs.water > float(last.get("water %d" % i, 1.0)) + 1e-6
        var food_rose := needs.food > float(last.get("food %d" % i, 1.0)) + 1e-6
        last["water %d" % i] = needs.water
        last["food %d" % i] = needs.food
        if (needs.drinking or water_rose) and not fresh:
            _report("%s: a horse drinks away from fresh water (e.g., at the salt lake)" % tag, who)
        if (needs.grazing or food_rose) and not pasture:
            _report("%s: a horse grazes away from a pasture" % tag, who)

    # NOTE (mristin):
    # The small figure does what the game understood of the player, so that
    # she sees that her body is understood (see [Coach]): she jumps with each
    # jump and squats with each squat which the level saw, raises her hands
    # while the player brakes and pulls the reins while the player turns (held
    # since the check before, since the keys may come between the frames);
    # and she shows none of these unless the player does it.
    for i in range(level.players()):
        var view := level.view(i)
        var coach := view.coach
        var shows := coach.showing()
        var who := "%s, the rider %d: the figure shows %s" % [where, i + 1, shows]
        var jumped := view.jumps_seen > int(last.get("jumps %d" % i, view.jumps_seen))
        var squatted := view.squats_seen > int(last.get("squats %d" % i, view.squats_seen))
        last["jumps %d" % i] = view.jumps_seen
        last["squats %d" % i] = view.squats_seen
        var braking: bool = service.IsBraking(i)
        var turning: bool = absf(service.GetTurn(i)) >= 0.3
        var held_braking: bool = braking and bool(last.get("braking %d" % i, false))
        var held_turning: bool = turning and bool(last.get("turning %d" % i, false))
        var held_still: bool = not braking and not bool(last.get("braking %d" % i, true))
        var held_straight: bool = not turning and not bool(last.get("turning %d" % i, true))
        last["braking %d" % i] = braking
        last["turning %d" % i] = turning
        var wanted := ""
        if jumped:
            wanted = "jump"
        elif shows != "jump" and held_braking:
            wanted = "brake"
        elif shows != "jump" and not braking and held_turning:
            wanted = "reins"
        if wanted != "" and shows != wanted:
            _report(
                "%s: the small figure does not show what the player does" % tag,
                "%s, not %s" % [who, wanted]
            )
        if squatted and shows == "stand":
            _report("%s: the small figure does not squat with the player" % tag, who)
        if (shows == "brake" and held_still) or (shows == "reins" and held_straight):
            _report("%s: the small figure shows what the player does not do" % tag, who)

    # NOTE (mristin):
    # An animal goes only forward (lost, following, entering the pen, home);
    # it joins a rider who stands near it, and runs into the pen only when a
    # rider brought it to the gate (give or take how far the riders and the
    # animals move between two checks). Once all are home, the clock stops.
    var moved := 4.0 * Rider.MAX_SPEED * level.get_process_delta_time()
    var states: Dictionary = last.get("states", {})
    var gate := map.home().gate()
    for animal in level.animals:
        var what := (
            "%s, the %s of %s at %s" % [where, animal.kind.id, animal.herd.name, animal.position]
        )
        var before: int = states.get(animal, animal.state)
        states[animal] = animal.state
        if animal.state < before:
            _report(
                "%s: an animal goes back to an earlier state" % tag,
                "%s: %d, then %d" % [what, before, animal.state]
            )
        var riders := range(level.players()).map(
            func(k: int) -> Vector2: return level.rider(k).position
        )
        if before == Animal.State.LOST and animal.state == Animal.State.FOLLOWING:
            if not riders.any(
                func(r: Vector2) -> bool:
                    return r.distance_to(animal.position) < Animal.JOIN_DISTANCE + moved
            ):
                _report("%s: an animal joins a rider far away" % tag, what)
        if before <= Animal.State.FOLLOWING and animal.state >= Animal.State.ENTERING:
            if not riders.any(
                func(r: Vector2) -> bool: return r.distance_to(gate) < Level.GATE_DISTANCE + moved
            ):
                _report("%s: an animal runs into the pen without a rider at the gate" % tag, what)
    last["states"] = states
    if (
        level.finished
        and bool(last.get("finished", false))
        and level.elapsed != float(last.get("elapsed", 0.0))
    ):
        _report("%s: the time of the ride runs after the end" % tag, where)

    if level.elapsed < float(last.get("elapsed", 0.0)):
        _report("%s: the time of the ride runs backwards" % tag, where)
    # NOTE (mristin):
    # The motion and the world over time, between this check and the last
    # (dt seconds of the game: the checks skip frames), see
    # level_motion_contracts.gd; what the level shows, see
    # level_view_contracts.gd; and what outlives it, see contract_book.gd.
    var frame := Engine.get_process_frames()
    var dt := level.get_process_delta_time() * (frame - int(last.get("frame", frame)))
    last["frame"] = frame
    _check_followers(level, tag, where, last, dt)
    _check_calls(level, tag, where, last, dt)
    _check_jumps(level, tag, where, last, dt)
    _check_motion(level, tag, where, last, dt)
    _check_crossings(level, tag, where, last)
    _check_lost(level, tag, where, last, dt)
    _check_edge(level, tag, where, last, dt)
    _check_views(level, tag, where)
    _check_clock(level, tag, where, last, dt)
    _check_standing_needs(level, tag, where)
    _check_gaits(level, tag, where)
    _check_maps_follow(level, tag, where)
    _check_own_hud(level, tag, where)
    _check_hints(level, tag, where, last)
    if full:
        _check_clue_areas(level, tag, where)
        _check_heard_in_view(level, tag, where)
        _check_tree(level, tag, true)
    _check_sounds(level, tag, true)
    _check_vision(level, tag, level.players())
    _check_level_life(level, tag)
    last["elapsed"] = level.elapsed
    last["locale"] = TranslationServer.get_locale()
    last["finished"] = level.finished
    _last[level.get_instance_id()] = last


## Forget the level, e.g., when it is left.
func forget(level_id: int) -> void:
    _last.erase(level_id)
    _since.clear()
