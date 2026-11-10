@tool
class_name Person
extends Node2D

## Place a person of the steppe in a level: when the rider stops next to them,
## they greet her and tell her where they saw the animals (see section 4 of
## DESIGN.md). The person is painted, seen from above (see
## [method Icons.person_above]).

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

var _painting: Texture2D = null


func _draw() -> void:
    # NOTE (mristin):
    # Keep the painting: a texture which nothing holds would draw white.
    _painting = Icons.person_above(portrait)
    var shown := _painting.get_size() * 0.5 * PaintedTopDown.PERSON_SCALE
    draw_circle(Vector2(2, 3), shown.x * 0.25, Palette.SHADOW)
    draw_texture_rect(_painting, Rect2((-shown * 0.5).round(), shown), false)
