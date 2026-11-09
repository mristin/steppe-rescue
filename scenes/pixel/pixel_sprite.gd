class_name PixelSprite
extends RefCounted

## Make textures from sprites written as rows of characters, one character per
## pixel, with the colors of [constant Palette.LEGEND].
##
## The sprites live in the code as small pictures, e.g.:
##
## [codeblock]
## const HAT := [
##     "..kkkk..",
##     ".krrrrk.",
##     "kyyyyyyk",
## ]
## [/codeblock]
##
## They are placeholders until the drawn sprites arrive, and the tests check
## that every row of a sprite has the same width and only known characters.

static var _cache: Dictionary = {}


## Make (or take from the cache) the texture of the sprite.
static func texture(rows: Array) -> ImageTexture:
    var key := "\n".join(PackedStringArray(rows))
    if _cache.has(key):
        return _cache[key]

    var image := image_of(rows)
    var result := ImageTexture.create_from_image(image)
    _cache[key] = result
    return result


## Make the image of the sprite.
static func image_of(rows: Array) -> Image:
    var height := rows.size()
    var width := 0
    for row in rows:
        width = maxi(width, (row as String).length())

    var image := Image.create_empty(maxi(width, 1), maxi(height, 1), false, Image.FORMAT_RGBA8)
    for y in range(height):
        var row: String = rows[y]
        for x in range(row.length()):
            var character := row[x]
            image.set_pixel(x, y, Palette.LEGEND.get(character, Color.MAGENTA))
    return image


## Check the sprite and return the problems, if any: rows of different widths
## and unknown characters.
static func problems(name: String, rows: Array) -> PackedStringArray:
    var result := PackedStringArray()
    if rows.is_empty():
        result.append("%s: the sprite is empty" % name)
        return result

    var width := (rows[0] as String).length()
    for y in range(rows.size()):
        var row: String = rows[y]
        if row.length() != width:
            result.append(
                "%s: the row %d is %d pixels wide, expected %d" % [name, y, row.length(), width]
            )
        for character in row:
            if not Palette.LEGEND.has(character):
                result.append("%s: the row %d has the unknown character %s" % [name, y, character])
    return result
