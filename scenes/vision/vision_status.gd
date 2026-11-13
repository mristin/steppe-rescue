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
        # NOTE (mristin):
        # Godot 4.6 implements no camera on Windows, so the camera server there
        # never finds one, whatever is plugged in.
        "NoCamera":
        (
            tr("The camera does not work on Windows yet. Use the keyboard.")
            if OS.get_name() == "Windows"
            else tr("No camera found. Use the keyboard.")
        ),
        "ModelsMissing": tr("The models are missing. Use the keyboard."),
        "Failed": tr("The camera failed. Use the keyboard."),
    }
    return messages.get(status, "")
