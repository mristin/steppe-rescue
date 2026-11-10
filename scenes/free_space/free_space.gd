class_name FreeSpace
extends Control

## Ask the player for a free space of about 2 × 2 m around her before she
## rides (see section 5 of DESIGN.md, "Safety"): the rider stands on a square
## of floor, marked 2 m wide and 2 m deep, and squats and pulls the reins on it,
## to show how much room the riding needs; one short line says it in words.
## It shows once each time the game starts, before the first level, while
## the camera is on (with the keyboard, the player does not move).
##
## Keys: Enter is Ready!, Escape goes back.

const _PANEL := Rect2(180, 22, 600, 420)
const _FEET := Vector2(480, 352)

## The floor: the near edge and the far edge, seen from the front and above.
const _NEAR := [Vector2(300, 388), Vector2(660, 388)]
const _FAR := [Vector2(370, 290), Vector2(590, 290)]

var _title: Label
var _metres: Array[Label] = []
var _ready_button: DwellButton
var _time := 0.0


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    _title = _label(Rect2(_PANEL.position.x + 20, _PANEL.position.y + 22, _PANEL.size.x - 40, 40))
    _title.autowrap_mode = TextServer.AUTOWRAP_WORD
    for at in [Vector2(450, 400), Vector2(642, 326)]:
        _metres.append(_label(Rect2(at, Vector2(60, 20))))

    _ready_button = DwellButton.new()
    _ready_button.position = Vector2(380, 462)
    _ready_button.size = Vector2(200, 56)
    _ready_button.font_size = 32
    _ready_button.primary = true
    _ready_button.pressed.connect(finish)
    add_child(_ready_button)

    add_child(HandCursor.new())
    _update_texts()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _title != null:
        _update_texts()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
                finish()
            KEY_ESCAPE:
                Flow.cancel(get_tree())


func _process(delta: float) -> void:
    _time += delta
    queue_redraw()


## The room is free: go on.
func finish() -> void:
    Flow.room_asked = true
    Flow.next(get_tree())


func _update_texts() -> void:
    # TRANSLATORS: Asked before riding; the player squats and swings her arms.
    _title.text = tr("Make room! Nothing within 1 m around you: about 2 × 2 m free.")
    for label in _metres:
        # TRANSLATORS: Two metres, the side of the free square on the floor.
        label.text = tr("2 m")
    _ready_button.text = tr("Ready!")


func _label(rect: Rect2) -> Label:
    var label := Label.new()
    label.position = rect.position
    label.size = rect.size
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_color_override("font_color", Palette.CRIMSON_DARK)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
    add_child(label)
    return label


func _draw() -> void:
    draw_texture(IntroPicture.background(), Vector2.ZERO)
    draw_texture(Ornaments.panel(_PANEL.size), _PANEL.position)

    var floor := PackedVector2Array([_FAR[0], _FAR[1], _NEAR[1], _NEAR[0]])
    draw_colored_polygon(floor, Palette.GRASS_LIGHT)
    for i in range(4):
        _dashes(floor[i], floor[(i + 1) % 4], Palette.CRIMSON)
    _arrow(_NEAR[0] + Vector2(0, 12), _NEAR[1] + Vector2(0, 12))
    _arrow(_NEAR[1] + Vector2(14, 0), _FAR[1] + Vector2(14, 0))

    # NOTE (mristin):
    # She squats, and pulls the reins to the left and to the right, to show
    # the room it takes.
    var phase := fposmod(_time, 6.0)
    var picture := PaintedGirl.squat(0)
    if phase < 3.0:
        picture = PaintedGirl.squat(PaintedGirl.squat_frame(fposmod(phase / 1.5, 1.0)))
    elif phase < 4.4:
        picture = PaintedGirl.reins(PaintedGirl.reins_frame(minf(1.0, (phase - 3.0) / 0.4)))
    elif phase < 5.8:
        picture = PaintedGirl.reins(PaintedGirl.reins_frame(-minf(1.0, (phase - 4.4) / 0.4)))
    PaintedGirl.draw(self, picture, _FEET, 0.8)


func _dashes(from: Vector2, to: Vector2, color: Color) -> void:
    var length := from.distance_to(to)
    var steps := int(length / 8.0)
    for i in range(steps):
        if i % 2 == 0:
            draw_line(
                from.lerp(to, float(i) / steps), from.lerp(to, float(i + 1) / steps), color, 2.0
            )


func _arrow(from: Vector2, to: Vector2) -> void:
    draw_line(from, to, Palette.OUTLINE, 2.0)
    var along := (to - from).normalized()
    var side := Vector2(-along.y, along.x)
    for tip in [[from, along], [to, -along]]:
        var at: Vector2 = tip[0]
        var into: Vector2 = tip[1]
        draw_colored_polygon(
            PackedVector2Array([at, at + into * 7 + side * 4, at + into * 7 - side * 4]),
            Palette.OUTLINE
        )
