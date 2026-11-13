class_name Conversation
extends Control

## Show what a person says: their portrait and name, and the lines, each with
## its pictures (the animals and the landmarks of a clue), so that a child who
## reads slowly still understands it.
##
## A long talk (e.g., Grandmother's, with all the people to ask) is split into
## pages no higher than [member max_height], so that it never covers the
## rider; dots at the bottom show the pages, and [method next_page] turns
## them.

## The portrait is drawn this big, in pixels.
const _PORTRAIT_SIDE := 64.0
const _MARGIN := 8.0

## The dots of the pages take this much room at the bottom.
const _DOTS_HEIGHT := 8.0

## The pages are at most this high, in pixels, with the margins.
var max_height := 170.0

var _portrait: Texture2D = null
var _rows: VBoxContainer

## The lines of each page (indices into the lines after the speaker), and
## the page shown.
var _pages: Array[Array] = []
var _page := 0


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
        # NOTE (mristin):
        # The pictures and the text of a line stay together on a page.
        var group := VBoxContainer.new()
        group.mouse_filter = Control.MOUSE_FILTER_IGNORE
        group.add_theme_constant_override("separation", 2)
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
            group.add_child(row)
        var text: String = line.get("text", "")
        if text != "":
            group.add_child(_label(text, width, Palette.OUTLINE))
        _rows.add_child(group)

    visible = true
    _paginate()
    queue_redraw()


## How many pages the talk has.
func pages() -> int:
    return _pages.size()


## The page shown, from 0.
func page() -> int:
    return _page


## Show the next page; false if this is the last one.
func next_page() -> bool:
    if _page + 1 >= _pages.size():
        return false
    _show_page(_page + 1)
    return true


## Show the page (e.g., the same page again in another language), or the
## last one if the talk has fewer.
func turn_to(index: int) -> void:
    _show_page(clampi(index, 0, _pages.size() - 1))


func close() -> void:
    visible = false


func _label(text: String, width: float, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.custom_minimum_size = Vector2(width, 0)
    # NOTE (mristin):
    # As wide as it will be, so that the pages know how high it wraps.
    label.size = Vector2(width, 0)
    label.add_theme_color_override(
        "font_color", Palette.FELT if color == Palette.OUTLINE else Palette.GOLD
    )
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
    label.add_theme_color_override("font_outline_color", Palette.OUTLINE)
    label.add_theme_constant_override("outline_size", 6)
    return label


## Split the lines into pages no higher than [member max_height], and show
## the first.
func _paginate() -> void:
    var separation := float(_rows.get_theme_constant("separation"))
    var children := _rows.get_children()
    var room := max_height - 2.0 * _MARGIN - _DOTS_HEIGHT
    var speaker := (children[0] as Control).get_combined_minimum_size().y
    _pages = [[]]
    var used := speaker
    for i in range(1, children.size()):
        var high := (children[i] as Control).get_combined_minimum_size().y + separation
        if used + high > room and not _pages[-1].is_empty():
            _pages.append([])
            used = speaker
        _pages[-1].append(i)
        used += high
    _show_page(0)


## Show the lines of the page, and make the panel as high as them, but at
## least as high as the portrait.
func _show_page(index: int) -> void:
    _page = index
    var children := _rows.get_children()
    for i in range(1, children.size()):
        (children[i] as Control).visible = i in _pages[index]
    _rows.reset_size()
    var portrait := _PORTRAIT_SIDE + 2.0 * _MARGIN
    var dots := _DOTS_HEIGHT if _pages.size() > 1 else 0.0
    size.y = maxf(portrait, _rows.get_combined_minimum_size().y + 2.0 * _MARGIN + dots)
    queue_redraw()


func _draw() -> void:
    # NOTE (mristin):
    # The panel is see-through, so that the rider and the steppe show behind
    # it; the text is light with a dark outline, readable on anything.
    draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.OUTLINE, 0.55))
    draw_rect(Rect2(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0), Color(Palette.NIGHT, 0.35))

    # NOTE (mristin):
    # The corners in gold, as a hint of the ornaments which come later.
    for corner in [
        Vector2(4, 4), Vector2(size.x - 9, 4), Vector2(4, size.y - 9), size - Vector2(9, 9)
    ]:
        draw_rect(Rect2(corner, Vector2(5, 1)), Palette.GOLD)
        draw_rect(Rect2(corner, Vector2(1, 5)), Palette.GOLD)
        draw_rect(Rect2(corner + Vector2(4, 0), Vector2(1, 5)), Palette.GOLD)
        draw_rect(Rect2(corner + Vector2(0, 4), Vector2(5, 1)), Palette.GOLD)

    if _pages.size() > 1:
        # NOTE (mristin):
        # A dot for each page, the one shown golden, at the bottom right.
        for i in range(_pages.size()):
            var dot := Vector2(size.x - 14.0 - (_pages.size() - 1 - i) * 10.0, size.y - 10.0)
            draw_rect(Rect2(dot - Vector2(3, 3), Vector2(6, 6)), Palette.OUTLINE)
            draw_rect(
                Rect2(dot - Vector2(2, 2), Vector2(4, 4)),
                Palette.GOLD if i == _page else Palette.FELT
            )

    if _portrait != null:
        var side := _PORTRAIT_SIDE
        var at := Vector2(_MARGIN, _MARGIN)
        draw_rect(Rect2(at - Vector2.ONE, Vector2.ONE * (side + 2.0)), Palette.OUTLINE)
        draw_texture_rect(_portrait, Rect2(at, Vector2.ONE * side), false)
