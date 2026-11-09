extends SceneTree
## Ride with the keyboard in the movement test: squatting faster makes the
## horse walk, trot and gallop, it stops after the squats stop, and the arrows
## turn it.

var _failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
    if not condition:
        print("FAIL ", message)
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


## Squat with the given period (in seconds of the game) for the given time.
func _squat(service: Node, period: float, duration: float) -> void:
    var elapsed := 0.0
    while elapsed < duration:
        service.SquatByKeyboard()
        await create_timer(period).timeout
        elapsed += period


func _run() -> void:
    var scene: Control = load("res://scenes/movement_test/movement_test.tscn").instantiate()
    root.add_child(scene)
    await process_frame

    var service: Node = root.get_node("Vision").service
    _check(service.GetGait() == 0, "the horse stands at the start")

    await _squat(service, 3.0, 15.0)
    _check(service.GetGait() == 1, "a squat every 3 s walks, got the gait %d" % service.GetGait())

    await _squat(service, 2.0, 12.0)
    _check(service.GetGait() == 2, "a squat every 2 s trots, got the gait %d" % service.GetGait())

    await _squat(service, 1.3, 10.0)
    _check(
        service.GetGait() == 3, "a squat every 1.3 s gallops, got the gait %d" % service.GetGait()
    )

    var speed_bar: SpeedBar = scene.get_node("Right/SpeedBar")
    _check(speed_bar.gait() == 3, "the speed bar shows the gallop")

    await create_timer(14.0).timeout
    _check(service.GetGait() == 0, "the horse stops after the squats stop")

    var left := InputEventKey.new()
    left.keycode = KEY_LEFT
    left.physical_keycode = KEY_LEFT
    left.pressed = true
    Input.parse_input_event(left)
    await create_timer(0.2).timeout
    _check(service.GetTurn() < 0.0, "the left arrow turns left")
    left.pressed = false
    Input.parse_input_event(left)
    await create_timer(0.2).timeout
    _check(service.GetTurn() == 0.0, "the horse goes straight without the arrows")

    if _failures.is_empty():
        print("RESULT: OK")
        quit(0)
    else:
        print("RESULT: FAILED (%d)" % _failures.size())
        quit(1)
