class_name PlayerCount
extends Control

## Ask how many players ride together in a new journey (see section 6 of
## DESIGN.md, "Two players"), as in Bird Dog: two big cards, "1 · One rider"
## and "2 · Two riders", each with as many painted riders, chosen with the hand
## cursor like everything else. Then every player creates her rider.
##
## Keys: 1 or 2 chooses, Escape goes back.

const _CARD := Vector2(300, 300)
const _CARDS_TOP := 120.0
const _GAP := 80.0

var _cards: Array[DwellButton] = []
var _title: Label
var _chosen := false


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

    _title = Label.new()
    _title.position = Vector2(0, 40)
    _title.size = Vector2(960, 40)
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _title.add_theme_font_size_override("font_size", 32)
    _title.add_theme_color_override("font_color", Palette.FELT)
    _title.add_theme_color_override("font_outline_color", Palette.OUTLINE)
    _title.add_theme_constant_override("outline_size", 6)
    add_child(_title)

    var left := (960.0 - 2.0 * _CARD.x - _GAP) * 0.5
    for count in [1, 2]:
        var card := DwellButton.new()
        card.position = Vector2(left + (count - 1) * (_CARD.x + _GAP), _CARDS_TOP)
        card.size = _CARD
        card.font_size = 32
        card.picture = riders(count)
        card.pressed.connect(func() -> void: choose(count))
        add_child(card)
        _cards.append(card)

    add_child(HandCursor.new())
    _update_texts()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _title != null:
        _update_texts()


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    match event.keycode:
        KEY_1, KEY_KP_1:
            choose(1)
        KEY_2, KEY_KP_2:
            choose(2)
        KEY_ESCAPE:
            Flow.cancel(get_tree())


## Let as many players ride in the journey, and go on to create their riders.
func choose(count: int) -> void:
    if _chosen:
        return
    _chosen = true
    get_node("/root/Profile").set_players(count)
    Flow.next(get_tree())


## The cards, for the tests: one rider, two riders.
func cards() -> Array[DwellButton]:
    return _cards


## The painted riders of the presets side by side, as many as the players.
static func riders(count: int) -> ImageTexture:
    var images: Array[Image] = []
    var width := 0
    var height := 0
    for i in range(count):
        var image := Painting.rider(Looks.PRESETS.keys()[i], true).get_image()
        image.convert(Image.FORMAT_RGBA8)
        images.append(image)
        width += image.get_width()
        height = maxi(height, image.get_height())
    var canvas := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
    var x := 0
    for image in images:
        canvas.blit_rect(
            image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(x, height - image.get_height())
        )
        x += image.get_width()
    var result := ImageTexture.create_from_image(canvas)
    result.set_size_override(Vector2i(width / Pixelate.DENSITY, height / Pixelate.DENSITY))
    return result


func _update_texts() -> void:
    # TRANSLATORS: The title of the screen where the players choose whether one or two ride.
    _title.text = tr("How many riders?")
    # TRANSLATORS: The card for a single player.
    _cards[0].text = tr("1 · One rider")
    # TRANSLATORS: The card for two players, who ride together on a split screen.
    _cards[1].text = tr("2 · Two riders")


func _draw() -> void:
    draw_texture(IntroPicture.background(), Vector2.ZERO)
