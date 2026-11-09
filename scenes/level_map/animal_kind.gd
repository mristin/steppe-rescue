class_name AnimalKind
extends Resource

## Describe a kind of animal (the sheep, the horses, the camels), in
## [code]data/animals/[/code].

## How the animal is drawn and its picture (see [Icons] and [TopDown]).
@export var id := ""

## One animal as the people name it in the clues, e.g., "a sheep" in "I saw a
## sheep near the spring".
@export var one := ""

## Several animals as the people name them in the clues, e.g., "sheep" in "I saw
## sheep near the spring".
@export var many := ""

## How fast the animal can follow the rider, in pixels per second; the slow
## animals fall behind a galloping horse and catch up when she slows down.
@export var speed := 80.0

## Whether the animal joins only a rider who comes slowly, and runs away from
## a galloping one.
@export var shy := false
