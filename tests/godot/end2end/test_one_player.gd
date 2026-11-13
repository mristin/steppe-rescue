extends "res://tests/godot/end2end/playthrough.gd"
## Play the whole game from the start to the end with one player, who rides alone,
## checking the contracts of the game all the way, then start it again (see
## playthrough.gd).
##
## Run it with `-- --settings=user://<file>`, so that it does not change the
## settings and the journeys of the player (see the autoload Languages).


func _init() -> void:
    players = 1
