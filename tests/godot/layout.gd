extends RefCounted
## Check the layout of what a screen shows, for the tests of the layout: that
## every text fits where it is written, and that no two elements overlap.
##
## An element is what the player sees as one thing: the text of a label (only
## as wide and high as its letters, not its whole box), a button, a picture,
## and the custom controls which the caller adds with their rectangles (e.g.,
## the speed bar). Two elements overlap if their rectangles share more than
## [constant TOLERANCE] pixels both ways; an element never overlaps the
## elements inside it (e.g., a button and the text on it), nor the ones listed
## as allowed to (e.g., a panel and what stands on it).
##
## Not a test itself (its name does not start with test_), it is preloaded by
## the tests.

## The screen, in logical pixels.
const SCREEN := Rect2(0, 0, 960, 540)

## Elements may touch by this many pixels, e.g., the outlines of the letters.
const TOLERANCE := 1.0

## A button writes its text this far from its sides (see [DwellButton]).
const _BUTTON_PADDING := 4.0

## The opaque part of each painted horse from above, by its steed, in logical
## pixels around the seat of the saddle, facing north (see [method
## horse_extent]).
static var _horse_extents := {}


## The rectangle on the screen which the letters of the label cover; an empty
## rectangle if the label shows no text.
static func text_rect(label: Label) -> Rect2:
    var result := Rect2()
    var started := false
    var shown := label.text.length()
    if label.visible_characters >= 0:
        shown = mini(shown, label.visible_characters)
    for i in range(shown):
        if label.text[i] in [" ", "\n", "\t"]:
            continue
        var bounds := label.get_character_bounds(i)
        if bounds.size == Vector2.ZERO:
            continue
        result = bounds if not started else result.merge(bounds)
        started = true
    if not started:
        return Rect2()
    return label.get_global_transform() * result


## The rectangle of the control on the screen.
static func global_rect(control: Control) -> Rect2:
    return control.get_global_transform() * Rect2(Vector2.ZERO, control.size)


## A short name of the node for the messages, e.g., "Label 'Play'".
static func describe(node: Node) -> String:
    var kind := node.get_class()
    var script := node.get_script() as Script
    if script != null and script.get_global_name() != "":
        kind = script.get_global_name()
    var text := ""
    if node is Label:
        text = (node as Label).text
    elif node is DwellButton:
        text = (node as DwellButton).text
    if text != "":
        return "%s %s" % [kind, JSON.stringify(text.replace("\n", " ").left(48))]
    return "%s %s" % [kind, node.name]


## The elements under the node which show now, as dictionaries with "node"
## and "rect" (on the screen), except those within [param skip]. Labels count
## by their letters; buttons and pictures by their whole rectangles; other
## nodes only when listed in [param extra] (a dictionary of the node to its
## rectangle on the screen), whether they show or not.
static func elements(under: Node, extra := {}, skip: Array = []) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var nodes: Array[Node] = [under]
    nodes.append_array(under.find_children("*", "Control", true, false))
    for node in nodes:
        var control := node as Control
        if control == null or extra.has(control) or not control.is_visible_in_tree():
            continue
        if skip.any(func(other: Node) -> bool: return _within(control, other)):
            continue
        if control.modulate.a <= 0.0 or control.self_modulate.a <= 0.0:
            continue
        var rect := Rect2()
        if control is Label:
            rect = text_rect(control as Label)
        elif control is DwellButton:
            rect = global_rect(control)
        elif control is TextureRect and (control as TextureRect).texture != null:
            rect = global_rect(control)
        if rect.has_area():
            result.append({"node": control, "rect": rect})
    for node in extra:
        var rect: Rect2 = extra[node]
        if rect.has_area():
            result.append({"node": node, "rect": rect})
    return result


## What does not fit: the texts of the buttons wider or higher than the
## buttons, the labels which cut their text off, and the elements which stand
## out of [param bounds] (the screen, or the player's half of it).
static func overflows(items: Array[Dictionary], bounds := SCREEN) -> Array[String]:
    var problems: Array[String] = []
    for item in items:
        var node: Node = item["node"]
        var rect: Rect2 = item["rect"]
        if not bounds.grow(TOLERANCE).encloses(rect):
            problems.append("%s at %s stands out of %s" % [describe(node), rect, bounds])
        if node is DwellButton:
            problems.append_array(_button_overflows(node as DwellButton))
        elif node is Label:
            problems.append_array(_label_overflows(node as Label))
    return problems


static func _button_overflows(button: DwellButton) -> Array[String]:
    var problems: Array[String] = []
    if button.text == "":
        return problems
    var font := button.get_theme_default_font()
    var left := button.text_left if button.text_left > 0.0 else _BUTTON_PADDING
    var room := button.size.x - left - _BUTTON_PADDING
    var lines := button.text.split("\n")
    var width := 0.0
    for line in lines:
        width = maxf(
            width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, button.font_size).x
        )
    if width > room + TOLERANCE:
        problems.append(
            (
                "%s: the text is %d px wide, but the button has room for %d"
                % [describe(button), width, room]
            )
        )
    var height := font.get_height(button.font_size) * lines.size()
    if button.picture != null:
        height += button.picture.get_height() + 2.0
    if height > button.size.y + TOLERANCE:
        problems.append(
            (
                "%s: the content is %d px high, but the button only %d"
                % [describe(button), height, button.size.y]
            )
        )
    return problems


static func _label_overflows(label: Label) -> Array[String]:
    var problems: Array[String] = []
    if label.get_visible_line_count() < label.get_line_count():
        problems.append(
            (
                "%s shows only %d of its %d lines"
                % [describe(label), label.get_visible_line_count(), label.get_line_count()]
            )
        )
    if label.clip_text or label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
        if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
            var font := label.get_theme_font("font")
            var size := label.get_theme_font_size("font_size")
            var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
            if width > label.size.x + TOLERANCE:
                problems.append(
                    "%s is cut off: %d px of text in %d px" % [describe(label), width, label.size.x]
                )
    return problems


## Whether the node is the other node or inside it.
static func _within(node: Node, other: Node) -> bool:
    return node == other or other.is_ancestor_of(node)


## The elements under the [param panel] (e.g., the lines of a conversation)
## which stand out of its rectangle on the screen.
static func outside(items: Array[Dictionary], panel: Node, rect: Rect2) -> Array[String]:
    var problems: Array[String] = []
    for item in items:
        var node: Node = item["node"]
        if node == panel or not _within(node, panel):
            continue
        if not rect.grow(TOLERANCE).encloses(item["rect"]):
            problems.append(
                (
                    "%s at %s stands out of %s at %s"
                    % [describe(node), item["rect"], describe(panel), rect]
                )
            )
    return problems


## The pairs of elements which overlap, except those inside one another, and
## those of [param allowed]: an array of pairs of nodes, where a node also
## stands for everything inside it.
static func overlaps(items: Array[Dictionary], allowed: Array = []) -> Array[String]:
    var problems: Array[String] = []
    for i in range(items.size()):
        for j in range(i + 1, items.size()):
            var a: Node = items[i]["node"]
            var b: Node = items[j]["node"]
            if _within(a, b) or _within(b, a):
                continue
            var skip := false
            for pair in allowed:
                if (
                    (_within(a, pair[0]) and _within(b, pair[1]))
                    or (_within(a, pair[1]) and _within(b, pair[0]))
                ):
                    skip = true
                    break
            if skip:
                continue
            var common: Rect2 = (items[i]["rect"] as Rect2).intersection(items[j]["rect"])
            if common.size.x > TOLERANCE and common.size.y > TOLERANCE:
                problems.append(
                    (
                        "%s at %s overlaps %s at %s"
                        % [describe(a), items[i]["rect"], describe(b), items[j]["rect"]]
                    )
                )
    return problems


## The rectangle of the strip of the missing animals at the top of a level
## (see [Slots]).
static func slots_rect(slots: Slots) -> Rect2:
    if slots.animals.is_empty():
        return Rect2()
    var icon := Icons.SIZE * 2.0
    var width := slots.animals.size() * (icon.x + 6.0) - 6.0
    var left := roundf((slots.size.x - width) * 0.5)
    return Rect2(
        slots.global_position + Vector2(left - 4.0, 0.0), Vector2(width + 8.0, icon.y + 6.0)
    )


## The HUD of the level, besides its texts, buttons and pictures: the panels
## which draw themselves, for [method elements]. The camera picture counts
## even while the camera is off, since it shows with the camera.
static func hud_extra(level: Level) -> Dictionary:
    var extra := {}
    var slots: Slots = level.get_node("Hud/Slots")
    extra[slots] = slots_rect(slots)
    var panel: Control = level.get_node("Hud/CameraPanel")
    extra[panel] = global_rect(panel)
    for i in range(level.players()):
        var view := level.view(i)
        for control in [view.speed_bar, view.needs_bars, view.map_view, view.coach]:
            if control.is_visible_in_tree():
                extra[control] = global_rect(control)
        if view.conversation.is_visible_in_tree():
            extra[view.conversation] = global_rect(view.conversation)
    return extra


## What of the level is not its HUD, for [method elements]: the views of the
## steppe, and the sounds heard at the edges of the views (see [Hearing]),
## which are faint marks meant to be seen over anything.
static func hud_skip(level: Level) -> Array:
    var skip: Array = [level.get_node("Views")]
    for i in range(level.players()):
        skip.append(level.view(i).hearing)
    return skip


## The opaque part of the painted horse, as drawn (see
## [method PaintedTopDown.draw_rider]): the frames of its run at half their
## size, a bit wider, around the seat.
static func horse_extent(steed: String) -> Rect2:
    if _horse_extents.has(steed):
        return _horse_extents[steed]
    var result := Rect2()
    for frame in range(PaintedTopDown.HORSE_FRAMES):
        var path := "res://assets/pictures/top_down/horses/%s/%d.png" % [steed, frame]
        var image := Image.load_from_file(ProjectSettings.globalize_path(path))
        if image == null:
            continue
        var used := Rect2(image.get_used_rect())
        used.position -= Vector2(image.get_size()) * 0.5
        var scale := Vector2(0.5 * PaintedTopDown.HORSE_WIDTH, 0.5)
        var drawn := Rect2(used.position * scale, used.size * scale)
        result = drawn if not result.has_area() else result.merge(drawn)
    _horse_extents[steed] = result
    return result


## Where the rider of the player shows on the screen: the rectangle around
## her horse, turned to her heading.
static func rider_on_screen(level: Level, player: int) -> Rect2:
    var view := level.view(player)
    var rider := view.rider
    var at := (
        rider.position - view.center(level.map.size) + view.rect.size * 0.5 + view.rect.position
    )
    var extent := horse_extent(rider.looks.get("steed", "1"))
    var corners := [
        extent.position,
        Vector2(extent.end.x, extent.position.y),
        extent.end,
        Vector2(extent.position.x, extent.end.y),
    ]
    var result := Rect2(at + (corners[0] as Vector2).rotated(rider.heading), Vector2.ZERO)
    for corner in corners:
        result = result.expand(at + (corner as Vector2).rotated(rider.heading))
    return result
