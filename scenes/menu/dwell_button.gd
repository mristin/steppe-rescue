class_name DwellButton
extends Control

## Be a big button of the menus, which the mouse clicks, and the hand clicks
## by holding the bird of the [HandCursor] over it for [constant DWELL_SECONDS]:
## a ring fills around the button meanwhile (see section 5 of DESIGN.md).
## A hovered button grows a little.
##
## The button shows a text, a picture, or both, on felt framed with the
## ornaments (see [Ornaments]); a [member selected] button is golden, the
## [member primary] button of a screen is crimson.

signal pressed

## The hand holds still this long to click.
const DWELL_SECONDS := 1.5

## The hovered button grows by this many pixels on each side.
const _GROW := 2.0

## The text on the button, drawn in the pixel font.
@export var text := "":
    set(value):
        text = value
        queue_redraw()

## The size of the font of the text.
@export var font_size := 16

## The picture on the button, above the text or alone.
var picture: Texture2D = null:
    set(value):
        picture = value
        queue_redraw()

## The color of a swatch on the button, at the left of the text, or alone
## (transparent: none).
var swatch := Color(0, 0, 0, 0):
    set(value):
        swatch = value
        queue_redraw()

## Whether the button is the main one of its screen (crimson), e.g., Play.
var primary := false:
    set(value):
        primary = value
        queue_redraw()

## Whether the button shows the current choice (golden).
var selected := false:
    set(value):
        selected = value
        queue_redraw()

## How far the hand has held still, in [0, 1].
var progress := 0.0

var _mouse_inside := false


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_entered.connect(func() -> void: _mouse_inside = true)
    mouse_exited.connect(func() -> void: _mouse_inside = false)


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        accept_event()
        press()


func _process(delta: float) -> void:
    if is_visible_in_tree() and _hand_inside():
        progress += delta / DWELL_SECONDS
        if progress >= 1.0:
            progress = 0.0
            press()
    else:
        progress = 0.0
    queue_redraw()


## Click the button.
func press() -> void:
    progress = 0.0
    pressed.emit()


## Whether the bird or the mouse is over the button.
func hovered() -> bool:
    return _hand_inside() or (_mouse_inside and not HandCursor.by_hand)


func _hand_inside() -> bool:
    return HandCursor.by_hand and get_global_rect().has_point(HandCursor.at)


func _draw() -> void:
    var rect := Rect2(Vector2.ZERO, size)
    if hovered():
        rect = rect.grow(_GROW)
    var style := "felt"
    if selected:
        style = "selected"
    elif primary:
        style = "primary_hover" if hovered() else "primary"
    elif hovered():
        style = "hover"
    draw_texture(Ornaments.panel(rect.size, style), rect.position)

    var font := get_theme_default_font()
    var text_height := font.get_height(font_size) if text != "" else 0.0
    var content := text_height
    if picture != null:
        content += picture.get_height() + (2.0 if text != "" else 0.0)
    elif swatch.a > 0.0 and text == "":
        content += 12.0
    var top := roundf(rect.position.y + (rect.size.y - content) * 0.5)

    if picture != null:
        var at := Vector2(rect.get_center().x - picture.get_width() * 0.5, top).round()
        draw_texture(picture, at)
        top += picture.get_height() + 2.0
    elif swatch.a > 0.0:
        # NOTE (mristin):
        # With a text, the swatch sits at the left; alone, in the middle.
        var left := rect.position.x + 8.0 if text != "" else rect.get_center().x - 10.0
        var middle := rect.get_center().y - 6.0 if text != "" else top
        var box := Rect2(Vector2(left, middle).round(), Vector2(20, 12))
        draw_rect(box.grow(1.0), Palette.OUTLINE)
        draw_rect(box, swatch)
        if text == "":
            top += 14.0

    if text != "":
        var width := rect.size.x - 8.0
        draw_string(
            font,
            Vector2(rect.position.x + 4.0, top + font.get_ascent(font_size)).round(),
            text,
            HORIZONTAL_ALIGNMENT_CENTER,
            width,
            font_size,
            Palette.FELT if primary and not selected else Palette.OUTLINE
        )

    if progress > 0.0:
        # NOTE (mristin):
        # The ring runs around the frame of the button, clockwise from the top
        # left, so that it fits a button of any shape.
        var outer := rect.grow(4.0)
        var length := 2.0 * (outer.size.x + outer.size.y)
        var reached := length * progress
        var corners := [
            outer.position,
            Vector2(outer.end.x, outer.position.y),
            outer.end,
            Vector2(outer.position.x, outer.end.y),
            outer.position,
        ]
        for i in range(4):
            var from: Vector2 = corners[i]
            var to: Vector2 = corners[i + 1]
            var side := from.distance_to(to)
            if reached <= 0.0:
                break
            var end := from.lerp(to, minf(1.0, reached / side))
            draw_line(from, end, Palette.CRIMSON, 3.0)
            reached -= side
