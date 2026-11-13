extends RefCounted
## Keep the problems which the contracts of the game find (see
## screen_contracts.gd and level_contracts.gd):
## each once, with its first example and how often it happened; a problem
## of the layout of a level counts only if it lasts (see [method _lasting]).
## Also the checks which the screens and the levels share: the texts, the
## hand cursor, what draws over what, what outlives the screens (no leaks),
## the sounds, and the vision as the game uses it.
##
## Not a test itself (its name does not start with test_), it is preloaded by
## the tests.

const Layout := preload("res://tests/godot/layout.gd")

## How long a problem of the layout of a level may last, in seconds of the
## game.
const GRACE_SECONDS := HudLayout.GLIDE_SECONDS + 0.8

## The font sizes step by this many logical pixels: Unifont has glyphs of 16
## px, drawn at [constant Pixelate.DENSITY] pixels of the screen per logical
## pixel.
const _FONT_STEP := 8

## The autoloads of the game (see project.godot): besides them, the tree
## holds only the current screen.
const _AUTOLOADS: Array[String] = ["Languages", "Profile", "Sounds", "Vision"]

## The keys which the bots press in a level (see rider_bot.gd and
## playthrough.gd); none stays down off the level.
const _LEVEL_KEYS: Array[Key] = [
    KEY_W,
    KEY_A,
    KEY_S,
    KEY_D,
    KEY_J,
    KEY_SPACE,
    KEY_UP,
    KEY_DOWN,
    KEY_LEFT,
    KEY_RIGHT,
    KEY_KP_0,
    KEY_ESCAPE,
    KEY_ENTER,
    KEY_KP_ENTER,
    KEY_R,
    KEY_C,
    KEY_L,
]

## The problems found, by their key, each with its first example and how
## often it happened.
var _found := {}

## Since when each problem of the layout of a level lasts, by its key.
var _since := {}

var _checks := 0

## A placeholder left in a text, e.g., "{rider}" or "{landmark@near}" (see
## [Grammar]).
var _placeholder := RegEx.create_from_string("\\{[A-Za-z_][^{}]*\\}")

## How many nodes the autoloads hold, and how many connections to the size of
## the window there are off the levels, as the first check saw them.
var _autoload_nodes := -1
var _size_connections := -1


## The problems found, one message for each.
func violations() -> Array[String]:
    var result: Array[String] = []
    for key in _found:
        var found: Dictionary = _found[key]
        result.append("%s (%d times), e.g., %s" % [key, found["count"], found["example"]])
    return result


## How many times the contracts were checked.
func checks() -> int:
    return _checks


func _report(key: String, example: String) -> void:
    if not _found.has(key):
        _found[key] = {"count": 0, "example": example}
        print("CONTRACT ", key, ": ", example)
    _found[key]["count"] += 1


## Report the elements which overlap now: at once, or (with [param now] in
## seconds of the game) when they overlapped for longer than [constant
## GRACE_SECONDS].
func _overlaps(
    items: Array[Dictionary], allowed: Array, tag: String, where: String, now: float
) -> Dictionary:
    var seen := {}
    for i in range(items.size()):
        for j in range(i + 1, items.size()):
            var problems := Layout.overlaps([items[i], items[j]], allowed)
            if problems.is_empty():
                continue
            var names := [Layout.describe(items[i]["node"]), Layout.describe(items[j]["node"])]
            names.sort()
            var key := "%s: %s overlaps %s" % [tag, names[0], names[1]]
            if now < 0.0:
                _report(key, where + ": " + problems[0])
            else:
                seen[key] = where + ": " + problems[0]
    return seen


## The problem lasts: report it once it lasted for longer than [constant
## GRACE_SECONDS].
func _lasting(seen: Dictionary, now: float) -> void:
    for key in seen:
        if not _since.has(key):
            _since[key] = now
        elif now - _since[key] > GRACE_SECONDS:
            _report(key, seen[key])
    for key in _since.keys():
        if not seen.has(key):
            _since.erase(key)


## The kind of the node, for the keys of the problems (the names of the nodes
## of the HUD are made up, e.g., "@Control@26").
static func _kind(node: Node) -> String:
    var script := node.get_script() as Script
    if script != null and script.get_global_name() != "":
        return script.get_global_name()
    return node.get_class()


static func _layer_of(node: Node) -> int:
    var at := node.get_parent()
    while at != null:
        if at is CanvasLayer:
            return (at as CanvasLayer).layer
        at = at.get_parent()
    return 0


static func _z_of(item: CanvasItem) -> int:
    var z := item.z_index
    var at := item
    while at.z_as_relative and at.get_parent() is CanvasItem:
        at = at.get_parent() as CanvasItem
        z += at.z_index
    return z


## Whether the item draws over the other: on a higher layer, at a higher z,
## or later in the tree.
static func _draws_over(item: CanvasItem, other: CanvasItem) -> bool:
    if _layer_of(item) != _layer_of(other):
        return _layer_of(item) > _layer_of(other)
    if _z_of(item) != _z_of(other):
        return _z_of(item) > _z_of(other)
    return item.is_greater_than(other)


## The texts shown under the node: no placeholder left unfilled (see
## [Grammar]), and all in Unifont at a size of whole pixels (see [constant
## _FONT_STEP]).
func _check_texts(under: Node, tag: String, where: String) -> void:
    for node in under.find_children("*", "Control", true, false):
        var control := node as Control
        if not control.is_visible_in_tree():
            continue
        var text := ""
        var font: Font = null
        var size := 0
        if control is Label:
            text = control.atr((control as Label).text)
            font = control.get_theme_font("font")
            size = control.get_theme_font_size("font_size")
        elif control is DwellButton:
            text = (control as DwellButton).text
            font = control.get_theme_default_font()
            size = (control as DwellButton).font_size
        else:
            continue
        if text == "":
            continue
        var what := "%s: %s" % [where, Layout.describe(control)]
        if _placeholder.search(text) != null:
            _report("%s: a text shows a placeholder" % tag, what)
        if not font.resource_path.contains("unifont") or size % _FONT_STEP != 0:
            _report(
                "%s: a text is not in Unifont at whole pixels" % tag,
                "%s, %s at %d" % [what, font.resource_path, size]
            )


## A screen with buttons to press has exactly one hand cursor, which draws
## over all of them (see section 5 of DESIGN.md).
func _check_cursor(screen: Node, tag: String, where: String) -> void:
    var buttons: Array[DwellButton] = []
    for node in screen.find_children("*", "DwellButton", true, false):
        var button := node as DwellButton
        if button.is_visible_in_tree() and not button.disabled:
            buttons.append(button)
    if buttons.is_empty():
        return
    var cursors := screen.find_children("*", "HandCursor", true, false)
    if cursors.size() != 1 or not (cursors[0] as HandCursor).is_visible_in_tree():
        _report(
            "%s: not exactly one hand cursor over the buttons" % tag,
            "%s: %d cursors" % [where, cursors.size()]
        )
        return
    for button in buttons:
        if not _draws_over(cursors[0] as CanvasItem, button):
            _report(
                "%s: the hand cursor draws under a button" % tag,
                "%s: %s" % [where, Layout.describe(button)]
            )


## What outlives the screens: the tree holds the autoloads and the current
## screen only, nothing is left of the screens before it (no level, hand
## cursor, layer or button), no node is out of the tree (an orphan, which
## leaks), the autoloads keep their nodes, and no screen leaves a connection
## to the size of the window behind (a level connects one, see
## [method Level._ready]).
func _check_tree(scene: Node, tag: String, in_level: bool) -> void:
    var tree := scene.get_tree()
    var root := tree.root
    var extra: Array[String] = []
    for child in root.get_children():
        if child != tree.current_scene and String(child.name) not in _AUTOLOADS:
            extra.append("%s (%s)" % [child.name, child.get_class()])
    if tree.current_scene != scene or not extra.is_empty():
        _report(
            "%s: the tree holds more than the autoloads and the screen" % tag,
            "%s: the current scene %s, also %s" % [tag, tree.current_scene, extra]
        )
    for kind in ["Level", "HandCursor", "CanvasLayer", "DwellButton"]:
        for node in root.find_children("*", kind, true, false):
            if node != scene and not scene.is_ancestor_of(node):
                _report(
                    "%s: a %s is left outside the screen" % [tag, kind],
                    "%s: %s" % [tag, node.get_path()]
                )
    var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
    var nodes := 0
    for autoload in _AUTOLOADS:
        nodes += 1 + root.get_node(autoload).find_children("*", "", true, false).size()
    if _autoload_nodes < 0:
        _autoload_nodes = nodes
    if orphans != 0 or nodes != _autoload_nodes:
        _report(
            "%s: nodes leak" % tag,
            (
                "%s: %d orphans, %d nodes in the autoloads (at first %d)"
                % [tag, orphans, nodes, _autoload_nodes]
            )
        )
    if in_level:
        return
    var connections := root.get_signal_connection_list("size_changed").size()
    if _size_connections < 0:
        _size_connections = connections
    if connections != _size_connections:
        _report(
            "%s: a screen left a connection to the size of the window" % tag,
            "%s: %d connections (at first %d)" % [tag, connections, _size_connections]
        )


## The sounds (see the autoload Sounds): the music plays all the time, the wind
## exactly in a level, and both are silent exactly while the sound is off,
## which silences every other sound, too; the players of the sounds do not
## pile up; and the sound is on or off as the settings saved it.
func _check_sounds(scene: Node, tag: String, in_level: bool) -> void:
    var sounds := scene.get_node("/root/Sounds")
    var on: bool = sounds.enabled
    var music: AudioStreamPlayer = sounds._music
    var wind: AudioStreamPlayer = sounds._wind
    var players: Array[AudioStreamPlayer] = sounds._players
    var state := (
        "%s: the sound on %s, the music playing %s (paused %s), the wind %s (paused %s)"
        % [tag, on, music.playing, music.stream_paused, wind.playing, wind.stream_paused]
    )
    if not music.playing or music.stream_paused == on:
        _report("%s: the music does not play exactly while the sound is on" % tag, state)
    if wind.playing != in_level or (in_level and wind.stream_paused == on):
        _report("%s: the wind does not blow exactly in a level with the sound on" % tag, state)
    if players.size() != 6 or sounds.get_child_count() != players.size() + 2:
        _report(
            "%s: the players of the sounds pile up" % tag,
            "%s: %d players, %d children" % [tag, players.size(), sounds.get_child_count()]
        )
    if not on and players.any(func(p: AudioStreamPlayer) -> bool: return p.playing):
        _report("%s: a sound plays while the sound is off" % tag, state)
    var saved := ConfigFile.new()
    var stored := true
    if saved.load(scene.get_node("/root/Languages").settings_path()) == OK:
        stored = bool(saved.get_value("general", "sound", true))
    if stored != on:
        _report(
            "%s: the sound is not as the settings saved it" % tag,
            "%s: on %s, saved %s" % [tag, on, stored]
        )


## The vision as the game uses it (see VisionService.cs): it counts the
## players who ride (with [param players] > 0); without a camera it is
## disabled; the speed stays in [0, 1], the turn in [-1, 1], and the gait is
## the one of the speed by [method GetGaitThresholds].
func _check_vision(scene: Node, tag: String, players: int) -> void:
    var service: Node = scene.get_node("/root/Vision").service
    if players > 0 and service.GetPlayerCount() != players:
        _report(
            "%s: the vision counts other players than ride" % tag,
            "%s: the vision %d, the riders %d" % [tag, service.GetPlayerCount(), players]
        )
    if (
        "--no-camera" in OS.get_cmdline_user_args()
        and (service.GetStatus() != "Disabled" or service.IsRunning())
    ):
        _report("%s: the vision runs without a camera" % tag, "%s: %s" % [tag, service.GetStatus()])
    var thresholds: Vector3 = service.GetGaitThresholds()
    for i in range(2):
        var speed: float = service.GetSpeed(i)
        var turn: float = service.GetTurn(i)
        var gait := 0
        for k in range(3):
            if speed >= thresholds[k]:
                gait = k + 1
        if speed < 0.0 or speed > 1.0 or turn < -1.0 or turn > 1.0:
            _report(
                "%s: the speed or the turn of the vision is out of its range" % tag,
                "%s, the player %d: the speed %f, the turn %f" % [tag, i + 1, speed, turn]
            )
        if service.GetGait(i) != gait:
            _report(
                "%s: the gait of the vision is not the one of its speed" % tag,
                (
                    "%s, the player %d: the gait %d at the speed %f, the thresholds %s"
                    % [tag, i + 1, service.GetGait(i), speed, thresholds]
                )
            )


## Off the level, the riding rests: no key of the level stays down (see
## keys.gd), and the vision neither brakes nor turns; the room around the
## player is asked only with a camera (see [method Flow.next]).
func _check_resting(screen: Node, tag: String) -> void:
    for key in _LEVEL_KEYS:
        if Input.is_key_pressed(key):
            _report(
                "%s: a key stays down off the level" % tag,
                "%s: %s" % [tag, OS.get_keycode_string(key)]
            )
    var service: Node = screen.get_node("/root/Vision").service
    for i in range(2):
        if service.IsBraking(i) or service.GetTurn(i) != 0.0:
            _report(
                "%s: the vision brakes or turns off the level" % tag,
                (
                    "%s, the player %d: braking %s, the turn %f"
                    % [tag, i + 1, service.IsBraking(i), service.GetTurn(i)]
                )
            )
    if screen is FreeSpace and service.GetStatus() == "Disabled":
        _report("%s: the room is asked without a camera" % tag, tag)


## A level is played only where the flow leads to it (see [Flow]): the way
## from Play is over, the level is open in the journey, the journey was
## chosen and has its riders, who saw How to Play; the camera panel shows
## exactly while the camera runs.
func _check_level_life(level: Level, tag: String) -> void:
    var profile := level.get_node("/root/Profile")
    var problems: Array[String] = []
    if Flow.playing or Flow.choosing:
        problems.append(
            "still on the way (playing %s, choosing %s)" % [Flow.playing, Flow.choosing]
        )
    if Flow.level == "" or not LevelList.is_open(Flow.level, profile):
        problems.append("the level %s is not open" % JSON.stringify(Flow.level))
    if not Flow.session_asked or profile.session_id == "":
        problems.append("no journey chosen")
    elif not profile.has_riders() or not profile.has_seen_instruction:
        problems.append("the riders are missing or did not see How to Play")
    for problem in problems:
        _report("%s: a level is played where the flow does not lead: %s" % [tag, problem], tag)
    var service: Node = level.get_node("/root/Vision").service
    if level.get_node("Hud/CameraPanel").visible != service.IsRunning():
        _report("%s: the camera panel shows, but the camera does not run" % tag, tag)
