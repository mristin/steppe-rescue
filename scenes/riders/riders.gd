class_name Riders
extends Control

## Let the children who share a computer choose who rides (see section 9 of
## DESIGN.md): a card for each rider, with her painted picture, her name and
## her stars, and New rider, who is created in the creator. The current
## rider's card is golden; Change rider opens the creator for her.
##
## It shows on the way from Play when more than one rider shares the computer
## (once each start), and from the settings.
##
## Keys: 1 to 6 choose a rider, Escape goes back.

const _CARD := Vector2(136, 200)
const _TOP := 96.0

var _cards: Array[DwellButton] = []
var _new: DwellButton
var _change: DwellButton
var _title: Label


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    var profile := get_node("/root/Profile")

    _title = Label.new()
    _title.position = Vector2(0, 36)
    _title.size = Vector2(960, 32)
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _title.add_theme_font_size_override("font_size", 32)
    _title.add_theme_color_override("font_color", Palette.FELT)
    _title.add_theme_color_override("font_outline_color", Palette.OUTLINE)
    _title.add_theme_constant_override("outline_size", 6)
    add_child(_title)

    var riders: Array[Dictionary] = profile.riders()
    var count := riders.size() + (1 if riders.size() < profile.MAX_RIDERS else 0)
    var gap := 12.0
    var left := roundf((960.0 - count * _CARD.x - (count - 1) * gap) * 0.5)
    for i in range(riders.size()):
        var rider: Dictionary = riders[i]
        var card := _button(Rect2(left + i * (_CARD.x + gap), _TOP, _CARD.x, _CARD.y))
        card.picture = Painting.rider(rider["looks"].get("rider", "1"), true)
        card.selected = i == profile.index and profile.has_rider
        card.pressed.connect(func() -> void: choose(i))
        _cards.append(card)
    if riders.size() < profile.MAX_RIDERS:
        _new = _button(Rect2(left + riders.size() * (_CARD.x + gap), _TOP, _CARD.x, _CARD.y))
        _new.font_size = 32
        _new.pressed.connect(add_rider)

    _change = _button(Rect2(260, 400, 200, 52))
    _change.pressed.connect(func() -> void: Flow.open(get_tree(), Flow.RIDER_CREATOR, Flow.RIDERS))
    _change.visible = profile.has_rider
    var back := _button(Rect2(500, 400, 200, 52))
    back.primary = true
    back.text = tr("Back")
    back.pressed.connect(func() -> void: Flow.cancel(get_tree()))

    add_child(HandCursor.new())
    _update_texts()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _title != null:
        _update_texts()


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    if event.keycode == KEY_ESCAPE:
        Flow.cancel(get_tree())
    elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
        choose(event.keycode - KEY_1)


## Ride as the rider of the index, and go on.
func choose(i: int) -> void:
    if i < 0 or i >= _cards.size():
        return
    get_node("/root/Profile").choose_rider(i)
    Flow.rider_asked = true
    Flow.next(get_tree())


## Start a new rider, and create her.
func add_rider() -> void:
    if get_node("/root/Profile").new_rider():
        Flow.rider_asked = true
        Flow.play(get_tree())


## The cards of the riders, for the tests.
func cards() -> Array[DwellButton]:
    return _cards


func _update_texts() -> void:
    var profile := get_node("/root/Profile")
    var riders: Array[Dictionary] = profile.riders()
    # TRANSLATORS: The title of the screen where the children choose who rides.
    _title.text = tr("Who rides today?")
    for i in range(_cards.size()):
        var written: String = riders[i]["name"]
        var name := written if written != "" else tr("Aigerim")
        _cards[i].text = "%s  ★%d" % [name, riders[i]["stars"]]
    if _new != null:
        # TRANSLATORS: The card which starts a new rider; keep it short.
        _new.text = tr("+ New")
    # TRANSLATORS: The button which opens the creator for the current rider.
    _change.text = tr("Change rider")


func _button(rect: Rect2) -> DwellButton:
    var button := DwellButton.new()
    button.position = rect.position
    button.size = rect.size
    add_child(button)
    return button


func _draw() -> void:
    draw_texture(IntroPicture.background(), Vector2.ZERO)
