class_name Palette
extends RefCounted

## Hold the one palette of the whole game, taken from the colors of the intro
## picture and the steppe: golden grass, sky blue, crimson, emerald, ochre,
## white felt and the dark outlines.
##
## Draw everything with these colors only, so that the pixel art stays coherent.

const OUTLINE := Color("#2b1a10")
const NIGHT := Color("#1b2233")
const SKY := Color("#3a6fb5")
const SKY_LIGHT := Color("#8fb8e0")
const GRASS := Color("#d9a53a")
const GRASS_DARK := Color("#a8772a")
const GRASS_LIGHT := Color("#f0cf6e")
const EMERALD := Color("#2e7d4f")
const EMERALD_LIGHT := Color("#5fae6e")
const CRIMSON := Color("#b3263a")
const CRIMSON_DARK := Color("#7a1626")
const CRIMSON_LIGHT := Color("#d95466")
const OCHRE := Color("#c9822b")
const GOLD := Color("#f2c14e")
const FELT := Color("#f4ead5")
const STONE := Color("#8a8580")
const STONE_LIGHT := Color("#b8b2a8")
const HORSE_BAY := Color("#7a3f1d")
const HORSE_BAY_LIGHT := Color("#a35a2c")
const HOOF := Color("#3b2a20")
const SKIN := Color("#e0a878")
const SKIN_DARK := Color("#b97a52")
const SKIN_FAIR := Color("#f2cfae")
const SKIN_TAN := Color("#cf9162")
const SKIN_DEEP := Color("#8a5634")
const INDIGO := Color("#33417e")
const INDIGO_LIGHT := Color("#5b6db0")
const HAIR_BLACK := Color("#1f1a1c")
const CHESTNUT := Color("#9c4a22")
const DUN := Color("#cdb07a")
const SHADOW := Color(0.0, 0.0, 0.0, 0.35)

## All the opaque colors of the palette, for [Pixelate].
const COLORS := [
    OUTLINE,
    NIGHT,
    SKY,
    SKY_LIGHT,
    GRASS,
    GRASS_DARK,
    GRASS_LIGHT,
    EMERALD,
    EMERALD_LIGHT,
    CRIMSON,
    CRIMSON_DARK,
    CRIMSON_LIGHT,
    OCHRE,
    GOLD,
    FELT,
    STONE,
    STONE_LIGHT,
    HORSE_BAY,
    HORSE_BAY_LIGHT,
    HOOF,
    SKIN,
    SKIN_DARK,
    SKIN_FAIR,
    SKIN_TAN,
    SKIN_DEEP,
    INDIGO,
    INDIGO_LIGHT,
    HAIR_BLACK,
    CHESTNUT,
    DUN,
]
