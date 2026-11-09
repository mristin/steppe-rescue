extends Node

## Know the languages of the game, choose one, and remember it.
##
## The languages are listed in `res://translations/languages.json`, each with its
## code, its name in itself, "Choose your language" in itself, and its alphabet
## (for the keyboard on the screen, on which the player types the name of her
## rider and her horse). That list
## is the only place to add a language: the translations
## (`res://translations/<code>.po`) are registered from it here, the language
## select shows it, and the tools in
## dev/translations/ create and check the .po files from it.
##
## The language which the players chose is saved in `user://settings.cfg` and
## used from then on. Start the game with `-- --lang=<code>` to override it.
##
## The game always shows the whole translation of the chosen language. The
## fuzzy mark of a message in the .po files only tells the translators that a
## native speaker has not reviewed it yet (see CONTRIBUTING.md); since Godot
## would skip the fuzzy messages and show English for them, we load the
## translations with the fuzzy marks removed (see [method _load_translation]).

const SOURCE_LANGUAGE := "en"

const _LIST_PATH := "res://translations/languages.json"
const _SETTINGS_PATH := "user://settings.cfg"
const _TRANSLATIONS_DIR := "user://translations"

## The languages in the order of the list, each a dictionary with "code",
## "name", "prompt" and "alphabet".
var languages: Array[Dictionary] = []

## Whether the language was chosen before (or given on the command line).
var has_chosen := false


func _ready() -> void:
    var listing: JSON = load(_LIST_PATH)
    for entry in listing.data:
        languages.append(entry)

    for code in codes():
        if code == SOURCE_LANGUAGE:
            continue
        var translation := _load_translation(code)
        if translation != null:
            TranslationServer.add_translation(translation)

    var settings := ConfigFile.new()
    if settings.load(_SETTINGS_PATH) == OK:
        var saved: String = settings.get_value("general", "language", "")
        if saved in codes():
            TranslationServer.set_locale(saved)
            has_chosen = true

    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--lang="):
            var code := arg.get_slice("=", 1)
            if code in codes():
                TranslationServer.set_locale(code)
                has_chosen = true
            else:
                push_warning("Unknown language %s; we know %s." % [code, codes()])

    if not has_chosen:
        TranslationServer.set_locale(SOURCE_LANGUAGE)


## The codes of all the languages, e.g., ["en", "ru", "kk"].
func codes() -> Array[String]:
    var result: Array[String] = []
    for language in languages:
        result.append(language["code"])
    return result


## The code of the language of the game now, e.g., "kk".
func current() -> String:
    var locale := TranslationServer.get_locale()
    for code in codes():
        if locale == code or locale.begins_with(code + "_"):
            return code
    return SOURCE_LANGUAGE


## The letters of the language of the game now, in upper case.
func alphabet() -> String:
    for language in languages:
        if language["code"] == current():
            return language["alphabet"]
    return "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


## Switch to the language and remember it for the next start.
func choose(code: String) -> void:
    if code not in codes():
        push_warning("Unknown language %s; we know %s." % [code, codes()])
        return
    TranslationServer.set_locale(code)
    has_chosen = true

    var settings := ConfigFile.new()
    settings.load(_SETTINGS_PATH)
    settings.set_value("general", "language", code)
    settings.save(_SETTINGS_PATH)


## Load the translation of the language with the fuzzy marks removed, so that
## every translated message shows (Godot skips the fuzzy ones); null if there
## is none.
func _load_translation(code: String) -> Translation:
    var source := "res://translations/%s.po" % code
    if not FileAccess.file_exists(source):
        # NOTE (mristin):
        # Without the text of the .po file (e.g., in an export which left it
        # out), the imported translation, without its fuzzy messages.
        if ResourceLoader.exists(source):
            return load(source)
        push_warning("The translation of %s is missing; run dev/translations/extract.py." % code)
        return null
    var kept := PackedStringArray()
    for line in FileAccess.get_file_as_string(source).split("\n"):
        if line.begins_with("#,") and "fuzzy" in line:
            var flags := line.substr(2).replace("fuzzy", "").replace(",", " ").strip_edges()
            if flags != "":
                kept.append("#, " + ", ".join(flags.split(" ", false)))
            continue
        kept.append(line)
    # NOTE (mristin):
    # Every running game writes a file of its own (several may start at once,
    # e.g., in the tests), loads it, and removes it again.
    DirAccess.make_dir_recursive_absolute(_TRANSLATIONS_DIR)
    var target := "%s/%s_%d.po" % [_TRANSLATIONS_DIR, code, OS.get_process_id()]
    var file := FileAccess.open(target, FileAccess.WRITE)
    if file == null:
        return load(source)
    file.store_string("\n".join(kept))
    file.close()
    var translation: Translation = ResourceLoader.load(target, "", ResourceLoader.CACHE_MODE_IGNORE)
    DirAccess.remove_absolute(target)
    return translation
