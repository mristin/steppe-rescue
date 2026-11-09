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
        if not service.HasPlayer():
            return tr("Step in front of the camera.")
        # TRANSLATORS: {pose} and {face} are the milliseconds to find the body and the face.
        return tr("I see you! (body {pose} ms, face {face} ms)").format(
            {"pose": int(service.GetInferenceMs()), "face": int(service.GetFaceMs())}
        )

    var messages := {
        "Disabled": tr("The camera is off. Use the keyboard."),
        "SearchingCamera": tr("Looking for a camera..."),
        "LoadingModels": tr("Loading..."),
        "NoCamera": tr("No camera found. Use the keyboard."),
        "ModelsMissing": tr("The models are missing. Use the keyboard."),
        "Failed": tr("The camera failed. Use the keyboard."),
    }
    return messages.get(status, "")
