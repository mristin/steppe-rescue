extends SceneTree
## Check the pixel art: every sprite is a proper rectangle of known colors, and
## the pixel font has every letter of every language and translation.

const _FONT := "res://assets/fonts/unifont/unifont-16.0.04.otf"

var _failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
    if not condition:
        print("FAIL ", message)
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    var sprites: Dictionary = Sprites.all()
    for name in sprites:
        for problem in PixelSprite.problems(name, sprites[name]):
            _check(false, problem)

    var font: FontFile = load(_FONT)
    var texts := PackedStringArray()
    var listing: JSON = load("res://translations/languages.json")
    for language in listing.data:
        texts.append(language["name"])
        texts.append(language["prompt"])
        texts.append(language["alphabet"])
        texts.append((language["alphabet"] as String).to_lower())

    for code in ["ru", "kk"]:
        var text := FileAccess.get_file_as_string("res://translations/%s.po" % code)
        _check(text != "", "the translation %s is missing" % code)
        for line in text.split("\n"):
            if line.begins_with("msgstr ") or line.begins_with("msgid "):
                texts.append(line)

    var missing := {}
    for text in texts:
        for character in text:
            if character.unicode_at(0) < 32:
                continue
            if not font.has_char(character.unicode_at(0)):
                missing[character] = true
    _check(missing.is_empty(), "the font misses the letters: %s" % "".join(missing.keys()))

    if _failures.is_empty():
        print("RESULT: OK")
        quit(0)
    else:
        print("RESULT: FAILED (%d)" % _failures.size())
        quit(1)
