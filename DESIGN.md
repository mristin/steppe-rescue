# The Steppe Rescue: Design

*Status: a first draft, for review.*

**The Steppe Rescue is a riding and searching game for children of about ten, played by doing squats in front of a webcam.**
You are a girl from a small aul (a village of yurts) in the steppe near Astana. The animals of the aul have wandered off: sheep, horses and camels. You ride out on your horse, ask the people you meet where they saw the animals, find them, and lead them home.
Nobody fights and nothing can hurt you. You win by riding, listening and being kind.

Each level takes about ten minutes, and most of it is riding. Every stride of the horse is a squat, so riding means exercising.

# Game design

## 1. Pillars

1. **The exercise is the controller.** You ride with your body: squats make the horse go, and reaching across your body with one hand turns it. The game never says "do squats". It shows the movement, and the horse answers it.
2. **Searching, not shooting.** The animals are not on the map. You find them by asking people, reading the landmarks, and listening.
3. **A real place, gently told.** The steppe around Astana: feather grass, birch groves, salt lakes, the Esil river, yurts, and the Bayterek tower on the horizon. Simplified for children, but not made up.
4. **Everyone is friendly.** There are no enemies, no timers that end the game, and no way to lose an animal for good. A slow player still finishes.
5. **Your rider, your horse.** You create the rider and her horse at the start, and every finished level adds a new piece of finery, so that they become more beautiful over the whole game.

## 2. Setting: the steppe near Astana

The game is set today, in the open steppe a short ride from Astana. The city is always visible as a skyline far away, with the Bayterek tower, but the levels themselves are the steppe.

### The landmarks

The landmarks are what the people talk about, so each one must be easy to recognize from above and have a short, clear name. A level uses a handful of them:

* **the spring** (*бұлақ*), a small pool with green grass around it,
* **the big rock**, a lone grey boulder,
* **the bushes** (*қараған*, the steppe acacia), a patch of low, dark-green shrubs,
* **the birch grove** (*қайың тоғайы*), the islands of birches which are typical of the steppe around Astana,
* **the lake** and **the salt lake**, the second with a white crust at its shore,
* **the river** (the Esil) with its reeds,
* **the old kurgan**, a low, grassy burial mound,
* **the stone figure** (*балбал*), an old carved stone standing in the grass,
* **the well** with a wooden sweep (the long pole for lifting the bucket),
* **the winter camp**, an empty stone enclosure (*қыстау*),
* **the power line** or **the road**, which cross a level as a long, straight line,
* **the yurts** of the people you meet.

### The seasons

The levels move through the year, which changes the colours and the landmarks a little: tulips and poppies in spring, golden feather grass in summer, brown grass and geese in autumn, and a final level in the first snow.

## 3. Characters

* **The rider** (the player). A girl of about ten, created by the player (section 6): her name, her looks, and her clothes.
* **Her horse**, also named and chosen by the player.
* **Grandmother** (*әже*) at home in the aul. She sends the rider out at the start of each level ("The storm in the night scattered our sheep...") and thanks her at the end.
* **The people of the steppe**, met in front of their yurts or on the way: a shepherd with his dog, a beekeeper, a herder of horses (*жылқышы*), children flying a kite, an old man playing the dombra, a woman milking mares for *қымыз*, a geologist with a backpack, a family on a picnic. Each has a portrait, a name and a short greeting, and each knows where they saw *some* of the animals.
* **The animals**:
  * **sheep**, the most common: small, in groups of 2 to 5, slow,
  * **horses**, alone or in pairs, fast, and a little shy (you have to ride close and slow),
  * **camels** (the two-humped Bactrian camel), always alone, slow, and usually far away.

## 4. A level

### The structure (about 10 minutes)

1. **The briefing at home** (30 s). Grandmother says which animals are missing. Their pictures appear as empty slots at the top of the screen, e.g., ○○○ sheep, ○ camel.
2. **Riding out.** The rider leaves the aul. The level is a large steppe, many screens wide, seen from above.
3. **Asking.** The rider rides up to a yurt or a person and stops. The person tells her where they saw some of the animals.
4. **Searching and listening.** Following the clues, the rider rides towards the landmarks. When she comes near an animal, she hears it before she sees it.
5. **Gathering.** When she comes close enough, the animal joins her and follows.
6. **Bringing them home.** She can bring the animals home one by one or all at once. Each animal that enters the pen at the aul fills its slot.
7. **The end.** When all the slots are full, Grandmother thanks her, and the rider chooses her reward (section 8).

### The map

* The map of the level shows the landmarks, the yurts, the home aul and the rider, painted like a hand-drawn map on felt or paper. **It never shows the animals.**
* A small map sits in a corner of the screen. When the rider stands still for a moment, the map opens large, and closes again when she rides on.
* **The clues are drawn on the map.** When someone tells the rider where they saw an animal, a small sketch of the animal and a dotted area appear on the map in that place ("between the spring and the bushes"). The area is only approximate. The sketch is crossed out when the animal is found.

### The clues

The people tell the rider where they saw the animals, always relative to the landmarks and with a rough distance.

* **The forms of a clue:**
  * near one landmark: "I saw two sheep close to the big rock."
  * between two landmarks: "A camel was walking between the bushes and the spring."
  * on one side of a landmark: "The horses were grazing north of the lake," where north is shown with the compass on the map, as well as by the word.
  * far or near from the speaker: "Far away, beyond the birch grove." / "Very near, just behind my yurt."
* **The pictures carry the clue.** Each clue line has the pictures of the animal and the landmarks in it, so a child who reads slowly still understands it.
* **Short.** At most two short sentences per line.
* **Every animal is covered by at least one clue**, and the clues of a level are checked automatically to point to exactly one area.
* **Later levels** use clues which need two steps ("The beekeeper knows; ask him by the river") and vaguer distances.
* People repeat their clue if you visit them again.

### Hearing the animals

When the rider is near an animal, but the animal is still off the screen, she hears it.

* **An icon at the edge of the screen** shows the direction: a small picture of the animal with sound waves, sitting on the edge of the screen where a straight line from the rider to the animal leaves the screen.
* **The closer, the louder:** the icon grows and its waves pulse faster as the rider comes closer. Far, it is faint and small; near, it is big and bright.
* **The sound** comes from the same side (stereo panning) and gets louder: the bleating of the sheep, the neighing of the horses and the grunting of the camels.
* The hearing radius is about two screens. The icon disappears as soon as the animal is on the screen.
* Hearing works even without a clue, so a rider who explores is rewarded, too.

### Gathering and herding

* **An animal joins** when the rider comes within about a horse's length of it, and stays near for a moment (about 1 s). The animal looks up, a small heart or musical note rises above it, and it starts to follow.
* **Horses are shy:** they join only if the rider comes slowly (the horse walking, not galloping). If she gallops at them, they trot away a little, and she can try again.
* **The followers** walk behind the rider in a loose line or herd. They keep up with a walk and a trot, but at a gallop the slow animals (sheep, camels) fall behind and call out; they never get lost, and they catch up when the rider slows down.
* **The pen.** At home, the animals run into the pen by themselves when the rider rides through the gate.

### The levels

About ten levels, each larger than the last. A level is data (the map, the landmarks, the people, the animals and the clues), so new levels can be added without code.

| # | Level | What's new |
|---|---|---|
| 1 | The lamb by the spring | The tutorial: one sheep, visible from home. Learning to ride and turn. |
| 2 | After the storm | Three sheep. The first conversation and the first clue on the map. |
| 3 | Grandmother's camel | The first camel, far away. Hearing the animals. |
| 4 | The foals | Shy horses: ride slowly. |
| 5 | The birch groves | Animals hidden among the trees; clues with directions (north, south...). |
| 6 | Along the Esil | A river with fords: the rider can cross only at the fords. |
| 7 | The salt lake | A large, open level with far-away clues. |
| 8 | The herder's request | Two-step clues: one person sends you to another. |
| 9 | Autumn migration | Many animals, the longest ride. |
| 10 | The first snow | The finale: everyone gathers at the aul for a celebration. |

### Stars

Each level gives one to three stars, for being reasonably fast. There is never a "game over": the level only ends when all the animals are home. Stars only change which rewards are offered (section 8), and any level can be replayed.

## 5. Controls: squats and reaching across

### The exercise

The player stands facing the camera, about 2 to 3 m away, so that the camera sees the whole upper body. The camera has to see the head and the hands.

### Speed: squats

* **The horse goes as fast as the player squats.** We track the vertical movement of the head. Each down-and-up of the head is one squat, and the rate of squatting sets the speed of the horse:

  | Squatting | The horse |
  |---|---|
  | none (standing still) | stops after a few seconds |
  | slow (a squat every 3 s or more) | walks |
  | steady (about a squat every 2 s) | trots |
  | brisk (a squat every 1.5 s or faster) | gallops |

* **Deep squats count more** than shallow bobs: the depth is measured relative to the size of the head, so the game works whether the player stands close or far. A tiny nod of the head does nothing.
* **Gentle changes.** The horse speeds up and slows down over a second or two, so the speed doesn't flicker between squats. When the player stops, the horse slows down to a walk and then stops, but never instantly.
* The horse never goes backwards, and a child is never stuck.
* **Calibration** at the start of each level (3 s, while Grandmother talks): we take the standing height and the size of the head.

### Turning: reaching across the head

* **The axis of the head** is the vertical line through the middle of the head.
* **When the right hand crosses to the other side** of the head axis, the horse turns **left**. When the left hand crosses, the horse turns **right**. It is like reaching across to pull the reins.
* **How far across sets how hard it turns:** a hand just across turns gently; a hand far across turns sharply.
* **Both hands across** (crossed arms): no turn.
* **Both hands on their own side** (or not seen): the horse keeps its course.
* The left and right are those of the player's body, not of the picture. In the mirrored camera picture, the player sees her own hand cross over, which is what she expects.
* Squatting and turning can be done at the same time: the horse turns while it runs.
* **Smoothing:** a turn starts after the hand has been across for about 0.1 s, and the horse's heading changes smoothly.

### Showing instead of telling

The game never writes "do squats" or "cross your arm". It shows the movement and lets the player discover the rest.

* **The instruction** (section 6) is an animation without words: the rider gets off the horse, does squats next to it, and the horse starts walking, then trotting, then galloping. Then she reaches across with her right hand, and the horse turns left.
* **The camera picture** in a corner of the screen shows the player herself, with her chosen hat and braids drawn over her face (section 6). Next to it, a small figure of the rider does the movement the game is waiting for.
* **When the horse stands still** for a few seconds, the figure squats slowly and invitingly, and the horse looks back at the player and stamps a hoof.
* **The speed bar** (section 6) fills with each squat and empties when the player stops, so the link between squatting and speed is visible at a glance.
* **The horse's movement echoes the player's:** each squat is visible as one stride, and the rider's figure on the horse bobs up and down in time with the player's squats.
* **A hint for turning** appears only when the rider rides off the map edge or into the same obstacle twice: a ghostly arm reaching across, with a curved arrow.

### Menus: the hand cursor

* In the menus, the conversations and the character creator, an open hand moves a cursor (a small bird).
* **Clicking:** holding the cursor still over a button for about 1.5 s fills a ring around it, and then the button clicks. Hovering grows the button.
* The buttons are big, with at most four on a screen.

### Fallbacks

* **Keyboard** for development and testing: Space or ↑ is one squat (tapping faster makes the horse faster), ← and → turn.
* **Mouse** in the menus.
* Without a camera, the game offers the keyboard mode.

### Safety

* The instruction shows good squats: the feet shoulder-width apart, the knees over the toes, the back straight, and not lower than the thighs level with the floor.
* After each level, there is a natural rest (the reward screen).
* Clear space: the game asks for a free space of about 2 × 2 m around the player before the first level.

## 6. Screens

### The flow

1. **The intro screen:** the painted picture of the rider and her horse, with the title "The Steppe Rescue" and "Find the lost animals and bring them home!", and the buttons Play, Levels, Settings and How to Play. The texts on the buttons and the title are drawn by the game (not part of the picture), so they can be translated.
2. **Choose the language:** English, Русский, Қазақша, as three big cards with the name of each language in itself (no flags). The choice is remembered.
3. **Create the rider and the horse** (the first time only).
4. **The instruction** (the first time only, and from the menu "How to Play").
5. **The level select.**
6. **The level** and the **reward** at its end.

### Creating the rider and her horse

A preview of the rider sitting on her horse in the steppe turns slowly and changes right away.

* **The rider's name.** It can be typed on the keyboard, or picked on a big on-screen keyboard with the hand cursor. The keyboard has the letters of the chosen language: Latin, Russian Cyrillic, or Kazakh Cyrillic (with ә, ғ, қ, ң, ө, ұ, ү, һ, і). A name has 1 to 12 letters. The default is Айгерим (written in the alphabet of the language: Aigerim, Айгерим), so "Ready!" is enough.
* **The rider's looks:** each option is a row with arrows (◀ ▶) and the current choice in the middle:
  * the skin tone (5),
  * the hair: two braids, one braid, a bun, short, loose (and the hair colour, 4),
  * the hat: an embroidered skullcap (*тақия*), a fur-trimmed hat (*бөрік*), a headscarf, a felt hat, none,
  * the colour of the coat (*шапан*) and the dress (6 each: crimson, indigo, emerald, ochre, white, black).
* **The horse:**
  * the name (default: Тұлпар, the winged horse of the legends),
  * the coat colour: bay, chestnut, grey, black, dun, piebald,
  * the marking on the face: none, a star, a blaze,
  * the colour of the mane and the tail.
* **Random** mixes new looks, and **Ready!** goes on.
* The rider and the horse can be changed later at home, for free (section 8).

### The face overlay

The camera picture in the corner of the screen shows the player, mirrored, **dressed as her rider**: a face landmark detector finds the face, and the game draws the chosen hat, the braids, the earrings and other finery over it, so that they move and turn with the player's head.

* The overlay follows the head's position, size and tilt.
* The finery won at the end of a level (earrings, a hat with owl feathers, ...) also appears on the overlay.
* The overlay is also shown big in the character creator, so the player sees herself in her new looks before the first ride.
* If the face is lost for a moment, the overlay stays where it was and fades out after about 0.5 s.

### The view while riding

* **Top-down**, looking straight down at the steppe. The rider and her horse stay in the middle of the screen, and the steppe scrolls under them. The world doesn't rotate; the horse turns.
* **On the screen:**
  * the slots of the missing animals at the top (empty, following, home),
  * **the speed bar**: a horizontal bar with three horse icons along it, a horse walking at the left, a horse trotting in the middle and a horse galloping at the right. The bar fills from the left with the horse's speed, and the icon the fill has reached lights up and moves. This is how the player sees that squatting faster makes the horse go faster,
  * the small map in a corner,
  * the camera picture with the face overlay and the small figure in the other corner,
  * the edge icons of the animals the rider hears.
* **The conversations** open when the rider stops next to a person: the portrait, the greeting, and the clue with its pictures. The clue is drawn on the map at the same time. Riding on closes the conversation.
* **The landscape** has things to ride around: lakes, rivers (crossed only at fords), groves and fences. The horse slides along them and never gets stuck.

### The level select

A large painted map of the steppe around the home aul, with a small banner for each level, showing its number, its name and its stars. Finished levels can be replayed; finishing a level unlocks the next.

## 7. The game world in motion

* The grass moves in the wind, clouds drift across and cast shadows, birds (larks, eagles, swallows) fly up when the horse passes.
* Marmots stand by their burrows and dive in as you pass; they are decoration, not animals to gather.
* Smoke rises from the yurts.
* Day turns into evening slowly during a level, as a gentle sense of time, never a deadline.

## 8. Rewards: dressing the rider and her horse

At the end of each level, the rider chooses **one** new piece of finery for herself or her horse, and the picture of them at home grows more splendid level by level.

### How it works

* **A scene at home** shows the rider standing next to her horse in front of the yurt, wearing everything she has won so far.
* **The choice:** after a level, three pieces are offered, as big cards. The player picks one, and it is added to the picture with a small celebration (a sparkle, a short tune). More stars mean better pieces on offer.
* **Built up in steps:** many pieces come in steps, each building on the last. For example, the saddle goes from a plain leather saddle, to one with silver studs, to a carved and painted festive saddle. After ten levels, the rider and the horse are clearly transformed, and the player can see how each level contributed.
* **Wearing them:** in the wardrobe at home, the player chooses which of the pieces she has won to wear, at any time and for free. The rider and horse appear dressed that way while riding, in the face overlay, and in the level select.

### The pieces

**For the horse** (the *ер-тұрман*, the horse's tack):

* the saddle (*ер*): plain → with silver studs → carved and painted,
* the saddle cloth (*тоқым*): felt → embroidered → with tassels,
* the bridle (*жүген*): leather → with silver plates → with coloured tassels,
* the breastplate (*өмілдірік*) and the crupper (*құйысқан*), with silver ornaments,
* the stirrups (*үзеңгі*): iron → engraved silver,
* the mane: braided, with ribbons, with an owl-feather tassel (*үкі*) for good luck.

**For the rider:**

* the hat: an embroidered skullcap → a fur-trimmed hat → with owl feathers,
* the vest (*камзол*) and the coat (*шапан*): plain → embroidered with ornaments (the ram's-horn pattern, *қошқар мүйіз*),
* earrings (*сырға*), bracelets (*білезік*) and rings (*жүзік*), in silver,
* the belt with silver plates,
* boots with embroidered tops.

**For the home** (a small extra, only if there's room in the design): a new felt carpet (*сырмақ*), a decorated door of the yurt, a dombra hanging inside.

## 9. Saving

* The game remembers the language, the rider and the horse, the stars of each level, and the finery won and worn.
* Several players can share a computer: the start screen lists the riders, each with her name and picture, and "New rider".
* A level in progress is not saved: a level is short enough to finish in one go.

## 10. Languages and text

* **The languages:** English, Russian and Kazakh, all three from the first version. Kazakh is written in Cyrillic (the alphabet in use in schools today); a Latin-script Kazakh can be added later as its own language.
* **Adding a language** is one entry in the list of languages and one translation file. No code names a language.
* **The font** is a pixel font that must cover Latin, Russian Cyrillic and the Kazakh letters (ә, ғ, қ, ң, ө, ұ, ү, һ, і). Since pixel fonts with all the Kazakh letters are rare, we may have to draw the missing letters ourselves.
* **All the texts are in translation files** (one per language), from the very first screen. The clues are written once as patterns with placeholders ("I saw {animal} between {landmark_a} and {landmark_b}"), and the translators translate the patterns and the names of the animals and the landmarks.
* **Grammar in the patterns:** Russian needs the cases and the numbers ("две овцы", "пять овец", "у родника", "между кустами и родником"), and Kazakh the case endings ("бұлақтың жанында", "тасқа жақын"). So the names of the landmarks and the animals carry their forms in each case, and the patterns pick the right one. The rider is a girl, so the Russian texts which address her use the feminine ("ты нашла").
* **Kazakh words in the other languages:** some words stay Kazakh in all three languages, where they add colour and are explained by a picture (*әже*, *тақия*, *шапан*). The names of the tack keep their Kazakh name as a subtitle in the reward cards.
* **Proofreading:** the Russian and the Kazakh are reviewed by native speakers before release.
* **Short lines:** at most two short sentences per line, with pictures of the animals and the landmarks in the line.

## 11. Art and sound

### Art

* **Pixel art.** The whole game is pixel art: the steppe, the landmarks, the rider, the horse, the animals, the people, the portraits, the icons, the speed bar, the map and the interface.
  * The game renders at a low resolution (e.g., 480 × 270) and is scaled up by whole numbers with nearest-neighbour filtering, so that the pixels stay crisp on any screen.
  * One limited palette for the whole game, taken from the colours of the intro picture and the steppe: golden grass, sky blue, crimson, emerald, ochre, white felt and dark outlines.
  * **Top-down sprites:** the rider and the horse have sprites in 8 directions with walk, trot and gallop cycles; the animals in 8 directions with a walk and an idle (grazing) cycle. The pieces of finery (section 8) and the looks from the creator are separate sprite layers drawn over the base sprites, so that every combination works without drawing each one.
  * **The portraits** in the conversations and the preview in the creator are larger pixel-art pictures, in the same palette.
  * **The face overlay** draws the hat, the braids and the finery as pixel-art sprites over the camera picture, which is itself shown pixelated (at a low resolution, in the palette), so that it fits the game.
* **The intro screen** is the one exception: the painted intro picture stays painted, as the cover of the game, without its text (the title and the buttons are drawn by the game in a pixel font). Open question: should it be redrawn as pixel art, too?
* **The font** is a pixel font with Latin, Cyrillic and the Kazakh letters.
* **The ornaments** follow the traditional Kazakh patterns (*ою-өрнек*): the ram's horn, the wave, the four-pointed star. They frame the conversations, the reward cards and the map.
* **No text in the pictures** that the player has to read, since the game is translated. The intro picture is used without its text, and the game writes the title and the buttons on top.

### Sound

* **The steppe:** wind in the grass, larks, the hooves of the horse (walk, trot and gallop sound different), the creak of the saddle.
* **The animals:** each kind has a few calls, used both for hearing them from afar and when they follow.
* **The music:** gentle dombra and kobyz music, public domain or CC0 only, quiet in the background; a short celebration tune for the rewards.
* There are no voices.

# Software architecture

## 12. Technical outline

* **Godot 4 (.NET).** The vision is in C#; the game is in GDScript.
* **The vision** runs ONNX models on the CPU:
  * **a body pose model** with the standard 17 key points (the nose, the eyes, the ears, the shoulders, the elbows, the wrists, ...). From it we take the head (the nose and the ears) and the wrists.
  * **a face landmark model** for the overlay: it gives the outline of the face, the eyes and the forehead, from which we compute the position, the size and the tilt of the head.
* **New in C#, without any Godot dependency, so that it can be unit-tested:**
  * `SquatMeter`: from the vertical position of the head over time (smoothed), it finds the squats, their depth and their rate, and gives a speed in [0, 1].
  * `ReinClassifier`: from the head axis and the wrists, it gives the turn in [-1, 1] (negative to the left).
  * `FaceAnchor`: from the face landmarks, the anchor points of the overlay (the top of the head, the ears, the chin) and the tilt.
* **The scenes** (GDScript):
  * `intro`, `language_select`, `rider_select`,
  * `rider_creator` (with the on-screen keyboard),
  * `instruction`: the wordless animation,
  * `level_select`,
  * `level`: the steppe, the rider, the animals, the people, the pen,
  * `hearing`: the edge icons and the panned sounds,
  * `speed_bar`: the bar with the walking, trotting and galloping horse icons,
  * `minimap` and `map`,
  * `conversation`,
  * `camera_panel`: the camera picture with the face overlay and the hint figure,
  * `reward` and `wardrobe`,
  * `calibration`.
* **The data:**
  * `data/levels/<nn>_<id>/`: each level's map, landmarks, people, animals and clues, as typed Godot resources,
  * `data/finery/`: the pieces for the rider and the horse, with their steps,
  * `translations/`: `messages.pot`, `ru.po`, `kk.po`.
* **The tests:**
  * unit tests for `SquatMeter` and `ReinClassifier`, on recordings of real players,
  * a check of every level: each animal is covered by a clue, each clue points to exactly one area, and every animal is reachable,
  * a check that every text has a translation in Russian and Kazakh,
  * a headless run of a level in keyboard mode.
* **Performance:** the game must run on old school laptops with integrated graphics while the vision runs. The steppe that doesn't move is drawn once, and the grass and the water are shaders.
* There is no network access.

## 13. The first thing we build: the movement test

Before the game, a test scene with only the camera, the two detectors and the measurements on the screen: the head's height over time, the counted squats, the speed of a horse, the turn from the hands, and the face overlay with a single hat. We record players of about ten, and tune the thresholds on those recordings.

## 14. Open questions

1. **Only a girl?** The story is about a girl. Should the player also be able to choose a boy rider?
2. **Two players?** One player for now. A second player on a split screen (as a second rider) could come later.
3. **The menus:** is holding the cursor still for 1.5 s good enough, or should a fist be needed for a click?
4. **The clues on the map:** should a clue be drawn automatically on the map (as described above), or should the child remember it?
5. **Stars by time:** or no stars at all, so that there is no pressure?
6. **Kazakh in Latin script** as well as Cyrillic?
7. **The intro picture** has the text painted into it. We need a version without the text (and without the buttons), so that the game can write them in each language. And should it stay painted, or be redrawn as pixel art like the rest of the game?
