class_name SideView
extends RefCounted

## Draw the horse seen from the side, facing right, with or without the rider
## on it, in the [Looks] which the player chose: in the speed bar, in the
## creator and on the intro screen.
##
## The horse and the rider are drawn as an illustration in vectors (SVG): the
## horse with its shaded body, its muscles, the flowing mane and tail and the
## bridle (жүген); the saddle cloth (тоқым) with the ram's horn ornament
## (қошқар мүйіз); the girl with her face in profile, her braids with the
## tassels (шашбау), the trimmed and embroidered coat (шапан), the belt with
## the silver plates and the embroidered boots. Each color comes in three
## shades (see [method Looks.shades]). The finery which the rider won (see
## [Finery]) is drawn in its steps over the plain tack and clothes: the
## saddle, the saddle cloth, the bridle, the breastplate, the stirrups and the
## mane of the horse; the owl feathers, the coat, the earrings, the bracelets,
## the belt and the boots of the rider. The picture is pixelated by [Pixelate]
## at the scale it is shown, so the big picture of the creator has all the
## details, and the small one of the speed bar keeps the shape.
##
## The box is 34 logical pixels wide at the scale 1: the hooves stand on the
## line y = 23, the feathers of the hat reach up to y = -11.

## The box of the horse alone, at the scale 1.
const HORSE_BOX := Rect2(-1, 0, 34, 24)

## The box of the horse with the rider on it, at the scale 1.
const RIDER_BOX := Rect2(-1, -11, 34, 35)

## Where the horse stands: between its hooves on the ground, at the scale 1.
const GROUND := Vector2(16, 23)

## The hips and the shoulders, where the legs start: the near and the far hind
## leg, then the near and the far front leg.
const _HIPS := [Vector2(8.4, 12.4), Vector2(9.8, 12.2), Vector2(20.2, 13.2), Vector2(18.8, 13)]

## The rider is drawn this big, around her seat in the saddle.
const _RIDER_SIZE := 0.88

## The lengths of the upper leg, the cannon and the pastern.
const _UPPER := 4.4
const _CANNON := 4.3
const _PASTERN := 1.1

## The angles of the legs in degrees from straight down, positive forward:
## [upper leg, cannon] of the near and the far hind leg, then the near and the
## far front leg, by the gait and the frame.
const _POSES := {
    "0_0": [[2, -4], [-4, -2], [0, 0], [4, 3]],
    "1_0": [[16, 8], [-14, -14], [18, 14], [-12, -12]],
    "1_1": [[-14, -14], [16, 8], [-12, -12], [18, 14]],
    "2_0": [[-20, -20], [30, -6], [40, -40], [-16, -16]],
    "2_1": [[30, -6], [-20, -20], [-16, -16], [40, -40]],
    "3_0": [[-48, -62], [-36, -50], [58, 60], [44, 48]],
    "3_1": [[42, 10], [32, 2], [-8, -80], [12, -66]],
}

## The body of the horse: the silhouette in the coat, the shadow of the belly,
## the light on the croup, the back and the neck, and the lines of the muscles
## of the shoulder, the hip and the belly.
const _HORSE_BODY := """
<path d="M6 8.6 C7 7.3 9.6 6.9 11.6 7.7 C13.4 8.5 16 8.5 18.4 7.5 C19.8 6.7 20.6 5.2 21.6 3.8
         C22.4 2.6 23.6 2 24.6 2.2 L25.6 3.6 L23.8 7.4 C23.2 8.8 22.9 10.2 22.7 11.6
         C22.5 13 21.8 14 20.8 14.4 C18 15.3 13 15.3 10.6 14.7 C9 14.4 7.4 14.2 6.3 13.2
         C5.4 12.2 5.2 10 6 8.6 Z" fill="{c1}"/>
<path d="M10.6 14.7 C13 15.3 18 15.3 20.8 14.4 C21.4 14.1 21.9 13.6 22.2 13
         C19 14 14 14.2 10.4 13.8 C8.8 13.6 7.4 13 6.6 12.4 C7.4 13.6 9 14.4 10.6 14.7 Z"
      fill="{c0}"/>
<path d="M7.2 8.2 C8.6 7.4 10.4 7.4 11.6 8.1 C10.4 8 8.6 8.2 7.4 8.8 Z" fill="{c2}"/>
<path d="M13.4 8.7 C15 8.9 16.6 8.7 18 8.1 C16.6 8.9 15 9.2 13.4 9 Z" fill="{c2}"/>
<path d="M20.2 7.2 C21 6.1 21.7 4.8 22.6 3.7 C22.1 4.9 21.5 6.2 20.8 7.6 Z" fill="{c2}"/>
<path d="M20.7 8.6 C19.6 10.2 19.6 12.2 20.4 13.6" stroke="{c0}" stroke-width="0.35"
      fill="none" stroke-linecap="round"/>
<path d="M8.4 8.6 C10.4 9.6 10.8 11.6 9.8 13.2" stroke="{c0}" stroke-width="0.35"
      fill="none" stroke-linecap="round"/>
<path d="M13.6 12.6 C15.4 13 17.4 13 18.8 12.6" stroke="{c0}" stroke-width="0.25"
      fill="none" stroke-linecap="round"/>
"""

## The head: its shape with the jaw, the ears, the eye with its light, the
## nostril and the mouth.
const _HORSE_HEAD := """
<path d="M23.4 3 C24.2 2.2 25.4 2.2 26.4 2.8 C27.8 3.6 29.6 5.2 30.8 6.6
         C31.4 7.4 31 8.4 30 8.4 C29 8.4 28.2 8 27.4 7.6 C26.4 7.2 25.6 6.9 24.6 7.6
         C24 6.2 23.4 4.6 23.4 3 Z" fill="{c1}"/>
<path d="M24.6 7.6 C25.6 6.9 26.4 7.2 27.4 7.6 C28.2 8 29 8.4 30 8.4 C29.4 8.8 28.4 8.6 27.4 8.2
         C26.4 7.8 25.4 7.6 24.6 7.6 Z" fill="{c0}"/>
<path d="M25.2 6.4 C26 5.8 27 5.9 27.6 6.8" stroke="{c0}" stroke-width="0.3" fill="none"
      stroke-linecap="round"/>
<path d="M26.4 3.2 C27.6 3.8 29 5 30.2 6.4" stroke="{c2}" stroke-width="0.35" fill="none"
      stroke-linecap="round"/>
<path d="M25 1.2 L25.6 0 L26.2 2.4 Z" fill="{c1}"/>
<path d="M24.2 1.6 L24.5 0.4 L25.1 2.2 Z" fill="{c0}"/>
<ellipse cx="26.5" cy="4.1" rx="0.55" ry="0.45" fill="{outline}"/>
<circle cx="26.65" cy="3.95" r="0.17" fill="{felt}"/>
<ellipse cx="30.2" cy="7.1" rx="0.35" ry="0.25" fill="{outline}" transform="rotate(40 30.2 7.1)"/>
<path d="M29 8.05 L30 8" stroke="{c0}" stroke-width="0.2"/>
"""

## The mane along the crest of the neck, in locks, and the forelock.
const _MANE := """
<path d="M18.2 7.2 C19.6 6 20.6 4.2 21.6 3 C22.4 2.2 23.4 1.6 24.6 1.8 L24.8 2.6
         C23.6 2.8 23 3.6 22.6 4.6 C22.4 5.4 22.2 6.2 21.8 6.8 C21.4 7.6 21 8.4 20.4 9.2
         C20 8.4 19.8 8.6 19.2 8.4 C18.8 8.2 18.6 7.8 18.2 7.2 Z" fill="{m1}"/>
<path d="M19.4 7.4 C20.4 6.2 21.2 4.6 22.2 3.4 M20.4 8 C21.2 6.8 21.8 5 22.8 3.8"
      stroke="{m2}" stroke-width="0.25" fill="none" stroke-linecap="round"/>
<path d="M20.8 6.2 C21.4 5 22 3.8 23 3" stroke="{m0}" stroke-width="0.25" fill="none"
      stroke-linecap="round"/>
<path d="M24.8 1.8 C25.8 2.2 26.4 3 26.2 3.8 C25.8 3.4 25.4 3.1 24.8 3 Z" fill="{m1}"/>
"""

## The bridle (жүген): the leather straps and the bit.
const _BRIDLE := """
<path d="M25.2 2.6 L26.6 7.4 M25.2 2.8 L27 3.4 M28.6 5.2 L29.4 8.3 M26.6 7.4 L29.2 7.8"
      stroke="{crimson_dark}" stroke-width="0.45" fill="none" stroke-linecap="round"/>
<circle cx="29.3" cy="7.9" r="0.45" fill="none" stroke="{stone}" stroke-width="0.25"/>
"""

## The silver plates on the bridle.
const _BRIDLE_PLATES := """
<g fill="{stone_light}">
  <circle cx="25.6" cy="4.2" r="0.3"/>
  <circle cx="26.1" cy="5.8" r="0.3"/>
  <circle cx="28.9" cy="6.3" r="0.3"/>
  <circle cx="26.2" cy="3.2" r="0.3"/>
</g>
"""

## The coloured tassels hanging from the bridle.
const _BRIDLE_TASSELS := """
<path d="M26.4 6.6 L26 9 M27.6 7.6 L27.4 9.6" stroke="{crimson}" stroke-width="0.5"
      stroke-linecap="round"/>
<g fill="{gold}"><circle cx="26.4" cy="6.6" r="0.3"/><circle cx="27.6" cy="7.6" r="0.3"/></g>
"""

## The breastplate (өмілдірік): a strap from the saddle around the chest, with
## silver ornaments.
const _BREASTPLATE := """
<path d="M18 8.4 C19.8 10.4 21.4 11.4 22.9 10.8" stroke="{bay}" stroke-width="0.7"
      fill="none" stroke-linecap="round"/>
<g fill="{stone_light}">
  <circle cx="19.6" cy="9.9" r="0.45"/><circle cx="21.2" cy="10.9" r="0.55"/>
  <circle cx="22.6" cy="10.9" r="0.45"/>
</g>
<circle cx="21.2" cy="10.9" r="0.2" fill="{crimson}"/>
"""

## The steps of the mane: braided, with ribbons, and with the owl-feather
## tassel (үкі) for good luck.
const _MANE_BRAIDS := """
<g fill="{m0}">
  <circle cx="19.4" cy="7.6" r="0.4"/><circle cx="20.4" cy="6.2" r="0.4"/>
  <circle cx="21.4" cy="4.8" r="0.4"/><circle cx="22.4" cy="3.6" r="0.4"/>
</g>
"""

const _MANE_RIBBONS := """
<path d="M19.4 7.6 L18.8 8.8 M20.4 6.2 L19.8 7.4 M21.4 4.8 L20.8 6 M22.4 3.6 L21.8 4.8"
      stroke="{crimson}" stroke-width="0.35" stroke-linecap="round"/>
"""

const _OWL_TASSEL := """
<path d="M24.6 1.6 C24 0 24.2 -1.4 24.8 -2 C25.2 -1 25.4 0.2 25 1.6 Z
         M25 1.6 C25.6 0.2 26.4 -0.4 27 -0.4 C26.6 0.4 26 1.2 25.2 1.8 Z" fill="{felt}"/>
<circle cx="24.9" cy="1.8" r="0.4" fill="{gold}"/>
"""

## The owl feathers (үкі) on the top of the hat, for good luck.
const _FEATHERS := """
<path d="M14 -10.1 C13.4 -11.2 13.6 -11.8 14.2 -12 C14.4 -11.4 14.6 -10.8 14.4 -10 Z
         M14.3 -10 C14.6 -11 15.2 -11.4 15.8 -11.2 C15.4 -10.6 15 -10.2 14.5 -9.9 Z"
      fill="{felt}"/>
<path d="M14 -10.2 C13.8 -10.8 13.9 -11.3 14.1 -11.6" stroke="{stone}" stroke-width="0.14"
      fill="none"/>
"""

## How far the feathers stand above those of the тақия, by the hat.
const _FEATHERS_UP := {"takiya": 0.0, "borik": 1.3, "scarf": 0.0, "felt_hat": 1.8, "none": -0.4}

## The patches of the piebald horse.
const _PIEBALD := """
<g fill="{bay}">
  <path d="M7 9 C8 7.6 10.6 7.6 11.6 8.8 C12.2 10.4 11 12 9.4 12.2 C7.8 12.4 6.6 10.8 7 9 Z"/>
  <path d="M15 11 C16 10.2 18 10.4 18.6 11.4 C18.6 12.8 17 13.6 15.6 13.2 C14.6 12.8 14.4 11.8 15 11
           Z"/>
  <path d="M21.2 4.6 C22 3.6 23.4 3.4 23.6 4.4 C23.6 5.8 22.4 7 21.4 6.6 C20.8 6 20.8 5.2 21.2 4.6
           Z"/>
</g>
"""

## The rider's leg and coat: the dress, her leg in the boot with the
## embroidered top in the stirrup, and the coat (шапан) with its shadow, its
## light and its trims.
const _RIDER_LEG_AND_COAT := """
<path d="M11.2 4.8 L14.8 4.8 C15.8 6.4 16.8 8.4 17.2 10.6 C16 11 14.8 11 13.8 10.6
         C12.6 9.8 11.8 8.6 11 7.8 Z" fill="{d1}"/>
<path d="M13.2 6.6 C13.8 8 14.4 9.2 14.6 10.6 M15.6 7.4 C16 8.4 16.4 9.4 16.6 10.6"
      stroke="{d0}" stroke-width="0.3" fill="none" stroke-linecap="round"/>
<path d="M13.6 5.8 L16.6 9.4" stroke="{d1}" stroke-width="2.4" stroke-linecap="round"/>
<path d="M14.2 5.8 L16.8 9" stroke="{d2}" stroke-width="0.4" stroke-linecap="round"/>
<path d="M16.6 9.6 L16.2 12.8" stroke="{hoof}" stroke-width="1.8" stroke-linecap="round"/>
<path d="M15.3 12.4 L16.8 12.4 C17.6 12.6 18 13 18.5 12.6 C18.3 13.5 17.6 13.8 16.8 13.8
         L15.4 13.8 Z" fill="{hoof}"/>
{boots}
<path d="M12 -2.4 C13 -2.9 14.4 -2.9 15.2 -2.2 C15.8 -0.6 15.8 1.6 15.4 3.4
         C15.8 5 16.6 6.4 17.2 7.8 C15.4 8.4 13 8.4 10.8 7.6 C11.2 6.2 11.6 4.8 11.8 3.4
         C11.2 1.4 11.2 -0.8 12 -2.4 Z" fill="{k1}"/>
<path d="M12 -2.4 C11.2 -0.8 11.2 1.4 11.8 3.4 C11.6 4.8 11.2 6.2 10.8 7.6 C11.6 7.9 12.2 8
         12.6 8 C12.2 6 12.6 4.6 12.8 3.4 C12.2 1.4 12.2 -0.6 12.8 -2.6 Z" fill="{k0}"/>
<path d="M14.6 -1.6 C15 0 15 1.6 14.8 2.8" stroke="{k2}" stroke-width="0.35" fill="none"
      stroke-linecap="round"/>
<path d="M15.2 -2.2 C15.7 0 15.5 2 15.4 3.4 C15.8 5 16.4 6.4 17.1 7.8 M10.8 7.6 C13 8.4 15.4 8.4
         17.2 7.8" stroke="{trim}" stroke-width="0.4" fill="none" stroke-linecap="round"/>
"""

## Over the coat: the collar, the belt with the silver plates, the reins and
## the arm in the sleeve with its cuff, and the hand.
const _RIDER_FRONT := """
<path d="M12.8 -2.9 L14.9 -2.6 L14.8 -1.8 L12.9 -2 Z" fill="{trim}"/>
<path d="M11.6 3 L15.7 3 L15.7 3.9 L11.6 3.9 Z" fill="{belt}"/>
{plates}
<path d="M18.2 3.4 C22 4.6 26 6.8 29.3 7.9" stroke="{crimson_dark}" stroke-width="0.3" fill="none"/>
<path d="M13.8 -1.6 L15 1.8 L17.2 2.9" stroke="{k1}" stroke-width="1.5" fill="none"
      stroke-linecap="round" stroke-linejoin="round"/>
<path d="M13.4 -0.8 L14.4 2.2 L16.6 3.4" stroke="{k0}" stroke-width="0.4" fill="none"
      stroke-linecap="round" stroke-linejoin="round"/>
<path d="M14.2 -1.6 L15.2 1.2" stroke="{k2}" stroke-width="0.3" stroke-linecap="round"/>
<path d="M16.8 2.7 L17.4 3" stroke="{trim}" stroke-width="1.6"/>
{bracelet}
<ellipse cx="18" cy="3.3" rx="0.7" ry="0.55" fill="{s1}"/>
<path d="M17.8 3.6 C18.2 3.8 18.6 3.6 18.6 3.3" stroke="{s0}" stroke-width="0.18" fill="none"/>
"""

## The head in profile: the neck, the face with the nose, the lips and the
## chin, the ear with the earring (сырға), the eye with its lashes, the brow,
## the blush, and the hair on the head.
const _HEAD := """
<path d="M13.2 -3.8 L14.6 -3.8 L14.8 -2.2 L13 -2.2 Z" fill="{s0}"/>
<path d="M12 -6.2 C12 -8.4 13.6 -9.2 14.8 -8.8 C16 -8.4 16.6 -7.4 16.6 -6.4 L16.5 -6
         C16.9 -5.6 17.3 -5.1 17.2 -4.9 C17 -4.7 16.8 -4.7 16.6 -4.7 C16.7 -4.4 16.7 -4.2 16.5 -4.1
         C16.6 -3.9 16.5 -3.7 16.3 -3.6 C16.2 -3.3 15.8 -3 15.4 -3 C14.6 -3 13.6 -3.4 13 -3.8
         C12.4 -4.4 12 -5.2 12 -6.2 Z" fill="{s1}"/>
<path d="M13 -3.8 C13.6 -3.4 14.6 -3 15.4 -3 C15.2 -3.4 14.4 -3.6 13.8 -4 Z" fill="{s0}"/>
<path d="M16 -7.4 C16.3 -7 16.5 -6.6 16.5 -6.1" stroke="{s2}" stroke-width="0.3" fill="none"
      stroke-linecap="round"/>
<ellipse cx="15.3" cy="-4.7" rx="0.6" ry="0.32" fill="{crimson_light}"/>
<path d="M16.15 -3.95 L16.55 -4.02" stroke="{crimson}" stroke-width="0.25" stroke-linecap="round"/>
<path d="M14.95 -5.95 C15.3 -6.3 15.8 -6.25 16 -5.95 C15.65 -5.75 15.3 -5.75 14.95 -5.95 Z"
      fill="{outline}"/>
<circle cx="15.6" cy="-6" r="0.1" fill="{felt}"/>
<path d="M14.95 -6 L14.65 -6.25 M15.15 -6.12 L14.95 -6.4" stroke="{outline}" stroke-width="0.14"
      stroke-linecap="round"/>
<path d="M14.9 -6.75 C15.3 -7 15.85 -6.95 16.15 -6.65" stroke="{h0}" stroke-width="0.24"
      fill="none" stroke-linecap="round"/>
<ellipse cx="13.6" cy="-5.3" rx="0.45" ry="0.65" fill="{s1}"/>
<path d="M13.5 -5.7 C13.8 -5.5 13.8 -5.1 13.5 -4.9" stroke="{s0}" stroke-width="0.18" fill="none"/>
{earring}
<path d="M11.7 -6 C11.4 -8.6 13.4 -9.7 15 -9.3 C16.2 -9 16.9 -8 16.8 -7
         C16.2 -7.6 15.4 -7.7 14.6 -7.4
         C14 -6.6 13.9 -6 14.1 -5 C13.4 -4.4 12.6 -4.4 11.9 -4.9 Z" fill="{h1}"/>
<path d="M12.4 -8.2 C13.2 -8.9 14.4 -9 15.4 -8.6 M12.2 -6.8 C12.6 -7.8 13.4 -8.3 14.4 -8.2"
      stroke="{h2}" stroke-width="0.22" fill="none" stroke-linecap="round"/>
<path d="M12 -5.4 C12.4 -6.4 13 -7 13.8 -7.4" stroke="{h0}" stroke-width="0.22" fill="none"
      stroke-linecap="round"/>
"""

const _LOOSE_HAIR := """
<path d="M11.8 -7.4 C10.4 -4.8 10 -1.4 10.6 1.6 C11.2 2.2 12.2 2.2 13 1.6 C12.8 -0.6 13 -3 13.6 -4.8
         Z" fill="{h1}"/>
<path d="M11.4 -5 C10.8 -2.8 10.8 -0.4 11.2 1.4 M12.4 -4.4 C12 -2.4 12 -0.4 12.2 1.4"
      stroke="{h0}" stroke-width="0.25" fill="none" stroke-linecap="round"/>
"""

const _BUN := """
<circle cx="11.6" cy="-8.2" r="1.5" fill="{h1}"/>
<path d="M10.6 -8.6 C11.2 -9.4 12.2 -9.4 12.8 -8.6 M10.6 -7.8 C11.2 -7.2 12.2 -7.2 12.8 -7.8"
      stroke="{h0}" stroke-width="0.25" fill="none"/>
<circle cx="12.6" cy="-9.2" r="0.3" fill="{gold}"/>
"""

## The silver plates on the belt.
const _BELT_PLATES := """
<g fill="{stone_light}">
  <rect x="12" y="3.15" width="0.6" height="0.6"/>
  <rect x="13.2" y="3.15" width="0.6" height="0.6"/>
  <rect x="14.4" y="3.15" width="0.6" height="0.6"/>
</g>
"""

## The silver bracelet (білезік) on the wrist.
const _BRACELET := """
<path d="M17.45 2.75 L17.6 3.45" stroke="{stone_light}" stroke-width="0.4"/>
"""

## The silver earring (сырға) with its crimson drop.
const _EARRING := """
<circle cx="13.6" cy="-4.4" r="0.26" fill="{stone_light}"/>
<circle cx="13.6" cy="-3.9" r="0.2" fill="{crimson}"/>
"""

## The embroidered tops and the golden seams of the boots.
const _BOOTS := """
<path d="M15.6 9.9 L17.6 10.1" stroke="{crimson}" stroke-width="0.8" stroke-linecap="round"/>
<path d="M15.8 9.9 L17.4 10.1" stroke="{gold}" stroke-width="0.25" stroke-dasharray="0.3 0.3"/>
<path d="M15.6 13.9 C15.8 14.6 17.2 14.6 17.4 13.9" stroke="{gold}" stroke-width="0.35"
      fill="none"/>
"""

## The hats: the embroidered skullcap (тақия), the
## fur-trimmed hat (бөрік), the headscarf (орамал) with its pattern, and the
## white felt hat with the black velvet brim.
const _HATS := {
    "takiya":
    """
<path d="M11.6 -7.4 C11.4 -10.4 16.6 -10.8 17 -7.6 Z" fill="{crimson}"/>
<path d="M12.2 -8.2 C12.4 -9.6 15.4 -9.9 16.2 -8.4" stroke="{crimson_light}" stroke-width="0.3"
      fill="none"/>
<path d="M11.4 -8 L17.1 -8 L17.1 -7.2 L11.4 -7.2 Z" fill="{gold}"/>
<path d="M11.6 -7.6 L16.9 -7.6" stroke="{crimson_dark}" stroke-width="0.18"
      stroke-dasharray="0.4 0.3"/>
<path d="M14.2 -9.8 L14.7 -9.1 L14.2 -8.4 L13.7 -9.1 Z" fill="{gold}"/>
""",
    "borik":
    """
<path d="M12 -7.6 C11.6 -11.4 16.8 -11.8 16.6 -7.6 Z" fill="{indigo}"/>
<path d="M12.8 -8.4 C12.8 -10.4 15.6 -10.8 16 -8.6" stroke="{indigo_light}" stroke-width="0.3"
      fill="none"/>
<path d="M14.3 -11 L14.3 -8" stroke="{gold}" stroke-width="0.3"/>
<circle cx="14.3" cy="-11.1" r="0.45" fill="{gold}"/>
<path d="M10.8 -7.4 C10.8 -8.8 17.8 -8.8 17.8 -7.4 C17.8 -6.4 10.8 -6.4 10.8 -7.4 Z"
      fill="{hoof}"/>
<path d="M11.4 -7.8 L11.8 -7 M12.6 -8 L13 -7 M13.8 -8.1 L14.2 -7 M15 -8.1 L15.4 -7
         M16.2 -8 L16.6 -7.1 M17.2 -7.8 L17.4 -7.2" stroke="{bay_light}" stroke-width="0.22"
      stroke-linecap="round"/>
""",
    "scarf":
    """
<path d="M11 -5.2 C10.4 -9.6 14.4 -10.8 16.4 -9 C17.2 -8.2 17.4 -7.2 17.2 -6.6
         C16.4 -7.4 15.4 -7.6 14.6 -7.2 C13.8 -6.4 13.4 -5.2 13.4 -3.8 C12.6 -2.8 11.2 -1.4 10 -1
         C10.4 -2.6 10.8 -3.8 11 -5.2 Z" fill="{crimson}"/>
<path d="M11.8 -8.6 C13 -9.8 15.2 -9.8 16.4 -8.4" stroke="{crimson_light}" stroke-width="0.3"
      fill="none"/>
<path d="M17.1 -6.7 C16.2 -7.6 15 -7.7 14.4 -7.1 C13.6 -6.2 13.3 -5.2 13.3 -3.9" stroke="{gold}"
      stroke-width="0.3" fill="none"/>
<g fill="{gold}">
  <circle cx="12.4" cy="-8" r="0.32"/>
  <circle cx="14.4" cy="-8.8" r="0.32"/>
  <circle cx="11.8" cy="-6" r="0.32"/>
  <circle cx="13" cy="-6.8" r="0.32"/>
  <circle cx="11.4" cy="-3.6" r="0.32"/>
  <circle cx="15.8" cy="-8.2" r="0.32"/>
</g>
<path d="M10.2 -1.2 L9.6 0.2 M10.8 -1.4 L10.6 0" stroke="{crimson_dark}" stroke-width="0.3"
      stroke-linecap="round"/>
""",
    "felt_hat":
    """
<path d="M11.8 -7.4 L13 -11.4 C13.6 -11.8 15 -11.8 15.6 -11.4 L16.8 -7.4 Z" fill="{felt}"/>
<path d="M13 -11.4 L12.2 -7.6" stroke="{stone_light}" stroke-width="0.4"/>
<path d="M13.6 -10 L15.2 -10 M13.4 -9.2 L15.4 -9.2" stroke="{crimson}" stroke-width="0.2"/>
<path d="M10.8 -7 C11 -8 12 -8.2 12.4 -7.8 L16.4 -7.8 C16.8 -8.4 17.8 -8 17.8 -7
         C16 -6.6 12.6 -6.6 10.8 -7 Z" fill="{night}"/>
<path d="M11.2 -7.2 L17.4 -7.2" stroke="{gold}" stroke-width="0.15" stroke-dasharray="0.3 0.3"/>
""",
}


## Where to draw the texture of [method texture] at the scale, so that the
## horse stands at [param ground].
static func top_left(ground: Vector2, rider: bool, scale: float) -> Vector2:
    var box := RIDER_BOX if rider else HORSE_BOX
    return (ground - (GROUND - box.position) * scale).round()


## The texture of the horse at the gait (0 stands, 1 walks, 2 trots, 3
## gallops) and the frame (0 or 1), with the rider if [param rider].
static func texture(
    looks: Dictionary, gait: int, frame: int, rider := false, scale := 1.0
) -> ImageTexture:
    var box := RIDER_BOX if rider else HORSE_BOX
    var body := (
        '<g transform="scale(%s)">%s</g>'
        % [_n(scale), svg(Looks.complete(looks), gait, frame, rider)]
    )
    return Pixelate.texture(body, Rect2(box.position * scale, box.size * scale))


## The horse (and the rider) as SVG, in the colors of the looks.
static func svg(looks: Dictionary, gait: int, frame: int, rider := false) -> String:
    var coat := _hex(Looks.shades(looks, "horse"))
    var mane := _hex(Looks.shades(looks, "mane"))
    var colors := {
        "c0": coat[0],
        "c1": coat[1],
        "c2": coat[2],
        "m0": mane[0],
        "m1": mane[1],
        "m2": mane[2],
    }
    var key := "%d_%d" % [gait, frame % 2] if gait > 0 else "0_0"
    var pose: Array = _POSES.get(key, _POSES["0_0"])
    var parts := PackedStringArray()

    parts.append(_tail(gait, frame).format(colors))
    parts.append(_leg(_HIPS[1], pose[1], coat[0], coat[0], true))
    parts.append(_leg(_HIPS[3], pose[3], coat[0], coat[0], false))
    parts.append(_HORSE_BODY.format(colors))
    if looks["horse"] == "piebald":
        parts.append(_PIEBALD)
    match looks["marking"]:
        "star":
            parts.append('<path d="M26.2 2.9 L26.9 3.6 L26.3 4.3 L25.7 3.6 Z" fill="{felt}"/>')
        "blaze":
            parts.append(
                (
                    '<path d="M26 3 C27 3.4 28.6 5 30 6.6 L30.4 7.4 C28.8 6 27.2 4.6 25.8 3.6 Z" '
                    + 'fill="{felt}"/>'
                )
            )
    parts.append(_HORSE_HEAD.format(colors))
    parts.append(_MANE.format(colors))
    var mane_step := Finery.step(looks, "mane")
    if mane_step >= 1:
        parts.append(_MANE_BRAIDS.format(colors))
    if mane_step >= 2:
        parts.append(_MANE_RIBBONS)
    if mane_step >= 3:
        parts.append(_OWL_TASSEL)
    parts.append(_leg(_HIPS[0], pose[0], coat[1], coat[0], true))
    parts.append(_leg(_HIPS[2], pose[2], coat[1], coat[0], false))
    parts.append(_BRIDLE)
    if Finery.step(looks, "bridle") >= 1:
        parts.append(_BRIDLE_PLATES)
    if Finery.step(looks, "bridle") >= 2:
        parts.append(_BRIDLE_TASSELS)
    if Finery.step(looks, "breastplate") >= 1:
        parts.append(_BREASTPLATE)

    # NOTE (mristin):
    # The horse is always saddled. The rider is a girl of ten: a bit smaller
    # than drawn, around the seat, and the saddle with her.
    var seat := _saddle(looks) + (_rider(looks) if rider else "")
    parts.append(
        (
            '<g transform="translate(14 7.6) scale(%s) translate(-14 -7.6)">%s</g>'
            % [_n(_RIDER_SIZE), seat]
        )
    )
    return "".join(parts)


## The tail: it hangs while the horse stands or walks, swings at the trot and
## streams out at the gallop; in locks of three shades.
static func _tail(gait: int, frame: int) -> String:
    var outline := (
        "M6.2 8.6 C4.6 8.8 3.6 10.6 3.4 13 C3.2 15.4 3.6 17.4 4.4 18.8 C4.6 17.8 4.9 16.8 5.1 16"
        + " C5.3 17 5.6 17.8 6.2 18.2 C5.9 15.6 5.8 12.4 6.9 10 Z"
    )
    var strands := "M5.6 9.6 C4.6 11.4 4.4 14.4 4.8 17 M6 10.4 C5.2 12.4 5.2 15 5.6 17.4"
    match gait:
        2:
            outline = (
                "M6.2 8.6 C4 8.8 2.6 10.4 2 12.6 C1.4 14.6 1.6 16.2 2.2 17.4 C2.6 16.4 2.9 15.6"
                + " 3.2 14.8 C3.4 15.8 3.8 16.4 4.4 16.8 C4 14.4 4.6 11.8 6.9 10 Z"
            )
            strands = "M5.2 9.6 C3.6 11.4 3 13.8 3 16.2 M5.8 10.2 C4.4 12 4 14.2 4.2 16.2"
        3:
            if frame % 2 == 0:
                outline = (
                    "M6.2 8.6 C4.2 7.6 2 8 -0.4 9.4 C0.6 9.6 1.4 9.8 2 10.2 C1 10.6 0 11.4"
                    + " -0.6 12.2 C1.6 11.8 4 11.2 6.9 10.4 Z"
                )
                strands = "M5.4 9.2 C3.8 8.8 2 9.2 0.4 10.2 M5.8 10 C4 10.2 2 10.8 0.2 11.8"
            else:
                outline = (
                    "M6.2 8.6 C4 8.6 2 9.8 0.2 11.6 C1.2 11.6 2 11.6 2.6 11.8 C1.6 12.6 0.8 13.6"
                    + " 0.4 14.6 C2.4 13.6 4.6 12 6.9 10.4 Z"
                )
                strands = "M5.4 9.4 C3.8 9.8 2.2 10.8 0.8 12 M5.8 10.2 C4.2 11 2.6 12.4 1.4 13.8"
    return (
        '<path d="%s" fill="{m1}"/>' % outline
        + (
            '<path d="%s" stroke="{m2}" stroke-width="0.3" fill="none" stroke-linecap="round"/>'
            % strands
        )
        + '<path d="M6.2 8.6 C5.4 8.8 4.8 9.4 4.6 10.2 C5.2 9.8 6 9.8 6.9 10 Z" fill="{m0}"/>'
    )


## A leg from the hip: the upper leg, broad and shaded, the cannon, the
## knee and the fetlock, the pastern and the hoof, at the angles of the pose.
static func _leg(hip: Vector2, angles: Array, color: String, shadow: String, hind: bool) -> String:
    var lower_direction := _down(angles[1])
    var knee: Vector2 = hip + _down(angles[0]) * _UPPER
    var fetlock := knee + lower_direction * _CANNON
    var hoof := fetlock + lower_direction * _PASTERN
    var side := Vector2(-lower_direction.y, lower_direction.x)
    var hoof_shape := PackedVector2Array(
        [
            hoof - side * 0.55 - lower_direction * 0.2,
            hoof + side * 0.55 - lower_direction * 0.2,
            hoof + side * 0.8 + lower_direction * 0.7,
            hoof - side * 0.8 + lower_direction * 0.7,
        ]
    )
    var parts := PackedStringArray()
    parts.append(
        (
            '<path d="M%s %s L%s %s" stroke="%s" stroke-width="%s" stroke-linecap="round"/>'
            % [_n(hip.x), _n(hip.y - 1.0), _n(knee.x), _n(knee.y), color, "2.6" if hind else "2.2"]
        )
    )
    parts.append(
        (
            (
                '<path d="M%s %s L%s %s L%s %s" stroke="%s" stroke-width="1.25" fill="none" '
                + 'stroke-linecap="round" stroke-linejoin="round"/>'
            )
            % [_n(knee.x), _n(knee.y), _n(fetlock.x), _n(fetlock.y), _n(hoof.x), _n(hoof.y), color]
        )
    )
    parts.append(_circle(fetlock, 0.8, color))
    parts.append(_circle(knee, 0.75, color))
    (
        parts
        . append(
            (
                '<path d="M%s %s L%s %s" stroke="%s" stroke-width="0.3" stroke-linecap="round"/>'
                % [
                    _n(knee.x + side.x * 0.4),
                    _n(knee.y + side.y * 0.4),
                    _n(fetlock.x + side.x * 0.35),
                    _n(fetlock.y + side.y * 0.35),
                    shadow,
                ]
            )
        )
    )
    parts.append(_polygon(hoof_shape, "{hoof}"))
    return "".join(parts)


## The rider sitting on the horse, on the saddle.
static func _rider(looks: Dictionary) -> String:
    var skin := _hex(Looks.shades(looks, "skin"))
    var hair := _hex(Looks.shades(looks, "hair_color"))
    var coat := _hex(Looks.shades(looks, "coat"))
    var dress := _hex(Looks.shades(looks, "dress"))
    var colors := {
        "s0": skin[0],
        "s1": skin[1],
        "s2": skin[2],
        "h0": hair[0],
        "h1": hair[1],
        "h2": hair[2],
        "k0": coat[0],
        "k1": coat[1],
        "k2": coat[2],
        "d0": dress[0],
        "d1": dress[1],
        "d2": dress[2],
        "trim": trim_color(looks, coat[0]),
        "belt": "{gold}" if Finery.step(looks, "belt") >= 1 else "{bay}",
        "plates": _BELT_PLATES if Finery.step(looks, "belt") >= 1 else "",
        "bracelet": _BRACELET if Finery.step(looks, "bracelets") >= 1 else "",
        "earring": _EARRING if Finery.step(looks, "earrings") >= 1 else "",
        "boots": _BOOTS if Finery.step(looks, "boots") >= 1 else "",
    }
    var parts := PackedStringArray()
    match looks["hair"]:
        "two_braids":
            parts.append(_braid(Vector2(12.6, -4.8), Vector2(11.2, 3.2)))
            parts.append(_braid(Vector2(13.1, -4.6), Vector2(12.2, 4.2)))
        "one_braid":
            parts.append(_braid(Vector2(12.8, -4.8), Vector2(11.6, 4)))
        "loose":
            parts.append(_LOOSE_HAIR)
    parts.append(_RIDER_LEG_AND_COAT)
    if Finery.step(looks, "coat") >= 2:
        parts.append(_ornament(Vector2(12.9, 5.8), 0.8, "{trim}"))
    parts.append(_RIDER_FRONT)
    parts.append(_HEAD)
    if looks["hair"] == "bun":
        parts.append(_BUN)
    parts.append(_HATS.get(looks["hat"], ""))
    if Finery.step(looks, "feathers") >= 1:
        var up: float = _FEATHERS_UP.get(looks["hat"], 0.0)
        parts.append('<g transform="translate(0 %s)">%s</g>' % [_n(-up), _FEATHERS])
    return "".join(parts).format(colors)


## The color of the trims of the coat: plain in the shadow of the coat, then
## embroidered in gold (or crimson on the ochre coat).
static func trim_color(looks: Dictionary, shadow: String) -> String:
    if Finery.step(looks, "coat") < 1:
        return shadow
    return "{crimson_dark}" if looks["coat"] == "ochre" else "{gold}"


## The saddle cloth (тоқым), the saddle (ер), the stirrup leather and the
## stirrup (үзеңгі), each plain or in the steps of the finery won: the cloth
## embroidered with the ram's horn, then with the tassels; the saddle with the
## silver studs, then carved and painted; the stirrup of engraved silver.
static func _saddle(looks: Dictionary) -> String:
    var parts := PackedStringArray()
    (
        parts
        . append(
            """
<path d="M9.6 7.6 L17.8 7.8 C18.2 9.6 18.2 11.4 17.6 12.8 L10 12.8 C9.4 11 9.4 9.2 9.6 7.6 Z"
      fill="{crimson_dark}"/>
"""
        )
    )
    var cloth := Finery.step(looks, "saddle_cloth")
    if cloth >= 1:
        (
            parts
            . append(
                """
<path d="M10.2 8.2 L17.2 8.4 C17.5 9.8 17.5 11.2 17.1 12.2 L10.5 12.2 C10.1 10.8 10 9.4 10.2 8.2 Z"
      fill="none" stroke="{gold}" stroke-width="0.3"/>
"""
            )
        )
        parts.append(_ornament(Vector2(13.8, 10.6), 1.3, "{gold}"))
    if cloth >= 2:
        (
            parts
            . append(
                """
<path d="M10.2 12.8 L10 14 M11 12.8 L10.9 13.9 M16.8 12.8 L17 14 M17.6 12.8 L17.8 13.8"
      stroke="{gold}" stroke-width="0.35" stroke-linecap="round"/>
"""
            )
        )
    (
        parts
        . append(
            """
<path d="M10.2 7.6 C10.4 5.8 11.8 6.2 13.2 6.6 L15.6 6.6 C16.4 6.2 17.2 5.2 17.9 5.4
         C18 6.6 17.4 7.6 16.6 7.9 L10.8 7.9 Z" fill="{bay}"/>
<path d="M10.6 7 C11.6 7 12.6 7.2 13.4 7.2 L15.8 7.2" stroke="{bay_light}" stroke-width="0.3"
      fill="none"/>
"""
        )
    )
    var saddle := Finery.step(looks, "saddle")
    if saddle >= 1:
        (
            parts
            . append(
                """
<g fill="{stone_light}">
  <circle cx="11.2" cy="7.4" r="0.26"/>
  <circle cx="16.4" cy="7.2" r="0.26"/>
  <circle cx="17.5" cy="6" r="0.26"/>
</g>
"""
            )
        )
    if saddle >= 2:
        (
            parts
            . append(
                """
<path d="M11.8 7.55 L15.6 7.55" stroke="{crimson}" stroke-width="0.4"/>
<g fill="{gold}">
  <circle cx="12.6" cy="7.55" r="0.2"/><circle cx="13.7" cy="7.55" r="0.2"/>
  <circle cx="14.8" cy="7.55" r="0.2"/>
</g>
<path d="M17.2 5.6 L17.8 5.8" stroke="{gold}" stroke-width="0.3"/>
"""
            )
        )
    var iron := "{stone_light}" if Finery.step(looks, "stirrups") >= 1 else "{stone}"
    parts.append('<path d="M15 7.6 L16.2 13.2" stroke="{hoof}" stroke-width="0.35"/>')
    parts.append(
        (
            (
                '<path d="M15.5 13.2 L16.9 13.2 L16.8 14.3 L15.6 14.3 Z" fill="none" stroke="%s" '
                + 'stroke-width="0.35"/>'
            )
            % iron
        )
    )
    if Finery.step(looks, "stirrups") >= 1:
        parts.append('<circle cx="16.2" cy="13.2" r="0.25" fill="{gold}"/>')
    return "".join(parts)


## The braid from the nape down the back, plaited in locks, with the tassel
## (шашбау) of golden beads and a crimson tuft at its end.
static func _braid(from: Vector2, to: Vector2) -> String:
    var parts := PackedStringArray()
    var steps := 9
    var angle := _n(rad_to_deg((to - from).angle()) - 90.0)
    for i in range(steps):
        var at := from.lerp(to, (i + 0.5) / steps)
        parts.append(
            (
                (
                    '<ellipse cx="%s" cy="%s" rx="0.55" ry="0.62" fill="%s" '
                    + 'transform="rotate(%s %s %s)"/>'
                )
                % [_n(at.x), _n(at.y), "{h1}" if i % 2 == 0 else "{h0}", angle, _n(at.x), _n(at.y)]
            )
        )
    parts.append(_circle(to + Vector2(0, 0.3), 0.32, "{gold}"))
    parts.append(_circle(to + Vector2(-0.1, 0.9), 0.26, "{gold}"))
    var tuft := PackedVector2Array(
        [to + Vector2(-0.5, 1.1), to + Vector2(0.3, 1.1), to + Vector2(-0.1, 2.2)]
    )
    parts.append(_polygon(tuft, "{crimson}"))
    return "".join(parts)


## The ram's horn ornament (қошқар мүйіз): a stem and two horns curling
## outwards, the most common motif of the Kazakh ornaments, as SVG for any
## picture.
static func ornament(at: Vector2, size: float, color: String) -> String:
    return _ornament(at, size, color)


static func _ornament(at: Vector2, size: float, color: String) -> String:
    var parts := PackedStringArray()
    parts.append("M%s %s L%s %s" % [_n(at.x), _n(at.y + 0.7 * size), _n(at.x), _n(at.y)])
    for direction in [-1.0, 1.0]:
        var x := func(dx: float) -> String: return _n(at.x + direction * dx * size)
        var y := func(dy: float) -> String: return _n(at.y + dy * size)
        (
            parts
            . append(
                (
                    "M%s %s C%s %s %s %s %s %s C%s %s %s %s %s %s"
                    % [
                        _n(at.x),
                        _n(at.y),
                        x.call(0.15),
                        y.call(-0.7),
                        x.call(1.0),
                        y.call(-0.95),
                        x.call(1.0),
                        y.call(-0.45),
                        x.call(1.0),
                        y.call(-0.05),
                        x.call(0.55),
                        y.call(0.0),
                        x.call(0.55),
                        y.call(-0.3),
                    ]
                )
            )
        )
    return (
        '<path d="%s" stroke="%s" stroke-width="%s" fill="none" stroke-linecap="round"/>'
        % [" ".join(parts), color, _n(0.2 * size)]
    )


static func _down(degrees: float) -> Vector2:
    return Vector2(sin(deg_to_rad(degrees)), cos(deg_to_rad(degrees)))


static func _circle(at: Vector2, r: float, color: String) -> String:
    return '<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % [_n(at.x), _n(at.y), _n(r), color]


static func _polygon(points: PackedVector2Array, color: String) -> String:
    var coordinates := PackedStringArray()
    for point in points:
        coordinates.append("%s,%s" % [_n(point.x), _n(point.y)])
    return '<polygon points="%s" fill="%s"/>' % [" ".join(coordinates), color]


static func _hex(colors: Array[Color]) -> Array[String]:
    var result: Array[String] = []
    for value in colors:
        result.append(Pixelate.color(value))
    return result


static func _n(value: float) -> String:
    return String.num(value, 3)
