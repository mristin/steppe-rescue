class_name Level
extends Node2D

## Play a level (see section 4 of DESIGN.md): Grandmother sends the rider out,
## the people tell her where they saw the animals, she hears them before she
## sees them, they follow her once she comes close, and they run into the pen
## when she rides up to its gate. When all the animals are home, Grandmother
## thanks her and she gets her stars, which the profile keeps; the next squat
## goes on to the reward.
##
## With two players, they ride together on a split screen (see section 6 of
## DESIGN.md, "Two players"; [LevelPlayer]): each rider has her own horse,
## her own followers and her own view with its HUD, and talks to the people on
## her own, in her half; the clues are shared on the maps of both, and so are
## the stars. The mission is over when all the animals are home, whoever
## brought them.
##
## The level is the one chosen in [member Flow.level], else [member map_scene].
##
## Keys: Space or W (the first player) and Up (the second player, or the
## first, alone) is a squat, A and D (or Left and Right) turn, S (or Down)
## brakes; C opens and closes the maps, L switches the language, R rides the
## level again, Enter goes on after the end, Escape twice quits.

## The rider talks to a person who is this close, in pixels...
const TALK_DISTANCE := 34.0

## ... and talks to them again only after she rode this far away.
const TALK_AGAIN_DISTANCE := 70.0

## A conversation stays open at least this long, in seconds; then the next
## squat closes it, and the rider rides on.
const TALK_SECONDS := 1.0

## Grandmother's thanks stay at least this long, in seconds; then the next
## squat goes on to the reward.
const THANKS_SECONDS := 3.0

## A galloping horse scares the shy animals within this distance, in pixels.
const SCARE_DISTANCE := 48.0

## The followers walk this far apart behind the rider, in pixels.
const FOLLOW_SPACING := 20.0

## The warning at the edge of the steppe stays this long, in seconds.
const EDGE_SECONDS := 2.5

## The small figure invites the rider to squat when the horse stood still
## this long, in seconds.
const STILL_SECONDS := 3.0

## A follower which lags this far behind its place behind the rider (e.g.,
## a slow sheep behind a gallop) calls out to her, in pixels...
const CALL_DISTANCE := 120.0

## ... every this many seconds, while it lags (see section 4 of DESIGN.md).
const CALL_EVERY := 2.5

## The pitch of the call of each kind of animal.
const _CALL_PITCH := {"camel": 0.7, "horse": 1.0, "sheep": 1.25, "lamb": 1.45}

## The animals run into the pen when the rider is this close to its gate.
const GATE_DISTANCE := 60.0

## The riders of two players start this far apart, in pixels.
const START_APART := 24.0

## The HUD glides out of the riders' way over this many seconds (see
## [HudLayout]).
const GIVE_WAY_SECONDS := HudLayout.GLIDE_SECONDS

## Where the conversation of one player stands, below the missing animals;
## with two players, each conversation stands at the top of its half.
const CONVERSATION := Rect2(8, 40, 600, 100)
const HALF_CONVERSATION := Rect2(8, 8, 464, 100)

## The conversations are at most this high, so that they fit above the rider
## in the middle of the view (see [member Conversation.max_height]).
const CONVERSATION_HEIGHT := 170.0

## Where the button OK stands at the end, with one and with two players.
const OK_AT := Vector2(408, 148)
const HALF_OK_AT := Vector2(380, 250)

## The level to play.
@export var map_scene: PackedScene

## How many players ride (1 or 2); 0 takes it from the profile.
@export_range(0, 2) var player_count := 0

var map: LevelMap
var animals: Array[Animal] = []

## Whether all the animals are home.
var finished := false

## How long the riders took, in seconds, from the first stride.
var elapsed := 0.0

## The water and the food of the first rider's horse.
var needs: HorseNeeds:
    get:
        return _players[0].needs

var _service: Node = null
var _people: Array[Person] = []
var _grandmother: Person = null
var _revealed: Array[Clue] = []

## The people whom Grandmother told the riders to ask, and whom they did not
## talk to yet (marked on the maps).
var _referred: Array[Person] = []
var _people_talked := {}
var _started := false
var _players: Array[LevelPlayer] = []
var _wildlife: Wildlife
var _finish_squats: Array[int] = []
var _finish_time := 0.0
var _ok: DwellButton = null
var _left := false

## Keeps the HUD out of the riders' way.
var _layout := HudLayout.new()

@onready var _world: Node2D = $World
@onready var _animals: Node2D = $World/Animals
@onready var _views: CanvasLayer = $Views
@onready var _hud: CanvasLayer = $Hud
@onready var _slots: Slots = $Hud/Slots
@onready var _camera_panel: CameraPanel = $Hud/CameraPanel
@onready var _status_label: Label = $Hud/StatusLabel
@onready var _quit_hint: QuitHint = $Hud/QuitHint


func _ready() -> void:
    _service = get_node("/root/Vision").service
    var profile := get_node("/root/Profile")
    var count := player_count if player_count > 0 else clampi(profile.players, 1, 2)
    _service.SetPlayerCount(count)
    _service.ResetRiding()
    get_node("/root/Sounds").wind(true)

    if Flow.level != "":
        map_scene = load(Flow.level)
    map = map_scene.instantiate()
    _world.add_child(map)
    _world.move_child(map, 0)

    _wildlife = Wildlife.new()
    _world.add_child(_wildlife)
    _world.move_child(_wildlife, 1)

    var start := map.start()
    _wildlife.populate(
        map.size, map.solids(), [start.position, map.home().position], hash(map.title)
    )

    var animal_count := 0
    for herd in map.herds():
        for spot in herd.spots():
            var animal := Animal.new()
            animal.setup(herd.animal, herd, herd.position + spot, animal_count)
            _animals.add_child(animal)
            animals.append(animal)
            animal_count += 1

    _people = map.people()
    for person in _people:
        if person.portrait == "grandmother":
            _grandmother = person

    # NOTE (mristin):
    # Two riders start side by side, the first player's on the left, as she
    # stands in the camera picture.
    var side := Vector2.RIGHT.rotated(start.rotation)
    for i in range(count):
        var player := LevelPlayer.new(i, count > 1)
        player.rider = $World/Rider if i == 0 else Rider.new()
        if i > 0:
            player.rider.name = "Rider%d" % (i + 1)
            _world.add_child(player.rider)
        player.rider.set_obstacles(map.solids(), map.size, map.jumpable())
        var offset := (i - (count - 1) * 0.5) * START_APART
        player.rider.position = player.rider.slide(start.position + side * offset)
        player.rider.heading = start.rotation
        player.rider.looks = profile.rider(i).dressed()
        player.trail.append(player.rider.position)
        player.brakes = _service.GetBrakeCount(i)
        player.jumps = _service.GetJumpCount(i)
        player.jumps_seen = player.jumps
        var bubble := NeedsBubble.new()
        bubble.needs = player.needs
        player.rider.add_child(bubble)
        _players.append(player)

    for player in _players:
        player.show_world(_world, null if player.index == 0 else _players[0], _views)
        _build_hud(player)
    get_viewport().size_changed.connect(_fit_views)
    _fit_views()

    _slots.animals = animals
    _slots.size = _slots.strip_size()
    _slots.position = Vector2(roundf((960.0 - _slots.size.x) * 0.5), 6)
    # NOTE (mristin):
    # The status of the camera wraps above the speed of the rider.
    _status_label.position = Vector2(8, 436)
    _status_label.size = Vector2(300, 42)
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    if count > 1:
        _camera_panel.position = Vector2(368, 364)
        _camera_panel.size = Vector2(224, 168)
        # NOTE (mristin):
        # The status goes into the left half, above the water and the food, so
        # that the line between the halves does not cross it.
        _status_label.position = Vector2(8, 384)
        _status_label.size = Vector2(288, 42)
        var divider := ColorRect.new()
        divider.color = Palette.OUTLINE
        divider.position = Vector2(479, 0)
        divider.size = Vector2(2, 540)
        divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _hud.add_child(divider)
        _hud.move_child(divider, 0)
    for player in _players:
        _build_coach(player)
    # NOTE (mristin):
    # The hint to quit draws over the rest of the HUD (e.g., the big map), so
    # that the second Escape never quits unannounced.
    _hud.move_child(_quit_hint, -1)
    _arrange()
    for player in _players:
        # NOTE (mristin):
        # Grandmother sends every rider out.
        if _grandmother != null:
            _talk(player, _grandmother)
    _update_views()


func _exit_tree() -> void:
    get_node("/root/Sounds").wind(false)


## Put the HUD of the rider into her part of the screen.
func _build_hud(player: LevelPlayer) -> void:
    var two := player.half
    player.hearing = Hearing.new()
    _add(player.hearing, player.rect, 0)

    player.speed_bar = SpeedBar.new()
    player.speed_bar.thresholds = _service.GetGaitThresholds()
    _add(player.speed_bar, player.place(Rect2(8, 482, 288 if two else 300, 50)))

    player.needs_bars = NeedsBars.new()
    player.needs_bars.needs = player.needs
    _add(
        player.needs_bars, player.place(Rect2(8, 430, 160, 48) if two else Rect2(324, 484, 160, 48))
    )

    player.map_view = MapView.new()
    player.map_view.map = map
    if two:
        player.map_view.small_rect = player.place(Rect2(8, 8, 160, 120))
        player.map_view.large_rect = player.place(Rect2(16, 40, 448, 460))
    _add(player.map_view, player.map_view.small_rect)

    player.conversation = Conversation.new()
    player.conversation.max_height = CONVERSATION_HEIGHT
    _add(player.conversation, player.place(HALF_CONVERSATION if two else CONVERSATION))

    player.edge_label = Label.new()
    player.edge_label.visible = false
    player.edge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _add(player.edge_label, Rect2(player.rect.position.x, 330, player.rect.size.x, 18))


## The small figure of the rider, next to the camera picture: at its left for
## the first player, at its right for the second.
func _build_coach(player: LevelPlayer) -> void:
    player.coach = Coach.new()
    var width := 60.0 if player.half else 64.0
    var x := _camera_panel.position.x - width - 4.0
    if player.index == 1:
        x = _camera_panel.position.x + _camera_panel.size.x + 4.0
    player.coach.position = Vector2(x, _camera_panel.position.y)
    player.coach.size = Vector2(width, _camera_panel.size.y)
    _hud.add_child(player.coach)
    # NOTE (mristin):
    # The small figure draws with the camera picture, under the big map.
    _hud.move_child(player.coach, _camera_panel.get_index() + 1)


## Let the HUD give way to the riders (see [HudLayout]), in the order of
## priority: the conversations, which the riders read, and the button OK stay
## where they open; the hints which show for a moment (the edge of the steppe,
## Escape to quit) next, then the camera picture with the small figures, the
## maps, the speeds, the water and the food, the status of the camera and the
## missing animals make room.
func _arrange() -> void:
    var screen := Rect2(0, 0, 960, 540)
    for player in _players:
        var conversation := player.conversation
        var at := conversation.position
        _layout.add(
            "conversation %d" % (player.index + 1),
            player.rect,
            func() -> Rect2: return Rect2(at, conversation.size),
            func() -> bool: return conversation.visible,
            func(to: Vector2) -> void: conversation.position = to
        )

    var ok_at := HALF_OK_AT if _players.size() > 1 else OK_AT
    _layout.add(
        "ok",
        screen,
        func() -> Rect2: return Rect2(ok_at, Vector2(200, 56)),
        func() -> bool: return _ok != null,
        func(to: Vector2) -> void: _ok.position = to
    )

    for player in _players:
        _add_hint("edge %d" % (player.index + 1), player.edge_label, player.rect)
    _add_hint("quit", _quit_hint, screen)

    # NOTE (mristin):
    # The camera picture and the small figures next to it move together.
    var group: Array[Control] = [_camera_panel]
    for player in _players:
        group.append(player.coach)
    var camera := Rect2(_camera_panel.position, _camera_panel.size)
    for control in group:
        camera = camera.merge(Rect2(control.position, control.size))
    var offsets: Array[Vector2] = []
    for control in group:
        offsets.append(control.position - camera.position)
    _layout.add(
        "camera",
        screen,
        func() -> Rect2: return camera,
        func() -> bool: return true,
        func(to: Vector2) -> void:
            for i in range(group.size()):
                group[i].position = to + offsets[i]
    )

    for player in _players:
        var map_view := player.map_view
        var small := map_view.small_rect
        _layout.add(
            "map %d" % (player.index + 1),
            player.rect,
            func() -> Rect2: return small,
            func() -> bool: return not map_view.large,
            func(to: Vector2) -> void: map_view.move_small(to)
        )
    for player in _players:
        for named in [["speed", player.speed_bar], ["needs", player.needs_bars]]:
            var control: Control = named[1]
            var home := Rect2(control.position, control.size)
            _layout.add(
                "%s %d" % [named[0], player.index + 1],
                player.rect,
                func() -> Rect2: return home,
                func() -> bool: return true,
                func(to: Vector2) -> void: control.position = to
            )

    var status := Rect2(_status_label.position, _status_label.size)
    _layout.add(
        "status",
        screen,
        func() -> Rect2: return status,
        func() -> bool: return _status_label.text != "",
        func(to: Vector2) -> void: _status_label.position = to
    )

    # NOTE (mristin):
    # The strip of the missing animals is small: it finds a gap the last.
    var slots := Rect2(_slots.position, _slots.size)
    _layout.add(
        "slots",
        screen,
        func() -> Rect2: return slots,
        func() -> bool: return not _slots.animals.is_empty(),
        func(to: Vector2) -> void: _slots.position = to
    )


## Add a hint of one line, centered in its label, as a piece only as big as
## its text.
func _add_hint(name: String, label: Label, bounds: Rect2) -> void:
    var home := label.position
    var text_size := func() -> Vector2:
        var font := label.get_theme_font("font")
        var font_size := label.get_theme_font_size("font_size")
        return Vector2(
            font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
            label.size.y
        )
    _layout.add(
        name,
        bounds,
        func() -> Rect2:
            var size: Vector2 = text_size.call()
            return Rect2(home + Vector2((label.size.x - size.x) * 0.5, 0.0), size),
        func() -> bool: return label.visible and label.text != "",
        func(to: Vector2) -> void:
            var size: Vector2 = text_size.call()
            label.position = to - Vector2((label.size.x - size.x) * 0.5, 0.0)
    )


## Glide the HUD out of the way of the riders, where they show on the screen.
func _give_way(delta: float) -> void:
    var riders: Array[Rect2] = []
    for player in _players:
        var at := (
            player.rider.position
            - player.center(map.size)
            + player.rect.size * 0.5
            + player.rect.position
        )
        riders.append(HudLayout.rider_rect(at))
    _layout.update(riders, delta)


## What keeps the HUD out of the riders' way, for the tests.
func hud() -> HudLayout:
    return _layout


## Put the control of the HUD at the rectangle, over the others (or at the
## index among them).
func _add(control: Control, rect: Rect2, at := -1) -> void:
    control.position = rect.position
    control.size = rect.size
    control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hud.add_child(control)
    if at >= 0:
        _hud.move_child(control, at)


## Render the views at the scale of the screen, so that the paintings keep
## their fine pixels.
func _fit_views() -> void:
    var scale := roundi(get_viewport().get_stretch_transform().get_scale().x)
    for player in _players:
        player.set_scale(maxi(1, scale))


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE:
                _quit_hint.press()
            KEY_C:
                var large := not _players[0].map_view.large
                for player in _players:
                    player.map_view.large = large
            KEY_R:
                get_tree().reload_current_scene()
            KEY_L:
                _next_language()
            KEY_ENTER, KEY_KP_ENTER:
                if finished:
                    _leave()


func _process(delta: float) -> void:
    if finished:
        _update_thanks(delta)
    for player in _players:
        _ride(player, delta)
    if _started and not finished:
        elapsed += delta

    _update_animals(delta)
    var others: Array = []
    for i in range(1, _players.size()):
        others.append([_players[i].rider.position, _players[i].rider.gait()])
    _wildlife.update(delta, _players[0].rider.position, _players[0].rider.gait(), others)
    _update_views()
    _give_way(delta)
    _update_hud()


## Ride the horse of the player for a moment: her squats, her brake and her
## reins, unless she talks to somebody.
func _ride(player: LevelPlayer, delta: float) -> void:
    var rider := player.rider
    # NOTE (mristin):
    # A tired horse walks however fast the player squats (see [HorseNeeds]),
    # so the gait is the slower of the squats and the horse.
    var gait: int = mini(_service.GetGait(player.index), rider.gait())
    if not finished:
        _update_conversation(player, delta, gait)

    var brakes: int = _service.GetBrakeCount(player.index)
    if brakes > player.brakes:
        player.brakes = brakes
        # NOTE (mristin):
        # A walking or trotting horse halts within a stride; only a galloping
        # one, stopped hard, rears up (the rider's gait is still the one
        # before the brake).
        if rider.gait() == 3:
            rider.rear()
    var standing := player.talking != null or finished
    # NOTE (mristin):
    # When the player jumps, her horse jumps, too.
    var jumps: int = _service.GetJumpCount(player.index)
    if jumps > player.jumps:
        player.jumps = jumps
        if not standing:
            rider.jump()
    var speed: float = 0.0 if standing else player.needs.cap(_service.GetSpeed(player.index))
    rider.ride(delta, speed, 0.0 if standing else _service.GetTurn(player.index))
    # NOTE (mristin):
    # The horse drinks and grazes only while it stands, by its own speed (e.g.,
    # in the air it flies on, whatever the player does).
    player.needs.update(
        delta,
        rider.speed / Rider.MAX_SPEED,
        map.at_fresh_water(rider.position),
        map.on_pasture(rider.position)
    )
    player.speed_bar.speed = speed
    if rider.speed > 0.0:
        _started = true

    # NOTE (mristin):
    # The edge of the steppe blocks the horse like a wall, and Grandmother's
    # word reminds the rider to stay near.
    player.edge_time = EDGE_SECONDS if rider.at_edge else maxf(0.0, player.edge_time - delta)
    note_bumps(delta, player.index)
    player.edge_label.visible = player.edge_time > 0.0
    player.edge_label.text = tr("Don't ride too far away!")

    if player.trail[player.trail.size() - 1].distance_to(rider.position) >= 3.0:
        player.trail.append(rider.position)
        if player.trail.size() > 1500:
            player.trail = player.trail.slice(500)
            player.trail_start += 500


## How many stars the ride earned so far: three within the par time of the
## level, two within twice as long, and one later.
func stars() -> int:
    if elapsed <= map.par_seconds:
        return 3
    if elapsed <= map.par_seconds * 2.0:
        return 2
    return 1


## How many players ride.
func players() -> int:
    return _players.size()


## The person the player talks to now, or null.
func talking_to(player := 0) -> Person:
    return _players[player].talking


## The clues which the riders heard so far.
func revealed() -> Array[Clue]:
    return _revealed


## The rider of the player.
func rider(player := 0) -> Rider:
    return _players[player].rider


## The animals which follow the rider of the player.
func followers(player := 0) -> Array[Animal]:
    return _players[player].followers


## The view and the HUD of the player, for the tests.
func view(player := 0) -> LevelPlayer:
    return _players[player]


## The wild creatures of the steppe.
func wildlife() -> Wildlife:
    return _wildlife


func _update_conversation(player: LevelPlayer, delta: float, gait: int) -> void:
    var squats: int = _service.GetSquatCount(player.index)
    if player.talking != null:
        player.talk_time += delta
        if player.talk_time >= TALK_SECONDS and squats > player.talk_squats:
            # NOTE (mristin):
            # The squat turns the page of a long talk, and closes the last.
            if player.conversation.next_page():
                player.talk_time = 0.0
                player.talk_squats = squats
                return
            player.talked_to = player.talking
            player.talking = null
            player.conversation.close()
        return

    if player.talked_to != null:
        if player.rider.position.distance_to(player.talked_to.position) > TALK_AGAIN_DISTANCE:
            player.talked_to = null

    if gait > 1:
        return
    for person in _people:
        if (
            person != player.talked_to
            and player.rider.position.distance_to(person.position) < TALK_DISTANCE
        ):
            _talk(player, person)
            return


## After Grandmother's thanks, the next squat of any rider goes on.
func _update_thanks(delta: float) -> void:
    _finish_time += delta
    for player in _players:
        player.talk_time = _finish_time
    if _finish_time < THANKS_SECONDS:
        return
    if _ok == null:
        _show_ok()
    for player in _players:
        if _service.GetSquatCount(player.index) > _finish_squats[player.index]:
            _leave()
            return


## Let the player talk to the person, in her own part of the screen; what
## the person tells goes on the maps of all the riders.
func _talk(player: LevelPlayer, person: Person) -> void:
    player.talking = person
    player.talk_time = 0.0
    player.talk_squats = _service.GetSquatCount(player.index)
    for clue in person.clues:
        if clue not in _revealed:
            _revealed.append(clue)
    _referred.erase(person)
    if person == _grandmother:
        for hint in map.referrals(person):
            var other: Person = hint["person"]
            if other not in _referred and not _people_talked.has(other):
                _referred.append(other)
    _people_talked[person] = true
    _show_conversation(player)


## Show (again, e.g., in another language) what the person says now to the
## player, by her name; shown again, the talk stays on its page.
func _show_conversation(player: LevelPlayer, again := false) -> void:
    if player.talking == null:
        return
    var page := player.conversation.page() if again else 0
    var rider_name: String = get_node("/root/Profile").rider_name(player.index)
    if _ok != null:
        _ok.text = tr("OK")
    var lines: Array[Dictionary] = []
    if finished:
        var rider := Grammar.verbatim(rider_name)
        lines.append({"text": Grammar.format(tr(map.thanks), {"rider": rider})})
        var icons: Array = []
        for i in range(3):
            var color := Color.WHITE if i < stars() else Color(0.2, 0.15, 0.1, 0.5)
            icons.append([Icons.star(2.0), color])
        lines.append({"icons": icons})
        lines.append({"text": tr("R: ride again · Esc: quit")})
    else:
        var rider := Grammar.verbatim(rider_name)
        lines.append({"text": Grammar.format(tr(player.talking.greeting), {"rider": rider})})
        for clue in player.talking.clues:
            lines.append({"icons": _clue_icons(clue), "text": map.clue_text(clue)})
        if player.talking == _grandmother:
            var hints := map.referrals(player.talking)
            if not hints.is_empty():
                lines.append({"text": tr("Ask the people of the steppe, too:")})
            for hint in hints:
                lines.append({"icons": _referral_icons(hint), "text": map.referral_text(hint)})
    player.conversation.open(
        Icons.portrait(player.talking.portrait), tr(player.talking.speaker), lines
    )
    if page > 0:
        player.conversation.turn_to(page)


## The pictures of a clue: the animals, then the landmarks.
func _clue_icons(clue: Clue) -> Array:
    var icons: Array = []
    for i in range(clue.count):
        icons.append([Icons.animal(clue.animal.id, 2.0), Color.WHITE])
    for landmark_name in [clue.landmark, clue.other]:
        var landmark := map.landmark(landmark_name)
        if landmark != null:
            icons.append([Icons.landmark(landmark.kind_id(), 2.0), Color.WHITE])
    return icons


## The pictures of Grandmother's hint whom to ask: the animals, the person
## and the landmark where they stand.
func _referral_icons(hint: Dictionary) -> Array:
    var clue: Clue = hint["clue"]
    var icons: Array = []
    for i in range(clue.count):
        icons.append([Icons.animal(clue.animal.id, 2.0), Color.WHITE])
    var who: Person = hint["person"]
    icons.append([Icons.portrait_icon(who.portrait, 2.0), Color.WHITE])
    var place: Landmark = hint["place"]
    if place != null:
        icons.append([Icons.landmark(place.kind_id(), 2.0), Color.WHITE])
    return icons


## The people whom Grandmother told the riders to ask, and whom they did not
## talk to yet.
func referred() -> Array[Person]:
    return _referred


func _update_animals(delta: float) -> void:
    var solids := map.solids()
    for animal in animals:
        match animal.state:
            Animal.State.LOST:
                _update_lost(animal, delta)
            Animal.State.ENTERING:
                # NOTE (mristin):
                # A follower who lags behind walks the rest of the trail of
                # its rider first, around the water, then into the pen.
                if not animal.path.is_empty():
                    var passed := animal.walk_along(animal.path, animal.kind.speed, delta)
                    animal.keep_out(solids)
                    animal.path = animal.path.slice(passed)
                    if (
                        animal.path.size() <= 1
                        and animal.position.distance_to(animal.path[0]) < 2.0
                    ):
                        animal.path = PackedVector2Array()
                elif animal.walk_to(animal.spot, animal.kind.speed, delta) < 2.0:
                    animal.state = Animal.State.HOME
            Animal.State.HOME:
                animal.graze(delta)

    var home := map.home()
    for player in _players:
        for i in range(player.followers.size()):
            # NOTE (mristin):
            # The followers walk along the trail of the rider, point by point,
            # so that one who lags behind goes around the water as she did,
            # instead of straight across it.
            var animal := player.followers[i]
            var behind := FOLLOW_SPACING * (i + 1)
            var way := player.trail_way(
                animal.crumb + 1, player.trail_index(behind), 16, player.trail_point(behind)
            )
            var passed := animal.walk_along(way, animal.kind.speed, delta)
            animal.crumb = maxi(animal.crumb, player.trail_start - 1) + passed
            animal.keep_out(solids)
            # NOTE (mristin):
            # A follower which fell far behind calls out, and keeps calling
            # until it caught up; it never gets lost.
            animal.lagging = (
                animal.position.distance_to(player.trail_point(behind)) > CALL_DISTANCE
            )
            if not animal.lagging:
                animal.call_wait = 0.0
                continue
            animal.call_wait -= delta
            if animal.call_wait <= 0.0:
                animal.call_wait = CALL_EVERY
                animal.call_out()
                get_node("/root/Sounds").play("call", _CALL_PITCH.get(animal.kind.id, 1.0))
        if (
            not player.followers.is_empty()
            and player.rider.position.distance_to(home.gate()) < GATE_DISTANCE
        ):
            var pen := home.pen().grow(-12.0)
            var end := player.trail_start + player.trail.size()
            for animal in player.followers:
                animal.state = Animal.State.ENTERING
                animal.lagging = false
                animal.path = player.trail_way(animal.crumb + 1, end - 1, end, home.gate())
                var spot := pen.position + Vector2(randf(), randf()) * pen.size
                animal.settle(spot.round(), 10.0)
            player.followers.clear()

    if not finished and animals.all(func(a: Animal) -> bool: return a.state == Animal.State.HOME):
        _finish()


## A lost animal flees from a rider who gallops at it, if it is shy, and
## joins the nearest rider who stays near it.
func _update_lost(animal: Animal, delta: float) -> void:
    var nearest: LevelPlayer = null
    var nearest_distance := INF
    for player in _players:
        var distance := animal.position.distance_to(player.rider.position)
        var gait: int = mini(_service.GetGait(player.index), player.rider.gait())
        if animal.kind.shy and gait >= 2 and distance < SCARE_DISTANCE:
            animal.flee_from(player.rider.position)
            animal.near_time = 0.0
            animal.graze(delta)
            return
        if distance < nearest_distance:
            nearest = player
            nearest_distance = distance
    if nearest != null and nearest_distance < Animal.JOIN_DISTANCE:
        animal.near_time += delta
        if animal.near_time >= Animal.JOIN_SECONDS:
            animal.state = Animal.State.FOLLOWING
            animal.crumb = nearest.nearest_on_trail(animal.position)
            animal.heart_time = Animal.HEART_SECONDS
            get_node("/root/Sounds").play("chime")
            nearest.followers.append(animal)
    else:
        animal.near_time = maxf(0.0, animal.near_time - delta)
    animal.graze(delta)


func _finish() -> void:
    finished = true
    get_node("/root/Sounds").play("tune")
    get_node("/root/Profile").finish_level(level_id(), stars())
    _finish_time = 0.0
    _finish_squats.clear()
    for player in _players:
        player.map_view.large = false
        player.talk_time = 0.0
        _finish_squats.append(_service.GetSquatCount(player.index))
        if _grandmother != null:
            player.talking = _grandmother
            _show_conversation(player)


## The id of the level (see [LevelList]).
func level_id() -> String:
    return LevelList.id(Flow.level if Flow.level != "" else map_scene.resource_path)


## Show the button OK after the thanks, which either rider presses with her
## hand (or the mouse) to go on, besides the squat.
func _show_ok() -> void:
    var layer := CanvasLayer.new()
    layer.layer = _hud.layer + 1
    add_child(layer)
    _ok = DwellButton.new()
    _ok.text = tr("OK")
    _ok.font_size = 32
    _ok.primary = true
    _ok.size = Vector2(200, 56)
    # NOTE (mristin):
    # With two players, the button stands in the middle, where both reach it,
    # below their conversations and between their riders.
    _ok.position = HALF_OK_AT if _players.size() > 1 else OK_AT
    _ok.pressed.connect(_leave)
    layer.add_child(_ok)
    var cursor := HandCursor.new()
    cursor.mirror = false
    layer.add_child(cursor)


## The button OK at the end of the level; null before it shows.
func ok_button() -> DwellButton:
    return _ok


## Go on to the reward after the end of the level.
func _leave() -> void:
    if _left:
        return
    _left = true
    Flow.reward(get_tree(), stars(), level_id())


## Let every view look at its rider, and the steppe draw what they show.
func _update_views() -> void:
    var seen: Array[Rect2] = []
    for player in _players:
        var view := player.view_transform(player.center(map.size))
        player.viewport.canvas_transform = view
        player.hearing.view = view
        seen.append(player.seen(map.size))
    _wildlife.views = seen


func _update_hud() -> void:
    for player in _players:
        _update_player_hud(player)
    _camera_panel.visible = _service.IsRunning()
    _status_label.text = VisionStatus.new().text(_service, false)


func _update_player_hud(player: LevelPlayer) -> void:
    var at := player.rider.position
    player.hearing.listen(animals, at)

    var map_view := player.map_view
    map_view.rider_at = at
    map_view.rider_heading = player.rider.heading
    map_view.has_partner = _players.size() > 1
    if map_view.has_partner:
        var partner := _players[1 - player.index].rider
        map_view.partner_at = partner.position
        map_view.partner_heading = partner.heading
    map_view.clues = _revealed
    map_view.people = _people
    map_view.referred = _referred
    for clue in _revealed:
        var herd := map.herd_of(clue)
        map_view.found[clue] = (
            herd != null
            and not animals.any(func(a: Animal) -> bool: return a.herd == herd and a.is_lost())
        )

    _update_coach(player, get_process_delta_time())


## Let the small figure do what the game understood of the player (see
## [Coach]): her squats, her reins, her brake and her jumps, from the camera
## or the keys; and know what the game waits for, as a hint over her head: a
## squat when the horse stands still or a conversation waits for one, the
## reins pulled after the edge of the steppe or the second run into the same
## obstacle, a jump at a creek.
func _update_coach(player: LevelPlayer, delta: float) -> void:
    var coach := player.coach
    coach.following = _service.IsRunning() and _service.HasPlayer(player.index)
    coach.jumping = _service.IsJumping(player.index)
    coach.live = Vector3(
        _service.GetSquatDepth(player.index),
        -float(_service.GetTurn(player.index)),
        1.0 if _service.IsBraking(player.index) else 0.0
    )
    player.still_time = player.still_time + delta if player.rider.speed <= 0.0 else 0.0
    var squats: int = _service.GetSquatCount(player.index)
    if squats > player.squats_seen:
        coach.echo()
    player.squats_seen = squats
    var jumps: int = _service.GetJumpCount(player.index)
    if jumps > player.jumps_seen and not coach.following:
        coach.echo_jump()
    player.jumps_seen = jumps
    var waiting := player.talk_time >= (THANKS_SECONDS if finished else TALK_SECONDS)
    if player.talking != null or finished:
        coach.mode = Coach.Mode.SQUAT if waiting else Coach.Mode.STAND
    elif player.jump_hint_time > 0.0:
        coach.mode = Coach.Mode.JUMP
    elif player.edge_time > 0.0 or player.turn_hint_time > 0.0:
        coach.mode = Coach.Mode.REACH
    elif player.still_time >= STILL_SECONDS:
        coach.mode = Coach.Mode.SQUAT
    else:
        coach.mode = Coach.Mode.STAND


## Count the runs of the player's rider into the obstacles: running into the
## same obstacle a second time shows how to turn (see section 5 of DESIGN.md);
## a touch counts once, until she leaves it.
func note_bumps(delta: float, index := 0) -> void:
    var player := _players[index]
    # NOTE (mristin):
    # At a creek, the horse must jump, not turn: the hint to jump shows at
    # once, and while she stays at it.
    if player.rider.at_creek():
        player.jump_hint_time = EDGE_SECONDS
    player.jump_hint_time = maxf(0.0, player.jump_hint_time - delta)
    var blocked := player.rider.blocked_by if player.rider.speed > 0.0 else -1
    if player.rider.at_creek():
        blocked = -1
    if blocked >= 0 and blocked != player.touching:
        player.bumps[blocked] = int(player.bumps.get(blocked, 0)) + 1
        if player.bumps[blocked] >= 2:
            player.turn_hint_time = EDGE_SECONDS
    player.touching = blocked
    player.turn_hint_time = maxf(0.0, player.turn_hint_time - delta)


## Whether the hint to turn shows for the player, after her rider ran into
## the same obstacle twice.
func turn_hint(player := 0) -> bool:
    return _players[player].turn_hint_time > 0.0


## What the small figure of the player next to the camera picture does now.
func coach_mode(player := 0) -> Coach.Mode:
    return _players[player].coach.mode


func _next_language() -> void:
    var languages := get_node("/root/Languages")
    var codes: Array[String] = languages.codes()
    var index := codes.find(languages.current())
    languages.choose(codes[(index + 1) % codes.size()])
    for player in _players:
        _show_conversation(player, true)
