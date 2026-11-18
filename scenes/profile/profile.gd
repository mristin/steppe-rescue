extends Node

## Keep the journeys (sessions) of the players, like the voyages of Bird Dog
## (see section 9 of DESIGN.md): a journey is one playthrough with its name,
## how many players ride together (1 or 2, chosen once for the journey), the
## rider of each player (see [RiderProfile]: her name, the name of her horse,
## their [Looks], and her own wardrobe of the [Finery] she won and wears), and
## how far they came: the stars of each level they finished, the levels whose
## gift they chose, and whether they have seen the instruction. The fields
## below are those of the current journey (see [method choose_session]).
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
## changes. Format 1 had a single rider, with her finery in the progress.
const FORMAT := 2

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

## How many players ride together in the journey: 1 or 2; 0 while a new
## journey has not chosen yet.
var players := 0

## The rider of each player (see [RiderProfile]), as many as [member players].
var riders: Array[RiderProfile] = [RiderProfile.new(0)]

## The most stars won in each finished level, by the id of the level (see
## [LevelList]).
var stars: Dictionary = {}

## Whether the players have seen the instruction (see [Instruction]).
var has_seen_instruction := false

## The ids of the levels whose gifts they chose: a level gives its gifts once,
## so that riding it again is no mine of finery.
var rewarded: Array = []


func _ready() -> void:
    _migrate()
    var last := last_id()
    if last != "":
        choose_session(last)
    if "--new-rider" in OS.get_cmdline_user_args():
        for each in riders:
            each.created = false


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


## Start a new journey with the name, and save it; how many players ride,
## and their riders, are still to choose (see [method set_players]).
func start_session(new_name: String) -> void:
    _new_session(new_name)
    _from_data({})
    _save()


## Let as many players ride together in the journey (1 or 2), each with her
## own rider (the new ones still to create), and save it.
func set_players(count: int) -> void:
    players = clampi(count, 1, 2)
    while riders.size() < players:
        riders.append(RiderProfile.new(riders.size()))
    riders.resize(players)
    _tell_vision()
    _save()


## Tell the vision how many players ride, so that it splits the camera
## picture between them.
func _tell_vision() -> void:
    var vision := get_node_or_null("/root/Vision")
    if vision != null and vision.service != null:
        vision.service.SetPlayerCount(maxi(1, players))


## The rider of the player (0 or 1); a player whom the journey does not have
## (e.g., a level of two players in a journey of one) gets the default rider of
## her place (Dana on Zhuldyz for the second), which is not saved.
func rider(player := 0) -> RiderProfile:
    if player >= riders.size():
        return RiderProfile.new(player)
    return riders[maxi(player, 0)]


## Whether every player created her rider.
func has_riders() -> bool:
    return players > 0 and riders.all(func(each: RiderProfile) -> bool: return each.created)


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


## Delete the saved journey of the id for good; return whether it was there.
## Deleting the current journey leaves none chosen, and the players choose
## (or start) one before they ride again.
func delete_session(id: String) -> bool:
    var path := _session_path(id)
    if id == "" or not FileAccess.file_exists(path):
        return false
    DirAccess.remove_absolute(path)
    var settings := ConfigFile.new()
    settings.load(_path())
    if settings.get_value("general", "last_session", "") == id:
        settings.set_value("general", "last_session", "")
        settings.save(_path())
    if id == session_id:
        session_id = ""
        session_name = ""
        created = ""
        _from_data({})
    return true


## The saved journeys, the most recently played first, each with "id",
## "name", "updated", "riders" (each a dictionary with "name", as written,
## empty for the default, and "looks") and "stars" (in all the levels).
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
        var shown: Array[Dictionary] = []
        for each in _riders_of(data):
            shown.append(
                {"name": str(each.get("name", "")), "looks": Looks.complete(each.get("looks", {}))}
            )
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
                    "riders": shown,
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
    var saved_riders: Array[Dictionary] = []
    for each in riders:
        saved_riders.append(each.to_data())
    return {
        "format": FORMAT,
        "id": session_id,
        "name": session_name,
        "created": created,
        "updated": Time.get_datetime_string_from_system(),
        "players": players,
        "riders": saved_riders,
        "progress":
        {
            "stars": stars,
            "instruction_seen": has_seen_instruction,
            "rewarded": rewarded,
        },
    }


## The riders of the saved data, as plain data; a save of format 1 has one
## rider, with her finery in the progress.
static func _riders_of(data: Dictionary) -> Array:
    if data.has("riders"):
        return data["riders"]
    if not data.has("rider"):
        return []
    var progress: Dictionary = data.get("progress", {})
    var single: Dictionary = data["rider"].duplicate()
    single["finery"] = progress.get("finery", {})
    single["taken_off"] = progress.get("taken_off", [])
    return [single]


func _from_data(data: Dictionary) -> void:
    var progress: Dictionary = data.get("progress", {})
    var saved_riders := _riders_of(data)
    players = clampi(int(data.get("players", saved_riders.size())), 0, 2)
    riders.clear()
    for i in range(maxi(1, players)):
        var each := RiderProfile.new(i)
        if i < saved_riders.size():
            each.from_data(saved_riders[i])
        riders.append(each)
    stars = {}
    var saved_stars: Dictionary = progress.get("stars", {})
    for level in saved_stars:
        stars[level] = int(saved_stars[level])
    has_seen_instruction = bool(progress.get("instruction_seen", false))
    rewarded = progress.get("rewarded", []).duplicate()
    _tell_vision()


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
        var section := "rider" if i == 0 else "rider_%d" % i
        var progress := "progress" if i == 0 else "progress_%d" % i
        if not settings.get_value(section, "created", false):
            break
        var written: String = settings.get_value(section, "name", "")
        start_session(written if written != "" else default_session_name())
        _from_data(
            {
                "rider":
                {
                    "created": true,
                    "name": written,
                    "horse_name": settings.get_value(section, "horse_name", ""),
                    "looks": settings.get_value(section, "looks", {}),
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


## The name of the player's rider, by default Aigerim (or Dana) in the
## alphabet of the language.
func rider_name(player := 0) -> String:
    return rider(player).rider_name()


## Keep the player's rider and remember her for the next start.
func save(a_rider_name: String, a_horse_name: String, a_looks: Dictionary, player := 0) -> void:
    var each := rider(player)
    each.name_written = a_rider_name.strip_edges().left(MAX_NAME)
    each.horse_name_written = a_horse_name.strip_edges().left(MAX_NAME)
    each.looks = Looks.complete(a_looks)
    each.looks.erase("finery")
    each.created = true
    if players == 0:
        players = 1
    _save()


## Put on (or take off) the piece which the player's rider won, in her
## wardrobe, and remember it.
func wear(piece: String, on: bool, player := 0) -> void:
    var each := rider(player)
    if on:
        each.taken_off.erase(piece)
    elif piece not in each.taken_off:
        each.taken_off.append(piece)
    _save()


## Win the next step of the piece of finery for the player's rider, and
## remember it.
func win(piece: String, player := 0) -> void:
    if not Finery.PIECES.has(piece):
        return
    var each := rider(player)
    each.finery[piece] = mini(int(each.finery.get(piece, 0)) + 1, Finery.PIECES[piece]["steps"])
    each.taken_off.erase(piece)
    _save()


## Whether they chose the gifts of the level already.
func was_rewarded(level_id: String) -> bool:
    return level_id in rewarded


## Remember that they chose the gifts of the level.
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
