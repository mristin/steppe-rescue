class_name Ornaments
extends RefCounted

## Draw the felt panels of the interface with the Kazakh ornaments (ою-өрнек):
## a band around the felt, a thin golden line inside it, and the ram's horn
## (қошқар мүйіз, see [method SideView.ornament]) in the corners, the way the
## felt carpets (сырмақ) are bordered. They frame the buttons, the panels and
## the banners (see section 11 of DESIGN.md).

## The styles: the color of the felt, the band and the line.
const STYLES := {
    "felt": ["{felt}", "{crimson}", "{gold}"],
    "hover": ["{grass_light}", "{crimson}", "{gold}"],
    "selected": ["{gold}", "{crimson_dark}", "{felt}"],
    "primary": ["{crimson}", "{crimson_dark}", "{gold}"],
    "primary_hover": ["{crimson_light}", "{crimson_dark}", "{gold}"],
}


## The panel of the size (in logical pixels) in the style, pixelated.
static func panel(size: Vector2, style := "felt") -> ImageTexture:
    var size_whole := size.round()
    var colors: Array = STYLES.get(style, STYLES["felt"])
    var w := size_whole.x
    var h := size_whole.y
    var band := clampf(minf(w, h) * 0.06, 1.0, 3.0)
    var parts := PackedStringArray()
    parts.append(
        (
            '<rect x="0.5" y="0.5" width="%s" height="%s" rx="2" fill="%s"/>'
            % [_n(w - 1), _n(h - 1), colors[0]]
        )
    )
    parts.append(
        (
            (
                '<rect x="%s" y="%s" width="%s" height="%s" rx="1.5" fill="none" stroke="%s" '
                + 'stroke-width="%s"/>'
            )
            % [_n(band), _n(band), _n(w - 2 * band), _n(h - 2 * band), colors[1], _n(band)]
        )
    )
    var inset := band * 2.4
    parts.append(
        (
            (
                '<rect x="%s" y="%s" width="%s" height="%s" rx="1" fill="none" stroke="%s" '
                + 'stroke-width="0.5"/>'
            )
            % [_n(inset), _n(inset), _n(w - 2 * inset), _n(h - 2 * inset), colors[2]]
        )
    )
    if minf(w, h) >= 44.0:
        var motif := clampf(minf(w, h) * 0.05, 3.0, 7.0)
        var reach := inset + motif * 1.6
        var corners := [
            [Vector2(reach, reach), -45.0],
            [Vector2(w - reach, reach), 45.0],
            [Vector2(w - reach, h - reach), 135.0],
            [Vector2(reach, h - reach), -135.0],
        ]
        for corner in corners:
            var at: Vector2 = corner[0]
            parts.append(
                (
                    '<g transform="translate(%s %s) rotate(%s)">%s</g>'
                    % [
                        _n(at.x),
                        _n(at.y),
                        _n(corner[1]),
                        SideView.ornament(Vector2.ZERO, motif, colors[1])
                    ]
                )
            )
    return Pixelate.texture("".join(parts), Rect2(Vector2.ZERO, size_whole))


static func _n(value: float) -> String:
    return String.num(value, 2)
