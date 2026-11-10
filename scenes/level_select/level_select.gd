class_name LevelSelect
extends Control

## Let the player choose a level (see section 6 of DESIGN.md): the painted map
## of the steppe around the home aul (see [SteppeMap]), where the rider stands
## by the yurts, with a banner over the spot of each open level, showing its
## name and the stars she won, and the number of the level on its spot. The
## next level to play is crimson. The levels not open yet show only their
## number, on a stone; finishing a level opens the next one (see [LevelList]).
##
## Keys: Enter plays the next level, Escape goes back.

const _BANNER := Vector2(200, 40)

var _banners: Array[DwellButton] = []
var _paths: Array[String] = []
var _back: DwellButton
var _next := ""


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    var profile := get_node("/root/Profile")
    _next = LevelList.next(profile)
    var all := LevelList.paths()
    for i in range(mini(all.size(), SteppeMap.SPOTS.size())):
        var path: String = all[i]
        _paths.append(path)
        if not LevelList.is_open(path, profile):
            _banners.append(null)
            continue
        var spot: Vector2 = SteppeMap.SPOTS[i]
        var banner := DwellButton.new()
        banner.position = Vector2(spot.x - _BANNER.x * 0.5, spot.y - _BANNER.y - 24)
        banner.size = _BANNER
        banner.primary = path == _next
        banner.pressed.connect(func() -> void: Flow.play(get_tree(), path))
        add_child(banner)
        _banners.append(banner)

    _back = DwellButton.new()
    _back.position = Vector2(24, 476)
    _back.size = Vector2(150, 44)
    _back.pressed.connect(func() -> void: Flow.cancel(get_tree()))
    add_child(_back)

    add_child(HandCursor.new())
    _update_texts()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _back != null:
        _update_texts()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE:
                Flow.cancel(get_tree())
            KEY_ENTER, KEY_KP_ENTER:
                if _next != "":
                    Flow.play(get_tree(), _next)


## The banners of the levels in their order, null for a level not open yet,
## for the tests.
func banners() -> Array[DwellButton]:
    return _banners


func _update_texts() -> void:
    for i in range(_banners.size()):
        if _banners[i] != null:
            _banners[i].text = tr(LevelList.title(_paths[i]))
    _back.text = tr("Back")


func _draw() -> void:
    draw_texture(SteppeMap.texture(_paths.size()), Vector2.ZERO)

    var rider := Painting.texture("res://assets/pictures/instruction/rider_on_horse.png")
    var shown := rider.get_size() * 0.32
    var feet := SteppeMap.AUL + Vector2(150, 70)
    draw_texture_rect(rider, Rect2((feet - Vector2(shown.x * 0.5, shown.y)).round(), shown), false)

    var profile := get_node("/root/Profile")
    var font := get_theme_default_font()
    for i in range(_paths.size()):
        var spot: Vector2 = SteppeMap.SPOTS[i]
        var open := _banners[i] != null
        if open:
            # NOTE (mristin):
            # The pole from the spot up to the banner, and the stars under it.
            draw_rect(Rect2(spot.x - 1, spot.y - 24, 2, 14), Palette.HOOF)
            var won: int = profile.stars.get(LevelList.id(_paths[i]), 0)
            var star := Icons.star(1.0)
            for s in range(3):
                var at := Vector2(spot.x - 21 + s * 15, spot.y - 23)
                var tint := Color.WHITE if s < won else Color(0.25, 0.2, 0.15, 0.55)
                draw_texture(star, at.round(), tint)
        var fill := Palette.CRIMSON if open else Palette.STONE
        draw_circle(spot, 11.0, Palette.OUTLINE)
        draw_circle(spot, 9.0, fill)
        draw_circle(spot, 9.0, Palette.GOLD if open else Palette.STONE_LIGHT, false, 1.0)
        var number := str(i + 1)
        var width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
        draw_string(
            font,
            Vector2(spot.x - width * 0.5, spot.y - 8 + font.get_ascent(16)).round(),
            number,
            HORIZONTAL_ALIGNMENT_LEFT,
            -1,
            16,
            Palette.FELT
        )
