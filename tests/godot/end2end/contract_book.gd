extends RefCounted
## Keep the problems which the contracts of the game find (see
## screen_contracts.gd and level_contracts.gd):
## each once, with its first example and how often it happened; a problem
## of the layout of a level counts only if it lasts (see [method _lasting]).
## Also the checks which the screens and the levels share: the texts, the
## hand cursor, and what draws over what.
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

## The problems found, by their key, each with its first example and how
## often it happened.
var _found := {}

## Since when each problem of the layout of a level lasts, by its key.
var _since := {}

var _checks := 0

## A placeholder left in a text, e.g., "{rider}" or "{landmark@near}" (see
## [Grammar]).
var _placeholder := RegEx.create_from_string("\\{[A-Za-z_][^{}]*\\}")


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
