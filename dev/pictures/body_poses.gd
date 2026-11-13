extends SceneTree

## Draw the painted clothes of every painted rider (see [PaintedBody]) in the
## poses of the game into one sheet, to review how they sit on the body (it
## needs a display, not --headless):
##
## [codeblock]
## $GODOT --path . --windowed --script dev/pictures/body_poses.gd -- sheet.png
## [/codeblock]
##
## Each row is a rider, each column a pose; the joints are drawn as dots.

## The side of a cell, in pixels.
const CELL := 320

## The poses, as the joints in a cell (in the order of [enum CameraPanel.Joint];
## the left of the player on the left, as in the mirrored camera picture).
const POSES := {
    "reins":
    [
        Vector2(110, 90), Vector2(210, 90), Vector2(100, 185), Vector2(220, 185),
        Vector2(140, 175), Vector2(180, 175), Vector2(125, 235), Vector2(195, 235),
        Vector2(125, 275), Vector2(195, 275), Vector2(125, 312), Vector2(195, 312),
    ],
    "arms down":
    [
        Vector2(110, 90), Vector2(210, 90), Vector2(100, 165), Vector2(220, 165),
        Vector2(98, 235), Vector2(222, 235), Vector2(125, 235), Vector2(195, 235),
        Vector2(125, 275), Vector2(195, 275), Vector2(125, 312), Vector2(195, 312),
    ],
    "turn left":
    [
        Vector2(110, 90), Vector2(210, 90), Vector2(85, 180), Vector2(175, 190),
        Vector2(55, 165), Vector2(115, 170), Vector2(125, 235), Vector2(195, 235),
        Vector2(125, 275), Vector2(195, 275), Vector2(125, 312), Vector2(195, 312),
    ],
    "brake":
    [
        Vector2(110, 90), Vector2(210, 90), Vector2(80, 40), Vector2(240, 40),
        Vector2(130, 5), Vector2(190, 5), Vector2(125, 235), Vector2(195, 235),
        Vector2(125, 275), Vector2(195, 275), Vector2(125, 312), Vector2(195, 312),
    ],
    "arms out":
    [
        Vector2(110, 90), Vector2(210, 90), Vector2(45, 95), Vector2(275, 95),
        Vector2(5, 80), Vector2(315, 80), Vector2(125, 235), Vector2(195, 235),
        Vector2(125, 275), Vector2(195, 275), Vector2(125, 312), Vector2(195, 312),
    ],
}


class Sheet:
    extends Control

    func _draw() -> void:
        var font := get_theme_default_font()
        var row := 0
        for preset in Looks.PRESETS:
            var looks := Looks.preset(Looks.DEFAULT, preset)
            var column := 0
            for pose in POSES:
                var at := Vector2(column * CELL, row * CELL)
                draw_rect(Rect2(at, Vector2.ONE * CELL), Color(0.3, 0.5, 0.35))
                var joints: Array = []
                for joint: Vector2 in POSES[pose]:
                    joints.append(at + joint)
                PaintedBody.draw_body(self, joints, looks, 1.0)
                PaintedBody.draw_hands(
                    self,
                    joints[CameraPanel.Joint.LEFT_HAND],
                    joints[CameraPanel.Joint.RIGHT_HAND],
                    (joints[0] as Vector2).distance_to(joints[1]),
                    0.0,
                    joints
                )
                for joint: Vector2 in joints:
                    draw_circle(joint, 2.5, Color.RED)
                draw_string(font, at + Vector2(6, 18), "%s, rider %s" % [pose, preset])
                column += 1
            row += 1


var _frames := 0
var _target := ""
var _viewport: SubViewport


func _initialize() -> void:
    _target = OS.get_cmdline_user_args()[0]
    # NOTE (mristin):
    # The sheet is drawn off the screen, so that it is not cut to the window.
    _viewport = SubViewport.new()
    _viewport.size = Vector2i(POSES.size() * CELL, Looks.PRESETS.size() * CELL)
    _viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    var sheet := Sheet.new()
    sheet.size = _viewport.size
    _viewport.add_child(sheet)
    root.add_child(_viewport)


func _process(_delta: float) -> bool:
    _frames += 1
    if _frames == 5:
        _viewport.get_texture().get_image().save_png(_target)
        print("Wrote ", _target)
        quit()
    return false
