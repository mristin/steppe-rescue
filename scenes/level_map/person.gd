@tool
class_name Person
extends Node2D

## Place a person of the steppe in a level: when the rider stops next to them,
## they greet her and tell her where they saw the animals (see section 4 of
## DESIGN.md).

const _COLORS := {
    "grandmother": [Palette.EMERALD, Palette.FELT],
    "shepherd": [Palette.OCHRE, Palette.HORSE_BAY],
    "beekeeper": [Palette.GOLD, Palette.EMERALD],
}

## The name of the person, shown in the conversation.
@export var speaker := ""

## The portrait in the conversation (see [constant Icons.PORTRAITS]).
@export_enum("grandmother", "shepherd", "beekeeper") var portrait := "shepherd":
    set(value):
        portrait = value
        queue_redraw()

## What the person says first; {rider} is the name of the rider.
@export_multiline var greeting := ""

## Where the person saw the animals.
@export var clues: Array[Clue] = []


func _draw() -> void:
    var colors: Array = _COLORS.get(portrait, _COLORS["shepherd"])
    var texture := TopDown.texture("person_" + portrait, TopDown.person(colors[0], colors[1]), 0.0)
    draw_circle(Vector2(1, 2), 4.0, Palette.SHADOW)
    draw_texture(texture, (-texture.get_size() * 0.5).floor())
