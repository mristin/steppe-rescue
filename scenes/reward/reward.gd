class_name Reward
extends Control

## Reward the rider at the end of a level (see section 8 of DESIGN.md): at
## home, in front of the yurt, she stands next to her horse, with the
## decorations of the home she won, and chooses one new piece of three, shown
## on big cards as a painting of the piece, with its name and its Kazakh
## word. The choice rings with a sparkle and a tune; Go on leads to the level
## select, and Wardrobe to the choice of what to wear. More stars offer the
## more splendid pieces (see [method Finery.offer]). A level gives its gift
## only once: riding it again shows the home without cards.
##
## Keys: 1, 2 and 3 choose a card, Enter goes on, Escape goes on, too.

## The painting of the home, the yurt at sunset, behind the rider.
const HOME := "res://assets/pictures/home/reward.png"

## Where the pieces of the finery go on the painted horses, which all stand
## alike, in profile, facing right: [piece, x, y, width], as fractions of the
## picture of the horse, in the order they are laid on. The braided mane and
## its ribbons, close-ups of a mane, show only on their cards.
const _ON_HORSE := [
    ["saddle_cloth", 0.5, 0.37, 0.34],
    ["stirrups", 0.5, 0.6, 0.1],
    ["saddle", 0.5, 0.3, 0.28],
    ["breastplate", 0.77, 0.43, 0.14],
    ["bridle", 0.88, 0.2, 0.16],
    ["mane", 0.76, 0.13, 0.07, 3],
]

## Where the pieces go on the painted riders, who all stand alike, facing the
## viewer. The coat shows only on its card and in the camera picture; the
## earrings only in the camera picture, since the painted girls wear their
## own.
const _ON_RIDER := [
    ["boots", 0.5, 0.925, 0.58],
    ["belt", 0.5, 0.45, 0.46],
    ["bracelets", 0.2, 0.62, 0.11],
    ["bracelets", 0.8, 0.62, 0.11],
    ["feathers", 0.5, 0.0, 0.3],
]

## Where the decorations of the home go in the painting of the home: the
## felt carpet in front of the door, the carved door in the doorway, and the
## dombra leaning against the barrel.
const _DECORATIONS := {
    "carpet": Rect2(592, 340, 276, 72),
    "door": Rect2(733, 200, 118, 152),
    "dombra": Rect2(612, 230, 56, 130),
}

## The rider stands here, in front of her horse.
const _RIDER_FEET := Vector2(110, 512)
const _HORSE_GROUND := Vector2(250, 492)

const _CARD := Vector2(160, 196)
const _CARDS_TOP := 150.0
const _PICTURE := Vector2(128, 116)

## How long the sparkle lasts, in seconds.
const SPARKLE_SECONDS := 1.6

static var _pictures: Dictionary = {}

## The pieces on offer, as [piece, step] pairs.
var offered: Array = []

## The piece chosen; empty until the player chooses.
var chosen := ""

## The stars won in the level.
var stars := 0

## Whether the level gave its gift before.
var replayed := false

var _cards: Array[DwellButton] = []
var _subtitles: Array[Label] = []
var _title: Label
var _go_on: DwellButton
var _wardrobe: DwellButton
var _sparkle := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    _rng.randomize()
    var profile := get_node("/root/Profile")
    stars = Flow.reward_stars
    replayed = profile.was_rewarded(Flow.reward_level)
    offered = [] if replayed else Finery.offer(profile.finery, stars, _rng)

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
    _wardrobe = DwellButton.new()
    _wardrobe.position = Vector2(810, 448)
    _wardrobe.size = Vector2(130, 44)
    _wardrobe.visible = _go_on.visible
    _wardrobe.pressed.connect(
        func() -> void: Flow.open(get_tree(), Flow.WARDROBE, Flow.LEVEL_SELECT)
    )
    add_child(_wardrobe)

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
    get_node("/root/Profile").reward(Flow.reward_level)
    for i in range(_cards.size()):
        _cards[i].visible = i == index
        _subtitles[i].visible = i == index
        _cards[i].selected = i == index
    _sparkle = SPARKLE_SECONDS
    get_node("/root/Sounds").play("tune")
    _go_on.visible = true
    _wardrobe.visible = true
    _update_texts()


## Go on to the level select.
func go_on() -> void:
    Flow.open(get_tree(), Flow.LEVEL_SELECT)


## The cards, for the tests.
func cards() -> Array[DwellButton]:
    return _cards


## Draw the home on the item: the yurt at sunset, with the decorations of the
## home which the rider wears (see [Finery]), and the painted rider standing
## in front of her painted horse; with [param spotlight], the home is dimmed
## and the rider and her horse stand in a golden light (the wardrobe).
static func draw_home(item: CanvasItem, profile: Node, spotlight := false) -> void:
    item.draw_texture(Painting.texture(HOME), Vector2.ZERO)
    if spotlight:
        _draw_spotlight(item)
    for piece in _DECORATIONS:
        if profile.wears(piece) and Finery.has_picture(piece, 1):
            var at: Rect2 = _DECORATIONS[piece]
            item.draw_texture_rect(
                Painting.fitted(Finery.PICTURES % [piece, 1], at.size), at, false
            )
    var looks: Dictionary = profile.dressed()
    var horse := Painting.horse(looks.get("steed", "1"))
    var horse_shown := horse.get_size() * 0.8
    var horse_rect := Rect2(
        (_HORSE_GROUND - Vector2(horse_shown.x * 0.5, horse_shown.y)).round(), horse_shown
    )
    item.draw_texture_rect(horse, horse_rect, false)
    dress(item, horse_rect, looks, "horse")
    var rider := Painting.rider(looks.get("rider", "1"))
    var shown := rider.get_size() * 0.7
    var rider_rect := Rect2((_RIDER_FEET - Vector2(shown.x * 0.5, shown.y)).round(), shown)
    item.draw_texture_rect(rider, rider_rect, false)
    dress(item, rider_rect, looks, "rider")


## Dim the home, and light the place where the rider and her horse stand.
static func _draw_spotlight(item: CanvasItem) -> void:
    item.draw_rect(Rect2(0, 0, 960, 540), Color(Palette.NIGHT, 0.55))
    var middle := Vector2(200, 410)
    for i in range(10):
        var t := float(i) / 10.0
        var radius := lerpf(240.0, 60.0, t)
        item.draw_set_transform(middle, 0.0, Vector2(1.0, 0.8))
        item.draw_circle(Vector2.ZERO, radius, Color(Palette.GOLD, 0.07 + 0.04 * t))
    item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    # NOTE (mristin):
    # A golden ring on the ground, where they stand.
    item.draw_set_transform(Vector2(185, 506), 0.0, Vector2(1.0, 0.22))
    item.draw_circle(Vector2.ZERO, 150.0, Color(Palette.GOLD, 0.35))
    item.draw_arc(Vector2.ZERO, 150.0, 0.0, TAU, 64, Palette.GOLD, 6.0, true)
    item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Lay the painted finery which she wears over the painted horse (or rider)
## drawn in the rectangle, at the places where the pieces go (see
## [constant _ON_HORSE] and [constant _ON_RIDER]).
static func dress(item: CanvasItem, rect: Rect2, looks: Dictionary, who: String) -> void:
    var places: Array = _ON_HORSE if who == "horse" else _ON_RIDER
    for place in places:
        var piece: String = place[0]
        var at := Finery.step(looks, piece)
        if at < 1 or (place.size() > 4 and at != place[4]):
            continue
        var path := Finery.PICTURES % [piece, at]
        if not ResourceLoader.exists(path):
            continue
        if not _pictures.has(path):
            _pictures[path] = load(path)
        var picture: Texture2D = _pictures[path]
        var center := rect.position + Vector2(place[1], place[2]) * rect.size
        var width: float = place[3] * rect.size.x
        var size := Vector2(width, width * picture.get_height() / picture.get_width())
        item.draw_texture_rect(picture, Rect2((center - size * 0.5).round(), size), false)


## The painting of the step of the piece (see assets/pictures/finery/), as
## the card shows it.
static func preview(piece: String, at: int, _looks := {}) -> ImageTexture:
    return Painting.fitted(Finery.PICTURES % [piece, at], _PICTURE)


func _update_texts() -> void:
    var rider_name: String = get_node("/root/Profile").rider_name()
    if replayed:
        # TRANSLATORS: {rider} is the rider's name; she rode a level again, whose gift she won before.
        _title.text = tr("Well done, {rider}! This ride gave its gift already.").format(
            {"rider": rider_name}
        )
    elif offered.is_empty():
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
    _wardrobe.text = tr("Wardrobe")


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
        # TRANSLATORS: The felt carpet of the yurt, сырмақ.
        "carpet": [tr("Felt carpet")],
        # TRANSLATORS: The carved and painted door of the yurt.
        "door": [tr("Carved door")],
        # TRANSLATORS: The dombra, the two-stringed lute, hanging at home.
        "dombra": [tr("Dombra")],
    }
    var steps: Array = names.get(piece, [piece])
    return steps[clampi(at - 1, 0, steps.size() - 1)]


func _draw() -> void:
    draw_home(self, get_node("/root/Profile"))
    draw_texture(Ornaments.panel(Vector2(540, 70)), Vector2(410, 14))
    var star := Icons.star(2.0)
    for i in range(3):
        var tint := Color.WHITE if i < stars else Color(0.25, 0.2, 0.15, 0.55)
        draw_texture(star, Vector2(644 + i * 28, 58), tint)

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
