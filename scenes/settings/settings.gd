class_name Settings
extends Control

## Let the player change her settings (see section 6 of DESIGN.md): the
## language, the rider with her horse, what she wears (the wardrobe) and the
## sound, on a felt panel with a row for each,
## next to the camera picture, big, in which she sees herself dressed as her
## rider (see [CameraPanel]), so that she can check that the camera sees her;
## without the camera, her rider stands there instead.
##
## Keys: Escape goes back to the intro.

const _PANEL := Rect2(424, 40, 512, 380)
const _CAMERA := Rect2(32, 112, 352, 264)

var _language: DwellButton
var _rider: DwellButton
var _wardrobe: DwellButton
var _sound: DwellButton
var _back: DwellButton
var _title: Label
var _row_labels: Array[Label] = []
var _status: Label
var _camera: CameraPanel
var _service: Node = null


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    _service = get_node("/root/Vision").service

    _camera = CameraPanel.new()
    _camera.position = _CAMERA.position
    _camera.size = _CAMERA.size
    _camera.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_camera)
    _status = _label(Rect2(_CAMERA.position.x, _CAMERA.end.y + 14, _CAMERA.size.x, 20))
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status.add_theme_color_override("font_color", Palette.FELT)
    _status.add_theme_color_override("font_outline_color", Palette.OUTLINE)
    _status.add_theme_constant_override("outline_size", 4)

    _title = _label(Rect2(_PANEL.position.x, _PANEL.position.y + 22, _PANEL.size.x, 20))
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.add_theme_font_size_override("font_size", 32)

    var left := _PANEL.position.x + 30.0
    for i in range(4):
        var top := _PANEL.position.y + 80.0 + i * 70.0
        _row_labels.append(_label(Rect2(left, top + 14, 150, 20)))
    _language = _button(Rect2(left + 160, _PANEL.position.y + 80, 290, 48))
    _language.pressed.connect(
        func() -> void: Flow.open(get_tree(), Flow.LANGUAGE_SELECT, Flow.SETTINGS)
    )
    _rider = _button(Rect2(left + 160, _PANEL.position.y + 150, 290, 48))
    _rider.pressed.connect(func() -> void: Flow.open(get_tree(), Flow.RIDERS, Flow.SETTINGS))
    _wardrobe = _button(Rect2(left + 160, _PANEL.position.y + 220, 290, 48))
    _wardrobe.pressed.connect(func() -> void: Flow.open(get_tree(), Flow.WARDROBE, Flow.SETTINGS))
    _sound = _button(Rect2(left + 160, _PANEL.position.y + 290, 290, 48))
    _sound.pressed.connect(
        func() -> void:
            var sounds := get_node("/root/Sounds")
            sounds.set_enabled(not sounds.enabled)
            _update_texts()
    )

    _back = _button(Rect2(_PANEL.get_center().x - 90, _PANEL.end.y + 24, 180, 56))
    _back.font_size = 32
    _back.primary = true
    _back.pressed.connect(func() -> void: Flow.open(get_tree(), Flow.INTRO))

    add_child(HandCursor.new())
    _update_texts()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _title != null:
        _update_texts()


func _process(_delta: float) -> void:
    var status: String = _service.GetStatus()
    if _camera.visible != (status == "Running"):
        _camera.visible = status == "Running"
        queue_redraw()
    if status == "Running":
        _status.text = "" if _service.HasPlayer() else tr("Step in front of the camera.")
    else:
        _status.text = VisionStatus.new().text(_service, false)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Flow.open(get_tree(), Flow.INTRO)


## The buttons, for the tests: the language, the rider and Back.
func buttons() -> Array[DwellButton]:
    return [_language, _rider, _back, _wardrobe, _sound]


func _update_texts() -> void:
    _title.text = tr("Settings")
    # TRANSLATORS: The label of the row with the language of the game.
    _row_labels[0].text = tr("Language")
    # TRANSLATORS: The label of the row with the name of the rider, which opens the creator.
    _row_labels[1].text = tr("Rider")
    var languages := get_node("/root/Languages")
    for language in languages.languages:
        if language["code"] == languages.current():
            _language.text = language["name"]
    var profile := get_node("/root/Profile")
    _rider.text = "%s · %s" % [profile.rider_name(), profile.horse_name()]
    # TRANSLATORS: The label of the row which opens the wardrobe of the finery.
    _row_labels[2].text = tr("Wardrobe")
    # TRANSLATORS: The button which opens the wardrobe, to choose what to wear.
    _wardrobe.text = tr("Choose what to wear")
    # TRANSLATORS: The label of the row with the sound on or off.
    _row_labels[3].text = tr("Sound")
    _sound.text = tr("On", "sound") if get_node("/root/Sounds").enabled else tr("Off", "sound")
    # TRANSLATORS: The button which goes back to the previous screen.
    _back.text = tr("Back")


func _label(rect: Rect2) -> Label:
    var label := Label.new()
    label.position = rect.position
    label.size = rect.size
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_color_override("font_color", Palette.CRIMSON_DARK)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
    add_child(label)
    return label


func _button(rect: Rect2) -> DwellButton:
    var button := DwellButton.new()
    button.position = rect.position
    button.size = rect.size
    add_child(button)
    return button


func _draw() -> void:
    draw_texture(IntroPicture.background(), Vector2.ZERO)
    draw_texture(Ornaments.panel(_PANEL.size), _PANEL.position)
    draw_texture(
        Ornaments.panel(_CAMERA.size + Vector2(24, 24)), _CAMERA.position - Vector2(12, 12)
    )
    if _camera.visible:
        return
    draw_rect(_CAMERA, Palette.SKY_LIGHT)
    draw_rect(
        Rect2(_CAMERA.position.x, _CAMERA.end.y - 40, _CAMERA.size.x, 40), Palette.GRASS_LIGHT
    )
    var rider := Painting.rider(get_node("/root/Profile").looks.get("rider", "1"))
    var feet := Vector2(_CAMERA.get_center().x, _CAMERA.end.y - 8)
    var shown := rider.get_size() * 0.85
    draw_texture_rect(rider, Rect2((feet - Vector2(shown.x * 0.5, shown.y)).round(), shown), false)
