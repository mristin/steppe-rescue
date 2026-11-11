extends SceneTree

## Record squats at a walk, a trot and a gallop, to study how the squats look
## to the vision and to tune the squat meter on them.
##
## [codeblock]
## $GODOT --path . --script dev/squats/record_squats.gd -- [<recording.jsonl>] [--rounds=3]
## [/codeblock]
##
## It needs the camera and a display (not --headless). It tells the player what
## to do, step by step, with a countdown and a chime at each step: stand still,
## squat as for a walk, a trot and a gallop, and stop; [code]--rounds[/code]
## times. Between the rounds, the player steps closer to the camera, and then
## farther from it, so that the squats are recorded at different distances.
## Meanwhile, the vision service records what it measures (see VisionRecorder):
## only numbers, never the pictures. The recording goes to
## ~/Downloads/squat_recordings/ by default; dev/squats/analyze.py studies it.
##
## The countdown to start waits until the camera sees the player. Escape stops
## early; what was recorded so far is kept. [code]--quick[/code] makes every
## step ten times shorter, to try the tool (e.g., with --no-camera).

const _GET_READY_SECONDS := 10.0

## The steps of one round: the label, how long, the title and what to do.
const _ROUND := [
    ["stand", 6.0, "Stand still", "Stand still, facing the camera, your arms down."],
    [
        "walk",
        20.0,
        "Walk",
        "Squat as you would to make your horse WALK: calmly, at your own pace.",
    ],
    [
        "trot",
        20.0,
        "Trot",
        "Squat as you would to make your horse TROT: brisker, at your own pace.",
    ],
    [
        "gallop",
        15.0,
        "Gallop",
        "Squat as you would to make your horse GALLOP: as fast as you comfortably can.",
    ],
    ["stop", 6.0, "Stop", "Stop squatting and stand still, as if your horse should halt."],
]

## Where to stand for the next round, in turn.
const _MOVES := [
    [
        "move",
        10.0,
        "Step closer",
        "Step one big step CLOSER to the camera. It should still see your head and hands.",
    ],
    [
        "move",
        10.0,
        "Step back",
        "Step two big steps BACK, farther from the camera than at the start.",
    ],
]

var _service: Node
var _path := ""
var _steps: Array = []
var _step := -1
var _left := 0.0
var _done := false
var _quick := false

var _title: Label
var _text: Label
var _count: Label
var _next: Label
var _coach: Coach


func _initialize() -> void:
    var rounds := 3
    for arg in OS.get_cmdline_user_args():
        if arg == "--quick":
            _quick = true
        elif arg.begins_with("--rounds="):
            rounds = maxi(1, int(arg.trim_prefix("--rounds=")))
        elif not arg.begins_with("--"):
            _path = arg
    if _path == "":
        _path = (
            "%s/Downloads/squat_recordings/squats-%s.jsonl"
            % [
                OS.get_environment("HOME"),
                Time.get_datetime_string_from_system().replace(":", "").replace("T", "-")
            ]
        )

    (
        _steps
        . append(
            [
                "",
                _GET_READY_SECONDS,
                "Get ready",
                "Step back until the camera sees all of you, from your head to your feet.",
            ]
        )
    )
    for i in range(rounds):
        if i > 0:
            _steps.append(_MOVES[(i - 1) % _MOVES.size()].duplicate())
            _steps[-1][0] = "move %d" % (i + 1)
        for step in _ROUND:
            _steps.append(["%s %d" % [step[0], i + 1], step[1], step[2], step[3]])
    _build.call_deferred()


func _build() -> void:
    _service = root.get_node("Vision").service
    _service.SetPlayerCount(1)

    var screen := ColorRect.new()
    screen.color = Palette.NIGHT
    screen.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(screen)

    var panel := CameraPanel.new()
    panel.position = Vector2(24, 96)
    panel.size = Vector2(480, 360)
    panel.show_skeleton = true
    screen.add_child(panel)

    _coach = Coach.new()
    _coach.position = Vector2(516, 96)
    _coach.size = Vector2(120, 360)
    screen.add_child(_coach)

    _title = _label(screen, Vector2(24, 16), Vector2(912, 48), 40, Palette.GOLD)
    _text = _label(screen, Vector2(656, 96), Vector2(280, 200), 18, Palette.FELT)
    _text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _count = _label(screen, Vector2(656, 300), Vector2(280, 100), 72, Palette.FELT)
    _next = _label(screen, Vector2(24, 470), Vector2(912, 60), 16, Palette.STONE_LIGHT)
    _next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    _go_to(0)


func _label(parent: Control, at: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.position = at
    label.size = size
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label


func _go_to(step: int) -> void:
    _step = step
    if step >= _steps.size():
        _finish()
        return
    var current: Array = _steps[step]
    _left = current[1] * (0.1 if _quick else 1.0)
    _title.text = "%s   (%d of %d)" % [current[2], step + 1, _steps.size()]
    _text.text = current[3]
    var following := "Then you are done."
    if step + 1 < _steps.size():
        following = "Next: %s." % _steps[step + 1][2]
    _next.text = following
    if step == 1:
        if not _service.StartRecording(_path):
            _title.text = "Could not record into %s" % _path
            _done = true
            return
    _service.SetRecordingLabel(current[0])
    root.get_node("Sounds").play("chime")


func _finish() -> void:
    var lines: int = _service.StopRecording()
    _done = true
    _title.text = "Thank you, all done!"
    _text.text = "Recorded %d lines into:\n%s" % [lines, _path]
    _count.text = ""
    _next.text = "Close the window, or press Escape."
    root.get_node("Sounds").play("tune")
    print("Recorded %d lines into %s" % [lines, _path])


func _process(delta: float) -> bool:
    if Input.is_key_pressed(KEY_ESCAPE):
        if not _done:
            _finish()
        return true
    if _done or _step < 0:
        return false

    _coach.following = _service.IsRunning() and _service.HasPlayer(0)
    _coach.live = Vector3(_service.GetSquatDepth(0), -float(_service.GetTurn(0)), 0.0)

    # NOTE (mristin):
    # The countdown to start waits until the camera sees the player.
    var seen: bool = _service.IsRunning() and _service.HasPlayer(0)
    if _step == 0 and not seen and _service.GetStatus() != "Disabled":
        _count.text = "..."
        _next.text = "Waiting until the camera sees you."
        return false

    _left -= delta
    _count.text = str(ceili(maxf(0.0, _left)))
    if _left <= 0.0:
        _go_to(_step + 1)
    return false
