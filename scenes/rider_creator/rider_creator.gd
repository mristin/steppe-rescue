class_name RiderCreator
extends Control

## Let the player create her rider and her horse (see section 6 of DESIGN.md):
## she chooses one of the painted riders (see [constant Looks.PRESETS]) on big
## cards, who stands next to her painted horse in the steppe and changes right
## away. While the camera runs, the camera picture shows the player big,
## dressed as the chosen rider (see [CameraPanel]). At the left are the names
## of the rider and the horse; at the right, on a felt panel with the
## ornaments, the cards, or, while a name is written, the big keys of the
## alphabet. Random chooses another rider, and Ready! keeps the rider (see the
## autoload Profile) and goes on.
##
## Keys: letters write the chosen name, Backspace takes a letter back, Tab
## switches between the names, Enter is Ready!, Escape goes back.

## The features of the rows, in their order, under the painted riders: none
## for now, since the horse is painted in one coat (the rows of the horse,
## "horse", "marking" and "mane", come back with the painted horses).
const _ROWS: Array[String] = []

## The cards of the painted riders, at the top of the panel, and of the
## painted horses under them.
const _CARD := Vector2(112, 176)
const _HORSE_CARD := Vector2(112, 104)

## The panel of the looks (or the keys), at the right.
const _PANEL := Rect2(452, 12, 496, 452)
const _ROW_HEIGHT := 44.0

## The painted rider stands at the left, in front of her horse, this many
## times her size.
const _RIDER_FEET := Vector2(104, 528)
const _RIDER_SHOWN := 0.82
const _HORSE_GROUND := Vector2(296, 512)

var looks: Dictionary = {}

## The names as the player writes them.
var rider_name := ""
var horse_name := ""

## Which name the keys write: "rider" or "horse"; empty while the panel shows
## the looks.
var editing := ""

var _camera: CameraPanel
var _rider_cards: Array[DwellButton] = []
var _horse_cards: Array[DwellButton] = []
var _rider_field: DwellButton
var _horse_field: DwellButton
var _values: Dictionary = {}
var _row_controls: Array[Control] = []
var _keyboard: OnScreenKeyboard
var _keyboard_title: Label
var _done_button: DwellButton
var _ready_button: DwellButton
var _random_button: DwellButton
var _row_labels: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _time := 0.0

## Whether the name is still the default, which the first letter replaces.
var _rider_default := true
var _horse_default := true


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    _rng.randomize()

    var profile := get_node("/root/Profile")
    looks = Looks.complete(profile.dressed())
    rider_name = profile.rider_name()
    horse_name = profile.horse_name()
    _rider_default = profile.rider_name_written == ""
    _horse_default = profile.horse_name_written == ""

    _rider_field = _button(Rect2(16, 14, 330, 46))
    _rider_field.font_size = 16
    _rider_field.pressed.connect(func() -> void: _edit("rider"))
    _horse_field = _button(Rect2(16, 68, 330, 46))
    _horse_field.pressed.connect(func() -> void: _edit("horse"))

    var presets := Looks.PRESETS.keys()
    var gap := (_PANEL.size.x - 40.0 - presets.size() * _CARD.x) / (presets.size() - 1)
    for i in range(presets.size()):
        var id: String = presets[i]
        var card := _button(
            Rect2(_PANEL.position + Vector2(20.0 + i * (_CARD.x + gap), 24.0), _CARD)
        )
        card.picture = Painting.rider(id, true)
        card.pressed.connect(func() -> void: choose_rider(id))
        _rider_cards.append(card)
        _row_controls.append(card)

    var horses := Looks.HORSE_PRESETS.keys()
    for i in range(horses.size()):
        var id: String = horses[i]
        var card := _button(
            Rect2(
                _PANEL.position + Vector2(20.0 + i * (_CARD.x + gap), 24.0 + _CARD.y + 16.0),
                _HORSE_CARD
            )
        )
        card.picture = Painting.horse(id, true)
        card.pressed.connect(func() -> void: choose_horse(id))
        _horse_cards.append(card)
        _row_controls.append(card)

    var top := _PANEL.position.y + 24.0 + _CARD.y + 16.0 + _HORSE_CARD.y + 16.0
    for i in range(_ROWS.size()):
        var feature: String = _ROWS[i]
        if feature == "":
            top += 12.0
            continue
        var label := Label.new()
        label.position = Vector2(_PANEL.position.x + 22, top + 9)
        label.size = Vector2(124, 20)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.add_theme_color_override("font_color", Palette.CRIMSON_DARK)
        label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
        add_child(label)
        _row_labels[feature] = label
        _row_controls.append(label)

        var left := _PANEL.position.x + 146.0
        var back := _button(Rect2(left, top, 36, 38))
        back.text = "◀"
        back.pressed.connect(func() -> void: _step(feature, -1))
        var value := _button(Rect2(left + 42, top, 238, 38))
        value.pressed.connect(func() -> void: _step(feature, 1))
        _values[feature] = value
        var forward := _button(Rect2(left + 286, top, 36, 38))
        forward.text = "▶"
        forward.pressed.connect(func() -> void: _step(feature, 1))
        _row_controls.append_array([back, value, forward])
        top += _ROW_HEIGHT

    _keyboard_title = Label.new()
    _keyboard_title.position = _PANEL.position + Vector2(20, 22)
    _keyboard_title.size = Vector2(_PANEL.size.x - 40, 20)
    _keyboard_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _keyboard_title.add_theme_color_override("font_color", Palette.CRIMSON_DARK)
    _keyboard_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
    add_child(_keyboard_title)
    _keyboard = OnScreenKeyboard.new()
    _keyboard.position = _PANEL.position + Vector2(20, 60)
    _keyboard.size = Vector2(_PANEL.size.x - 40, 300)
    _keyboard.typed.connect(_type)
    add_child(_keyboard)
    _keyboard.build(get_node("/root/Languages").alphabet())
    _done_button = _button(Rect2(_PANEL.get_center().x - 80, _PANEL.end.y - 66, 160, 46))
    _done_button.pressed.connect(func() -> void: _edit(""))

    _random_button = _button(Rect2(452, 478, 200, 50))
    _random_button.pressed.connect(randomize_looks)
    _ready_button = _button(Rect2(748, 478, 200, 50))
    _ready_button.font_size = 32
    _ready_button.primary = true
    _ready_button.pressed.connect(finish)

    _camera = CameraPanel.new()
    _camera.position = Vector2(232, 124)
    _camera.size = Vector2(208, 156)
    _camera.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_camera)

    add_child(HandCursor.new())
    _update()


func _process(delta: float) -> void:
    _time += delta
    _camera.visible = get_node("/root/Vision").service.IsRunning()
    _camera.looks = looks
    queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed):
        return
    match event.keycode:
        KEY_ESCAPE:
            if editing != "":
                _edit("")
            else:
                Flow.cancel(get_tree())
        KEY_ENTER, KEY_KP_ENTER:
            finish()
        KEY_TAB:
            _edit("horse" if editing == "rider" else "rider")
        KEY_BACKSPACE:
            _type(OnScreenKeyboard.BACKSPACE)
        _:
            var letter := char(event.unicode) if event.unicode > 0 else ""
            if letter == "" or not _is_letter(letter):
                return
            if editing == "":
                _edit("rider")
            _type(letter)
    get_viewport().set_input_as_handled()


## Choose the painted rider of the preset.
func choose_rider(id: String) -> void:
    looks = Looks.preset(looks, id)
    _update()


## Choose the painted horse of the preset.
func choose_horse(id: String) -> void:
    looks = Looks.horse_preset(looks, id)
    _update()


## Choose another painted rider and horse at random.
func randomize_looks() -> void:
    var horses := Looks.HORSE_PRESETS.keys()
    looks = Looks.horse_preset(looks, horses[_rng.randi_range(0, horses.size() - 1)])
    var others := Looks.PRESETS.keys().filter(func(id: String) -> bool: return id != looks["rider"])
    choose_rider(others[_rng.randi_range(0, others.size() - 1)])


## Keep the rider and her horse and go on.
func finish() -> void:
    var profile := get_node("/root/Profile")
    # NOTE (mristin):
    # A default name stays empty in the profile, so that it follows the
    # language of the game (Aigerim, Айгерим).
    var written_rider := "" if _rider_default else rider_name.strip_edges()
    var written_horse := "" if _horse_default else horse_name.strip_edges()
    profile.save(written_rider, written_horse, looks)
    Flow.next(get_tree())


## The camera picture with the overlay, for the tests.
func camera_panel() -> CameraPanel:
    return _camera


## The keys on the screen, for the tests.
func keyboard() -> OnScreenKeyboard:
    return _keyboard


## Write a letter into the chosen name, or take one back.
func _type(letter: String) -> void:
    if editing == "":
        editing = "rider"
    var name := rider_name if editing == "rider" else horse_name
    var fresh := _rider_default if editing == "rider" else _horse_default
    if fresh:
        name = ""
    if letter == OnScreenKeyboard.BACKSPACE:
        name = name.left(name.length() - 1)
    elif name.length() < get_node("/root/Profile").MAX_NAME:
        name += letter.to_upper() if name == "" else letter.to_lower()
    if editing == "rider":
        rider_name = name
        _rider_default = false
    else:
        horse_name = name
        _horse_default = false
    _update()


## Write the name ("rider" or "horse") with the keys, or show the looks again
## (empty).
func _edit(which: String) -> void:
    editing = "" if which == editing else which
    _update()


func _step(feature: String, by: int) -> void:
    looks = Looks.step(looks, feature, by)
    _update()


## Whether the letter is in the alphabet of any language of the game.
func _is_letter(letter: String) -> bool:
    for language in get_node("/root/Languages").languages:
        var alphabet: String = language["alphabet"]
        if letter.to_upper() in alphabet:
            return true
    return false


func _update() -> void:
    var empty := "…"
    _rider_field.text = tr("Rider: {name}").format(
        {"name": rider_name if rider_name != "" else empty}
    )
    _horse_field.text = tr("Horse: {name}").format(
        {"name": horse_name if horse_name != "" else empty}
    )
    _rider_field.selected = editing == "rider"
    _horse_field.selected = editing == "horse"

    var writing := editing != ""
    for control in _row_controls:
        control.visible = not writing
    _keyboard.visible = writing
    _keyboard_title.visible = writing
    _done_button.visible = writing
    if editing == "rider":
        _keyboard_title.text = tr("Write the name of your rider")
    elif editing == "horse":
        _keyboard_title.text = tr("Write the name of your horse")
    # TRANSLATORS: The button which closes the keys after writing a name.
    _done_button.text = tr("Done")

    for i in range(_rider_cards.size()):
        _rider_cards[i].selected = Looks.PRESETS.keys()[i] == looks.get("rider", "1")
    for i in range(_horse_cards.size()):
        _horse_cards[i].selected = Looks.HORSE_PRESETS.keys()[i] == looks.get("steed", "1")
    for feature in _values:
        var value: DwellButton = _values[feature]
        value.text = _option_name(feature, looks[feature])
        value.swatch = Looks.option_color(feature, looks[feature])
        (_row_labels[feature] as Label).text = _feature_name(feature)
    _random_button.text = tr("Random")
    # TRANSLATORS: The button which keeps the rider and starts the game.
    _ready_button.text = tr("Ready!")


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _ready_button != null:
        _update()


func _button(rect: Rect2) -> DwellButton:
    var button := DwellButton.new()
    button.position = rect.position
    button.size = rect.size
    add_child(button)
    return button


func _draw() -> void:
    draw_texture(IntroPicture.background(), Vector2.ZERO)

    # NOTE (mristin):
    # The painted rider stands next to her painted horse in the steppe; the
    # horse is a bit taller than the girl of ten.
    var horse := Painting.horse(looks.get("steed", "1"))
    var horse_size := horse.get_size()
    var horse_rect := Rect2(
        (_HORSE_GROUND - Vector2(horse_size.x * 0.5, horse_size.y)).round(), horse_size
    )
    draw_texture_rect(horse, horse_rect, false)
    Reward.dress(self, horse_rect, looks, "horse")
    var rider := Painting.rider(looks.get("rider", "1"))
    var shown := rider.get_size() * _RIDER_SHOWN
    var rider_rect := Rect2((_RIDER_FEET - Vector2(shown.x * 0.5, shown.y)).round(), shown)
    draw_texture_rect(rider, rider_rect, false)
    Reward.dress(self, rider_rect, looks, "rider")

    draw_texture(Ornaments.panel(_PANEL.size), _PANEL.position)


## The name of the feature on its row.
func _feature_name(feature: String) -> String:
    var names := {
        "skin": tr("Skin"),
        "hair": tr("Hair"),
        "hair_color": tr("Hair color"),
        "hat": tr("Hat"),
        # TRANSLATORS: The coat of the rider, a шапан.
        "coat": tr("Coat"),
        "dress": tr("Dress"),
        # TRANSLATORS: The color of the coat of the horse.
        "horse": tr("Horse"),
        # TRANSLATORS: The white marking on the face of the horse.
        "marking": tr("Marking"),
        "mane": tr("Mane"),
    }
    return names.get(feature, feature)


## The name of the option of the feature, translated in the context of the
## feature, since its word changes with it (e.g., a black horse is вороной).
func _option_name(feature: String, option: String) -> String:
    var names := {}
    match feature:
        "skin":
            names = {
                "fair": tr("very light", "skin"),
                "light": tr("light", "skin"),
                "tan": tr("tanned", "skin"),
                "dark": tr("dark", "skin"),
                "deep": tr("very dark", "skin"),
            }
        "hair":
            names = {
                "two_braids": tr("two braids", "hair"),
                "one_braid": tr("one braid", "hair"),
                "bun": tr("a bun", "hair"),
                "short": tr("short", "hair"),
                "loose": tr("loose", "hair"),
            }
        "hair_color":
            names = {
                "black": tr("black", "hair"),
                "dark_brown": tr("dark brown", "hair"),
                "brown": tr("brown", "hair"),
                "auburn": tr("auburn", "hair"),
            }
        "hat":
            names = {
                "takiya": tr("тақия", "hat"),
                "borik": tr("бөрік", "hat"),
                "scarf": tr("headscarf", "hat"),
                "felt_hat": tr("felt hat", "hat"),
                "none": tr("no hat", "hat"),
            }
        "coat":
            names = {
                "crimson": tr("crimson", "coat"),
                "indigo": tr("indigo", "coat"),
                "emerald": tr("emerald", "coat"),
                "ochre": tr("ochre", "coat"),
                "white": tr("white", "coat"),
                "black": tr("black", "coat"),
            }
        "dress":
            names = {
                "crimson": tr("crimson", "dress"),
                "indigo": tr("indigo", "dress"),
                "emerald": tr("emerald", "dress"),
                "ochre": tr("ochre", "dress"),
                "white": tr("white", "dress"),
                "black": tr("black", "dress"),
            }
        "horse":
            names = {
                "bay": tr("bay", "horse"),
                "chestnut": tr("chestnut", "horse"),
                "grey": tr("grey", "horse"),
                "black": tr("black", "horse"),
                "dun": tr("dun", "horse"),
                "piebald": tr("piebald", "horse"),
            }
        "marking":
            names = {
                "none": tr("none", "marking"),
                "star": tr("a star", "marking"),
                "blaze": tr("a blaze", "marking"),
            }
        "mane":
            names = {
                "black": tr("black", "mane"),
                "dark_brown": tr("dark brown", "mane"),
                "flaxen": tr("flaxen", "mane"),
                "grey": tr("grey", "mane"),
            }
    return names.get(option, option)
