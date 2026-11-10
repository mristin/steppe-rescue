extends SceneTree
## Check the wild creatures of the steppe: every kind lives in the level; the
## hare, the saiga and the fox run away from the rider who comes near and
## stay in the steppe; the marmot dives into its burrow and peeks out again
## after she left; the lark flies up and lands farther on; the locusts hop
## away; the eagle circles over its home; and the swallows swoop around the
## rider.

var _failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
    if not condition:
        print("FAIL ", message)
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


func _wait(seconds: float) -> void:
    await create_timer(seconds).timeout


func _run() -> void:
    var level: Level = (load("res://scenes/level/level.tscn") as PackedScene).instantiate()
    root.add_child(level)
    await process_frame
    await process_frame

    var wild := level.wildlife()
    for kind in Wildlife.KINDS:
        _check(not wild.of_kind(kind).is_empty(), "the %s lives in the steppe" % kind)

    var rider_at := level.rider().position
    var bounds := Rect2(Vector2.ZERO, level.map.size)
    for kind in ["hare", "saiga", "fox"]:
        var runner: Wildlife.Creature = wild.of_kind(kind)[0]
        runner.position = rider_at + Vector2(30, 0)
        runner.target = runner.position
    var marmot: Wildlife.Creature = wild.of_kind("marmot")[0]
    marmot.position = rider_at + Vector2(-40, 0)
    var lark: Wildlife.Creature = wild.of_kind("lark")[0]
    lark.position = rider_at + Vector2(0, 30)
    var locust: Wildlife.Creature = wild.of_kind("locust")[0]
    locust.position = rider_at + Vector2(0, -20)
    var eagle: Wildlife.Creature = wild.of_kind("eagle")[0]
    var eagle_from := eagle.position

    await _wait(0.2)
    _check(marmot.state == Wildlife.State.HIDDEN, "the marmot dives into its burrow")
    _check(lark.altitude > 0.0, "the lark flies up")
    _check(locust.state == Wildlife.State.FLEE, "the locust hops away")

    await _wait(1.0)
    for kind in ["hare", "saiga", "fox"]:
        var runner: Wildlife.Creature = wild.of_kind(kind)[0]
        var distance := runner.position.distance_to(rider_at)
        _check(distance > 100.0, "the %s runs away, %.0f px" % [kind, distance])
        _check(bounds.has_point(runner.position), "the %s stays in the steppe" % kind)
    _check(eagle.position.distance_to(eagle_from) > 5.0, "the eagle circles")
    _check(eagle.position.distance_to(eagle.home) < 150.0, "the eagle circles over its home")
    for swallow in wild.of_kind("swallow"):
        _check(
            swallow.position.distance_to(level.rider().position) < 250.0,
            "the swallows swoop around the rider"
        )

    await _wait(3.0)
    _check(lark.altitude == 0.0, "the lark lands again")
    _check(lark.position.distance_to(rider_at) > 60.0, "the lark lands farther on")

    marmot.position = rider_at + Vector2(400, 0)
    await _wait(4.5)
    _check(marmot.state == Wildlife.State.IDLE, "the marmot peeks out after the rider left")

    if _failures.is_empty():
        print("RESULT: OK")
        quit(0)
    else:
        print("RESULT: FAILED (%d)" % _failures.size())
        quit(1)
