extends "res://tests/godot/end2end/level_motion_contracts.gd"
## Check what a level shows to the players, besides its layout (see
## level_contracts.gd, which calls these checks): the horse drinks and grazes
## only while it stands; the speed bar lights the gait of the horse; every
## clue is drawn around its herd; the small figure shows exactly the hints
## which the level gives; the pictures of the animals heard stand in the view
## of their rider; and the HUD of each player shows her own state.
##
## Not a test itself (its name does not start with test_), it is preloaded by
## the tests.


## A horse drinks or grazes (and its bubble shows it) only while it stands
## (by its own speed: e.g., a rearing horse stands, whatever the speed bar
## shows of the squats): never while it walks, however slowly (see section 4
## of DESIGN.md).
func _check_standing_needs(level: Level, tag: String, where: String) -> void:
    for i in range(level.players()):
        var view := level.view(i)
        if not (view.needs.drinking or view.needs.grazing):
            continue
        if view.rider.gait() != 0:
            _report(
                "%s: a horse drinks or grazes while it walks" % tag,
                (
                    "%s, the rider %d: %f px/s, the gait %d, drinking %s, grazing %s"
                    % [
                        where,
                        i + 1,
                        view.rider.speed,
                        view.rider.gait(),
                        view.needs.drinking,
                        view.needs.grazing
                    ]
                )
            )


## The speed bar marks the gaits where the squats change them, and lights
## the horse of the gait which the horse runs (but in the air and while it
## rears, see the contract of the speed).
func _check_gaits(level: Level, tag: String, where: String) -> void:
    var thresholds: Vector3 = level.get_node("/root/Vision").service.GetGaitThresholds()
    for i in range(level.players()):
        var view := level.view(i)
        var rider := view.rider
        var bar := view.speed_bar
        var who := "%s, the rider %d" % [where, i + 1]
        if not bar.thresholds.is_equal_approx(thresholds):
            _report(
                "%s: the speed bar marks other gaits than the squats" % tag,
                "%s: %s, not %s" % [who, bar.thresholds, thresholds]
            )
        if rider.jumping() < 0.0 and rider.rear_time < 0.0 and bar.gait() != rider.gait():
            _report(
                "%s: the speed bar lights another gait than the horse runs" % tag,
                (
                    "%s: the bar %d at %f, the horse %d at %f px/s"
                    % [who, bar.gait(), bar.speed, rider.gait(), rider.speed]
                )
            )


## Every clue on the maps is drawn: a dashed area in the steppe around the
## herd it tells of, whose card shows that herd's animal and how many they
## are (see section 4 of DESIGN.md, "The map").
func _check_clue_areas(level: Level, tag: String, where: String) -> void:
    var map := level.map
    var steppe := Rect2(Vector2.ZERO, map.size)
    for clue in level.revealed():
        var area := map.clue_area(clue)
        var herd := map.herd_of(clue)
        var what := (
            "%s: %s %s, %d %s" % [where, clue.form, clue.landmark, clue.count, clue.animal.id]
        )
        if area.z <= 0.0 or not steppe.has_point(Vector2(area.x, area.y)):
            _report(
                "%s: a clue is not drawn on the maps, or off the steppe" % tag,
                "%s, the area %s" % [what, area]
            )
        elif herd == null or herd.animal != clue.animal or herd.count != clue.count:
            _report(
                "%s: a clue on the maps does not mark its herd, or miscounts it" % tag,
                "%s, the herd of %s" % [what, "none" if herd == null else str(herd.count)]
            )


## The warning at the edge is in the language of the game (a frame late after
## a switch); the small figure shows the arrow up exactly while the hint to
## jump runs, and the curved arrow exactly while the edge or the hint to turn
## runs (and the rider does not talk), see section 5 of DESIGN.md.
func _check_hints(level: Level, tag: String, where: String, last: Dictionary) -> void:
    for i in range(level.players()):
        var view := level.view(i)
        var who := "%s, the rider %d" % [where, i + 1]
        if (
            view.edge_label.visible
            and last.get("locale", "") == TranslationServer.get_locale()
            and view.edge_label.text != level.tr("Don't ride too far away!")
        ):
            _report(
                "%s: the warning at the edge is not in the language of the game" % tag,
                "%s: %s" % [who, JSON.stringify(view.edge_label.text)]
            )
        var expected := -1
        if view.talking == null and not level.finished:
            if view.jump_hint_time > 0.0:
                expected = Coach.Mode.JUMP
            elif view.edge_time > 0.0 or view.turn_hint_time > 0.0:
                expected = Coach.Mode.REACH
        var shown: int = view.coach.mode
        if shown not in [Coach.Mode.REACH, Coach.Mode.JUMP]:
            shown = -1
        if shown != expected:
            _report(
                "%s: the small figure shows another hint than the level gives" % tag,
                (
                    "%s: %d, not %d (the edge %f, the turn %f, the jump %f)"
                    % [
                        who,
                        shown,
                        expected,
                        view.edge_time,
                        view.turn_hint_time,
                        view.jump_hint_time
                    ]
                )
            )


## The picture of every animal heard stands at the edge of the view of its
## rider, inside it (not over the other half), in the direction of the
## animal (see [method Hearing._draw]).
func _check_heard_in_view(level: Level, tag: String, where: String) -> void:
    for i in range(level.players()):
        var view := level.view(i)
        var hearing := view.hearing
        var who := "%s, the rider %d" % [where, i + 1]
        var box := Layout.global_rect(hearing)
        if (
            not box.is_equal_approx(view.rect)
            or not hearing.rider_at.is_equal_approx(view.rider.position)
        ):
            _report(
                "%s: the hearing listens elsewhere than the view of its rider" % tag,
                "%s: %s at %s, the view %s" % [who, box, hearing.rider_at, view.rect]
            )
            continue
        var inner := Rect2(Vector2.ZERO, hearing.size).grow(-Hearing._INSET)
        var center := hearing.view * hearing.rider_at
        for sound in hearing.heard:
            var direction := (hearing.view * (sound["at"] as Vector2) - center).normalized()
            if direction == Vector2.ZERO:
                continue
            var t := INF
            if direction.x != 0.0:
                var x := inner.end.x if direction.x > 0.0 else inner.position.x
                t = minf(t, (x - center.x) / direction.x)
            if direction.y != 0.0:
                var y := inner.end.y if direction.y > 0.0 else inner.position.y
                t = minf(t, (y - center.y) / direction.y)
            var scale := 2.0 if float(sound["closeness"]) > 0.5 else 1.0
            var radius := Icons.SIZE.x * scale * 0.5 + 3.0
            var at := box.position + (center + direction * t).round()
            var drawn := Rect2(at - Vector2.ONE * radius, Vector2.ONE * 2.0 * radius)
            if t < 0.0 or not view.rect.grow(Layout.TOLERANCE).encloses(drawn):
                _report(
                    "%s: the picture of an animal heard stands out of the view" % tag,
                    "%s: the %s at %s, drawn at %s" % [who, sound["id"], sound["at"], drawn]
                )


## Each map shows its own rider where she is and heading where she heads,
## and her partner (likewise) exactly when two ride.
func _check_maps_follow(level: Level, tag: String, where: String) -> void:
    for i in range(level.players()):
        var map_view := level.view(i).map_view
        var rider := level.view(i).rider
        var who := "%s, the rider %d" % [where, i + 1]
        if (
            map_view.map != level.map
            or not map_view.rider_at.is_equal_approx(rider.position)
            or not is_equal_approx(map_view.rider_heading, rider.heading)
        ):
            _report(
                "%s: a map shows its rider elsewhere or heading elsewhere" % tag,
                (
                    "%s: %s heading %f, she at %s heading %f"
                    % [
                        who,
                        map_view.rider_at,
                        map_view.rider_heading,
                        rider.position,
                        rider.heading
                    ]
                )
            )
        if map_view.has_partner != (level.players() > 1):
            _report(
                "%s: a map shows a partner who does not ride, or no partner" % tag,
                "%s: %s" % [who, map_view.has_partner]
            )
        elif map_view.has_partner:
            var partner := level.view(1 - i).rider
            if (
                not map_view.partner_at.is_equal_approx(partner.position)
                or not is_equal_approx(map_view.partner_heading, partner.heading)
            ):
                _report(
                    "%s: a map shows the partner elsewhere or heading elsewhere" % tag,
                    "%s: %s, she at %s" % [who, map_view.partner_at, partner.position]
                )


## The HUD and the horse of each player show her own state: her water and
## food in her bars and in the one upright bubble over her horse, her looks
## as she is dressed; the slots show the animals of the level, in its order.
func _check_own_hud(level: Level, tag: String, where: String) -> void:
    var profile := level.get_node("/root/Profile")
    for i in range(level.players()):
        var view := level.view(i)
        var who := "%s, the rider %d" % [where, i + 1]
        var bubbles := view.rider.find_children("*", "NeedsBubble", false, false)
        var bubble: NeedsBubble = bubbles[0] if bubbles.size() == 1 else null
        if (
            view.needs_bars.needs != view.needs
            or bubble == null
            or bubble.needs != view.needs
            or not bubble.is_visible_in_tree()
            or not is_zero_approx(bubble.global_rotation)
        ):
            _report(
                "%s: the water and the food shown are not those of her horse" % tag,
                "%s: %d bubbles" % [who, bubbles.size()]
            )
        var dressed: Dictionary = profile.rider(i).dressed()
        if JSON.stringify(view.rider.looks) != JSON.stringify(dressed):
            _report(
                "%s: a rider rides otherwise than she is dressed" % tag,
                "%s: %s, not %s" % [who, view.rider.looks, dressed]
            )
    var slots: Slots = level.get_node("Hud/Slots")
    if slots.animals != level.animals or not slots.size.is_equal_approx(slots.strip_size()):
        _report(
            "%s: the slots show other animals than the level has" % tag,
            "%s: %d slots, %d animals" % [where, slots.animals.size(), level.animals.size()]
        )
