extends Node

## Remember the riders who share the computer (see section 9 of DESIGN.md),
## each with her name, the name of her horse and their [Looks], the stars of
## each level she finished, the [Finery] she won and wears, and whether she
## has seen the instruction, in the settings next to the language (see the
## autoload Languages, which also tells where the settings are). The fields
## below are those of the current rider (see [method choose_rider]).
##
## The first rider is kept in the sections "rider" and "progress", the others
## in "rider_1", "progress_1", and so on; "general/rider" is the current one.
##
## Start the game with `-- --new-rider` to create the rider again.

const _SECTION := "rider"
const _PROGRESS := "progress"

## The most riders on one computer.
const MAX_RIDERS := 6

## The longest name, in letters.
const MAX_NAME := 12

## The index of the current rider.
var index := 0

## Whether the player created her rider already.
var has_rider := false

## The name of the rider as the player wrote it; empty for the default name in
## the language of the game (see [method rider_name]).
var rider_name_written := ""

## The name of the horse as the player wrote it; empty for the default name.
var horse_name_written := ""

## The looks of the rider and her horse.
var looks: Dictionary = Looks.DEFAULT.duplicate()

## The most stars won in each finished level, by the id of the level (see
## [LevelList]).
var stars: Dictionary = {}

## Whether the player has seen the instruction (see [Instruction]).
var has_seen_instruction := false

## The finery which the rider won: the step of each piece (see [Finery]).
var finery: Dictionary = {}

## The pieces of the finery which she won but took off in the wardrobe.
var taken_off: Array = []

## The ids of the levels whose gift she chose: a level gives its gift once, so
## that riding it again is no mine of finery.
var rewarded: Array = []


func _ready() -> void:
    var settings := ConfigFile.new()
    settings.load(_path())
    index = clampi(int(settings.get_value("general", "rider", 0)), 0, MAX_RIDERS - 1)
    _load(index)
    if "--new-rider" in OS.get_cmdline_user_args():
        has_rider = false


## The riders who share the computer, in their order, each a dictionary with
## her "name" (as written, empty for the default), her "looks" and her
## "stars" (in all the levels).
func riders() -> Array[Dictionary]:
    var settings := ConfigFile.new()
    settings.load(_path())
    var result: Array[Dictionary] = []
    for i in range(MAX_RIDERS):
        if not settings.get_value(_section(i), "created", false):
            break
        var total := 0
        for level in settings.get_value(_progress(i), "stars", {}).values():
            total += int(level)
        (
            result
            . append(
                {
                    "name": settings.get_value(_section(i), "name", ""),
                    "looks": Looks.complete(settings.get_value(_section(i), "looks", {})),
                    "stars": total,
                }
            )
        )
    return result


## Become the rider of the index, and remember her as the current one.
func choose_rider(i: int) -> void:
    index = clampi(i, 0, MAX_RIDERS - 1)
    _load(index)
    _store("general", {"rider": index})


## Start a new rider after the others, to be created in the creator; false if
## there are already [constant MAX_RIDERS].
func new_rider() -> bool:
    var count := riders().size()
    if count >= MAX_RIDERS:
        return false
    index = count
    _load(index)
    _store("general", {"rider": index})
    return true


## Load the rider of the index, or a new one if there is none.
func _load(i: int) -> void:
    var settings := ConfigFile.new()
    settings.load(_path())
    var rider := _section(i)
    var progress := _progress(i)
    has_rider = settings.get_value(rider, "created", false)
    rider_name_written = settings.get_value(rider, "name", "")
    horse_name_written = settings.get_value(rider, "horse_name", "")
    looks = Looks.complete(settings.get_value(rider, "looks", {}))
    stars = settings.get_value(progress, "stars", {})
    has_seen_instruction = settings.get_value(progress, "instruction_seen", false)
    finery = Finery.complete(settings.get_value(progress, "finery", {}))
    taken_off = settings.get_value(progress, "taken_off", [])
    rewarded = settings.get_value(progress, "rewarded", [])


func _section(i: int) -> String:
    return _SECTION if i == 0 else "%s_%d" % [_SECTION, i]


func _progress(i: int) -> String:
    return _PROGRESS if i == 0 else "%s_%d" % [_PROGRESS, i]


## The name of the rider, by default Aigerim in the alphabet of the language.
func rider_name() -> String:
    if rider_name_written != "":
        return rider_name_written
    # TRANSLATORS: The default name of the rider, a girl, in your alphabet.
    return tr("Aigerim")


## The name of the horse, by default Tulpar (the winged horse of the legends).
func horse_name() -> String:
    if horse_name_written != "":
        return horse_name_written
    # TRANSLATORS: The default name of the horse, Тұлпар, in your alphabet.
    return tr("Tulpar")


## Keep the rider and remember her for the next start.
func save(a_rider_name: String, a_horse_name: String, a_looks: Dictionary) -> void:
    rider_name_written = a_rider_name.strip_edges().left(MAX_NAME)
    horse_name_written = a_horse_name.strip_edges().left(MAX_NAME)
    looks = Looks.complete(a_looks)
    looks.erase("finery")
    has_rider = true

    _store(
        _section(index),
        {
            "created": true,
            "name": rider_name_written,
            "horse_name": horse_name_written,
            "looks": looks,
        }
    )


## The looks of the rider dressed in the finery she wears, to draw her.
func dressed() -> Dictionary:
    var result := looks.duplicate()
    var worn := {}
    for piece in finery:
        if piece not in taken_off:
            worn[piece] = finery[piece]
    result["finery"] = worn
    return result


## Whether she wears the piece which she won.
func wears(piece: String) -> bool:
    return finery.has(piece) and piece not in taken_off


## Put on (or take off) the piece which she won, in the wardrobe, and
## remember it.
func wear(piece: String, on: bool) -> void:
    if on:
        taken_off.erase(piece)
    elif piece not in taken_off:
        taken_off.append(piece)
    _store(_progress(index), {"taken_off": taken_off})


## Win the next step of the piece of finery, and remember it.
func win(piece: String) -> void:
    if not Finery.PIECES.has(piece):
        return
    finery[piece] = mini(int(finery.get(piece, 0)) + 1, Finery.PIECES[piece]["steps"])
    taken_off.erase(piece)
    _store(_progress(index), {"finery": finery, "taken_off": taken_off})


## Whether she chose the gift of the level already.
func was_rewarded(level_id: String) -> bool:
    return level_id in rewarded


## Remember that she chose the gift of the level.
func reward(level_id: String) -> void:
    if level_id == "" or level_id in rewarded:
        return
    rewarded.append(level_id)
    _store(_progress(index), {"rewarded": rewarded})


## Whether the player finished the level.
func has_finished(level_id: String) -> bool:
    return stars.has(level_id)


## Remember that the player finished the level with the stars, keeping the
## most stars of all her rides.
func finish_level(level_id: String, won: int) -> void:
    stars[level_id] = maxi(won, stars.get(level_id, 0))
    _store(_progress(index), {"stars": stars})


## Remember that the player has seen the instruction.
func see_instruction() -> void:
    has_seen_instruction = true
    _store(_progress(index), {"instruction_seen": true})


## Write the values into the section of the settings, keeping the rest.
func _store(section: String, values: Dictionary) -> void:
    var settings := ConfigFile.new()
    settings.load(_path())
    for key in values:
        settings.set_value(section, key, values[key])
    DirAccess.make_dir_recursive_absolute(_path().get_base_dir())
    settings.save(_path())


func _path() -> String:
    return get_node("/root/Languages").settings_path()
