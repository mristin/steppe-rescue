extends "res://tests/godot/end2end/contract_book.gd"
## Check the motion and the world of a level over time, between two checks
## (see level_contracts.gd, which calls these checks): the followers walk
## around what blocks the horse and cross the river only at a ford; a jump
## which fell short of a creek counts, and after a few every jump is helped;
## the horse never teleports, turns at most as fast as it can and keeps its
## heading in the air; it crosses a creek only in the air and the river only
## at a ford; the lost animals graze slowly at their spots, and the shy ones
## move off only when scared and join only a rider who walks; a follower
## which falls behind calls out; the warning at
## the edge shows exactly when it should; every view looks at its rider, but
## never beyond the steppe; and the time of the ride runs from the first
## stride, with the game.
##
## Not a test itself (its name does not start with test_), it is preloaded by
## the tests.

## How far a rider or an animal may stand in what blocks the horse, in pixels.
const _SLACK := 0.5


## The side of the river (or creek) the point is on: -1 north, 1 south.
static func _side(at: Vector2, river: River) -> float:
    return signf(at.y - river.position.y)


## Whether the point is at a ford of the river, give or take a horse.
static func _at_ford(at: Vector2, river: River) -> bool:
    for ford in river.fords:
        if absf(at.x - ford) <= river.ford_width() * 0.5 + river.size() + Rider.RADIUS:
            return true
    return false


## The rivers (with fords) and the creeks (jumped over) of the level.
static func _waters(level: Level, creeks: bool) -> Array[River]:
    var result: Array[River] = []
    for landmark in level.map.landmarks():
        if landmark is River and (landmark is Creek) == creeks:
            result.append(landmark as River)
    return result


## The followers walk around what blocks the horse, and cross a river only at
## a ford, as their rider must (see section 4 of DESIGN.md, "The followers",
## and section 4, "The levels": "the rider can cross only at the fords").
func _check_followers(
    level: Level, tag: String, where: String, last: Dictionary, dt: float
) -> void:
    var solids := level.map.solids()
    var rivers := _waters(level, false)
    for i in range(level.players()):
        var rider := level.rider(i)
        for animal in level.followers(i):
            var what := (
                "%s, the %s of %s at %s, following the rider %d at %s"
                % [where, animal.kind.id, animal.herd.name, animal.position, i + 1, rider.position]
            )
            for solid in solids:
                if animal.position.distance_to(Vector2(solid.x, solid.y)) < solid.z - _SLACK:
                    _report(
                        "%s: a follower walks through what blocks the horse" % tag,
                        "%s, in %s" % [what, solid]
                    )
            var key := "follower %d" % animal.get_instance_id()
            var before: Variant = last.get(key)
            if before is Vector2 and dt > 0.0:
                var at: Vector2 = before
                if at.distance_to(animal.position) > animal.kind.speed * dt + 0.01:
                    _report(
                        "%s: a follower runs faster than its kind" % tag,
                        "%s, from %s in %.2f s" % [what, at, dt]
                    )
                for river in rivers:
                    if (
                        _side(at, river) * _side(animal.position, river) < 0.0
                        and not (_at_ford(at, river) and _at_ford(animal.position, river))
                    ):
                        _report(
                            "%s: a follower crosses the river away from a ford" % tag,
                            "%s, from %s" % [what, at]
                        )
            last[key] = animal.position


## A jump from the bank of a creek which lands back on that bank fell short
## and counts (once), with a splash; a jump which carried the horse over does
## not count; after SHORT_JUMPS_HELPED short jumps, every jump is helped (see
## [constant Rider.SHORT_JUMPS_HELPED]: "a child ... is never stuck").
func _check_jumps(level: Level, tag: String, where: String, last: Dictionary, dt: float) -> void:
    var creeks := _waters(level, true)
    for i in range(level.players()):
        var rider := level.rider(i)
        var who := "%s, the rider %d at %s" % [where, i + 1, rider.position]
        var key := "jump %d" % i
        var before: Array = last.get(key, [])
        last[key] = [rider.jump_time, rider.short_jumps]
        if (
            rider.jump_time >= 0.0
            and rider.short_jumps >= Rider.SHORT_JUMPS_HELPED
            and rider._jump_speed < Rider.HELPED_JUMP_SPEED - 1e-6
        ):
            _report(
                "%s: a jump after the short jumps is not helped" % tag,
                "%s: %d short, flying as from %.2f" % [who, rider.short_jumps, rider._jump_speed]
            )
        if before.is_empty() or dt <= 0.0:
            continue
        var shorts: int = before[1]
        if rider.short_jumps < shorts or rider.short_jumps > shorts + 1:
            _report(
                "%s: the short jumps are miscounted" % tag,
                "%s: %d, then %d" % [who, shorts, rider.short_jumps]
            )
        if float(before[0]) < 0.0 or rider.jump_time >= 0.0:
            if rider.short_jumps != shorts:
                _report("%s: a short jump counts without a landing" % tag, who)
            continue
        # NOTE (mristin):
        # The horse landed since the last check.
        var take_off := rider._take_off
        for creek in creeks:
            var bank := creek.size() + Rider.RADIUS + 0.5
            var back := _side(take_off, creek) * _side(rider.position, creek) > 0.0
            var from_bank := absf(take_off.y - creek.position.y) <= bank
            var on_bank := absf(rider.position.y - creek.position.y) <= bank
            if from_bank and back and on_bank and rider.short_jumps != shorts + 1:
                _report(
                    "%s: a jump which fell short of a creek does not count" % tag,
                    "%s, took off at %s, %d short jumps" % [who, take_off, rider.short_jumps]
                )
            if not back and rider.short_jumps != shorts:
                _report(
                    "%s: a jump over a creek counts as short" % tag,
                    "%s, took off at %s" % [who, take_off]
                )
        if rider.short_jumps > shorts and rider.splash_time < 0.0:
            _report("%s: a short jump does not splash" % tag, who)


## The horse moves at most at its full gallop (the slide along what blocks it
## and the landing in a creek push it a little more), never teleports, turns
## at most at [constant Rider.TURN_RATE], and keeps its heading in the air.
func _check_motion(level: Level, tag: String, where: String, last: Dictionary, dt: float) -> void:
    var reach := 0.0
    for creek in _waters(level, true):
        reach = maxf(reach, creek.size() + Rider.RADIUS)
    for i in range(level.players()):
        var rider := level.rider(i)
        var who := "%s, the rider %d at %s" % [where, i + 1, rider.position]
        var key := "ride %d" % i
        var before: Array = last.get(key, [])
        last[key] = [rider.position, rider.heading, rider.jump_time]
        if before.is_empty() or dt <= 0.0:
            continue
        var at: Vector2 = before[0]
        var jump_before: float = before[2]
        var landed := jump_before >= 0.0 and rider.jump_time < 0.0
        var allowed := Rider.MAX_SPEED * dt * 1.5 + 1.0 + (reach if landed else 0.0)
        if at.distance_to(rider.position) > allowed:
            _report(
                "%s: a horse jumps across the steppe in a moment" % tag,
                "%s, from %s in %.2f s" % [who, at, dt]
            )
        var turned := absf(wrapf(rider.heading - float(before[1]), -PI, PI))
        if turned > Rider.TURN_RATE * dt + 1e-4:
            _report(
                "%s: a horse turns faster than it can" % tag,
                "%s: %.3f rad in %.2f s" % [who, turned, dt]
            )
        if jump_before >= 0.0 and rider.jump_time > jump_before and turned > 1e-6:
            _report("%s: a horse turns in the air" % tag, "%s: %.3f rad" % [who, turned])


## The horse crosses a creek only in the air, and a river only at a ford (see
## [Creek] and [River]).
func _check_crossings(level: Level, tag: String, where: String, last: Dictionary) -> void:
    var creeks := _waters(level, true)
    var rivers := _waters(level, false)
    for i in range(level.players()):
        var rider := level.rider(i)
        var who := "%s, the rider %d at %s" % [where, i + 1, rider.position]
        var key := "crossing %d" % i
        var before: Array = last.get(key, [])
        last[key] = [rider.position, rider.jump_time]
        if before.is_empty():
            continue
        var at: Vector2 = before[0]
        for creek in creeks:
            if (
                _side(at, creek) * _side(rider.position, creek) < 0.0
                and float(before[1]) < 0.0
                and rider.jump_time < 0.0
            ):
                _report(
                    "%s: a horse crosses a creek on the ground" % tag, "%s, from %s" % [who, at]
                )
        for river in rivers:
            if (
                _side(at, river) * _side(rider.position, river) < 0.0
                and not (_at_ford(at, river) and _at_ford(rider.position, river))
            ):
                _report(
                    "%s: a horse crosses the river away from a ford" % tag,
                    "%s, from %s" % [who, at]
                )


## A lost animal grazes slowly around its spot; its spot moves only when it is
## shy and flees from a rider at a trot or a gallop near it; a shy animal joins
## only a rider who walks (see section 4 of DESIGN.md, "Horses are shy").
func _check_lost(level: Level, tag: String, where: String, last: Dictionary, dt: float) -> void:
    var service: Node = level.get_node("/root/Vision").service
    var gaits: Array[int] = []
    for i in range(level.players()):
        gaits.append(mini(service.GetGait(i), level.rider(i).gait()))
    var gaits_before: Array = last.get("gaits", gaits)
    last["gaits"] = gaits
    for animal in level.animals:
        var key := "lost %d" % animal.get_instance_id()
        var before: Array = last.get(key, [])
        last[key] = [animal.state, animal.position, animal.spot]
        if before.is_empty() or dt <= 0.0 or int(before[0]) != Animal.State.LOST:
            continue
        var what := (
            "%s, the %s of %s at %s" % [where, animal.kind.id, animal.herd.name, animal.position]
        )
        var at: Vector2 = before[1]
        var spot: Vector2 = before[2]
        if animal.state == Animal.State.FOLLOWING and animal.kind.shy:
            for i in range(level.players()):
                if animal in level.followers(i) and gaits[i] >= 2 and int(gaits_before[i]) >= 2:
                    _report(
                        "%s: a shy animal joins a rider at a trot or a gallop" % tag,
                        "%s, the rider %d at the gait %d" % [what, i + 1, gaits[i]]
                    )
        if animal.state != Animal.State.LOST:
            continue
        if at.distance_to(animal.position) > Animal._GRAZE_SPEED * dt + 0.01:
            _report("%s: a lost animal runs" % tag, "%s, from %s in %.2f s" % [what, at, dt])
        if not spot.is_equal_approx(animal.spot):
            var scared := false
            for i in range(level.players()):
                var close := level.rider(i).position.distance_to(at)
                var gait := maxi(gaits[i], int(gaits_before[i]))
                var near := close < Level.SCARE_DISTANCE + Rider.MAX_SPEED * dt
                scared = scared or (gait >= 2 and near)
            if not (animal.kind.shy and scared):
                _report(
                    "%s: a lost animal moves away though nobody scared it" % tag,
                    "%s: the spot %s, then %s" % [what, spot, animal.spot]
                )
        else:
            var off := animal.position.distance_to(animal.spot)
            if off > Animal._GRAZE_RADIUS + 0.5 and off > at.distance_to(spot) + 1e-3:
                _report(
                    "%s: a lost animal wanders off its spot" % tag,
                    "%s: %.1f px from %s" % [what, off, animal.spot]
                )


## The warning at the edge shows exactly while the horse is at the edge of the
## steppe (standing on it) and for [constant Level.EDGE_SECONDS] after.
func _check_edge(level: Level, tag: String, where: String, last: Dictionary, dt: float) -> void:
    var edge := Rect2(Vector2.ZERO, level.map.size).grow(-Rider.EDGE)
    for i in range(level.players()):
        var view := level.view(i)
        var rider := view.rider
        var who := "%s, the rider %d at %s" % [where, i + 1, rider.position]
        var shown := view.edge_label.visible and view.edge_label.text != ""
        if shown != (view.edge_time > 0.0) or (rider.at_edge and not shown):
            _report(
                "%s: the warning at the edge shows when it should not, or the other way" % tag,
                (
                    "%s: shown %s, %.2f s left, at the edge: %s"
                    % [who, shown, view.edge_time, rider.at_edge]
                )
            )
        var p := rider.position
        var on_edge := (
            is_equal_approx(p.x, edge.position.x)
            or is_equal_approx(p.x, edge.end.x)
            or is_equal_approx(p.y, edge.position.y)
            or is_equal_approx(p.y, edge.end.y)
        )
        var fresh := is_equal_approx(view.edge_time, Level.EDGE_SECONDS)
        if rider.at_edge and (not on_edge or not fresh):
            _report(
                "%s: a horse at the edge is not on it, or its warning is not fresh" % tag,
                "%s, the edge %s, %.2f s left" % [who, edge, view.edge_time]
            )
        var left := float(last.get("edge %d" % i, 0.0))
        if dt > 0.0 and view.edge_time < maxf(0.0, left - dt) - 1e-4:
            _report(
                "%s: the warning at the edge ends early" % tag,
                "%s: %.2f s left, then %.2f s after %.2f s" % [who, left, view.edge_time, dt]
            )
        last["edge %d" % i] = view.edge_time


## Every view looks at its rider, but never beyond the steppe.
func _check_views(level: Level, tag: String, where: String) -> void:
    var steppe := Rect2(Vector2.ZERO, level.map.size)
    for i in range(level.players()):
        var view := level.view(i)
        var at := view.rider.position
        var who := "%s, the rider %d at %s" % [where, i + 1, at]
        var center := view.center(level.map.size)
        var seen := view.seen(level.map.size)
        if not steppe.grow(0.5).encloses(seen):
            _report("%s: a view shows beyond the steppe" % tag, "%s: %s" % [who, seen])
        var origin := view.viewport.canvas_transform.origin
        var expected := (view.rect.size * 0.5 - center).round()
        if not origin.is_equal_approx(expected):
            _report(
                "%s: a view does not look where it should" % tag,
                "%s: at %s, not %s" % [who, origin, expected]
            )
        var around := Rect2(at - view.rect.size * 0.5, view.rect.size)
        if steppe.encloses(around) and not center.is_equal_approx(at):
            _report("%s: a view does not follow its rider" % tag, "%s: at %s" % [who, center])


## The time of the ride starts with the first stride, then runs with the game
## until all the animals are home (see [member Level.elapsed]).
func _check_clock(level: Level, tag: String, where: String, last: Dictionary, dt: float) -> void:
    var moving := false
    for i in range(level.players()):
        var rider := level.rider(i)
        var before: Variant = last.get("clock at %d" % i)
        moving = (
            moving
            or rider.speed > 0.0
            or (before is Vector2 and not (before as Vector2).is_equal_approx(rider.position))
        )
        last["clock at %d" % i] = rider.position
    var started: bool = moving or bool(last.get("started", false))
    var clock: Array = last.get("clock", [])
    if not clock.is_empty() and dt > 0.0:
        if level.elapsed > 0.0 and not started:
            _report("%s: the time of the ride runs before the first stride" % tag, where)
        var ran := level.elapsed - float(clock[0])
        var running := float(clock[0]) > 0.0 and not bool(clock[1])
        if running and not level.finished and absf(ran - dt) > 1e-3:
            _report(
                "%s: the time of the ride does not run with the game" % tag,
                "%s: %.3f s in %.3f s" % [where, ran, dt]
            )
    last["started"] = started
    last["clock"] = [level.elapsed, level.finished]


## A follower which lags far behind its place behind the rider (see [constant
## Level.CALL_DISTANCE]) is marked so, and calls out at least every [constant
## Level.CALL_EVERY] seconds while it lags (see section 4 of DESIGN.md, "fall
## behind and call out").
func _check_calls(level: Level, tag: String, where: String, last: Dictionary, dt: float) -> void:
    for i in range(level.players()):
        for k in range(level.followers(i).size()):
            var animal: Animal = level.followers(i)[k]
            var place := level.view(i).trail_point(Level.FOLLOW_SPACING * (k + 1))
            var behind := animal.position.distance_to(place)
            var what := (
                "%s, the %s of %s, %.0f px behind its place behind the rider %d"
                % [where, animal.kind.id, animal.herd.name, behind, i + 1]
            )
            if animal.lagging != (behind > Level.CALL_DISTANCE):
                _report("%s: a follower lags, but is not marked so, or the other way" % tag, what)
            var key := "calls %d" % animal.get_instance_id()
            var before: Array = last.get(key, [])
            var called := not before.is_empty() and animal.calls > int(before[0])
            if not animal.lagging:
                last[key] = [animal.calls, -1.0]
                continue
            # NOTE (mristin):
            # How long it lags since its last call (or since it fell behind).
            var lagged := 0.0
            if not before.is_empty() and float(before[1]) >= 0.0 and not called:
                lagged = float(before[1]) + dt
            if lagged > Level.CALL_EVERY + 2.0 * dt + 0.01:
                _report("%s: a follower lags behind without calling out" % tag, what)
            last[key] = [animal.calls, lagged]
