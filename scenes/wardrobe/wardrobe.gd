class_name Wardrobe
extends Control

## Let the rider choose which pieces of the finery she won to wear (see
## section 8 of DESIGN.md), at home, for free and at any time: a card for each
## piece she won, golden while she wears it; pressing it takes it off or puts
## it on. The rider stands at home, and the decorations of the home show as
## she chooses them (see [method Reward.draw_home]); what she wears also shows
## over her face in the camera picture.
##
## Keys: Escape goes back.

## The cards stand in a wide strip along the top, over the sky, so that the
## home below (the yurt with its decorations, the rider and her horse) shows.
const _PANEL := Rect2(16, 12, 880, 232)
const _CARD := Vector2(88, 80)
const _COLUMNS := 9

var _cards: Array[DwellButton] = []
var _pieces: Array[String] = []
var _title: Label
var _back: DwellButton


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    var profile := get_node("/root/Profile")

    _title = Label.new()
    _title.position = _PANEL.position + Vector2(16, 18)
    _title.size = Vector2(_PANEL.size.x - 32, 24)
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _title.add_theme_color_override("font_color", Palette.CRIMSON_DARK)
    _title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
    add_child(_title)

    for piece in Finery.PIECES:
        if not profile.finery.has(piece):
            continue
        var at: int = profile.finery[piece]
        if not Finery.has_picture(piece, at):
            continue
        var i := _pieces.size()
        var card := DwellButton.new()
        card.position = (
            _PANEL.position
            + Vector2(20 + (i % _COLUMNS) * (_CARD.x + 6), 50 + (i / _COLUMNS) * (_CARD.y + 6))
        )
        card.size = _CARD
        card.picture = Painting.fitted(Finery.PICTURES % [piece, at], Vector2(64, 60))
        card.selected = profile.wears(piece)
        card.pressed.connect(func() -> void: toggle(piece))
        add_child(card)
        _cards.append(card)
        _pieces.append(piece)

    _back = DwellButton.new()
    _back.position = Vector2(776, 470)
    _back.size = Vector2(168, 54)
    _back.font_size = 32
    _back.primary = true
    _back.pressed.connect(func() -> void: Flow.cancel(get_tree()))
    add_child(_back)

    add_child(HandCursor.new())
    _update_texts()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _title != null:
        _update_texts()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Flow.cancel(get_tree())


## Take the piece off, or put it on.
func toggle(piece: String) -> void:
    var profile := get_node("/root/Profile")
    profile.wear(piece, not profile.wears(piece))
    var i := _pieces.find(piece)
    if i >= 0:
        _cards[i].selected = profile.wears(piece)
    queue_redraw()


## The cards of the pieces she won, for the tests.
func cards() -> Array[DwellButton]:
    return _cards


## The pieces of the cards, in their order, for the tests.
func pieces() -> Array[String]:
    return _pieces


func _update_texts() -> void:
    if _pieces.is_empty():
        # TRANSLATORS: In the wardrobe, before the rider won any finery.
        _title.text = tr("Bring the animals home to win finery!")
    else:
        # TRANSLATORS: The title of the wardrobe; the chosen pieces are golden.
        _title.text = tr("Choose what to wear")
    _back.text = tr("Back")


func _draw() -> void:
    Reward.draw_home(self, get_node("/root/Profile"))
    draw_texture(Ornaments.panel(_PANEL.size), _PANEL.position)
