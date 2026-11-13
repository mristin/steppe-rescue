extends RefCounted
## Press the keys of the keyboard as a player does, for the tests which play
## the game (see test_playthrough.gd): the events go through [Input], so the
## game sees them as from a real keyboard, both as events (e.g., a squat) and
## as keys held down (e.g., a turn).
##
## Not a test itself (its name does not start with test_), it is preloaded by
## the tests.

## The keys held down now.
static var _held := {}


static func _event(key: Key, pressed: bool) -> InputEventKey:
    var event := InputEventKey.new()
    event.keycode = key
    event.physical_keycode = key
    event.pressed = pressed
    return event


## Press the key and keep it down.
static func press(key: Key) -> void:
    if _held.has(key):
        return
    _held[key] = true
    Input.parse_input_event(_event(key, true))


## Let the key go.
static func release(key: Key) -> void:
    if not _held.has(key):
        return
    _held.erase(key)
    Input.parse_input_event(_event(key, false))


## Keep the key down or let it go.
static func hold(key: Key, down: bool) -> void:
    if down:
        press(key)
    else:
        release(key)


## Press the key and let it go at once.
static func tap(key: Key) -> void:
    release(key)
    Input.parse_input_event(_event(key, true))
    Input.parse_input_event(_event(key, false))


## Let all the keys go, e.g., when the screen changes.
static func release_all() -> void:
    for key in _held.keys():
        release(key)


## Write the text on the keyboard, letter by letter.
static func write(text: String) -> void:
    for letter in text:
        for pressed in [true, false]:
            var event := InputEventKey.new()
            event.unicode = letter.unicode_at(0)
            event.pressed = pressed
            Input.parse_input_event(event)
