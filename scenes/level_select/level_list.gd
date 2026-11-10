class_name LevelList
extends RefCounted

## Know the levels of the game: the scenes of `res://data/levels/`, in the
## order of their file names, which start with their number (e.g.,
## `01_the_lamb_by_the_spring.tscn`). The id of a level is its file name
## without the extension; the profile keeps the stars by it (see the autoload
## Profile).
##
## The first level is always open, and finishing a level opens the next one
## (see section 6 of DESIGN.md).

const DIRECTORY := "res://data/levels"

static var _titles: Dictionary = {}


## The paths of the levels, in their order.
static func paths() -> Array[String]:
    var names := PackedStringArray()
    for file in DirAccess.get_files_at(DIRECTORY):
        # NOTE (mristin):
        # An exported game lists the scenes as .remap.
        var name := file.trim_suffix(".remap")
        if name.ends_with(".tscn") and name not in names:
            names.append(name)
    names.sort()
    var result: Array[String] = []
    for name in names:
        result.append("%s/%s" % [DIRECTORY, name])
    return result


## The id of the level at the path, e.g., "01_the_lamb_by_the_spring".
static func id(path: String) -> String:
    return path.get_file().get_basename()


## The title of the level as written in its map, untranslated.
static func title(path: String) -> String:
    if not _titles.has(path):
        var map: LevelMap = (load(path) as PackedScene).instantiate()
        _titles[path] = map.title
        map.free()
    return _titles[path]


## Whether the player may play the level: the first one, and each one after a
## finished one.
static func is_open(path: String, profile: Node) -> bool:
    var all := paths()
    var index := all.find(path)
    return index == 0 or (index > 0 and profile.has_finished(id(all[index - 1])))


## The level to play next: the first open level not finished yet; empty if all
## are finished.
static func next(profile: Node) -> String:
    for path in paths():
        if not profile.has_finished(id(path)):
            return path if is_open(path, profile) else ""
    return ""
