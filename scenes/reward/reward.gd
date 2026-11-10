class_name Reward
extends Control

## Reward the rider at the end of a level (see section 8 of DESIGN.md): at
## home, in front of the yurts, she stands next to her horse wearing all the
## finery she won so far, and chooses one new piece of three, shown on big
## cards as a close-up of her own horse or of her, with the name and, for the
## tack, the Kazakh word. The piece joins the picture with a sparkle, and Go
## on leads to the level select. More stars offer the more splendid pieces
## (see [method Finery.offer]).
##
## Keys: 1, 2 and 3 choose a card, Enter goes on, Escape goes on, too.

## The painting of the home, the yurt at sunset, behind the rider.
const HOME := "res://assets/pictures/home/reward.png"

## The rider stands here, in front of her horse.
const _RIDER_FEET := Vector2(110, 512)
const _HORSE_GROUND := Vector2(250, 492)

const _CARD := Vector2(160, 196)
const _CARDS_TOP := 150.0
const _PICTURE := Vector2(128, 116)

## How long the sparkle lasts, in seconds.
const SPARKLE_SECONDS := 1.6

## The pieces on offer, as [piece, step] pairs.
var offered: Array = []

## The piece chosen; empty until the player chooses.
var chosen := ""

## The stars won in the level.
var stars := 0

var _cards: Array[DwellButton] = []
var _subtitles: Array[Label] = []
var _title: Label
var _go_on: DwellButton
var _sparkle := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    _rng.randomize()
    var profile := get_node("/root/Profile")
    stars = Flow.reward_stars
    offered = Finery.offer(profile.finery, stars, _rng)

    _title = Label.new()
    _title.position = Vector2(420, 34)
    _title.size = Vector2(520, 24)
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.add_theme_color_override("font_color", Palette.CRIMSON_DARK)
    _title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
    _title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_title)

    var width := offered.size() * _CARD.x + maxf(0, offered.size() - 1) * 12.0
    var left := roundf(680.0 - width * 0.5)
    for i in range(offered.size()):
        var piece: String = offered[i][0]
        var at: int = offered[i][1]
        var card := DwellButton.new()
        card.position = Vector2(left + i * (_CARD.x + 12.0), _CARDS_TOP)
        card.size = _CARD
        card.picture = preview(piece, at, profile.dressed())
        card.pressed.connect(func() -> void: choose(i))
        add_child(card)
        _cards.append(card)
        var subtitle := Label.new()
        subtitle.position = card.position + Vector2(0, _CARD.y + 6)
        subtitle.size = Vector2(_CARD.x, 20)
        subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        subtitle.text = Finery.PIECES[piece]["kazakh"]
        subtitle.add_theme_color_override("font_color", Palette.FELT)
        subtitle.add_theme_color_override("font_outline_color", Palette.OUTLINE)
        subtitle.add_theme_constant_override("outline_size", 4)
        subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(subtitle)
        _subtitles.append(subtitle)

    _go_on = DwellButton.new()
    _go_on.position = Vector2(590, 440)
    _go_on.size = Vector2(200, 60)
    _go_on.font_size = 32
    _go_on.primary = true
    _go_on.visible = offered.is_empty()
    _go_on.pressed.connect(go_on)
    add_child(_go_on)

    add_child(HandCursor.new())
    _update_texts()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _title != null:
        _update_texts()


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    match event.keycode:
        KEY_1, KEY_2, KEY_3:
            choose(event.keycode - KEY_1)
        KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE:
            if _go_on.visible:
                go_on()


func _process(delta: float) -> void:
    _sparkle = maxf(0.0, _sparkle - delta)
    queue_redraw()


## Choose the card: the rider wins its piece, and the others go.
func choose(index: int) -> void:
    if chosen != "" or index < 0 or index >= offered.size():
        return
    chosen = offered[index][0]
    get_node("/root/Profile").win(chosen)
    for i in range(_cards.size()):
        _cards[i].visible = i == index
        _subtitles[i].visible = i == index
        _cards[i].selected = i == index
    _sparkle = SPARKLE_SECONDS
    _go_on.visible = true
    _update_texts()


## Go on to the level select.
func go_on() -> void:
    Flow.open(get_tree(), Flow.LEVEL_SELECT)


## The cards, for the tests.
func cards() -> Array[DwellButton]:
    return _cards


## The painting of the step of the piece (see assets/pictures/finery/), as
## the card shows it.
static func preview(piece: String, at: int, _looks := {}) -> ImageTexture:
    return Painting.fitted("res://assets/pictures/finery/%s_%d.png" % [piece, at], _PICTURE)


func _update_texts() -> void:
    var rider_name: String = get_node("/root/Profile").rider_name()
    if offered.is_empty():
        _title.text = tr("{rider}, you have won all the finery!").format({"rider": rider_name})
    elif chosen == "":
        # TRANSLATORS: {rider} is the rider's name; she chooses one of three gifts.
        _title.text = tr("Well done, {rider}! Choose a gift.").format({"rider": rider_name})
    else:
        _title.text = tr("How beautiful!")
    for i in range(_cards.size()):
        _cards[i].text = piece_name(offered[i][0], offered[i][1])
    # TRANSLATORS: The button which goes on from the gift to the map of the levels.
    _go_on.text = tr("Go on")


## The name of the step of the piece.
func piece_name(piece: String, at: int) -> String:
    var names := {
        "saddle": [tr("Silver studs"), tr("Painted saddle")],
        # TRANSLATORS: The felt cloth under the saddle, тоқым.
        "saddle_cloth": [tr("Embroidered cloth"), tr("Tassels")],
        "bridle": [tr("Silver bridle"), tr("Bridle tassels")],
        "breastplate": [tr("Breastplate")],
        "stirrups": [tr("Silver stirrups")],
        "mane": [tr("Braided mane"), tr("Mane ribbons"), tr("Owl-feather tassel")],
        "feathers": [tr("Owl feathers")],
        "coat": [tr("Embroidered coat"), tr("Ram's horn pattern")],
        "earrings": [tr("Earrings")],
        "bracelets": [tr("Bracelets")],
        "belt": [tr("Silver belt")],
        "boots": [tr("Embroidered boots")],
    }
    var steps: Array = names.get(piece, [piece])
    return steps[clampi(at - 1, 0, steps.size() - 1)]


func _draw() -> void:
    draw_texture(Painting.texture(HOME), Vector2.ZERO)
    draw_texture(Ornaments.panel(Vector2(540, 70)), Vector2(410, 14))
    var star := Icons.star(2.0)
    for i in range(3):
        var tint := Color.WHITE if i < stars else Color(0.25, 0.2, 0.15, 0.55)
        draw_texture(star, Vector2(644 + i * 28, 58), tint)

    # NOTE (mristin):
    # The painted rider stands in front of her painted horse, at home.
    var looks: Dictionary = get_node("/root/Profile").looks
    var horse := Painting.horse(looks.get("steed", "1"))
    var horse_shown := horse.get_size() * 0.8
    draw_texture_rect(
        horse,
        Rect2((_HORSE_GROUND - Vector2(horse_shown.x * 0.5, horse_shown.y)).round(), horse_shown),
        false
    )
    var rider := Painting.rider(looks.get("rider", "1"))
    var shown := rider.get_size() * 0.7
    draw_texture_rect(
        rider, Rect2((_RIDER_FEET - Vector2(shown.x * 0.5, shown.y)).round(), shown), false
    )

    if _sparkle <= 0.0:
        return
    # NOTE (mristin):
    # The sparkle: golden stars burst out of the rider and her horse and fade.
    var spent := 1.0 - _sparkle / SPARKLE_SECONDS
    var small := Icons.star(1.0)
    for i in range(24):
        var angle := i * TAU / 24.0 + (i % 3) * 0.2
        var center := Vector2(300, 420) if i % 2 == 0 else Vector2(120, 400)
        var at := center + Vector2(cos(angle), sin(angle)) * (20.0 + spent * (90.0 + (i % 4) * 20))
        draw_texture(small, at.round(), Color(1, 1, 1, 1.0 - spent))
