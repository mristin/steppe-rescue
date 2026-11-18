class_name TopDown
extends RefCounted

## Draw the creatures seen from above (the rider on her horse, the animals and
## the people) as pixel art in any of the [constant DIRECTIONS] headings.
##
## A creature is a list of ellipses in its own frame, facing north (up, -y),
## each [code][center_x, center_y, radius_x, radius_y, color][/code], the later
## over the earlier. For each heading we turn the ellipses as vectors (SVG)
## and pixelate them with [Pixelate], so the creature stays crisp pixel art in
## every direction, instead of rotating a picture, which would blur or break
## the pixels.
##
## These are placeholders until the drawn sprites arrive.

## The number of the headings.
const DIRECTIONS := 64

static var _cache: Dictionary = {}


## The heading of the direction nearest to the heading, in radians (0 is
## north, clockwise).
static func snap(heading: float) -> float:
    var step := TAU / DIRECTIONS
    return posmod(roundi(heading / step), DIRECTIONS) * step


## Make (or take from the cache) the texture of the creature at the heading.
## The [param key] names the creature and its frame, for the cache.
static func texture(key: String, shapes: Array, heading: float) -> ImageTexture:
    var direction := posmod(roundi(heading / (TAU / DIRECTIONS)), DIRECTIONS)
    var full_key := "%s@%d" % [key, direction]
    if _cache.has(full_key):
        return _cache[full_key]

    var half := _half(shapes)
    var view := Rect2(-half, -half, 2 * half, 2 * half)
    var result := ImageTexture.create_from_image(
        Pixelate.image_of(svg(shapes, direction * TAU / DIRECTIONS), view)
    )
    result.set_size_override(Vector2i(view.size))
    _cache[full_key] = result
    return result


## The creature as vectors (SVG) turned to the heading, around its center.
static func svg(shapes: Array, heading: float) -> String:
    var parts := PackedStringArray()
    parts.append('<g transform="rotate(%s)">' % String.num(rad_to_deg(heading), 3))
    for shape in shapes:
        (
            parts
            . append(
                (
                    '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"/>'
                    % [
                        String.num(shape[0], 3),
                        String.num(shape[1], 3),
                        String.num(shape[2], 3),
                        String.num(shape[3], 3),
                        Pixelate.color(shape[4]),
                    ]
                )
            )
        )
    parts.append("</g>")
    return "".join(parts)


## Rasterize the creature at the heading, with the outline; the image is square
## with the creature's center in the middle.
static func image_of(shapes: Array, heading: float) -> Image:
    var half := _half(shapes)
    return Pixelate.image_of(svg(shapes, heading), Rect2(-half, -half, 2 * half, 2 * half))


## Half the side of the square which holds the creature in every heading, in
## logical pixels, with room for the outline.
static func _half(shapes: Array) -> int:
    var reach := 1.0
    for shape in shapes:
        var center := Vector2(shape[0], shape[1])
        reach = maxf(reach, center.length() + maxf(shape[2], shape[3]))
    return ceili(reach) + 1


## The tail of the horse for the gait, swaying with the frame.
static func _tail(color: Color, frame: int, gait: int) -> Array:
    var sway := 1.0 if frame == 0 else -1.0
    match gait:
        1:
            return [[0.0, 8.5, 1.0, 2.0, color], [0.5 * sway, 12.0, 1.7, 2.8, color]]
        2:
            return [[0.0, 9.0, 1.0, 2.4, color], [0.7 * sway, 13.5, 1.6, 3.4, color]]
        3:
            return [
                [0.0, 9.5, 1.1, 2.6, color],
                [0.5 * sway, 13.5, 1.4, 2.6, color],
                [1.3 * sway, 17.0, 1.9, 2.6, color],
            ]
        _:
            return [[0.0, 8.5, 1.0, 2.0, color], [0.0, 11.5, 1.6, 2.6, color]]


## The four legs, stepping with the frame (0 or 1).
static func _legs(front: float, back: float, apart: float, frame: int, color: Color) -> Array:
    var step := 1.5 if frame == 0 else -1.5
    return [
        [-apart, front + step, 1.1, 2.0, color],
        [apart, front - step, 1.1, 2.0, color],
        [-apart, back - step, 1.1, 2.0, color],
        [apart, back + step, 1.1, 2.0, color],
    ]


## The horse, with the rider on it or without.
##
## From above, the head and the tail must not look alike: the head sits on a
## long neck with the dark mane, has the ears, a white blaze and a dark nose;
## the tail is a dark plume which widens to its end.
##
## The tail flies with the [param gait] (0 stands, 1 walks, 2 trots, 3
## gallops): it hangs, sways, streams out and flies long behind the horse.
static func horse(
    coat: Color, mane: Color, frame: int, rider: Dictionary = {}, gait: int = 0
) -> Array:
    var shapes := _legs(-4.5, 6.0, 3.4, frame, Palette.HOOF)
    shapes.append_array(_tail(mane, frame, gait))
    shapes.append([0.0, 1.5, 4.2, 7.0, coat])
    shapes.append([0.0, -6.5, 2.0, 3.5, coat])
    shapes.append([0.0, -11.0, 2.4, 3.2, coat])
    shapes.append([-1.5, -9.0, 0.7, 1.0, mane])
    shapes.append([1.5, -9.0, 0.7, 1.0, mane])
    shapes.append([0.0, -6.0, 0.8, 3.5, mane])
    shapes.append([0.0, -11.5, 0.6, 2.0, Palette.FELT])
    shapes.append([0.0, -13.8, 1.3, 0.9, Palette.HOOF])
    if not rider.is_empty():
        var bob := 0.0 if frame == 0 else 0.5
        shapes.append([-1.2, 2.8, 0.8, 1.6, rider.get("hair", Palette.HOOF)])
        shapes.append([1.2, 2.8, 0.8, 1.6, rider.get("hair", Palette.HOOF)])
        shapes.append([0.0, 0.5 + bob, 4.2, 2.6, rider.get("coat", Palette.CRIMSON)])
        shapes.append([0.0, 0.6 + bob, 2.3, 2.3, rider.get("hat", Palette.CRIMSON_DARK)])
    return scaled(shapes, 1.35)


static func sheep(frame: int) -> Array:
    var shapes := _legs(-2.5, 3.0, 2.2, frame, Palette.HOOF)
    shapes.append([0.0, 4.6, 2.2, 1.6, Palette.FELT])
    shapes.append([0.0, 0.5, 3.6, 4.6, Palette.FELT])
    shapes.append([0.0, -4.8, 1.6, 2.0, Palette.HOOF])
    return scaled(shapes, 1.8)


static func camel(frame: int) -> Array:
    var shapes := _legs(-4.5, 5.0, 3.2, frame, Palette.GRASS_DARK)
    shapes.append([0.0, 8.5, 0.9, 2.0, Palette.GRASS_DARK])
    shapes.append([0.0, 0.5, 4.2, 8.0, Palette.OCHRE])
    shapes.append([0.0, -2.5, 2.6, 2.4, Palette.GRASS_DARK])
    shapes.append([0.0, 3.0, 2.6, 2.4, Palette.GRASS_DARK])
    shapes.append([0.0, -10.0, 1.3, 3.5, Palette.OCHRE])
    shapes.append([0.0, -14.0, 1.9, 2.6, Palette.OCHRE])
    return scaled(shapes, 1.35)


## A person standing, seen from above: the shoulders in the coat and the hat.
static func person(coat: Color, hat: Color) -> Array:
    var shapes := [
        [-4.0, 2.5, 1.5, 2.0, Palette.SKIN],
        [4.0, 2.5, 1.5, 2.0, Palette.SKIN],
        [0.0, 0.0, 6.0, 4.0, coat],
        [0.0, 0.0, 3.5, 3.5, hat],
    ]
    return scaled(shapes, 1.3)


## The creature made bigger by the factor.
static func scaled(shapes: Array, factor: float) -> Array:
    var result := []
    for shape in shapes:
        result.append(
            [shape[0] * factor, shape[1] * factor, shape[2] * factor, shape[3] * factor, shape[4]]
        )
    return result


## The creature of the kind of an animal, by the id of the kind.
static func animal(id: String, frame: int) -> Array:
    match id:
        "camel":
            return camel(frame)
        "horse":
            return horse(Palette.STONE_LIGHT, Palette.STONE, frame)
        _:
            return sheep(frame)
