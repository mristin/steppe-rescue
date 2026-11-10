extends SceneTree

## Export every picture which the game draws, big, into a folder, with a
## manifest of how the game uses each one, so that an artist (or an image
## model) can redraw them:
##
## [codeblock]
## $GODOT --headless --path . --script dev/pictures/export_art.gd -- <folder>
## [/codeblock]
##
## The pictures are drawn as vectors and pixelated at [constant _ZOOM] times
## the size at which the game shows them (see [Pixelate]), so they keep their
## details. The manifest (manifest.json) gives, for each file, the size in
## the logical pixels of the game (960 x 540; the screen shows two pixels per
## logical pixel), what it is, where it is used, and how it is placed.

## The pictures are exported this many times bigger than the game shows them.
const _ZOOM := 4.0

var _folder := ""
var _manifest: Array[Dictionary] = []


func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    _folder = args[0] if not args.is_empty() else "art"
    DirAccess.make_dir_recursive_absolute(_folder)
    _export.call_deferred()


func _export() -> void:
    var looks := Looks.DEFAULT.duplicate()
    var all_finery := Looks.DEFAULT.duplicate()
    all_finery["finery"] = {}
    for piece in Finery.PIECES:
        all_finery["finery"][piece] = Finery.PIECES[piece]["steps"]

    # NOTE (mristin):
    # The icons.
    for name in Icons.all():
        _put(
            "icons/%s.png" % name,
            Icons.of(Icons.all()[name], 2.0 * _ZOOM),
            Icons.SIZE * 2.0,
            "An icon in the conversations, the bars, the hearing and the map.",
            "Drawn at 1x to 3x of 12 x 9 logical pixels; transparent background."
        )

    # NOTE (mristin):
    # The rider and her horse from the side.
    for gait in range(4):
        for frame in range(2):
            _put(
                "side_view/horse_gait%d_frame%d.png" % [gait, frame],
                SideView.texture(looks, gait, frame, false, 2.0 * _ZOOM),
                SideView.HORSE_BOX.size * 2.0,
                (
                    "The horse from the side, facing right, saddled; gait 0 stands, 1 walks, "
                    + "2 trots, 3 gallops; two frames each."
                ),
                (
                    "The speed bar (at 1.5x), the reward (6x), the instruction (6x). "
                    + "The hooves stand on the line y = 23 of a 34 x 24 box."
                )
            )
    for gait in [0, 3]:
        _put(
            "side_view/rider_on_horse_gait%d.png" % gait,
            SideView.texture(looks, gait, 0, true, 2.0 * _ZOOM),
            SideView.RIDER_BOX.size * 2.0,
            "The rider on her horse from the side, facing right, in the default looks.",
            "The creator (9x), the level select (2.5x), the instruction (6x)."
        )
    _put(
        "side_view/rider_in_all_finery.png",
        SideView.texture(all_finery, 0, 0, true, 2.0 * _ZOOM),
        SideView.RIDER_BOX.size * 2.0,
        "The rider and her horse wearing every piece of finery at its last step.",
        "As above; each piece is a layer drawn over the plain tack and clothes."
    )
    for feature in ["hair", "hat", "coat", "horse", "marking"]:
        for option in Looks.OPTIONS[feature]:
            var varied := looks.duplicate()
            varied[feature] = option
            _put(
                "side_view/looks/%s_%s.png" % [feature, option],
                SideView.texture(varied, 0, 0, true, 1.5 * _ZOOM),
                SideView.RIDER_BOX.size * 1.5,
                "The rider in the %s %s (the other looks are the defaults)." % [option, feature],
                "Every option of the creator must combine with every other (they are layers)."
            )
    for piece in Finery.PIECES:
        for at in range(1, Finery.PIECES[piece]["steps"] + 1):
            var dressed := looks.duplicate()
            dressed["finery"] = {piece: at}
            _put(
                "finery/%s_step%d.png" % [piece, at],
                Reward.preview(piece, at, looks),
                Vector2(128, 116),
                (
                    "The reward card of the finery %s (%s), step %d of %d: a close-up."
                    % [piece, Finery.PIECES[piece]["kazakh"], at, Finery.PIECES[piece]["steps"]]
                ),
                "The picture on a reward card, about 128 x 116 logical pixels."
            )

    # NOTE (mristin):
    # The rider from the front: the face overlay and the figure.
    for hair in Looks.OPTIONS["hair"]:
        for hat in Looks.OPTIONS["hat"]:
            var varied := looks.duplicate()
            varied["hair"] = hair
            varied["hat"] = hat
            varied["finery"] = {"earrings": 1, "feathers": 1}
            _put(
                "front_view/overlay_%s_%s.png" % [hair, hat],
                FrontView.overlay(varied, 10.0 * _ZOOM / 2.0),
                FrontView.OVERLAY_BOX.size * 10.0,
                (
                    "The face overlay: the hat, the hair and the earrings drawn over the "
                    + "player's face in the camera picture; the face itself stays free."
                ),
                (
                    "Placed by the middle between the eyes, which is at 50% x and "
                    + "%d%% y of the picture; one eye distance is 1/4.4 of its width."
                    % roundi(-FrontView.OVERLAY_BOX.position.y / FrontView.OVERLAY_BOX.size.y * 100)
                )
            )
    var poses := {
        "stand": [0.0, 0.0],
        "squat_half": [0.5, 0.0],
        "squat_deep": [1.0, 0.0],
        "reins_left": [0.0, 1.0],
        "reins_right": [0.0, -1.0],
    }
    for pose in poses:
        _put(
            "front_view/figure_%s.png" % pose,
            FrontView.figure(looks, poses[pose][0], poses[pose][1], 3.0 * _ZOOM),
            FrontView.FIGURE_BOX.size * 12.0,
            "The rider standing in front of the camera, as in a mirror: %s." % pose,
            (
                "The instruction (12 per eye distance), the small figure in the level (4), "
                + "the free space (11), the settings (12), the reward (8). Feet on the bottom."
            )
        )

    # NOTE (mristin):
    # The creatures from above.
    var rider_shapes := TopDown.horse(
        Looks.color(looks, "horse"),
        Looks.color(looks, "mane"),
        0,
        {
            "coat": Looks.color(looks, "coat"),
            "hat": Looks.hat_color(looks),
            "hair": Looks.color(looks, "hair_color")
        },
        0
    )
    _put_top("rider_on_horse", rider_shapes, "The rider on her horse from above, while riding.")
    for id in ["sheep", "horse", "camel"]:
        _put_top("animal_" + id, TopDown.animal(id, 0), "A lost animal to bring home: " + id)
    _put_top(
        "person",
        TopDown.person(Palette.INDIGO, Palette.FELT),
        "A person of the steppe from above (Grandmother, the shepherd, the beekeeper)."
    )
    for kind in Wildlife.KINDS:
        if kind == "locust":
            continue
        for frame in range(2):
            _put_top(
                "wild_%s_frame%d" % [kind, frame],
                TopDown.scaled(WildShapes.of(kind, frame), Wildlife.KINDS[kind]["scale"]),
                "A wild %s, decoration, which runs or flies away from the rider." % kind
            )
    _put_top("wild_burrow", WildShapes.burrow(), "The burrow of a marmot.")

    # NOTE (mristin):
    # The landmarks, the panels and the big pictures.
    var ids := ["spring", "rock", "bushes", "birches", "lake", "pasture", "kurgan", "well", "yurt"]
    var landmarks := Landmark.contact_sheet()
    for i in range(landmarks.size()):
        var texture: ImageTexture = landmarks[i]
        _put(
            "landmarks/%s.png" % ids[i],
            texture,
            texture.get_size(),
            "The landmark %s on the level map, from above." % ids[i],
            "Drawn at its radius on the map; round, centred; the game sizes it per level."
        )
    for style in Ornaments.STYLES:
        _put(
            "ui/panel_%s.png" % style,
            Ornaments.panel(Vector2(200, 60), style),
            Vector2(200, 60),
            "A felt panel with the ornaments, for the buttons and the frames (%s)." % style,
            "Stretched to any size by the game: the border must work as a nine-patch."
        )
    _put(
        "maps/level_select_map.png",
        SteppeMap.texture(10),
        SteppeMap.SIZE,
        "The painted map of the level select: the home aul and the path past ten levels.",
        "Full screen. The banners of the levels stand over the spots of SteppeMap.SPOTS."
    )
    _put(
        "maps/steppe_background.png",
        IntroPicture.background(),
        IntroPicture.SIZE,
        "The steppe behind the language select, the creator, the settings and the reward.",
        "Full screen, under the panels; the rider stands in it in the creator."
    )

    for id in Icons.PORTRAITS:
        _put(
            "portraits/%s.png" % id,
            Icons.portrait(id),
            Vector2(64, 64),
            "The portrait of %s in the conversations, a photograph pixelized." % id,
            "64 x 64 logical pixels (128 x 128 on the screen)."
        )

    var file := FileAccess.open(_folder + "/manifest.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(_manifest, "  "))
    file.close()
    print("Wrote %d pictures to %s" % [_manifest.size(), _folder])
    quit()


func _put_top(name: String, shapes: Array, what: String) -> void:
    _put(
        "top_down/%s.png" % name,
        TopDown.texture("export_" + name, TopDown.scaled(shapes, _ZOOM), 0.0),
        Vector2.ZERO,
        what + " Facing north (up).",
        (
            "Seen straight from above, facing up; the game turns it to 64 headings "
            + "(16 for the wild ones) and draws it at a quarter of this size."
        )
    )


func _put(path: String, texture: Texture2D, logical: Vector2, what: String, use: String) -> void:
    var target := "%s/%s" % [_folder, path]
    DirAccess.make_dir_recursive_absolute(target.get_base_dir())
    var image := texture.get_image()
    image.save_png(target)
    var shown := logical if logical != Vector2.ZERO else Vector2(image.get_size()) / (_ZOOM * 2.0)
    _manifest.append(
        {
            "file": path,
            "pixels": [image.get_width(), image.get_height()],
            "logical_size_in_game": [roundi(shown.x), roundi(shown.y)],
            "what": what,
            "use": use,
        }
    )
