class_name LevelSelect
extends Control

## Let the player choose a level (see section 6 of DESIGN.md): the painted map
## of the steppe around the home aul (see [SteppeMap]), where the rider stands
## by the yurts and the path winds past the numbered spot of each level, and
## the list of all the levels at the left, one row each, with its number, its
## name and the stars she won. The next level to play is crimson. The levels
## not open yet are listed, too, dim and locked, with a stone on their spot;
## finishing a level opens the next one (see [LevelList]). The row which the
## hand or the mouse points at rings its spot on the map.
##
## Keys: Enter plays the next level, Escape goes back.

## Each row of the list is this big...
const ROW := Vector2(300, 40)

## ... and this far below the one before.
const ROW_STEP := 44.0

## The list starts here.
const LIST := Vector2(16, 16)

## The riders of the journey with their horses stand at this share of their
## size at home (see [method Reward.draw_pair]), this far apart with two
## players.
const PAIR_SCALE := 0.3
const PAIR_APART := 96.0

## The name in a row starts this far from its left, after the number.
const _TEXT_LEFT := 40.0

var _rows: Array[DwellButton] = []
var _paths: Array[String] = []
var _back: DwellButton
var _next := ""
var _marks: _Marks


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    var profile := get_node("/root/Profile")
    _next = LevelList.next(profile)
    var all := LevelList.paths()
    for i in range(mini(all.size(), SteppeMap.SPOTS.size())):
        var path: String = all[i]
        _paths.append(path)
        var row := DwellButton.new()
        row.position = LIST + Vector2(0, i * ROW_STEP)
        row.size = ROW
        row.text_left = _TEXT_LEFT
        row.primary = path == _next
        row.disabled = not LevelList.is_open(path, profile)
        if row.disabled:
            # NOTE (mristin):
            # A locked row stays solid, only darker, so that its name reads
            # well over the map.
            row.modulate = Color(0.72, 0.68, 0.64)
        row.pressed.connect(func() -> void: Flow.play(get_tree(), path))
        add_child(row)
        _rows.append(row)

    _back = DwellButton.new()
    _back.position = Vector2(24, 476)
    _back.size = Vector2(150, 44)
    _back.pressed.connect(func() -> void: Flow.cancel(get_tree()))
    add_child(_back)

    _marks = _Marks.new()
    _marks.select = self
    add_child(_marks)

    add_child(HandCursor.new())
    _update_texts()


func _process(_delta: float) -> void:
    queue_redraw()
    _marks.queue_redraw()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _back != null:
        _update_texts()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE:
                Flow.cancel(get_tree())
            KEY_ENTER, KEY_KP_ENTER:
                if _next != "":
                    Flow.play(get_tree(), _next)


## The rows of the levels in their order, for the tests; the rows of the
## levels not open yet are disabled.
func rows() -> Array[DwellButton]:
    return _rows


## The paths of the levels of the rows.
func paths() -> Array[String]:
    return _paths


## Whether the level of the row is open.
func is_open(index: int) -> bool:
    return not _rows[index].disabled


## The index of the row which the hand or the mouse points at; -1 if none.
func hovered_row() -> int:
    for i in range(_rows.size()):
        if _rows[i].hovered():
            return i
    return -1


func _update_texts() -> void:
    for i in range(_rows.size()):
        _rows[i].text = tr(LevelList.title(_paths[i]))
    _back.text = tr("Back")


func _draw() -> void:
    draw_texture(SteppeMap.texture(_paths.size()), Vector2.ZERO)

    # NOTE (mristin):
    # The riders of the journey stand next to the aul with their horses,
    # dressed in the finery they wear (see section 8 of DESIGN.md), side by
    # side with two players.
    var profile := get_node("/root/Profile")
    var count: int = clampi(profile.players, 1, 2)
    for i in range(count):
        var feet := SteppeMap.AUL + Vector2(220.0 + (i - (count - 1) * 0.5) * PAIR_APART, 50.0)
        Reward.draw_pair(
            self,
            profile.rider(i).dressed(),
            feet + Vector2(-100, 6) * PAIR_SCALE,
            feet + Vector2(40, -14) * PAIR_SCALE,
            PAIR_SCALE
        )

    # NOTE (mristin):
    # The ring around the spot of the row pointed at, pulsing, under the spots.
    var pointed := hovered_row()
    if pointed >= 0:
        var spot: Vector2 = SteppeMap.SPOTS[pointed]
        var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.2)
        var color := Palette.GOLD if is_open(pointed) else Palette.STONE_LIGHT
        draw_circle(spot, 15.0 + 3.0 * pulse, Color(color, 0.35), true, -1.0, true)
        draw_circle(spot, 15.0 + 3.0 * pulse, color, false, 2.0, true)

    for i in range(_paths.size()):
        draw_number(self, SteppeMap.SPOTS[i], i, 9.0)


## Draw over the rows of the list: the number of each level at its left, and
## its stars (or a lock, if it is not open yet) at its right.
class _Marks:
    extends Control

    var select: LevelSelect

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        set_anchors_preset(Control.PRESET_FULL_RECT)

    func _draw() -> void:
        var profile := get_node("/root/Profile")
        var star := Icons.star(1.0)
        for i in range(select.rows().size()):
            var row := select.rows()[i]
            var rect := Rect2(row.position, row.size)
            var middle := rect.get_center().y
            select.draw_number(self, Vector2(rect.position.x + 20.0, middle), i, 11.0)
            var won: int = profile.stars.get(LevelList.id(select.paths()[i]), 0)
            if not select.is_open(i) and won == 0:
                _draw_lock(Vector2(rect.end.x - 22.0, middle))
                continue
            for s in range(3):
                var at := Vector2(rect.end.x - 56.0 + s * 15.0, middle - star.get_height() * 0.5)
                var tint := Color.WHITE if s < won else Color(0.25, 0.2, 0.15, 0.45)
                draw_texture(star, at.round(), tint)

    ## A small padlock, its middle at the point.
    func _draw_lock(at: Vector2) -> void:
        draw_arc(at + Vector2(0, -3), 5.0, PI, TAU, 12, Palette.OUTLINE, 4.0, true)
        draw_arc(at + Vector2(0, -3), 5.0, PI, TAU, 12, Palette.STONE_LIGHT, 2.0, true)
        var body := Rect2(at + Vector2(-7, -3), Vector2(14, 11))
        draw_rect(body.grow(1.0), Palette.OUTLINE)
        draw_rect(body, Palette.STONE)
        draw_rect(Rect2(at + Vector2(-1, 0), Vector2(2, 4)), Palette.OUTLINE)


## Draw the number of the level in a medallion on the canvas item (the map
## or the marks over the rows): crimson if open, else a stone.
func draw_number(item: CanvasItem, at: Vector2, index: int, radius: float) -> void:
    var open := is_open(index)
    var fill := Palette.CRIMSON if open else Palette.STONE
    item.draw_circle(at, radius + 2.0, Palette.OUTLINE, true, -1.0, true)
    item.draw_circle(at, radius, fill, true, -1.0, true)
    item.draw_circle(at, radius, Palette.GOLD if open else Palette.STONE_LIGHT, false, 1.0, true)
    var font := get_theme_default_font()
    var number := str(index + 1)
    var width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
    item.draw_string(
        font,
        Vector2(at.x - width * 0.5, at.y - 8 + font.get_ascent(16)).round(),
        number,
        HORIZONTAL_ALIGNMENT_LEFT,
        -1,
        16,
        Palette.FELT
    )
