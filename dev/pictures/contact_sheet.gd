extends SceneTree

## Render the pictures of the game (the icons, the horse and the rider seen
## from the side in some looks and gaits, the creatures seen from above, the
## landmarks) into one contact sheet, enlarged, to review the vector art after
## its pixelation:
##
## [codeblock]
## $GODOT --headless --path . --script dev/pictures/contact_sheet.gd -- sheet.png
## [/codeblock]

const _WIDTH := 640
const _ZOOM := 2

var _sheet: Image
var _x := 4
var _y := 4
var _row := 0


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var target := args[0] if not args.is_empty() else "contact_sheet.png"

    _sheet = Image.create_empty(_WIDTH, 2000, false, Image.FORMAT_RGBA8)
    _sheet.fill(Palette.GRASS)

    for name in Icons.all():
        _put(Icons.of(Icons.all()[name], 2.0))
    _break()

    for gait in range(4):
        for frame in range(2):
            _put(SideView.texture(Looks.DEFAULT, gait, frame, false, 2.0))
    _break()

    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    _put(SideView.texture(Looks.DEFAULT, 0, 0, true, 3.0))
    for i in range(5):
        var looks := Looks.random(rng)
        looks["hat"] = Looks.OPTIONS["hat"][i]
        looks["hair"] = Looks.OPTIONS["hair"][i]
        _put(SideView.texture(looks, 0, 0, true, 3.0))
    _break()

    for i in range(5):
        var looks := Looks.random(rng)
        looks["hat"] = Looks.OPTIONS["hat"][i]
        looks["hair"] = Looks.OPTIONS["hair"][i]
        _put(FrontView.overlay(looks, 16.0))
    for pose in [[0.0, 0.0], [0.5, 0.0], [1.0, 0.0], [0.0, 1.0]]:
        _put(FrontView.figure(Looks.DEFAULT, pose[0], pose[1], 8.0))
    _break()

    for i in range(8):
        var heading := i * TAU / 8.0
        _put(
            TopDown.texture(
                "rider", TopDown.horse(Palette.HORSE_BAY, Palette.HOOF, 0, {}, 3), heading
            )
        )
        _put(TopDown.texture("sheep", TopDown.sheep(0), heading))
        _put(TopDown.texture("camel", TopDown.camel(0), heading))
    _break()

    for picture in _extra_pictures():
        _put(picture)
    _break()

    var sheet := _sheet.get_region(Rect2i(0, 0, _WIDTH, _y + 4))
    sheet.resize(sheet.get_width() * _ZOOM, sheet.get_height() * _ZOOM, Image.INTERPOLATE_NEAREST)
    sheet.save_png(target)
    print("Wrote ", target)
    quit()


## The pictures which other scenes draw, e.g., the landmarks; found by name so
## that this tool runs before they exist.
func _extra_pictures() -> Array:
    var result := []
    for script_path in ["res://scenes/level_map/landmark.gd", "res://scenes/intro/intro_picture.gd"]:
        if not ResourceLoader.exists(script_path):
            continue
        var script: Script = load(script_path)
        if script.has_method("contact_sheet"):
            result.append_array(script.call("contact_sheet"))
    return result


func _put(texture: Texture2D) -> void:
    var image := texture.get_image()
    if _x + image.get_width() > _WIDTH - 4:
        _break()
    _sheet.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(_x, _y))
    _x += image.get_width() + 4
    _row = maxi(_row, image.get_height())


func _break() -> void:
    if _row == 0:
        return
    _x = 4
    _y += _row + 6
    _row = 0
