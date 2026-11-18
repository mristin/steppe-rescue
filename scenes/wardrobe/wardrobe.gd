class_name Wardrobe
extends Control

## Let the rider choose which pieces of the finery she won to wear (see
## section 8 of DESIGN.md), at home, for free and at any time. The rider and
## her horse stand in a golden light on the left, dressed as she chooses.
## On the right, two panels: on top what she wears, below what she does not;
## pressing a card moves its piece to the other panel. The decorations of the
## home show at home as she chooses them (see [method Reward.draw_home]);
## what she wears also shows over her face in the camera picture.
##
## With two players, each has her own wardrobe (see
## [member Flow.wardrobe_player]), with the hand cursor of her half of the
## camera picture.
##
## Keys: Escape goes back.

## The panel of what she wears, and the panel of what she does not.
const _WORN := Rect2(392, 8, 552, 250)
const _NOT_WORN := Rect2(392, 264, 552, 250)
## The cards are big while a panel holds at most two rows of them, and
## smaller when it needs three.
const _CARD := Vector2(96, 88)
const _SMALL_CARD := Vector2(66, 60)
const _GAP := 4.0
const _COLUMNS := 5
const _SMALL_COLUMNS := 7

## The player (0 or 1) whose wardrobe this is.
var player := 0

var _cards: Array[DwellButton] = []
var _pieces: Array[String] = []
var _worn_title: Label
var _not_worn_title: Label
var _empty: Label
var _back: DwellButton


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    var profile := get_node("/root/Profile")
    player = clampi(Flow.wardrobe_player, 0, profile.riders.size() - 1)
    var finery: Dictionary = profile.rider(player).finery

    _worn_title = _label(_WORN)
    _not_worn_title = _label(_NOT_WORN)
    _empty = _label(Rect2(_WORN.position + Vector2(0, 90), _WORN.size))
    # NOTE (mristin):
    # The hint is long in some languages: it wraps onto a second line.
    _empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _empty.size.y = 60

    for piece in Finery.PIECES:
        if not finery.has(piece):
            continue
        var at: int = finery[piece]
        if not Finery.has_picture(piece, at):
            continue
        var card := DwellButton.new()
        card.pressed.connect(func() -> void: toggle(piece))
        add_child(card)
        _cards.append(card)
        _pieces.append(piece)

    _back = DwellButton.new()
    _back.position = Vector2(16, 12)
    _back.size = Vector2(168, 54)
    _back.font_size = 32
    _back.primary = true
    _back.pressed.connect(func() -> void: Flow.cancel(get_tree()))
    add_child(_back)

    _arrange()
    var cursor := HandCursor.new()
    cursor.player = player if profile.players > 1 else -1
    add_child(cursor)
    _update_texts()


func _label(panel: Rect2) -> Label:
    var label := Label.new()
    label.position = panel.position + Vector2(16, 12)
    label.size = Vector2(panel.size.x - 32, 24)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", 24)
    label.add_theme_color_override("font_color", Palette.CRIMSON_DARK)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
    add_child(label)
    return label


## Put each card into the panel where its piece is: worn or not.
func _arrange() -> void:
    var profile := get_node("/root/Profile")
    var totals := {true: 0, false: 0}
    for piece in _pieces:
        totals[profile.rider(player).wears(piece)] += 1
    var counts := {true: 0, false: 0}
    for i in range(_cards.size()):
        var worn: bool = profile.rider(player).wears(_pieces[i])
        var panel := _WORN if worn else _NOT_WORN
        var small: bool = totals[worn] > 2 * _COLUMNS
        var card_size := _SMALL_CARD if small else _CARD
        var columns := _SMALL_COLUMNS if small else _COLUMNS
        var n: int = counts[worn]
        counts[worn] = n + 1
        _cards[i].size = card_size
        _cards[i].position = (
            panel.position
            + Vector2(
                18 + (n % columns) * (card_size.x + _GAP), 46 + (n / columns) * (card_size.y + _GAP)
            )
        )
        var at: int = profile.rider(player).finery[_pieces[i]]
        _cards[i].picture = Painting.fitted(
            Finery.PICTURES % [_pieces[i], at], card_size - Vector2(16, 14)
        )
        _cards[i].selected = worn


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _worn_title != null:
        _update_texts()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Flow.cancel(get_tree())


## Take the piece off, or put it on.
func toggle(piece: String) -> void:
    var profile := get_node("/root/Profile")
    profile.wear(piece, not profile.rider(player).wears(piece), player)
    _arrange()
    queue_redraw()


## The cards of the pieces she won, for the tests.
func cards() -> Array[DwellButton]:
    return _cards


## The pieces of the cards, in their order, for the tests.
func pieces() -> Array[String]:
    return _pieces


## Whether the piece's card stands in the panel of what she wears, for the
## tests.
func in_worn_panel(piece: String) -> bool:
    var i := _pieces.find(piece)
    return i >= 0 and Rect2(_WORN).has_point(_cards[i].position)


func _update_texts() -> void:
    # TRANSLATORS: The wardrobe: the title of the panel of the finery which she wears.
    _worn_title.text = tr("Wearing")
    var profile := get_node("/root/Profile")
    if profile.players > 1:
        _worn_title.text = "%s · %s" % [profile.rider_name(player), _worn_title.text]
    # TRANSLATORS: The wardrobe: the title of the panel of the finery which she won, but took off.
    _not_worn_title.text = tr("Not wearing")
    # TRANSLATORS: In the wardrobe, before the rider won any finery.
    _empty.text = tr("Bring the animals home to win finery!") if _pieces.is_empty() else ""
    _back.text = tr("Back")


func _draw() -> void:
    Reward.draw_home(self, get_node("/root/Profile"), true, player)
    draw_texture(Ornaments.panel(_WORN.size), _WORN.position)
    draw_texture(Ornaments.panel(_NOT_WORN.size), _NOT_WORN.position)
