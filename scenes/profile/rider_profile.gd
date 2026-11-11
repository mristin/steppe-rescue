class_name RiderProfile
extends RefCounted

## Keep one rider of a journey (see [Profile]): her name and the name of her
## horse as the player wrote them, their [Looks], and her own wardrobe: the
## [Finery] she won and the pieces she took off. With two players, each has
## her own rider and her own wardrobe.

## Whether the player created her rider already.
var created := false

## The name of the rider as the player wrote it; empty for the default name in
## the language of the game (see [method rider_name]).
var name_written := ""

## The name of the horse as the player wrote it; empty for the default name.
var horse_name_written := ""

## The looks of the rider and her horse.
var looks: Dictionary = Looks.DEFAULT.duplicate()

## The finery which the rider won: the step of each piece (see [Finery]).
var finery: Dictionary = {}

## The pieces of the finery which she won but took off in the wardrobe.
var taken_off: Array = []

## The player (0 or 1), for her default name.
var player := 0


func _init(a_player := 0) -> void:
    player = a_player
    looks = default_looks(a_player)


## The looks of a new rider of the player: the second player starts on another
## painted rider and horse than the first, since two players never ride the
## same (see [method Profile.taken]).
static func default_looks(a_player: int) -> Dictionary:
    if a_player == 0:
        return Looks.DEFAULT.duplicate()
    return Looks.horse_preset(Looks.preset(Looks.DEFAULT, "2"), "2")


## The name of the rider, by default Aigerim (Dana for the second player) in
## the alphabet of the language.
func rider_name() -> String:
    if name_written != "":
        return name_written
    if player == 1:
        # TRANSLATORS: The default name of the second rider, a girl, in your alphabet.
        return tr("Dana")
    # TRANSLATORS: The default name of the rider, a girl, in your alphabet.
    return tr("Aigerim")


## The name of the horse, by default Tulpar, the winged horse of the legends
## (Zhuldyz, "star", for the second player).
func horse_name() -> String:
    if horse_name_written != "":
        return horse_name_written
    if player == 1:
        # TRANSLATORS: The second rider's default horse name, Жұлдыз ("star"), in your alphabet.
        return tr("Zhuldyz")
    # TRANSLATORS: The default name of the horse, Тұлпар, in your alphabet.
    return tr("Tulpar")


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


## The rider as plain data, for the save.
func to_data() -> Dictionary:
    return {
        "created": created,
        "name": name_written,
        "horse_name": horse_name_written,
        "looks": looks,
        "finery": finery,
        "taken_off": taken_off,
    }


## Take the rider from the plain data of the save.
func from_data(data: Dictionary) -> void:
    created = bool(data.get("created", false))
    name_written = str(data.get("name", ""))
    horse_name_written = str(data.get("horse_name", ""))
    var saved_looks: Dictionary = data.get("looks", {})
    looks = Looks.complete(saved_looks) if not saved_looks.is_empty() else default_looks(player)
    var saved_finery: Dictionary = data.get("finery", {})
    var won := {}
    for piece in saved_finery:
        won[piece] = int(saved_finery[piece])
    finery = Finery.complete(won)
    taken_off = data.get("taken_off", []).duplicate()
