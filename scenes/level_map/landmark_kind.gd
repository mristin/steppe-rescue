class_name LandmarkKind
extends Resource

## Describe a kind of landmark (the spring, the big rock, ...), in
## [code]data/landmarks/[/code].
##
## The people name the landmarks in their clues, so the name of the kind is
## translated with the forms which the clues need (see [Grammar] and
## dev/translations/extract.py): "near" ("у родника"), "of" ("к северу от
## родника"), "and" and "between" ("между кустами и родником").

## How the landmark is drawn, and its picture in the clues (see [Icons]).
@export var id := ""

## The name in English, e.g., "the spring".
@export var name := ""

## The size of a landmark of this kind in pixels, if the level does not say.
@export var radius := 16.0

## How much of the radius blocks the horse (0 lets it ride over).
@export_range(0.0, 1.0) var solid := 1.0

## Whether the horse drinks here: a spring, a lake or a river, but not a salt
## lake (see section 4 of DESIGN.md, "Water and grass for the horse").
@export var fresh_water := false

## Whether the horse grazes here: a pasture of green grass; the steppe
## elsewhere is too dry.
@export var pasture := false
