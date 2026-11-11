class_name Sessions
extends Control

## Let the players choose their journey (see section 9 of DESIGN.md), like
## the voyages of Bird Dog: Continue the last journey (it shows its name, its
## riders and their stars), start a New journey (named next, then the players
## choose whether one or two ride, and create their riders), or go on with one
## of the other recent journeys. Change rider opens the creator for the riders
## of the current journey.
##
## It shows on the way from Play once each start, when there is a journey
## already, and from the settings.
##
## Keys: Enter continues, N starts a new journey, 1 to 3 choose another
## journey, Escape goes back.

## The most other journeys shown next to the last one.
const OTHERS := 3

const _CONTINUE := Rect2(36, 84, 260, 330)
const _OTHER := Vector2(176, 236)
const _OTHERS_LEFT := 330.0
const _OTHERS_TOP := 178.0

var _sessions: Array[Dictionary] = []
var _continue: DwellButton = null
var _others: Array[DwellButton] = []
var _names: Array[Label] = []
var _new: DwellButton
var _change: DwellButton
var _back: DwellButton
var _title: Label


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    var profile := get_node("/root/Profile")
    _sessions = profile.sessions()

    _title = _label(Rect2(0, 22, 960, 32), 32)

    # NOTE (mristin):
    # The last journey is the current one, if there is one.
    var last: String = profile.session_id if profile.session_id != "" else profile.last_id()
    var ordered: Array[Dictionary] = []
    for session in _sessions:
        if session["id"] == last:
            ordered.push_front(session)
        else:
            ordered.append(session)
    _sessions = ordered

    if not _sessions.is_empty():
        _continue = _button(_CONTINUE)
        _continue.primary = true
        _continue.font_size = 32
        _continue.picture = _picture(_sessions[0])
        _continue.pressed.connect(func() -> void: choose(0))
        _names.append(
            _label(Rect2(_CONTINUE.position.x, _CONTINUE.end.y + 6, _CONTINUE.size.x, 20))
        )

    for i in range(1, mini(_sessions.size(), OTHERS + 1)):
        var rect := Rect2(Vector2(_OTHERS_LEFT + (i - 1) * (_OTHER.x + 12.0), _OTHERS_TOP), _OTHER)
        var card := _button(rect)
        card.picture = _picture(_sessions[i])
        card.pressed.connect(func() -> void: choose(i))
        _others.append(card)
        _names.append(_label(Rect2(rect.position.x, rect.end.y + 6, rect.size.x, 20)))

    _new = _button(Rect2(_OTHERS_LEFT, 84, 3 * _OTHER.x + 24.0, 72))
    _new.font_size = 32
    _new.primary = _sessions.is_empty()
    _new.pressed.connect(start_new)

    _change = _button(Rect2(_OTHERS_LEFT, 470, 260, 52))
    _change.visible = profile.has_riders()
    _change.pressed.connect(
        func() -> void: Flow.open(get_tree(), Flow.RIDER_CREATOR, Flow.SESSIONS)
    )
    _back = _button(Rect2(744, 470, 200, 52))
    _back.text = tr("Back")
    _back.pressed.connect(func() -> void: Flow.cancel(get_tree()))

    add_child(HandCursor.new())
    _update_texts()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _title != null:
        _update_texts()


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    match event.keycode:
        KEY_ESCAPE:
            Flow.cancel(get_tree())
        KEY_ENTER, KEY_KP_ENTER:
            choose(0)
        KEY_N:
            start_new()
        KEY_1, KEY_2, KEY_3:
            choose(event.keycode - KEY_1 + 1)


## Go on with the journey of the index (0 is the last one), and go on.
func choose(i: int) -> void:
    if i < 0 or i >= mini(_sessions.size(), OTHERS + 1):
        return
    get_node("/root/Profile").choose_session(_sessions[i]["id"])
    Flow.session_asked = true
    Flow.next(get_tree())


## Name a new journey; then its rider is created.
func start_new() -> void:
    Flow.open(get_tree(), Flow.SESSION_NAME, Flow.SESSIONS)


## The journeys on the screen, the last one first, for the tests.
func shown() -> Array[Dictionary]:
    return _sessions.slice(0, OTHERS + 1)


func _update_texts() -> void:
    # TRANSLATORS: The title of the screen where the players choose their journey (a saved game).
    _title.text = tr("Your journeys")
    for i in range(_names.size()):
        var session: Dictionary = _sessions[i]
        var rider := _names_of(session)
        var card: DwellButton = _continue if i == 0 else _others[i - 1]
        if i == 0:
            # TRANSLATORS: The button which goes on with the last journey.
            card.text = tr("Continue")
            _names[i].text = "%s · %s ★%d" % [session["name"], rider, session["stars"]]
        else:
            card.text = "%s ★%d" % [rider, session["stars"]]
            _names[i].text = session["name"]
    # TRANSLATORS: The button which starts a new journey (a new saved game).
    _new.text = tr("+ New journey")
    # TRANSLATORS: The button which opens the creator for the rider of the current journey.
    _change.text = tr("Change rider")
    _back.text = tr("Back")


## The painted riders of the journey on its card: one, or two side by side.
func _picture(session: Dictionary) -> Texture2D:
    var riders: Array = session["riders"]
    if riders.size() < 2:
        var looks: Dictionary = riders[0]["looks"] if not riders.is_empty() else Looks.DEFAULT
        return Painting.rider(looks.get("rider", "1"), true)
    var images: Array[Image] = []
    var width := 0
    var height := 0
    for each in riders:
        var image := Painting.rider(each["looks"].get("rider", "1"), true).get_image()
        image.convert(Image.FORMAT_RGBA8)
        # NOTE (mristin):
        # Two riders share the card, each at a little less than her size.
        image.resize(
            image.get_width() * 3 / 4, image.get_height() * 3 / 4, Image.INTERPOLATE_LANCZOS
        )
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


## The names of the riders of the journey, e.g., "Aigerim and Dana".
func _names_of(session: Dictionary) -> String:
    var names: Array[String] = []
    var riders: Array = session["riders"]
    for i in range(riders.size()):
        var written: String = riders[i]["name"]
        if written == "":
            written = tr("Aigerim") if i == 0 else tr("Dana")
        names.append(written)
    if names.is_empty():
        return tr("Aigerim")
    if names.size() == 1:
        return names[0]
    return tr("{first} and {second}").format({"first": names[0], "second": names[1]})


func _label(rect: Rect2, font_size := 16) -> Label:
    var label := Label.new()
    label.position = rect.position
    label.size = rect.size
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.clip_text = true
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Palette.FELT)
    label.add_theme_color_override("font_outline_color", Palette.OUTLINE)
    label.add_theme_constant_override("outline_size", 6)
    add_child(label)
    return label


func _button(rect: Rect2) -> DwellButton:
    var button := DwellButton.new()
    button.position = rect.position
    button.size = rect.size
    add_child(button)
    return button


func _draw() -> void:
    draw_texture(IntroPicture.background(), Vector2.ZERO)
