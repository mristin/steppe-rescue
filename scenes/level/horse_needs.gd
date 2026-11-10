class_name HorseNeeds
extends RefCounted

## Keep how thirsty and how hungry the horse is (see section 4 of DESIGN.md,
## "Water and grass for the horse").
##
## The water and the food empty slowly while the horse runs, faster at a
## gallop. When one of them is empty, the horse only walks slowly, however
## fast the player squats; it never stops, so a child is never stuck. The
## horse drinks by itself when it stands at fresh water, and grazes when it
## stands on a pasture.

## A full bar lasts this many seconds of trotting...
const _TROT_SECONDS := 240.0

## ... at this speed (in [0, 1], see [method Rider.gait]).
const _TROT_SPEED := 0.6

## The water and the food empty this much faster at a gallop.
const _GALLOP_FACTOR := 1.5

## The speed from which the horse gallops, in [0, 1].
const _GALLOP_SPEED := 0.8

## The food empties slower than the water, so that the two bars do not run
## low at the same time.
const _FOOD_FACTOR := 0.7

## Drinking fills the water bar this much per second...
const DRINK_RATE := 0.25

## ... and grazing the food bar this much per second.
const GRAZE_RATE := 0.15

## A bar below this shows that the horse needs water or food: the bar blinks
## and a bubble rises above the horse.
const LOW := 0.25

## An empty bar caps the speed of the horse (in [0, 1]) to a slow walk.
const TIRED_SPEED := 0.2

## Below this speed (in [0, 1]) the horse stands, and can drink and graze.
const STANDING_SPEED := 0.05

## The water, in [0, 1]: 1 is full.
var water := 1.0

## The food, in [0, 1]: 1 is full.
var food := 1.0

## Whether the horse drank in the last update.
var drinking := false

## Whether the horse grazed in the last update.
var grazing := false


## The speed in [0, 1] which the horse can run at, from the speed of the squats.
func cap(speed: float) -> float:
    if water <= 0.0 or food <= 0.0:
        return minf(speed, TIRED_SPEED)
    return speed


## Empty the bars while the horse runs at the speed (in [0, 1]) for [param
## delta] seconds, and fill them while it stands at fresh water or on a pasture.
func update(delta: float, speed: float, at_water: bool, on_pasture: bool) -> void:
    var effort := speed / (_TROT_SPEED * _TROT_SECONDS)
    if speed >= _GALLOP_SPEED:
        effort *= _GALLOP_FACTOR
    water = maxf(0.0, water - effort * delta)
    food = maxf(0.0, food - effort * _FOOD_FACTOR * delta)

    var standing := speed < STANDING_SPEED
    drinking = standing and at_water and water < 1.0
    grazing = standing and on_pasture and food < 1.0
    if drinking:
        water = minf(1.0, water + DRINK_RATE * delta)
    if grazing:
        food = minf(1.0, food + GRAZE_RATE * delta)


func thirsty() -> bool:
    return water < LOW


func hungry() -> bool:
    return food < LOW
