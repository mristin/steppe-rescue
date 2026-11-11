extends SceneTree

## Record what the vision measures while the player follows a plan of actions
## (e.g., squat at a walk, a trot and a gallop, or jump), to study how they
## look to the vision and to tune the squat meter on them.
##
## [codeblock]
## $GODOT --path . --script dev/squats/record_squats.gd -- \
##     [--plan=res://dev/squats/plans/jumps.csv] [<recording.jsonl>]
## [/codeblock]
##
## The plan is a CSV file with a header and one step per row: the label which
## the recording gives the step (e.g., "walk 2"), how long it lasts in seconds,
## its title and what the player should do, and optionally the times (in
## seconds from the start of the step, separated by spaces) at which to call
## "JUMP!" (each call is marked in the recording, so that the jumps are known).
## The plans live in dev/squats/plans/; the default is squats.csv.
##
## It needs the camera and a display (not --headless). It tells the player what
## to do, step by step, with a countdown and a chime at each step; first, it
## waits until the camera sees her. Meanwhile, the vision service records what
## it measures (see VisionRecorder): only numbers, never the pictures. The
## recording goes to ~/Downloads/squat_recordings/<plan>-<time>.jsonl by
## default; dev/squats/analyze.py studies it.
##
## Escape stops early; what was recorded so far is kept. [code]--quick[/code]
## makes every step ten times shorter, to try the tool (e.g., with --no-camera).

const _DEFAULT_PLAN := "res://dev/squats/plans/squats.csv"

const _GET_READY_SECONDS := 10.0

## How long the call to jump shows, in seconds.
const _CALL_SECONDS := 0.8

var _service: Node
var _path := ""
var _steps: Array[Dictionary] = []
var _step := -1
var _left := 0.0
var _elapsed := 0.0
var _calls: Array[float] = []
var _call_left := 0.0
var _done := false
var _quick := false

var _title: Label
var _text: Label
var _count: Label
var _next: Label
var _call: Label
var _coach: Coach


func _initialize() -> void:
    var plan := _DEFAULT_PLAN
    for arg in OS.get_cmdline_user_args():
        if arg == "--quick":
            _quick = true
        elif arg.begins_with("--plan="):
            plan = arg.trim_prefix("--plan=")
        elif not arg.begins_with("--"):
            _path = arg
    if _path == "":
        _path = (
            "%s/Downloads/squat_recordings/%s-%s.jsonl"
            % [
                OS.get_environment("HOME"),
                plan.get_file().get_basename(),
                Time.get_datetime_string_from_system().replace(":", "").replace("T", "-")
            ]
        )

    (
        _steps
        . append(
            {
                "label": "",
                "seconds": _GET_READY_SECONDS,
                "title": "Get ready",
                "text":
                (
                    "Step back until the camera sees all of you, from your head to your feet, "
                    + "with some room above your head."
                ),
                "calls": [],
            }
        )
    )
    var error := _load_plan(plan)
    _build.call_deferred(error)


## Read the steps of the plan; return what went wrong, or "".
func _load_plan(plan: String) -> String:
    var file := FileAccess.open(plan, FileAccess.READ)
    if file == null:
        return "Could not read the plan %s." % plan
    file.get_csv_line()
    while not file.eof_reached():
        var row := file.get_csv_line()
        if row.size() < 4 or row[0].strip_edges() == "":
            continue
        var calls: Array[float] = []
        if row.size() > 4:
            for at in row[4].split(" ", false):
                calls.append(float(at))
        (
            _steps
            . append(
                {
                    "label": row[0],
                    "seconds": float(row[1]),
                    "title": row[2],
                    "text": row[3],
                    "calls": calls,
                }
            )
        )
    if _steps.size() < 2:
        return "The plan %s has no steps." % plan
    return ""


func _build(error: String) -> void:
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
    _call = _label(screen, Vector2(24, 200), Vector2(480, 120), 96, Palette.CRIMSON_LIGHT)
    _call.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _call.add_theme_color_override("font_outline_color", Palette.OUTLINE)
    _call.add_theme_constant_override("outline_size", 12)
    _call.text = "JUMP!"
    _call.visible = false

    if error != "":
        _title.text = error
        _done = true
        return
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
    var current := _steps[step]
    var scale := 0.1 if _quick else 1.0
    _left = current["seconds"] * scale
    _elapsed = 0.0
    _calls.clear()
    for at in current["calls"]:
        _calls.append(at * scale)
    _title.text = "%s   (%d of %d)" % [current["title"], step + 1, _steps.size()]
    _text.text = current["text"]
    var following := "Then you are done."
    if step + 1 < _steps.size():
        following = "Next: %s." % _steps[step + 1]["title"]
    _next.text = following
    if step == 1:
        if not _service.StartRecording(_path):
            _title.text = "Could not record into %s" % _path
            _done = true
            return
    _service.SetRecordingLabel(current["label"])
    root.get_node("Sounds").play("chime")


func _finish() -> void:
    var lines: int = _service.StopRecording()
    _done = true
    _call.visible = false
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
    _coach.jumping = _service.IsJumping(0)

    # NOTE (mristin):
    # The countdown to start waits until the camera sees the player.
    var seen: bool = _service.IsRunning() and _service.HasPlayer(0)
    if _step == 0 and not seen and _service.GetStatus() != "Disabled":
        _count.text = "..."
        _next.text = "Waiting until the camera sees you."
        return false

    _left -= delta
    _elapsed += delta
    _count.text = str(ceili(maxf(0.0, _left)))

    # NOTE (mristin):
    # Call the jumps, and mark each call in the recording.
    _call_left = maxf(0.0, _call_left - delta)
    if not _calls.is_empty() and _elapsed >= _calls[0]:
        _calls.pop_front()
        _call_left = _CALL_SECONDS
        _service.MarkRecording("jump")
        root.get_node("Sounds").play("stamp")
    _call.visible = _call_left > 0.0

    if _left <= 0.0:
        _go_to(_step + 1)
    return false
