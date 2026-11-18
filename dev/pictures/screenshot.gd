extends SceneTree

## Take a screenshot of a scene of the game, as the player sees it on a 1080p
## screen, to review the pixel art in place (it needs a display, not
## --headless):
##
## [codeblock]
## $GODOT --path . --windowed --resolution 1920x1080 \
##     --script dev/pictures/screenshot.gd -- res://scenes/intro/intro.tscn shot.png [frames]
## [/codeblock]
##
## Add the usual arguments of the game after it, e.g., --no-camera or --lang=kk.

var _frames := 0
var _wait := 90
var _target := ""


func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    _target = args[1]
    if args.size() > 2 and args[2].is_valid_int():
        _wait = int(args[2])
    change_scene_to_file.call_deferred(args[0])


func _process(_delta: float) -> bool:
    _frames += 1
    if _frames == _wait:
        root.get_texture().get_image().save_png(_target)
        print("Wrote ", _target)
        quit()
    return false
