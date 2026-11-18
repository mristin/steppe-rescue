class_name Icons
extends RefCounted

## Hold the small pictures of the interface: the animals and the landmarks in
## the clues, the slots and the hearing, the stars, the heart, the water and
## the grass of the horse, and the portraits of the people.
##
## The pictures are drawn as vectors (SVG, in a box of 12x9 logical pixels,
## with the color names of [method Pixelate.texture]) and pixelated by
## [Pixelate] at the size they are shown, so a bigger icon gets more pixels,
## not bigger ones.
##
## The portraits are pixelized from old photographs in the public domain (see
## dev/pictures/pixelize.py and THIRD_PARTY_NOTICES.md).
##
## The pictures carry the clues, so that a child who reads slowly still
## understands them (see section 4 of DESIGN.md).

## The box of an icon at the scale 1, in logical pixels.
const SIZE := Vector2(12, 9)

const SHEEP := """
<g fill="{hoof}">
  <rect x="3" y="5.5" width="1.1" height="3.2"/>
  <rect x="7" y="5.5" width="1.1" height="3.2"/>
</g>
<g fill="{felt}">
  <circle cx="3.2" cy="4.4" r="2.3"/>
  <circle cx="5.4" cy="3.2" r="2.5"/>
  <circle cx="7.6" cy="4.2" r="2.2"/>
  <ellipse cx="5.4" cy="5.2" rx="3.9" ry="1.6"/>
</g>
<ellipse cx="10" cy="3.7" rx="1.6" ry="1.3" fill="{hoof}"/>
<ellipse cx="9.1" cy="2.7" rx="1" ry="0.5" fill="{hoof}" transform="rotate(-25 9.1 2.7)"/>
<circle cx="10.5" cy="3.4" r="0.35" fill="{felt}"/>
"""

const HORSE := """
<path d="M1.6 3.8 C0.6 4.6 0.4 6.2 0.7 7.6 L1.5 7.4 C1.4 6.2 1.7 5 2.2 4.4 Z" fill="{hoof}"/>
<g fill="{bay}">
  <rect x="2.2" y="5" width="0.9" height="3.3"/>
  <rect x="3.4" y="5" width="0.9" height="3.3"/>
  <rect x="6.3" y="5" width="0.9" height="3.3"/>
  <rect x="7.5" y="5" width="0.9" height="3.3"/>
  <ellipse cx="5" cy="4.6" rx="3.6" ry="1.8"/>
  <path d="M6.8 4.2 L8.4 1.4 L10 1.2 L9.2 4.6 Z"/>
  <ellipse cx="10.2" cy="2.2" rx="1.6" ry="0.85" transform="rotate(28 10.2 2.2)"/>
</g>
<g fill="{hoof}">
  <rect x="2.2" y="8" width="0.9" height="0.8"/>
  <rect x="3.4" y="8" width="0.9" height="0.8"/>
  <rect x="6.3" y="8" width="0.9" height="0.8"/>
  <rect x="7.5" y="8" width="0.9" height="0.8"/>
  <path d="M7 3.6 L8.3 1 L9.2 0.7 L8.2 2.4 Z"/>
  <ellipse cx="9.1" cy="0.9" rx="0.35" ry="0.7"/>
</g>
<circle cx="10.2" cy="2" r="0.3" fill="{outline}"/>
"""

const CAMEL := """
<g fill="{grass_dark}">
  <rect x="2.4" y="5.4" width="0.8" height="3.4"/>
  <rect x="7.1" y="5.4" width="0.8" height="3.4"/>
</g>
<g fill="{ochre}">
  <rect x="3.4" y="5.4" width="0.8" height="3.4"/>
  <rect x="6.1" y="5.4" width="0.8" height="3.4"/>
  <ellipse cx="5.1" cy="5" rx="3.6" ry="1.5"/>
  <circle cx="3.8" cy="3.8" r="1.5"/>
  <circle cx="6.3" cy="3.8" r="1.5"/>
  <path d="M7.6 4.2 C9 4.4 9.2 2.6 9.6 1.6 L10.5 1.8 C10.2 3.4 9.8 5.6 8 5.6 Z"/>
  <ellipse cx="10.6" cy="1.7" rx="1.2" ry="0.7"/>
</g>
<path d="M1.5 4.6 L1 6.6" stroke="{grass_dark}" stroke-width="0.6"/>
<circle cx="10.8" cy="1.5" r="0.3" fill="{outline}"/>
"""

const SPRING := """
<ellipse cx="6" cy="4.5" rx="5.2" ry="3.8" fill="{emerald_light}"/>
<ellipse cx="6" cy="4.6" rx="3.2" ry="2.3" fill="{sky}"/>
<ellipse cx="5" cy="3.8" rx="1.2" ry="0.5" fill="{sky_light}"/>
<g fill="{emerald}">
  <path d="M1.4 3 L1.8 1.2 L2.2 3 Z"/>
  <path d="M10 6.4 L10.4 4.6 L10.8 6.4 Z"/>
</g>
"""

const ROCK := """
<path d="M1.2 7.5 L2.2 3.6 L4.6 1.6 L8 1.8 L10.4 4 L11 7.5 Z" fill="{stone}"/>
<path d="M3 4.2 L4.8 2.6 L7.4 2.8 L6.2 4.6 Z" fill="{stone_light}"/>
"""

const BUSHES := """
<g fill="{emerald}">
  <circle cx="3.2" cy="5.2" r="2.6"/>
  <circle cx="6.2" cy="3.8" r="2.9"/>
  <circle cx="8.8" cy="5.4" r="2.4"/>
  <rect x="1" y="5.2" width="10" height="2.6"/>
</g>
<g fill="{emerald_light}">
  <circle cx="5.4" cy="2.8" r="0.8"/>
  <circle cx="2.6" cy="4.4" r="0.6"/>
  <circle cx="8.4" cy="4.6" r="0.6"/>
</g>
"""

const BIRCHES := """
<g fill="{felt}">
  <rect x="2.4" y="4" width="1.1" height="4.8"/>
  <rect x="8.4" y="4" width="1.1" height="4.8"/>
</g>
<g fill="{outline}">
  <rect x="2.4" y="5.6" width="0.6" height="0.4"/>
  <rect x="2.9" y="7.2" width="0.6" height="0.4"/>
  <rect x="8.9" y="5.2" width="0.6" height="0.4"/>
  <rect x="8.4" y="6.8" width="0.6" height="0.4"/>
</g>
<g fill="{emerald_light}">
  <ellipse cx="3" cy="2.8" rx="2.6" ry="2.6"/>
  <ellipse cx="9" cy="2.8" rx="2.6" ry="2.6"/>
</g>
<g fill="{emerald}">
  <circle cx="3.8" cy="3.6" r="0.9"/>
  <circle cx="9.8" cy="3.6" r="0.9"/>
</g>
"""

const LAKE := """
<ellipse cx="6" cy="4.5" rx="5.6" ry="3.6" fill="{sky_light}"/>
<ellipse cx="6.2" cy="4.6" rx="4.6" ry="2.8" fill="{sky}"/>
<g fill="{sky_light}">
  <rect x="3.4" y="3.6" width="2.4" height="0.5"/>
  <rect x="6.4" y="5.4" width="2.2" height="0.5"/>
</g>
"""

const KURGAN := """
<path d="M0.6 7.4 C2 2.4 10 2.4 11.4 7.4 Z" fill="{grass_dark}"/>
<path d="M2.4 6.8 C3.6 3.4 8.4 3.4 9.6 6.8 Z" fill="{grass}"/>
<path d="M4.4 4.6 C5.2 3.4 6.8 3.4 7.6 4.6 Z" fill="{grass_light}"/>
"""

const WELL := """
<path d="M0.6 0.6 L7.6 5.2" stroke="{ochre}" stroke-width="0.8"/>
<rect x="7" y="0.8" width="0.8" height="4" fill="{bay}"/>
<rect x="2.6" y="3.6" width="6.8" height="4.8" rx="0.8" fill="{stone}"/>
<rect x="3.6" y="4.6" width="4.8" height="2.6" fill="{night}"/>
<rect x="2.6" y="3.6" width="6.8" height="0.8" fill="{stone_light}"/>
"""

const YURT := """
<path d="M1 8.4 L1 5 C2 2 4 0.8 6 0.8 C8 0.8 10 2 11 5 L11 8.4 Z" fill="{felt}"/>
<rect x="1" y="4.6" width="10" height="0.9" fill="{crimson}"/>
<rect x="4.8" y="0.4" width="2.4" height="0.8" fill="{ochre}"/>
<rect x="4.8" y="5.8" width="2.4" height="2.6" fill="{ochre}"/>
<rect x="5.8" y="5.8" width="0.4" height="2.6" fill="{bay}"/>
"""

const PASTURE := """
<ellipse cx="6" cy="6.6" rx="5.6" ry="2.2" fill="{emerald}"/>
<g fill="{emerald_light}">
  <path d="M2 7 L1.4 2.6 L2.8 6.2 Z"/>
  <path d="M3.2 7 L3.6 1.6 L4.2 6.6 Z"/>
  <path d="M5.2 7 L5.8 0.8 L6.6 6.8 Z"/>
  <path d="M7.4 7 L8.6 2 L8.4 6.8 Z"/>
  <path d="M9 7.2 L10.6 3.2 L9.8 7.2 Z"/>
</g>
<circle cx="4.4" cy="5.4" r="0.6" fill="{gold}"/>
<circle cx="8" cy="5.8" r="0.6" fill="{felt}"/>
"""

## The water of the horse: a drop.
const WATER := """
<path d="M6 0.6 C7.4 3 9.2 4.6 9.2 6 C9.2 7.8 7.8 8.6 6 8.6 C4.2 8.6 2.8 7.8 2.8 6
         C2.8 4.6 4.6 3 6 0.6 Z" fill="{sky}"/>
<ellipse cx="4.8" cy="5.8" rx="0.7" ry="1.2" fill="{sky_light}"/>
"""

## The food of the horse: a tuft of grass.
const GRASS := """
<g fill="{emerald_light}">
  <path d="M5.2 8.6 L2 2 L6.2 8.6 Z"/>
  <path d="M5.4 8.6 L6 0.4 L6.8 8.6 Z"/>
  <path d="M6 8.6 L10 1.8 L7.2 8.6 Z"/>
</g>
<g fill="{emerald}">
  <path d="M4.6 8.6 L3.4 4.6 L5.6 8.6 Z"/>
  <path d="M6.6 8.6 L8.4 5 L7.6 8.6 Z"/>
</g>
"""

const STAR := """
<path d="M6 0.3 L7.5 3.3 L10.8 3.6 L8.3 5.8 L9.1 8.8 L6 7.1 L2.9 8.8 L3.7 5.8 L1.2 3.6
         L4.5 3.3 Z" fill="{gold}"/>
<path d="M6 2 L6.8 3.8 L5.4 4.4 Z" fill="{felt}"/>
"""

const HEART := """
<path d="M6 8.4 C3 6.2 1.4 4.8 1.4 3 C1.4 1.6 2.5 0.8 3.6 0.8 C4.6 0.8 5.4 1.4 6 2.4
         C6.6 1.4 7.4 0.8 8.4 0.8 C9.5 0.8 10.6 1.6 10.6 3 C10.6 4.8 9 6.2 6 8.4 Z"
      fill="{crimson}"/>
<circle cx="3.6" cy="2.6" r="0.6" fill="{felt}"/>
"""

## The cursor of the hand in the menus: a swallow.
const BIRD := """
<path d="M6 4.6 C4.6 2.4 2.4 1 0.4 1.4 C2 2.4 3.4 3.6 4.4 5.2 Z" fill="{indigo}"/>
<path d="M6 4.6 C7.4 2.4 9.6 1 11.6 1.4 C10 2.4 8.6 3.6 7.6 5.2 Z" fill="{indigo}"/>
<ellipse cx="6" cy="5.2" rx="1.6" ry="2.4" fill="{indigo}"/>
<path d="M5.2 7 L4.2 8.8 L6 7.8 L7.8 8.8 L6.8 7 Z" fill="{indigo}"/>
<ellipse cx="6" cy="5.6" rx="0.8" ry="1.4" fill="{felt}"/>
<circle cx="6" cy="3.4" r="0.7" fill="{crimson}"/>
"""

## The pictures of the animals, by the id of their kind.
const ANIMALS := {"sheep": SHEEP, "horse": HORSE, "camel": CAMEL}

## The pictures of the landmarks, by the id of their kind.
const LANDMARKS := {
    "spring": SPRING,
    "rock": ROCK,
    "bushes": BUSHES,
    "birches": BIRCHES,
    "lake": LAKE,
    "kurgan": KURGAN,
    "well": WELL,
    "yurt": YURT,
    "pasture": PASTURE,
}

## The portraits of the people, by the portrait of a [Person].
const PORTRAITS := ["grandmother", "shepherd", "beekeeper"]

const _PORTRAITS_DIR := "res://assets/pictures/people"


## The icon of the picture at the scale (the box of [constant SIZE] times it).
static func of(picture: String, scale := 1.0) -> ImageTexture:
    var body := '<g transform="scale(%s)">%s</g>' % [String.num(scale, 3), picture]
    return Pixelate.texture(body, Rect2(Vector2.ZERO, SIZE * scale))


## The icon of the animal of the kind, painted (or drawn, without a painting).
static func animal(id: String, scale := 1.0) -> ImageTexture:
    var painted := _painted("animal_" + id, scale)
    return painted if painted != null else of(ANIMALS.get(id, SHEEP), scale)


## The icon of the landmark of the kind, painted (or drawn, without a
## painting).
static func landmark(id: String, scale := 1.0) -> ImageTexture:
    var painted := _painted("landmark_" + id, scale)
    return painted if painted != null else of(LANDMARKS.get(id, ROCK), scale)


static func star(scale := 1.0) -> ImageTexture:
    var painted := _painted("star", scale)
    return painted if painted != null else of(STAR, scale)


static func heart(scale := 1.0) -> ImageTexture:
    var painted := _painted("heart", scale)
    return painted if painted != null else of(HEART, scale)


static func water(scale := 1.0) -> ImageTexture:
    var painted := _painted("water", scale)
    return painted if painted != null else of(WATER, scale)


static func grass(scale := 1.0) -> ImageTexture:
    var painted := _painted("grass", scale)
    return painted if painted != null else of(GRASS, scale)


## The portrait, painted, 128 x 128; it is drawn 64 logical pixels wide.
static func portrait(id: String) -> Texture2D:
    return load("%s/%s_portrait.png" % [_PORTRAITS_DIR, id if id in PORTRAITS else "shepherd"])


## The portrait of the person, painted, fitted into the box of the icons at
## the scale, like the other icons (e.g., in a hint whom to ask).
static func portrait_icon(id: String, scale := 1.0) -> ImageTexture:
    var name := id if id in PORTRAITS else "shepherd"
    return Painting.fitted("%s/%s_portrait.png" % [_PORTRAITS_DIR, name], SIZE * scale)


## The person seen from above, painted, two pixels of the screen per logical
## pixel; the middle of the person in the middle of the picture.
static func person_above(id: String) -> Texture2D:
    return load("%s/%s_above.png" % [_PORTRAITS_DIR, id if id in PORTRAITS else "shepherd"])


## The bird of the hand cursor, painted.
static func bird(scale := 1.0) -> ImageTexture:
    var painted := _painted("bird", scale)
    return painted if painted != null else of(BIRD, scale)


## The painted icon (see assets/pictures/icons/) fitted into the box of the
## icons at the scale, like the drawn icons, so that every icon takes the
## same place; null if there is no painting.
static func _painted(name: String, scale: float) -> ImageTexture:
    return Painting.fitted("res://assets/pictures/icons/%s.png" % name, SIZE * scale)


## All the pictures by their names, for the tests.
static func all() -> Dictionary:
    var result := {"star": STAR, "heart": HEART, "water": WATER, "grass": GRASS, "bird": BIRD}
    for id in ANIMALS:
        result["animal_" + id] = ANIMALS[id]
    for id in LANDMARKS:
        result["landmark_" + id] = LANDMARKS[id]
    return result
