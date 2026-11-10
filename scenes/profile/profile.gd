extends Node

## Remember the rider of the player: her name, the name of her horse and their
## [Looks], the stars of each level she finished, the [Finery] she won, and
## whether she has seen the instruction (see section 9 of DESIGN.md), in the settings next to the
## language (see the autoload Languages, which also tells where the settings
## are).
##
## Start the game with `-- --new-rider` to create the rider again.

const _SECTION := "rider"
const _PROGRESS := "progress"

## The longest name, in letters.
const MAX_NAME := 12

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


func _ready() -> void:
    var settings := ConfigFile.new()
    if settings.load(_path()) == OK and settings.has_section(_SECTION):
        has_rider = settings.get_value(_SECTION, "created", false)
        rider_name_written = settings.get_value(_SECTION, "name", "")
        horse_name_written = settings.get_value(_SECTION, "horse_name", "")
        looks = Looks.complete(settings.get_value(_SECTION, "looks", {}))
    if settings.has_section(_PROGRESS):
        stars = settings.get_value(_PROGRESS, "stars", {})
        has_seen_instruction = settings.get_value(_PROGRESS, "instruction_seen", false)
        finery = Finery.complete(settings.get_value(_PROGRESS, "finery", {}))
    if "--new-rider" in OS.get_cmdline_user_args():
        has_rider = false


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
        _SECTION,
        {
            "created": true,
            "name": rider_name_written,
            "horse_name": horse_name_written,
            "looks": looks,
        }
    )


## The looks of the rider dressed in her finery, to draw her.
func dressed() -> Dictionary:
    var result := looks.duplicate()
    result["finery"] = finery.duplicate()
    return result


## Win the next step of the piece of finery, and remember it.
func win(piece: String) -> void:
    if not Finery.PIECES.has(piece):
        return
    finery[piece] = mini(int(finery.get(piece, 0)) + 1, Finery.PIECES[piece]["steps"])
    _store(_PROGRESS, {"finery": finery})


## Whether the player finished the level.
func has_finished(level_id: String) -> bool:
    return stars.has(level_id)


## Remember that the player finished the level with the stars, keeping the
## most stars of all her rides.
func finish_level(level_id: String, won: int) -> void:
    stars[level_id] = maxi(won, stars.get(level_id, 0))
    _store(_PROGRESS, {"stars": stars})


## Remember that the player has seen the instruction.
func see_instruction() -> void:
    has_seen_instruction = true
    _store(_PROGRESS, {"instruction_seen": true})


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
