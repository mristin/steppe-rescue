class_name Intro
extends Control

## Show the intro screen (see section 6 of DESIGN.md): the painting of the
## rider and her horse in the steppe near Astana, with the title painted in,
## and the buttons written by the game so that they can be translated: Play,
## Levels, Settings and How to Play, where the painting had them.
##
## The painting is the one picture of the game which is not pixel art: it is
## shown as painted, at the resolution of the screen (see
## [constant PAINTING]).
##
## Keys: Enter plays, Escape twice quits.

## The painting, 1920 x 1080, one pixel of it on each pixel of the screen.
const PAINTING := "res://assets/pictures/intro/painting.png"

var _play: DwellButton
var _levels: DwellButton
var _how_to_play: DwellButton
var _settings: DwellButton
var _quit_hint: QuitHint
var _painting: Texture2D


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _painting = load(PAINTING)

    _play = _button(Rect2(606, 296, 228, 56), 32)
    _play.primary = true
    _play.pressed.connect(func() -> void: Flow.play(get_tree()))
    _levels = _button(Rect2(636, 362, 168, 38), 16)
    _levels.pressed.connect(func() -> void: Flow.open(get_tree(), Flow.LEVEL_SELECT))
    _settings = _button(Rect2(636, 408, 168, 38), 16)
    _settings.pressed.connect(func() -> void: Flow.open(get_tree(), Flow.SETTINGS))
    _how_to_play = _button(Rect2(636, 454, 168, 38), 16)
    _how_to_play.pressed.connect(func() -> void: Flow.open(get_tree(), Flow.INSTRUCTION))

    _quit_hint = QuitHint.new()
    _quit_hint.position = Vector2(0, 516)
    _quit_hint.size = Vector2(960, 20)
    add_child(_quit_hint)

    add_child(HandCursor.new())
    _update_texts()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _play != null:
        _update_texts()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
                Flow.play(get_tree())
            KEY_ESCAPE:
                _quit_hint.press()


func _update_texts() -> void:
    # TRANSLATORS: The button which starts the game.
    _play.text = tr("Play")
    # TRANSLATORS: The button which opens the map with all the levels.
    _levels.text = tr("Levels")
    # TRANSLATORS: The button which shows how to ride by squatting and pulling the reins.
    _how_to_play.text = tr("How to Play")
    _settings.text = tr("Settings")


## The buttons, for the tests: Play, Levels, How to Play and Settings.
func buttons() -> Array[DwellButton]:
    return [_play, _levels, _how_to_play, _settings]


func _button(rect: Rect2, font_size: int) -> DwellButton:
    var button := DwellButton.new()
    button.position = rect.position
    button.size = rect.size
    button.font_size = font_size
    add_child(button)
    return button


func _draw() -> void:
    draw_texture_rect(_painting, Rect2(Vector2.ZERO, Vector2(960, 540)), false)
