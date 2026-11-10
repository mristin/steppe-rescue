extends SceneTree
## Check the pixel art: every vector picture becomes pixels of the palette at
## the density of the screen, the portraits are 128x128 in the palette, and
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
    var palette := {}
    for color in Palette.COLORS:
        palette[(color as Color).to_html()] = true
    palette[Color(0, 0, 0, 0).to_html()] = true

    # NOTE (mristin):
    # Every vector picture reads as SVG and becomes pixels of the palette.
    var pictures := {}
    for name in Icons.all():
        pictures["icon " + name] = Icons.of(Icons.all()[name], 2.0)
    for hat in FrontView.all():
        var looks := Looks.DEFAULT.duplicate()
        looks["hat"] = hat
        pictures["hat " + hat] = FrontView.hat(looks, 32.0)
    for feature in Looks.OPTIONS:
        for option in Looks.OPTIONS[feature]:
            var looks := Looks.DEFAULT.duplicate()
            looks[feature] = option
            pictures["rider %s=%s" % [feature, option]] = SideView.texture(looks, 0, 0, true, 2.0)
    for hair in Looks.OPTIONS["hair"]:
        for hat in Looks.OPTIONS["hat"]:
            var looks := Looks.DEFAULT.duplicate()
            looks["hair"] = hair
            looks["hat"] = hat
            pictures["overlay %s %s" % [hair, hat]] = FrontView.overlay(looks, 10.0)
    for pose in [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0], [0.5, 0.6]]:
        pictures["figure %s" % [pose]] = FrontView.figure(Looks.DEFAULT, pose[0], pose[1], 10.0)
    pictures["map of the levels"] = SteppeMap.pixelated(3)
    var all_finery := Looks.DEFAULT.duplicate()
    all_finery["finery"] = {}
    for piece in Finery.PIECES:
        all_finery["finery"][piece] = Finery.PIECES[piece]["steps"]
        for at in range(1, Finery.PIECES[piece]["steps"] + 1):
            pictures["reward %s %d" % [piece, at]] = Reward.preview(piece, at, Looks.DEFAULT)
    pictures["rider in all the finery"] = SideView.texture(all_finery, 3, 1, true, 3.0)
    pictures["figure in all the finery"] = FrontView.figure(all_finery, 0.5, 0.5, 10.0)
    pictures["overlay in all the finery"] = FrontView.overlay(all_finery, 10.0)
    for kind in Wildlife.KINDS:
        for frame in range(2):
            pictures["wild %s %d" % [kind, frame]] = TopDown.texture(
                "test_wild_%s_%d" % [kind, frame], WildShapes.of(kind, frame), 0.4
            )

    # NOTE (mristin):
    # The overlay shows the hair and the finery, not only the hat.
    var plain := {"hair": "short", "hat": "takiya", "finery": {}}
    var braids := {"hair": "two_braids", "hat": "takiya", "finery": {"earrings": 1}}
    _check(
        (
            _opaque(FrontView.overlay(braids, 10.0).get_image())
            > _opaque(FrontView.overlay(plain, 10.0).get_image())
        ),
        "the braids show in the overlay"
    )
    for gait in range(4):
        for frame in range(2):
            pictures["horse %d %d" % [gait, frame]] = SideView.texture(Looks.DEFAULT, gait, frame)
    for id in ["sheep", "horse", "camel"]:
        pictures["from above " + id] = TopDown.texture(id, TopDown.animal(id, 0), 0.7)
    for picture in Landmark.contact_sheet():
        pictures["landmark %d" % pictures.size()] = picture
    for name in pictures:
        var texture: ImageTexture = pictures[name]
        var image := texture.get_image()
        _check(
            image.get_size() == Vector2i(texture.get_size()) * Pixelate.DENSITY,
            "the picture %s has %d pixels per logical pixel" % [name, Pixelate.DENSITY]
        )
        _check(_off_palette(image, palette).is_empty(), "the picture %s is off the palette" % name)
        _check(_opaque(image) > 0, "the picture %s is empty" % name)

    for id in Icons.PORTRAITS:
        # NOTE (mristin):
        # The portraits are paintings, not pixel art.
        var image := Icons.portrait(id).get_image()
        _check(image.get_size() == Vector2i(128, 128), "the portrait %s is 128x128" % id)
        _check(Icons.person_above(id) != null, "%s is painted from above" % id)

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

    _finish()


func _finish() -> void:
    if _failures.is_empty():
        print("RESULT: OK")
        quit(0)
    else:
        print("RESULT: FAILED (%d)" % _failures.size())
        quit(1)


func _off_palette(image: Image, palette: Dictionary) -> Dictionary:
    var strange := {}
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var html := image.get_pixel(x, y).to_html()
            if not palette.has(html):
                strange[html] = true
    return strange


func _opaque(image: Image) -> int:
    var count := 0
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            if image.get_pixel(x, y).a > 0.0:
                count += 1
    return count
