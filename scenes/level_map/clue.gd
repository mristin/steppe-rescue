class_name Clue
extends Resource

## Tell where a person saw some animals, relative to the landmarks (see section
## 4 of DESIGN.md).
##
## The clue marks an area on the map: around the landmark ("near"), between the
## two landmarks ("between"), or on one side of the landmark ("north", ...).
## The tests check that the area covers the animals.

@export_enum("near", "between", "north", "south", "east", "west") var form := "near"

## The kind of the animals.
@export var animal: AnimalKind

## How many animals the person saw.
@export_range(1, 9) var count := 1

## The name of the landmark node in the level.
@export var landmark := ""

## The name of the other landmark node, for "between".
@export var other := ""
