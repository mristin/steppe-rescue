class_name Grammar
extends RefCounted

## Fill the placeholders of a translated sentence with the right grammatical
## forms (see section 10 of DESIGN.md and CONTRIBUTING.md).
##
## Russian and Kazakh decline the names of the landmarks, so a translation may
## ask for:
##
## * a form of an inserted name: [code]{landmark@near}[/code] takes the form of
##   the landmark's name with the context "near" from the .po file, e.g.,
##   "у родника" or "бұлақтың жанында". Without such a form, the plain name
##   stands.
## * a noun which agrees with a number: [code]{count|овца|овцы|овец}[/code]
##   picks the form for the number of [code]{count}[/code] by the plural rule of
##   the language (English and Kazakh: one, other; Russian: one, few, many).
##
## The values of the arguments are English message IDs (translated here, with
## the asked form), numbers, or names which stand as they are (see [method
## verbatim]), e.g., the name the player wrote, which must not be translated
## even if it is also a message (e.g., "Dana").

static var _placeholder := RegEx.create_from_string("\\{([a-z_]+)(@[a-z_]+|\\|[^{}]*)?\\}")


## A value of an argument which stands as it is, untranslated (see [method
## format]).
static func verbatim(value: String) -> Dictionary:
    return {"verbatim": value}


static func format(text: String, args: Dictionary) -> String:
    var result := ""
    var at := 0
    for found in _placeholder.search_all(text):
        result += text.substr(at, found.get_start() - at)
        at = found.get_end()
        var key := found.get_string(1)
        if not args.has(key):
            result += found.get_string()
            continue
        result += _fill(args[key], found.get_string(2))
    return result + text.substr(at)


static func _fill(value: Variant, how: String) -> String:
    if how.begins_with("|"):
        var forms := how.substr(1).split("|")
        return forms[mini(plural_index(int(value)), forms.size() - 1)]
    if value is Dictionary and (value as Dictionary).has("verbatim"):
        return (value as Dictionary)["verbatim"]
    if not value is String:
        return str(value)
    if how.begins_with("@"):
        var form := String(TranslationServer.translate(value, how.substr(1)))
        if form != value:
            return form
    return String(TranslationServer.translate(value))


## Which form of a noun goes with the number in the current language: 0 for
## one, 1 for a few (Russian: 2 to 4), 2 for many.
static func plural_index(count: int) -> int:
    var language := TranslationServer.get_locale().left(2)
    if language in ["ru", "uk"]:
        var last := absi(count) % 10
        var last_two := absi(count) % 100
        if last == 1 and last_two != 11:
            return 0
        if last >= 2 and last <= 4 and (last_two < 12 or last_two > 14):
            return 1
        return 2
    return 0 if count == 1 else 1
