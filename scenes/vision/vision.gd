extends Node

## Keep the camera and the vision running for the whole game, across all the
## scenes, so that the camera starts only once (which takes a few seconds).
##
## The scenes use `get_node("/root/Vision").service` (the VisionService, in
## C#): the camera picture, the speed of the horse from the squats, the turn
## from the hands and the anchor of the looks over the face.
##
## Start with `-- --no-camera` to run without the camera, e.g., in the tests.
## The keyboard always works: Space or Up is a squat, Left and Right turn.

@onready var service: Node = $Service


func _enter_tree() -> void:
    # NOTE (mristin):
    # The service starts the camera in its _ready, which runs before ours.
    if "--no-camera" in OS.get_cmdline_user_args():
        $Service.UseCamera = false
