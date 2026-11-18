extends SceneTree
## Check the water and the food of the horse: they empty while the horse runs,
## faster at a gallop; an empty bar makes the horse walk slowly, but never
## stop; the horse drinks at the spring and grazes on the pasture, but not at
## the big rock.

var _failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
    if not condition:
        print("FAIL ", message)
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


func _wait(seconds: float) -> void:
    await create_timer(seconds).timeout


func _check_model() -> void:
    var trot := HorseNeeds.new()
    var gallop := HorseNeeds.new()
    for i in range(600):
        trot.update(0.1, 0.6, false, false)
        gallop.update(0.1, 1.0, false, false)
    _check(trot.water < 1.0 and trot.food < 1.0, "the bars empty while the horse trots")
    _check(trot.water > 0.5, "a minute of trotting leaves the horse water, got %f" % trot.water)
    _check(trot.food > trot.water, "the food empties slower than the water")
    _check(gallop.water < trot.water - 0.1, "a gallop empties the bars faster")

    var tired := HorseNeeds.new()
    tired.water = 0.0
    _check(tired.cap(1.0) == HorseNeeds.TIRED_SPEED, "a thirsty horse only walks slowly")
    _check(tired.cap(0.1) == 0.1, "a thirsty horse still walks")
    _check(HorseNeeds.TIRED_SPEED >= 0.05, "a thirsty horse never stops")

    var resting := HorseNeeds.new()
    resting.water = 0.1
    resting.food = 0.1
    resting.update(1.0, 0.5, true, true)
    _check(not resting.drinking and not resting.grazing, "a running horse neither drinks nor eats")
    for i in range(100):
        resting.update(0.1, 0.0, true, true)
    _check(resting.water == 1.0, "the horse drinks its fill in ten seconds")
    _check(resting.food > 0.9, "the horse eats its fill in ten seconds, got %f" % resting.food)
    _check(not resting.drinking, "a horse with its fill does not drink on")


func _run() -> void:
    _check_model()

    var level: Level = (load("res://scenes/level/level.tscn") as PackedScene).instantiate()
    root.add_child(level)
    await process_frame
    await process_frame

    var service: Node = root.get_node("Vision").service
    var rider := level.rider()
    var map := level.map

    var spring := map.landmark("Spring")
    var pasture := map.landmark("Pasture")
    var rock := map.landmark("BigRock")
    _check(map.at_fresh_water(spring.position + Vector2(spring.size() + 4.0, 0)), "the spring")
    _check(map.on_pasture(pasture.position), "the pasture")
    _check(not map.at_fresh_water(rock.position + Vector2(rock.size() + 4.0, 0)), "not the rock")
    _check(
        not map.on_pasture(rock.position + Vector2(rock.size() + 4.0, 0)), "no grass at the rock"
    )

    # NOTE (mristin):
    # Close the conversation with Grandmother, and let the horse stop again.
    await _wait(1.5)
    service.SquatByKeyboard(0)
    await _wait(6.0)
    _check(level.talking_to() == null, "Grandmother lets the rider go")

    level.needs.water = 0.0
    for i in range(8):
        service.SquatByKeyboard(0)
        await _wait(0.6)
    _check(service.GetGait(0) == 3, "the squats ask for a gallop")
    _check(rider.gait() == 1, "a thirsty horse only walks, got the gait %d" % rider.gait())
    _check(rider.speed > 0.0, "a thirsty horse never stops")

    await _wait(6.0)
    level.needs.water = 0.1
    level.needs.food = 0.1
    rider.position = rock.position + Vector2(rock.size() + 10.0, 0)
    await _wait(2.0)
    _check(level.needs.water <= 0.1, "the horse does not drink at the rock")
    _check(level.needs.food <= 0.1, "the horse does not graze at the rock")

    rider.position = spring.position + Vector2(spring.solid_radius() + Rider.RADIUS, 0)
    await _wait(2.0)
    _check(level.needs.water > 0.5, "the horse drinks at the spring, got %f" % level.needs.water)

    rider.position = pasture.position
    await _wait(2.0)
    _check(level.needs.food > 0.3, "the horse grazes on the pasture, got %f" % level.needs.food)

    if _failures.is_empty():
        print("RESULT: OK")
        quit(0)
    else:
        print("RESULT: FAILED (%d)" % _failures.size())
        quit(1)
