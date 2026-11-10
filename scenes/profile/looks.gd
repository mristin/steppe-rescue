class_name Looks
extends RefCounted

## Know the looks of the rider and her horse which the player chooses in the
## creator (see section 6 of DESIGN.md): the options of each feature, their
## colors, the defaults and a random mix.
##
## The looks are a dictionary from the feature (e.g., "hat") to the id of the
## option (e.g., "takiya"), so that they can be saved as they are.

## The options of each feature, in the order of the creator.
const OPTIONS := {
    "rider": ["1", "2", "3", "4"],
    "steed": ["1", "2", "3", "4"],
    "skin": ["fair", "light", "tan", "dark", "deep"],
    "hair": ["two_braids", "one_braid", "bun", "short", "loose"],
    "hair_color": ["black", "dark_brown", "brown", "auburn"],
    "hat": ["takiya", "borik", "scarf", "felt_hat", "none"],
    "coat": ["crimson", "indigo", "emerald", "ochre", "white", "black"],
    "dress": ["crimson", "indigo", "emerald", "ochre", "white", "black"],
    "horse": ["bay", "chestnut", "grey", "black", "dun", "piebald"],
    "marking": ["none", "star", "blaze"],
    "mane": ["black", "dark_brown", "flaxen", "grey"],
}

## The rider of the painting of the intro: two black braids, the crimson
## тақия, the green coat over the crimson dress, on her bay horse with the
## white blaze and the black mane.
const DEFAULT := {
    "rider": "1",
    "steed": "1",
    "skin": "light",
    "hair": "two_braids",
    "hair_color": "black",
    "hat": "takiya",
    "coat": "emerald",
    "dress": "crimson",
    "horse": "bay",
    "marking": "blaze",
    "mane": "black",
}

## The painted riders to choose from (see [method Painting.rider]), each with
## the looks she wears, so that the rest of the game (e.g., the face overlay)
## dresses the player as her.
const PRESETS := {
    "1":
    {
        "skin": "light",
        "hair": "two_braids",
        "hair_color": "black",
        "hat": "takiya",
        "coat": "emerald",
        "dress": "crimson",
    },
    "2":
    {
        "skin": "light",
        "hair": "one_braid",
        "hair_color": "black",
        "hat": "borik",
        "coat": "indigo",
        "dress": "white",
    },
    "3":
    {
        "skin": "light",
        "hair": "bun",
        "hair_color": "dark_brown",
        "hat": "scarf",
        "coat": "ochre",
        "dress": "white",
    },
    "4":
    {
        "skin": "light",
        "hair": "short",
        "hair_color": "dark_brown",
        "hat": "none",
        "coat": "crimson",
        "dress": "white",
    },
}

## The painted horses to choose from (see [method Painting.horse]), each with
## the looks of its coat.
const HORSE_PRESETS := {
    "1": {"horse": "bay", "marking": "blaze", "mane": "black"},
    "2": {"horse": "chestnut", "marking": "none", "mane": "flaxen"},
    "3": {"horse": "grey", "marking": "none", "mane": "grey"},
    "4": {"horse": "dun", "marking": "none", "mane": "black"},
}

const _CLOTH := {
    "crimson": Palette.CRIMSON,
    "indigo": Palette.INDIGO,
    "emerald": Palette.EMERALD,
    "ochre": Palette.OCHRE,
    "white": Palette.FELT,
    "black": Palette.HAIR_BLACK,
}

const _COLORS := {
    "skin":
    {
        "fair": Palette.SKIN_FAIR,
        "light": Palette.SKIN,
        "tan": Palette.SKIN_TAN,
        "dark": Palette.SKIN_DARK,
        "deep": Palette.SKIN_DEEP,
    },
    "hair_color":
    {
        "black": Palette.HAIR_BLACK,
        "dark_brown": Palette.HOOF,
        "brown": Palette.HORSE_BAY,
        "auburn": Palette.CHESTNUT,
    },
    "coat": _CLOTH,
    "dress": _CLOTH,
    "horse":
    {
        "bay": Palette.HORSE_BAY,
        "chestnut": Palette.CHESTNUT,
        "grey": Palette.STONE_LIGHT,
        "black": Palette.HAIR_BLACK,
        "dun": Palette.DUN,
        "piebald": Palette.FELT,
    },
    "mane":
    {
        "black": Palette.HAIR_BLACK,
        "dark_brown": Palette.HOOF,
        "flaxen": Palette.GRASS_LIGHT,
        "grey": Palette.STONE,
    },
}

## The shades of the colors, [shadow, light], for the shading of the drawn
## pictures, by the color as HTML.
const _SHADES := {
    "e0a878": [Palette.SKIN_TAN, Palette.SKIN_FAIR],
    "f2cfae": [Palette.SKIN, Palette.FELT],
    "cf9162": [Palette.SKIN_DARK, Palette.SKIN],
    "b97a52": [Palette.SKIN_DEEP, Palette.SKIN_TAN],
    "8a5634": [Palette.HORSE_BAY, Palette.SKIN_DARK],
    "1f1a1c": [Palette.NIGHT, Palette.HOOF],
    "3b2a20": [Palette.HAIR_BLACK, Palette.HORSE_BAY],
    "7a3f1d": [Palette.HOOF, Palette.HORSE_BAY_LIGHT],
    "9c4a22": [Palette.HORSE_BAY, Palette.OCHRE],
    "b3263a": [Palette.CRIMSON_DARK, Palette.CRIMSON_LIGHT],
    "33417e": [Palette.NIGHT, Palette.INDIGO_LIGHT],
    "2e7d4f": [Palette.NIGHT, Palette.EMERALD_LIGHT],
    "c9822b": [Palette.HORSE_BAY, Palette.GOLD],
    "f4ead5": [Palette.STONE_LIGHT, Palette.FELT],
    "b8b2a8": [Palette.STONE, Palette.FELT],
    "cdb07a": [Palette.OCHRE, Palette.GRASS_LIGHT],
    "f0cf6e": [Palette.GRASS, Palette.FELT],
    "8a8580": [Palette.HOOF, Palette.STONE_LIGHT],
}

## The legs on the far side of the horse are a shade darker, by its coat.
const _FAR_LEGS := {
    "bay": Palette.HOOF,
    "chestnut": Palette.HORSE_BAY,
    "grey": Palette.STONE,
    "black": Palette.NIGHT,
    "dun": Palette.OCHRE,
    "piebald": Palette.STONE_LIGHT,
}


## The shades of the color of the feature: [shadow, base, light].
static func shades(looks: Dictionary, feature: String) -> Array[Color]:
    var base := color(looks, feature)
    var pair: Array = _SHADES.get(base.to_html(false), [base.darkened(0.3), base.lightened(0.3)])
    return [pair[0], base, pair[1]]


## The looks completed with the defaults, without unknown options; the
## finery which the rider wears, if any, is kept (see [Finery]).
static func complete(looks: Dictionary) -> Dictionary:
    var result := DEFAULT.duplicate()
    for feature in OPTIONS:
        if looks.get(feature, "") in OPTIONS[feature]:
            result[feature] = looks[feature]
    if looks.get("finery") is Dictionary:
        result["finery"] = Finery.complete(looks["finery"])
    return result


## The color of the chosen option of the feature (for the features with
## colors: skin, hair_color, coat, dress, horse, mane).
static func color(looks: Dictionary, feature: String) -> Color:
    var colors: Dictionary = _COLORS[feature]
    return colors.get(looks.get(feature, DEFAULT[feature]), colors[DEFAULT[feature]])


## The color of the option of the feature, e.g., for a swatch in the creator;
## transparent if the feature has no colors.
static func option_color(feature: String, option: String) -> Color:
    if not _COLORS.has(feature):
        return Color(0, 0, 0, 0)
    return _COLORS[feature].get(option, Color(0, 0, 0, 0))


## The darker color of the legs on the far side of the horse.
static func far_legs(looks: Dictionary) -> Color:
    return _FAR_LEGS.get(looks.get("horse", "bay"), Palette.HOOF)


## The color of the hat seen from above, or of the hair without a hat.
static func hat_color(looks: Dictionary) -> Color:
    match looks.get("hat", "takiya"):
        "takiya", "scarf":
            return Palette.CRIMSON
        "borik":
            return Palette.HOOF
        "felt_hat":
            return Palette.FELT
    return color(looks, "hair_color")


## The looks of the painted rider of the preset, keeping the horse and the
## finery.
static func preset(looks: Dictionary, id: String) -> Dictionary:
    var result := looks.duplicate()
    result["rider"] = id
    result.merge(PRESETS.get(id, PRESETS[DEFAULT["rider"]]), true)
    return result


## The looks with the painted horse of the preset.
static func horse_preset(looks: Dictionary, id: String) -> Dictionary:
    var result := looks.duplicate()
    result["steed"] = id
    result.merge(HORSE_PRESETS.get(id, HORSE_PRESETS[DEFAULT["steed"]]), true)
    return result


## The option after (or, with a negative step, before) the chosen one.
static func step(looks: Dictionary, feature: String, by: int) -> Dictionary:
    var options: Array = OPTIONS[feature]
    var result := looks.duplicate()
    var index := options.find(looks.get(feature, DEFAULT[feature]))
    result[feature] = options[posmod(index + by, options.size())]
    return result


## New looks, mixed at random.
static func random(rng: RandomNumberGenerator) -> Dictionary:
    var result := {}
    for feature in OPTIONS:
        var options: Array = OPTIONS[feature]
        result[feature] = options[rng.randi_range(0, options.size() - 1)]
    return result
