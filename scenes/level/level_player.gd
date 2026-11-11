class_name LevelPlayer
extends RefCounted

## Keep one rider of a [Level] and what she sees (see section 6 of DESIGN.md,
## "Two players"): her horse, its water and food, the animals which follow
## her, the person she talks to, and her view of the steppe with her own HUD.
##
## With one player, her view fills the screen. With two, each has her half
## of it, as in Bird Dog and Ergo Chaos: two SubViewports show the one steppe
## (they share its World2D), each following its own rider, and the panels of
## the right half stand mirrored, so that the camera picture fits between the
## halves at the bottom.

## The player: 0, or 1 with two players (the right half of the screen).
var index := 0

## Whether the view is a half of the screen (two players).
var half := false

## The part of the screen which the view takes, in logical pixels.
var rect := Rect2(0, 0, 960, 540)

var rider: Rider
var needs := HorseNeeds.new()

## The animals which follow her, in the order they joined, and the trail
## which they follow.
var followers: Array[Animal] = []
var trail := PackedVector2Array()

## How many times she braked, to see when she brakes again.
var brakes := 0

## How many times she jumped, to see when she jumps again.
var jumps := 0

## How long the warning at the edge of the steppe still shows, in seconds.
var edge_time := 0.0

## How often she ran into each obstacle, by its index (see
## [member Rider.blocked_by]), and the one she touches now.
var bumps: Dictionary = {}
var touching := -1

## How long the hint to turn still shows, in seconds.
var turn_hint_time := 0.0

## How long the hint to jump (at a creek) still shows, in seconds.
var jump_hint_time := 0.0

## How long her horse has stood still, and the squats seen so far, for the
## small figure.
var still_time := 0.0
var squats_seen := 0

## The person she talks to now, the one she talked to last (she talks to
## them again only after she rode away), how long the talk lasts, and the
## squats when it started.
var talking: Person = null
var talked_to: Person = null
var talk_time := 0.0
var talk_squats := 0

var viewport: SubViewport
var display: TextureRect
var hearing: Hearing
var map_view: MapView
var speed_bar: SpeedBar
var needs_bars: NeedsBars
var conversation: Conversation
var edge_label: Label
var coach: Coach


func _init(an_index: int, is_half: bool) -> void:
    index = an_index
    half = is_half
    rect = Rect2(an_index * 480, 0, 480, 540) if half else Rect2(0, 0, 960, 540)


## A rectangle given for the left half (or the whole screen), mirrored into the
## right half for the second player.
func place(at: Rect2) -> Rect2:
    if half and index == 1:
        return Rect2(Vector2(960.0 - at.position.x - at.size.x, at.position.y), at.size)
    return at


## Show the [param world] in a SubViewport of this view, or the world of the
## [param shared] view, and put the picture of the view on the [param layer].
func show_world(world: Node2D, shared: LevelPlayer, layer: CanvasLayer) -> void:
    viewport = SubViewport.new()
    viewport.name = "View%d" % index
    viewport.disable_3d = true
    viewport.transparent_bg = false
    viewport.handle_input_locally = false
    viewport.canvas_item_default_texture_filter = (
        Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    )
    viewport.snap_2d_transforms_to_pixel = true
    viewport.snap_2d_vertices_to_pixel = true
    viewport.size_2d_override = Vector2i(rect.size)
    viewport.size_2d_override_stretch = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    layer.add_child(viewport)
    if shared == null:
        world.get_parent().remove_child(world)
        viewport.add_child(world)
    else:
        viewport.world_2d = shared.viewport.world_2d

    display = TextureRect.new()
    display.name = "Display%d" % index
    display.position = rect.position
    display.size = rect.size
    display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    display.stretch_mode = TextureRect.STRETCH_SCALE
    display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    display.mouse_filter = Control.MOUSE_FILTER_IGNORE
    display.texture = viewport.get_texture()
    layer.add_child(display)


## Render the view at [param scale] pixels of the screen per logical pixel,
## so that the paintings keep their fine pixels.
func set_scale(scale: int) -> void:
    viewport.size = Vector2i(rect.size * maxi(1, scale))


## Where the view looks: at the rider, but never beyond the edge of the
## steppe of the [param size].
func center(size: Vector2) -> Vector2:
    var middle := rect.size * 0.5
    return Vector2(
        clampf(rider.position.x, middle.x, maxf(middle.x, size.x - middle.x)),
        clampf(rider.position.y, middle.y, maxf(middle.y, size.y - middle.y))
    )


## How the steppe maps onto the view, looking at the [param at].
func view_transform(at: Vector2) -> Transform2D:
    return Transform2D(0.0, (rect.size * 0.5 - at).round())


## The part of the steppe which the view shows.
func seen(size: Vector2) -> Rect2:
    return Rect2(center(size) - rect.size * 0.5, rect.size)


## The point on her trail this far behind her.
func trail_point(distance: float) -> Vector2:
    var previous := rider.position
    var remaining := distance
    for i in range(trail.size() - 1, -1, -1):
        var segment := previous.distance_to(trail[i])
        if segment >= remaining and segment > 0.0:
            return previous.lerp(trail[i], remaining / segment)
        remaining -= segment
        previous = trail[i]
    return previous
