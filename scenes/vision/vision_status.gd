class_name VisionStatus
extends RefCounted

## Say what the camera is doing, for the status line of the screens.


## The status of the vision service; with [param timing], how long the
## computer needs for a picture while the camera runs, else nothing then.
func text(service: Node, timing: bool) -> String:
    var status: String = service.GetStatus()
    if status == "Running":
        if not timing:
            return ""
        if not service.HasPlayer(0):
            return tr("Step in front of the camera.")
        # TRANSLATORS: {pose}, {face}: ms for the body, the face; {rate}: bodies a second.
        return tr("I see you! (body {pose} ms, {rate} times a second; face {face} ms)").format(
            {
                "pose": int(service.GetInferenceMs()),
                "rate": roundi(service.GetPoseRate()),
                "face": int(service.GetFaceMs())
            }
        )

    var messages := {
        "Disabled": tr("The camera is off. Use the keyboard."),
        "SearchingCamera": tr("Looking for a camera..."),
        "LoadingModels": tr("Loading..."),
        "NoCamera": _no_camera(service),
        "ModelsMissing": tr("The models are missing. Use the keyboard."),
        "Failed": tr("The camera failed. Use the keyboard."),
    }
    return messages.get(status, "")


## Why there is no camera: on Windows, Godot 4.6 has no camera of its own,
## and the vision service needs its camera extension, which Windows must allow.
func _no_camera(service: Node) -> String:
    var reason: String = (
        service.GetNoCameraReason() if service.has_method("GetNoCameraReason") else ""
    )
    if reason == "unsupported":
        return tr("The camera does not work on Windows yet. Use the keyboard.")
    if reason == "denied":
        return tr("Windows does not allow the camera. Use the keyboard.")
    return tr("No camera found. Use the keyboard.")
