class_name OnScreenKeyboard
extends Control

## Show the letters of the language of the game as big keys (see section 6 of
## DESIGN.md), so that the player can write a name with the hand cursor: the
## Latin, the Russian or the Kazakh alphabet, from translations/languages.json,
## and a key to take back the last letter.

## A key was pressed: a letter, or [constant BACKSPACE].
signal typed(letter: String)

const BACKSPACE := "⌫"

const _KEY := Vector2(38, 32)
const _GAP := 6.0

var _keys: Array[DwellButton] = []


## Lay out the keys of the alphabet in the rectangle (in rows from the top).
func build(alphabet: String) -> void:
    for key in _keys:
        key.queue_free()
    _keys.clear()

    var letters: Array[String] = []
    for letter in alphabet:
        letters.append(letter)
    letters.append(BACKSPACE)

    var per_row := maxi(1, int((size.x + _GAP) / (_KEY.x + _GAP)))
    var rows := ceili(float(letters.size()) / per_row)
    per_row = ceili(float(letters.size()) / rows)
    for i in range(letters.size()):
        var row := i / per_row
        var column := i % per_row
        var in_row := mini(per_row, letters.size() - row * per_row)
        var row_width := in_row * _KEY.x + (in_row - 1) * _GAP
        var left := roundf((size.x - row_width) * 0.5)
        var key := DwellButton.new()
        key.text = letters[i]
        key.font_size = 16 if letters[i] != BACKSPACE else 16
        key.position = Vector2(left + column * (_KEY.x + _GAP), row * (_KEY.y + _GAP))
        key.size = _KEY
        var letter := letters[i]
        key.pressed.connect(func() -> void: typed.emit(letter))
        add_child(key)
        _keys.append(key)


## The keys, for the tests.
func keys() -> Array[DwellButton]:
    return _keys
