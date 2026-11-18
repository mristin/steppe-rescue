class_name SessionName
extends Control

## Name a new journey (see section 9 of DESIGN.md), like the voyages of Bird
## Dog: the name starts as the date and the time (e.g., "2026-11-10 14:05"),
## so that OK is enough; the first key written replaces it. The keys on the
## screen have the letters of the language, the digits, "-", ":" and a space.
## OK starts the journey, and its rider is created next.
##
## Keys: typing writes, Backspace takes back, Enter is OK, Escape goes back.

## The key which writes a space.
const SPACE := "␣"

const _PANEL := Rect2(120, 20, 720, 440)

## Whether the name is still the default (the date and the time).
var fresh := true

## The name as written.
var written := ""

var _title: Label
var _name: Label
var _keyboard: OnScreenKeyboard
var _ok: DwellButton
var _back: DwellButton


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    written = get_node("/root/Profile").default_session_name()

    _title = _label(Rect2(_PANEL.position + Vector2(20, 22), Vector2(_PANEL.size.x - 40, 24)))
    _title.add_theme_color_override("font_color", Palette.CRIMSON_DARK)
    _title.add_theme_font_size_override("font_size", 24)
    _name = _label(Rect2(_PANEL.position + Vector2(20, 58), Vector2(_PANEL.size.x - 40, 36)))
    _name.add_theme_font_size_override("font_size", 32)
    _name.add_theme_color_override("font_color", Palette.OUTLINE)

    _keyboard = OnScreenKeyboard.new()
    _keyboard.position = _PANEL.position + Vector2(20, 108)
    _keyboard.size = Vector2(_PANEL.size.x - 40, 320)
    _keyboard.key_size = Vector2(48, 50)
    _keyboard.key_font_size = 24
    _keyboard.typed.connect(_type)
    add_child(_keyboard)
    _keyboard.build(get_node("/root/Languages").alphabet() + "0123456789-:" + SPACE)

    _ok = _button(Rect2(_PANEL.get_center().x + 20, _PANEL.end.y + 16, 200, 56))
    _ok.font_size = 32
    _ok.primary = true
    _ok.pressed.connect(finish)
    _back = _button(Rect2(_PANEL.get_center().x - 220, _PANEL.end.y + 20, 200, 48))
    _back.pressed.connect(func() -> void: Flow.cancel(get_tree()))

    add_child(HandCursor.new())
    _update()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _title != null:
        _update()


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed):
        return
    match event.keycode:
        KEY_ESCAPE:
            Flow.cancel(get_tree())
        KEY_ENTER, KEY_KP_ENTER:
            finish()
        KEY_BACKSPACE:
            _type(OnScreenKeyboard.BACKSPACE)
        _:
            var letter := char(event.unicode) if event.unicode > 0 else ""
            if letter != "":
                _type(SPACE if letter == " " else letter)


## Start the journey with the name; its rider is created next.
func finish() -> void:
    get_node("/root/Profile").start_session(written)
    Flow.session_asked = true
    Flow.play(get_tree())


## The keys on the screen, for the tests.
func keyboard() -> OnScreenKeyboard:
    return _keyboard


## Write a letter into the name, or take one back.
func _type(letter: String) -> void:
    if fresh:
        written = ""
        fresh = false
    if letter == OnScreenKeyboard.BACKSPACE:
        written = written.left(written.length() - 1)
    elif written.length() < get_node("/root/Profile").MAX_SESSION_NAME:
        var character := " " if letter == SPACE else letter
        if character.length() != 1:
            return
        written += character.to_upper() if written == "" else character.to_lower()
    _update()


func _update() -> void:
    # TRANSLATORS: The title of the screen where the players name a new journey (a saved game).
    _title.text = tr("Name your journey")
    _name.text = written + ("" if fresh else "_")
    _ok.text = tr("OK")
    _back.text = tr("Back")


func _label(rect: Rect2) -> Label:
    var label := Label.new()
    label.position = rect.position
    label.size = rect.size
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
