extends Control

## Test the movements before we build the game: the camera picture with the
## pose and the hat over the face, the speed bar from the squats, the turn
## from the hands, and the depth of the squats over time (see section 13 of
## DESIGN.md).
##
## This screen is for the developers and the play-tests, so, unlike the game,
## it writes out what it measures.
##
## Keys: Space or Up is a squat, Left and Right turn, L switches the language,
## Escape quits.

var _service: Node = null
var _last_count := 0

@onready var _title: Label = $Title
@onready var _speed_bar: SpeedBar = $Right/SpeedBar
@onready var _gait_label: Label = $Right/GaitLabel
@onready var _turn_label: Label = $Right/TurnLabel
@onready var _turn_gauge: TurnGauge = $Right/TurnGauge
@onready var _depth_label: Label = $Right/DepthLabel
@onready var _depth_plot: DepthPlot = $Right/DepthPlot
@onready var _squats_label: Label = $Right/SquatsLabel
@onready var _status_label: Label = $StatusLabel
@onready var _keys_label: Label = $KeysLabel


func _ready() -> void:
    _service = get_node("/root/Vision").service
    _speed_bar.thresholds = _service.GetGaitThresholds()
    _service.ResetRiding()
    _update_texts()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE:
                get_tree().quit()
            KEY_L:
                _next_language()


func _process(delta: float) -> void:
    var speed: float = _service.GetSpeed()
    _speed_bar.speed = speed

    var turn: float = _service.GetTurn()
    _turn_gauge.turn = turn

    var count: int = _service.GetSquatCount()
    _depth_plot.add(delta, _service.GetSquatDepth(), count != _last_count)
    _last_count = count

    _update_texts()


func _update_texts() -> void:
    _title.text = tr("Movement test")
    _gait_label.text = _gait_name(_service.GetGait())
    _turn_label.text = _turn_name(_service.GetTurn())
    _depth_label.text = tr("Squat depth")
    # TRANSLATORS: {count} is the number of the squats so far.
    _squats_label.text = tr("Squats: {count}").format({"count": _service.GetSquatCount()})
    _status_label.text = _status_text()
    _keys_label.text = tr("Space: squat · ←/→: turn · L: language · Esc: quit")


func _gait_name(gait: int) -> String:
    match gait:
        1:
            return tr("The horse walks.")
        2:
            return tr("The horse trots.")
        3:
            return tr("The horse gallops!")
        _:
            return tr("The horse stands.")


func _turn_name(turn: float) -> String:
    if turn < -0.05:
        return tr("Turning left")
    if turn > 0.05:
        return tr("Turning right")
    return tr("Straight ahead")


func _status_text() -> String:
    var status: String = _service.GetStatus()
    if status == "Running":
        if not _service.HasPlayer():
            return tr("Step in front of the camera.")
        # TRANSLATORS: {pose} and {face} are the milliseconds to find the body and the face.
        return tr("I see you! (body {pose} ms, face {face} ms)").format(
            {"pose": int(_service.GetInferenceMs()), "face": int(_service.GetFaceMs())}
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


func _next_language() -> void:
    var languages := get_node("/root/Languages")
    var codes: Array[String] = languages.codes()
    var index := codes.find(languages.current())
    languages.choose(codes[(index + 1) % codes.size()])
    _update_texts()
