extends Node

## Keep the camera and the vision running for the whole game, across all the
## scenes, so that the camera starts only once (which takes a few seconds).
##
## The scenes use `get_node("/root/Vision").service` (the VisionService, in
## C#): the camera picture, the speed of the horse from the squats, the turn
## from the hands and the anchor of the looks over the face, of each player
## (0, or 1 with two players; the [Profile] tells the service how many play).
##
## Start with `-- --no-camera` to run without the camera, e.g., in the tests.
## The keyboard always works: Space or W is a squat of the first player, A and
## D turn, S brakes; Up, Left, Right and Down ride the second player (or the
## first, when she rides alone).

@onready var service: Node = $Service


func _enter_tree() -> void:
    # NOTE (mristin):
    # The service starts the camera in its _ready, which runs before ours.
    if "--no-camera" in OS.get_cmdline_user_args():
        $Service.UseCamera = false


func _ready() -> void:
    var profile := get_node_or_null("/root/Profile")
    if profile != null:
        service.SetPlayerCount(maxi(1, profile.players))
