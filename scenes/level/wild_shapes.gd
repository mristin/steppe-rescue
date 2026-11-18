class_name WildShapes
extends RefCounted

## Shape the wild creatures of the steppe seen from above (see [Wildlife]), as
## the ellipses of [TopDown], facing north, in two frames of their stride or
## of the beat of their wings.


## The creature of the kind in the frame (0 or 1).
static func of(kind: String, frame: int) -> Array:
    match kind:
        "saiga":
            return saiga(frame)
        "roe_deer":
            return roe_deer(frame)
        "hare":
            return hare(frame)
        "fox":
            return fox(frame)
        "marmot":
            return marmot()
        "burrow":
            return burrow()
        "lark":
            return lark(frame)
        "eagle":
            return eagle(frame)
        "falcon":
            return falcon(frame)
        "swallow":
            return swallow(frame)
    return hare(frame)


## The saiga (ақбөкен): a sandy body, the pale belly at the sides, the big
## drooping nose, and the amber horns of the male.
static func saiga(frame: int) -> Array:
    var shapes := _legs(-3.6, 4.2, 2.4, frame, Palette.OCHRE)
    shapes.append([0.0, 1.0, 2.8, 5.6, Palette.DUN])
    shapes.append([0.0, 1.4, 1.6, 4.2, Palette.GRASS_LIGHT])
    shapes.append([0.0, -5.6, 1.3, 1.8, Palette.DUN])
    shapes.append([0.0, -7.4, 1.2, 1.0, Palette.OCHRE])
    shapes.append([-0.6, -4.6, 0.3, 1.0, Palette.FELT])
    shapes.append([0.6, -4.6, 0.3, 1.0, Palette.FELT])
    return shapes


## The roe deer: a reddish body, the big ears and the white rump.
static func roe_deer(frame: int) -> Array:
    var shapes := _legs(-3.8, 4.4, 2.2, frame, Palette.HORSE_BAY)
    shapes.append([0.0, 1.0, 2.6, 5.8, Palette.HORSE_BAY_LIGHT])
    shapes.append([0.0, 6.0, 1.4, 1.1, Palette.FELT])
    shapes.append([0.0, -6.0, 1.2, 2.0, Palette.HORSE_BAY_LIGHT])
    shapes.append([-1.2, -5.6, 0.5, 0.9, Palette.HORSE_BAY])
    shapes.append([1.2, -5.6, 0.5, 0.9, Palette.HORSE_BAY])
    shapes.append([0.0, -7.8, 0.6, 0.6, Palette.HOOF])
    return shapes


## The hare: grey-brown, with the long ears laid back and the white tail.
static func hare(frame: int) -> Array:
    var stretch := 0.6 if frame == 1 else 0.0
    var shapes := [
        [-1.4, 3.4 + stretch, 0.7, 1.4, Palette.STONE],
        [1.4, 3.4 + stretch, 0.7, 1.4, Palette.STONE],
        [0.0, 1.0, 1.9, 3.2 + stretch, Palette.STONE],
        [0.0, 4.2 + stretch, 0.8, 0.7, Palette.FELT],
        [-0.6, -0.6, 0.4, 2.0, Palette.STONE_LIGHT],
        [0.6, -0.6, 0.4, 2.0, Palette.STONE_LIGHT],
        [0.0, -2.6, 1.2, 1.4, Palette.STONE],
    ]
    return shapes


## The corsac fox: an ochre body, the dark ears and the bushy tail with its
## pale tip.
static func fox(frame: int) -> Array:
    var swing := 0.6 if frame == 1 else -0.6
    var shapes := _legs(-3.0, 3.0, 1.8, frame, Palette.HOOF)
    shapes.append([swing, 6.6, 1.3, 2.8, Palette.OCHRE])
    shapes.append([swing * 1.6, 9.0, 0.9, 0.9, Palette.FELT])
    shapes.append([0.0, 0.6, 2.0, 4.2, Palette.OCHRE])
    shapes.append([0.0, -4.4, 1.4, 1.7, Palette.OCHRE])
    shapes.append([-0.9, -5.2, 0.5, 0.7, Palette.HOOF])
    shapes.append([0.9, -5.2, 0.5, 0.7, Palette.HOOF])
    shapes.append([0.0, -6.0, 0.5, 0.6, Palette.FELT])
    return shapes


## The marmot (суыр) standing up by its burrow.
static func marmot() -> Array:
    return [
        [0.0, 0.6, 2.2, 2.6, Palette.DUN],
        [0.0, -1.8, 1.4, 1.3, Palette.OCHRE],
        [0.0, -2.8, 0.6, 0.4, Palette.HOOF],
    ]


## The burrow of a marmot: a mound of sand with the hole.
static func burrow() -> Array:
    return [
        [0.0, 1.2, 4.0, 3.0, Palette.GRASS_DARK],
        [0.0, 1.6, 1.8, 1.3, Palette.HOOF],
    ]


## The lark (бозторғай): small and brown, its wings open in flight.
static func lark(frame: int) -> Array:
    var wing := 2.0 if frame == 0 else 1.2
    return [
        [-wing, 0.2, wing, 0.8, Palette.HORSE_BAY_LIGHT],
        [wing, 0.2, wing, 0.8, Palette.HORSE_BAY_LIGHT],
        [0.0, 0.4, 1.0, 2.0, Palette.OCHRE],
        [0.0, -1.6, 0.7, 0.7, Palette.HORSE_BAY_LIGHT],
    ]


## The golden eagle (бүркіт): the broad dark wings, the golden nape.
static func eagle(frame: int) -> Array:
    var wing := 7.0 if frame == 0 else 6.2
    return [
        [-wing, 0.4, wing, 1.8, Palette.HOOF],
        [wing, 0.4, wing, 1.8, Palette.HOOF],
        [-wing * 1.6, 0.8, 1.6, 1.0, Palette.HAIR_BLACK],
        [wing * 1.6, 0.8, 1.6, 1.0, Palette.HAIR_BLACK],
        [0.0, 4.6, 1.6, 1.8, Palette.HOOF],
        [0.0, 0.0, 1.6, 4.0, Palette.HORSE_BAY],
        [0.0, -3.8, 1.0, 1.2, Palette.DUN],
        [0.0, -5.0, 0.4, 0.5, Palette.GOLD],
    ]


## The saker falcon (ителгі): the narrow pointed wings, grey above.
static func falcon(frame: int) -> Array:
    var wing := 4.4 if frame == 0 else 3.4
    return [
        [-wing, 0.6, wing, 0.9, Palette.STONE],
        [wing, 0.6, wing, 0.9, Palette.STONE],
        [0.0, 3.4, 0.9, 1.6, Palette.STONE],
        [0.0, 0.0, 1.1, 2.8, Palette.STONE_LIGHT],
        [0.0, -2.6, 0.8, 0.8, Palette.HOOF],
    ]


## The barn swallow (қарлығаш): dark blue, the swept wings, the forked tail
## and the red throat.
static func swallow(frame: int) -> Array:
    var wing := 2.6 if frame == 0 else 1.8
    return [
        [-wing, 1.0, wing, 0.6, Palette.NIGHT],
        [wing, 1.0, wing, 0.6, Palette.NIGHT],
        [-0.5, 3.0, 0.3, 1.2, Palette.NIGHT],
        [0.5, 3.0, 0.3, 1.2, Palette.NIGHT],
        [0.0, 0.4, 0.8, 1.8, Palette.INDIGO],
        [0.0, -1.4, 0.5, 0.5, Palette.CRIMSON],
    ]


## Four legs in their stride, under the body: the front pair at [param front],
## the hind pair at [param back], [param apart] from each other.
static func _legs(front: float, back: float, apart: float, frame: int, color: Color) -> Array:
    var step := 1.2 if frame == 0 else -1.2
    return [
        [-apart * 0.5, front + step, 0.5, 1.4, color],
        [apart * 0.5, front - step, 0.5, 1.4, color],
        [-apart * 0.5, back - step, 0.5, 1.4, color],
        [apart * 0.5, back + step, 0.5, 1.4, color],
    ]
