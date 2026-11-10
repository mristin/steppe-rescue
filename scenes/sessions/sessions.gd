class_name Sessions
extends Control

## Let the players choose their journey (see section 9 of DESIGN.md), like
## the voyages of Bird Dog: Continue the last journey (it shows its name, its
## rider and her stars), start a New journey (named next, then its rider is
## created), or go on with one of the other recent journeys. Change rider
## opens the creator for the rider of the current journey.
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
        _continue.picture = Painting.rider(_sessions[0]["looks"].get("rider", "1"), true)
        _continue.pressed.connect(func() -> void: choose(0))
        _names.append(
            _label(Rect2(_CONTINUE.position.x, _CONTINUE.end.y + 6, _CONTINUE.size.x, 20))
        )

    for i in range(1, mini(_sessions.size(), OTHERS + 1)):
        var rect := Rect2(Vector2(_OTHERS_LEFT + (i - 1) * (_OTHER.x + 12.0), _OTHERS_TOP), _OTHER)
        var card := _button(rect)
        card.picture = Painting.rider(_sessions[i]["looks"].get("rider", "1"), true)
        card.pressed.connect(func() -> void: choose(i))
        _others.append(card)
        _names.append(_label(Rect2(rect.position.x, rect.end.y + 6, rect.size.x, 20)))

    _new = _button(Rect2(_OTHERS_LEFT, 84, 3 * _OTHER.x + 24.0, 72))
    _new.font_size = 32
    _new.primary = _sessions.is_empty()
    _new.pressed.connect(start_new)

    _change = _button(Rect2(_OTHERS_LEFT, 470, 260, 52))
    _change.visible = profile.has_rider
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
        var rider: String = session["rider"] if session["rider"] != "" else tr("Aigerim")
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
