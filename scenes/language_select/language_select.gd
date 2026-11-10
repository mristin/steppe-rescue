class_name LanguageSelect
extends Control

## Let the player choose the language (see section 6 of DESIGN.md): a big card
## for each language of translations/languages.json, with its name in itself
## and no flags, under "Choose your language" in every language, since the
## player may not read the language of the game yet. The choice is
## remembered (see the autoload Languages).
##
## Keys: Escape goes back.

const _CARD := Vector2(240, 120)
const _GAP := 24.0

var _cards: Array[DwellButton] = []


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    var languages := get_node("/root/Languages")

    var prompts := PackedStringArray()
    for language in languages.languages:
        prompts.append(language["prompt"])
    var prompt := Label.new()
    prompt.text = "  ·  ".join(prompts)
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt.position = Vector2(0, 120)
    prompt.size = Vector2(960, 20)
    prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
    prompt.add_theme_color_override("font_color", Palette.OUTLINE)
    prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
    add_child(prompt)

    var count: int = languages.languages.size()
    var width := count * _CARD.x + (count - 1) * _GAP
    var left := roundf((960.0 - width) * 0.5)
    for i in range(count):
        var language: Dictionary = languages.languages[i]
        var card := DwellButton.new()
        card.text = language["name"]
        card.font_size = 32
        card.position = Vector2(left + i * (_CARD.x + _GAP), 210)
        card.size = _CARD
        card.selected = languages.has_chosen and language["code"] == languages.current()
        var code: String = language["code"]
        card.pressed.connect(func() -> void: _choose(code))
        add_child(card)
        _cards.append(card)

    add_child(HandCursor.new())


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Flow.cancel(get_tree())


## The cards of the languages, in the order of the list, for the tests.
func cards() -> Array[DwellButton]:
    return _cards


func _choose(code: String) -> void:
    get_node("/root/Languages").choose(code)
    Flow.next(get_tree())


func _draw() -> void:
    draw_texture(IntroPicture.background(), Vector2.ZERO)
    draw_texture(Ornaments.panel(Vector2(660, 44)), Vector2(150, 108))
    var bird := Icons.of(Icons.BIRD, 4.0)
    draw_texture(bird, Vector2(456, 40))
