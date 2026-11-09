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
const SHADOW := Color(0.0, 0.0, 0.0, 0.35)

## The legend of the characters in the sprites of [PixelSprite], shared by
## all the sprites, so that a sprite reads like a little picture.
const LEGEND := {
    ".": Color(0, 0, 0, 0),
    "k": OUTLINE,
    "b": HORSE_BAY,
    "l": HORSE_BAY_LIGHT,
    "h": HOOF,
    "r": CRIMSON,
    "d": CRIMSON_DARK,
    "y": GOLD,
    "o": OCHRE,
    "e": EMERALD,
    "f": FELT,
    "g": GRASS,
    "s": SKIN,
    "z": SKIN_DARK,
    "a": STONE,
    "w": STONE_LIGHT,
    "u": SKY,
    "i": SKY_LIGHT,
    "m": EMERALD_LIGHT,
    "n": NIGHT,
    "c": GRASS_DARK,
    "t": GRASS_LIGHT,
}
