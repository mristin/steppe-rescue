extends SceneTree
## Jump with the horse: a jump from a gallop flies longer and farther than one
## from a walk, the horse keeps its speed in the air, the painted frames of the
## jump come in order, a rearing horse does not jump, only a jump from a trot
## or a gallop carries the horse over a creek, and the player's jump makes her
## horse jump in the level.

const _LEVEL := "res://scenes/level/level.tscn"

var _failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
    if not condition:
        print("FAIL ", message)
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


## Jump at the speed in [0, 1], and return the airtime, the distance and the
## frames shown, in order.
func _jump(speed: float) -> Dictionary:
    var rider := Rider.new()
    root.add_child(rider)
    var step := 1.0 / 60.0
    for i in range(30):
        rider.ride(step, speed, 0.0)
    rider.jump()
    var start := rider.position
    var airtime := 0.0
    var frames: Array[int] = []
    var held := true
    while rider.jumping() >= 0.0 and airtime < 5.0:
        if frames.is_empty() or frames[-1] != rider.jump_frame():
            frames.append(rider.jump_frame())
        # NOTE (mristin):
        # The player stops squatting in the air; the horse flies on.
        rider.ride(step, 0.0, 1.0)
        if rider.jumping() >= 0.0:
            held = held and rider.speed > 0.0
        airtime += step
    var result := {
        "airtime": airtime,
        "distance": start.distance_to(rider.position),
        "frames": frames,
        "held": held,
    }
    rider.queue_free()
    return result


## Ride north at the creek (at y = 1000) at the speed, jumping when the horse
## is this far from the creek (no jump if negative), and return where it ends.
func _at_creek(speed: float, jump_before: float) -> float:
    return _ride_at_creek(Rider.new(), speed, jump_before)


func _ride_at_creek(rider: Rider, speed: float, jump_before: float) -> float:
    root.add_child(rider)
    var creek: Array[Vector3] = []
    for x in range(0, 2000, 5):
        creek.append(Vector3(x, 1000.0, 10.0))
    var empty: Array[Vector3] = []
    rider.set_obstacles(empty, Vector2(2000, 2000), creek)
    rider.position = Vector2(1000, 1100)
    var jumped := false
    for i in range(240):
        if not jumped and jump_before >= 0.0 and rider.position.y - 1000.0 <= jump_before + 18.0:
            rider.jump()
            jumped = true
        rider.ride(1.0 / 60.0, speed, 0.0)
    var y := rider.position.y
    rider.queue_free()
    return y


func _run() -> void:
    var walk := _jump(0.2)
    var gallop := _jump(0.9)
    _check(gallop["airtime"] > walk["airtime"] + 0.3, "a jump from a gallop flies longer")
    _check(gallop["distance"] > walk["distance"] * 3.0, "and much farther")
    _check(gallop["frames"] == [0, 1, 2, 3, 4], "the frames of the jump come in order")
    _check(walk["held"] and gallop["held"], "the horse keeps its speed in the air")

    _check(_at_creek(0.9, -1.0) > 1000.0, "the creek stops a horse which does not jump")
    _check(_at_creek(0.9, 4.0) < 1000.0, "a galloping horse jumps over the creek")
    _check(_at_creek(0.6, 4.0) < 1000.0, "and a trotting one, too")
    _check(_at_creek(0.2, 4.0) > 1000.0, "a jump from a walk falls short")
    # NOTE (mristin):
    # Jumps which fall short splash back onto the bank; after two, every jump
    # carries the horse over, even from a walk.
    var tired := Rider.new()
    _check(_ride_at_creek(tired, 0.2, 4.0) > 1000.0, "the first short jump splashes back")
    _check(tired.short_jumps == 1, "it counts as short, got %d" % tired.short_jumps)
    tired = Rider.new()
    tired.short_jumps = Rider.SHORT_JUMPS_HELPED
    _check(
        _ride_at_creek(tired, 0.2, 4.0) < 1000.0, "after two, even a jump from a walk helps over"
    )
    var over := Rider.new()
    _ride_at_creek(over, 0.9, 4.0)
    _check(over.short_jumps == 0, "a jump over the creek is not short")
    for level_path in [
        "res://data/levels/03_grandmothers_camel.tscn", "res://data/levels/04_the_foals.tscn"
    ]:
        var map: LevelMap = load(level_path).instantiate()
        _check(not map.jumpable().is_empty(), "a creek runs across %s" % level_path)
        map.free()

    var rearing := Rider.new()
    root.add_child(rearing)
    rearing.rear()
    rearing.jump()
    _check(rearing.jumping() < 0.0, "a rearing horse does not jump")
    rearing.queue_free()

    var level: Level = (load(_LEVEL) as PackedScene).instantiate()
    level.player_count = 1
    if current_scene != null:
        current_scene.queue_free()
    root.add_child(level)
    current_scene = level
    await process_frame
    await process_frame
    var service: Node = root.get_node("Vision").service
    # NOTE (mristin):
    # Close the conversation with Grandmother first.
    await create_timer(Level.TALK_SECONDS + 0.2).timeout
    service.SquatByKeyboard(0)
    await create_timer(0.3).timeout
    service.JumpByKeyboard(0)
    await process_frame
    await process_frame
    _check(level.rider(0).jumping() >= 0.0, "the player's jump makes her horse jump")

    if _failures.is_empty():
        print("RESULT: OK")
        quit(0)
    else:
        print("RESULT: FAILED (%d)" % _failures.size())
        quit(1)
