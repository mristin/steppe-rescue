extends Node

## Keep the journeys (sessions) of the players, like the voyages of Bird Dog
## (see section 9 of DESIGN.md): a journey is one playthrough with its name,
## its rider (her name, the name of her horse and their [Looks]) and how far
## she came: the stars of each level she finished, the [Finery] she won and
## wears, the levels whose gift she chose, and whether she has seen the
## instruction. The fields below are those of the current journey (see
## [method choose_session]).
##
## Every journey is a JSON file in the directory of the saves next to the
## settings (see [method saves_dir]), written to a temporary file first and
## then renamed, so that a crash while saving never destroys the last good
## save. The settings remember the last journey ("general/last_session").
## The riders of the older versions, kept in the settings, become journeys
## once.
##
## Start the game with `-- --new-rider` to create the rider again.

## The format of the saves; bump it and convert the old files on load when it
## changes.
const FORMAT := 1

## The longest name, in letters.
const MAX_NAME := 12

## The longest name of a journey, in letters.
const MAX_SESSION_NAME := 24

## The most riders of the older versions which become journeys.
const _OLD_RIDERS := 6

## The id of the current journey (the name of its file); empty before one.
var session_id := ""

## The name of the current journey.
var session_name := ""

## When the current journey was created.
var created := ""

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
    _migrate()
    var last := last_id()
    if last != "":
        choose_session(last)
    if "--new-rider" in OS.get_cmdline_user_args():
        has_rider = false


## The name of a new journey before the player changes it: the date and the
## time.
static func default_session_name() -> String:
    var now := Time.get_datetime_dict_from_system()
    return (
        "%04d-%02d-%02d %02d:%02d"
        % [now["year"], now["month"], now["day"], now["hour"], now["minute"]]
    )


## The directory of the saves: "saves" next to the settings, or, for the
## settings of the tests, "<their name>_saves".
func saves_dir() -> String:
    var settings := _path()
    if settings.get_file() == "settings.cfg":
        return settings.get_base_dir().path_join("saves")
    return settings.get_basename() + "_saves"


## Start a new journey with the name and a rider still to create, and save it.
func start_session(new_name: String) -> void:
    _new_session(new_name)
    _from_data({})
    _save()


## Give the current data a new journey: its id, its name and when it was
## created.
func _new_session(new_name: String) -> void:
    var now := Time.get_datetime_dict_from_system()
    var id := (
        "%04d%02d%02d-%02d%02d%02d"
        % [now["year"], now["month"], now["day"], now["hour"], now["minute"], now["second"]]
    )
    # NOTE (mristin):
    # Two journeys started within a second get different ids.
    var suffix := 1
    session_id = id
    while FileAccess.file_exists(_session_path(session_id)):
        suffix += 1
        session_id = "%s-%d" % [id, suffix]
    session_name = new_name.strip_edges().left(MAX_SESSION_NAME)
    if session_name == "":
        session_name = default_session_name()
    created = Time.get_datetime_string_from_system()


## Go on with the journey of the id; return whether it was found.
func choose_session(id: String) -> bool:
    var data: Variant = read(id)
    if data == null:
        return false
    session_id = id
    session_name = data.get("name", id)
    created = data.get("created", "")
    _from_data(data)
    _remember_last()
    return true


## The saved journeys, the most recently played first, each with "id",
## "name", "updated", "rider" (her name as written, empty for the default),
## "looks" and "stars" (in all the levels).
func sessions() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if not DirAccess.dir_exists_absolute(saves_dir()):
        return result
    for file in DirAccess.get_files_at(saves_dir()):
        if not file.ends_with(".json"):
            continue
        var id := file.get_basename()
        var data: Variant = read(id)
        if data == null:
            continue
        var rider: Dictionary = data.get("rider", {})
        var total := 0
        for level in data.get("progress", {}).get("stars", {}).values():
            total += int(level)
        (
            result
            . append(
                {
                    "id": id,
                    "name": data.get("name", id),
                    "updated": data.get("updated", ""),
                    "rider": rider.get("name", ""),
                    "looks": Looks.complete(rider.get("looks", {})),
                    "stars": total,
                }
            )
        )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary) -> bool:
            return (
                a["updated"] > b["updated"] or (a["updated"] == b["updated"] and a["id"] > b["id"])
            )
    )
    return result


## The id of the journey played last, if its save still exists, else "".
func last_id() -> String:
    var settings := ConfigFile.new()
    settings.load(_path())
    var id: String = settings.get_value("general", "last_session", "")
    if id == "" or read(id) == null:
        return ""
    return id


## Read the save of a journey; null if it is missing or broken.
func read(id: String) -> Variant:
    var path := _session_path(id)
    if id == "" or not FileAccess.file_exists(path):
        return null
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not data is Dictionary or int(data.get("format", 0)) > FORMAT:
        return null
    return data


## The journey as plain data, for its save.
func to_data() -> Dictionary:
    return {
        "format": FORMAT,
        "id": session_id,
        "name": session_name,
        "created": created,
        "updated": Time.get_datetime_string_from_system(),
        "rider":
        {
            "created": has_rider,
            "name": rider_name_written,
            "horse_name": horse_name_written,
            "looks": looks,
        },
        "progress":
        {
            "stars": stars,
            "instruction_seen": has_seen_instruction,
            "finery": finery,
            "taken_off": taken_off,
            "rewarded": rewarded,
        },
    }


func _from_data(data: Dictionary) -> void:
    var rider: Dictionary = data.get("rider", {})
    var progress: Dictionary = data.get("progress", {})
    has_rider = bool(rider.get("created", false))
    rider_name_written = str(rider.get("name", ""))
    horse_name_written = str(rider.get("horse_name", ""))
    looks = Looks.complete(rider.get("looks", {}))
    stars = {}
    var saved_stars: Dictionary = progress.get("stars", {})
    for level in saved_stars:
        stars[level] = int(saved_stars[level])
    has_seen_instruction = bool(progress.get("instruction_seen", false))
    var saved_finery: Dictionary = progress.get("finery", {})
    var won := {}
    for piece in saved_finery:
        won[piece] = int(saved_finery[piece])
    finery = Finery.complete(won)
    taken_off = progress.get("taken_off", []).duplicate()
    rewarded = progress.get("rewarded", []).duplicate()


## Save the current journey; without one (e.g., in the tests), start one.
func _save() -> void:
    if session_id == "":
        _new_session(default_session_name())
    DirAccess.make_dir_recursive_absolute(saves_dir())
    var path := _session_path(session_id)
    var temporary := path + ".tmp"
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        push_error(
            "Could not save the journey to %s: %s" % [temporary, FileAccess.get_open_error()]
        )
        return
    file.store_string(JSON.stringify(to_data(), "  "))
    file.close()
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)
    DirAccess.rename_absolute(temporary, path)
    _remember_last()


func _remember_last() -> void:
    var settings := ConfigFile.new()
    settings.load(_path())
    settings.set_value("general", "last_session", session_id)
    DirAccess.make_dir_recursive_absolute(_path().get_base_dir())
    settings.save(_path())


func _session_path(id: String) -> String:
    return saves_dir().path_join("%s.json" % id)


## Turn the riders of the older versions, kept in the settings ("rider",
## "rider_1", ... with their "progress", "progress_1", ...), into journeys,
## once; the current one becomes the last journey.
func _migrate() -> void:
    var settings := ConfigFile.new()
    if settings.load(_path()) != OK or settings.get_value("general", "migrated", false):
        return
    var current := int(settings.get_value("general", "rider", 0))
    var current_id := ""
    for i in range(_OLD_RIDERS):
        var rider := "rider" if i == 0 else "rider_%d" % i
        var progress := "progress" if i == 0 else "progress_%d" % i
        if not settings.get_value(rider, "created", false):
            break
        var written: String = settings.get_value(rider, "name", "")
        start_session(written if written != "" else default_session_name())
        _from_data(
            {
                "rider":
                {
                    "created": true,
                    "name": written,
                    "horse_name": settings.get_value(rider, "horse_name", ""),
                    "looks": settings.get_value(rider, "looks", {}),
                },
                "progress":
                {
                    "stars": settings.get_value(progress, "stars", {}),
                    "instruction_seen": settings.get_value(progress, "instruction_seen", false),
                    "finery": settings.get_value(progress, "finery", {}),
                    "taken_off": settings.get_value(progress, "taken_off", []),
                    "rewarded": settings.get_value(progress, "rewarded", []),
                },
            }
        )
        _save()
        if i == current:
            current_id = session_id
    settings.load(_path())
    settings.set_value("general", "migrated", true)
    if current_id != "":
        settings.set_value("general", "last_session", current_id)
    settings.save(_path())
    session_id = ""


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
    _save()


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
    _save()


## Win the next step of the piece of finery, and remember it.
func win(piece: String) -> void:
    if not Finery.PIECES.has(piece):
        return
    finery[piece] = mini(int(finery.get(piece, 0)) + 1, Finery.PIECES[piece]["steps"])
    taken_off.erase(piece)
    _save()


## Whether she chose the gift of the level already.
func was_rewarded(level_id: String) -> bool:
    return level_id in rewarded


## Remember that she chose the gift of the level.
func reward(level_id: String) -> void:
    if level_id == "" or level_id in rewarded:
        return
    rewarded.append(level_id)
    _save()


## Whether the player finished the level.
func has_finished(level_id: String) -> bool:
    return stars.has(level_id)


## Remember that the player finished the level with the stars, keeping the
## most stars of all her rides.
func finish_level(level_id: String, won: int) -> void:
    stars[level_id] = maxi(won, stars.get(level_id, 0))
    _save()


## Remember that the player has seen the instruction.
func see_instruction() -> void:
    has_seen_instruction = true
    _save()


func _path() -> String:
    return get_node("/root/Languages").settings_path()
