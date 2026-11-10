class_name Conversation
extends Control

## Show what a person says: their portrait and name, and the lines, each with
## its pictures (the animals and the landmarks of a clue), so that a child who
## reads slowly still understands it.

## The portrait is drawn this big, in pixels.
const _PORTRAIT_SIDE := 64.0
const _MARGIN := 8.0

var _portrait: Texture2D = null
var _rows: VBoxContainer


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _rows = VBoxContainer.new()
    _rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _rows.add_theme_constant_override("separation", 2)
    add_child(_rows)
    visible = false


## Show the person and the lines: each line a dictionary with "text" and
## optionally "icons" (an array of [code][texture, modulate][/code]), drawn at
## the size of their texture.
func open(portrait: Texture2D, speaker: String, lines: Array[Dictionary]) -> void:
    _portrait = portrait
    for child in _rows.get_children():
        _rows.remove_child(child)
        child.queue_free()

    var text_left := _MARGIN * 2.0 + _PORTRAIT_SIDE
    var width := size.x - text_left - _MARGIN
    _rows.position = Vector2(text_left, _MARGIN - 2.0)
    _rows.size = Vector2(width, 0)

    _rows.add_child(_label(speaker, width, Palette.CRIMSON_DARK))
    for line in lines:
        var icons: Array = line.get("icons", [])
        if not icons.is_empty():
            var row := HBoxContainer.new()
            row.add_theme_constant_override("separation", 2)
            for icon in icons:
                var picture := TextureRect.new()
                picture.texture = icon[0]
                picture.modulate = icon[1]
                picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                picture.custom_minimum_size = (icon[0] as Texture2D).get_size()
                row.add_child(picture)
            _rows.add_child(row)
        var text: String = line.get("text", "")
        if text != "":
            _rows.add_child(_label(text, width, Palette.OUTLINE))

    visible = true
    _fit.call_deferred()
    queue_redraw()


func close() -> void:
    visible = false


func _label(text: String, width: float, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.custom_minimum_size = Vector2(width, 0)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
    return label


## Make the panel as high as its lines, but at least as high as the portrait.
func _fit() -> void:
    var portrait := _PORTRAIT_SIDE + 2.0 * _MARGIN
    size.y = maxf(portrait, _rows.get_combined_minimum_size().y + 2.0 * _MARGIN)
    queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Palette.OUTLINE)
    draw_rect(Rect2(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0), Palette.FELT)

    # NOTE (mristin):
    # The corners in gold, as a hint of the ornaments which come later.
    for corner in [
        Vector2(4, 4), Vector2(size.x - 9, 4), Vector2(4, size.y - 9), size - Vector2(9, 9)
    ]:
        draw_rect(Rect2(corner, Vector2(5, 1)), Palette.GOLD)
        draw_rect(Rect2(corner, Vector2(1, 5)), Palette.GOLD)
        draw_rect(Rect2(corner + Vector2(4, 0), Vector2(1, 5)), Palette.GOLD)
        draw_rect(Rect2(corner + Vector2(0, 4), Vector2(5, 1)), Palette.GOLD)

    if _portrait != null:
        var side := _PORTRAIT_SIDE
        var at := Vector2(_MARGIN, _MARGIN)
        draw_rect(Rect2(at - Vector2.ONE, Vector2.ONE * (side + 2.0)), Palette.OUTLINE)
        draw_texture_rect(_portrait, Rect2(at, Vector2.ONE * side), false)
