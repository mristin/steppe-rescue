# The Steppe Rescue: Design

**The Steppe Rescue is a riding and searching game for children of about seven-ten, played by doing squats in front of a webcam.**
You are a girl from a small aul (a village of yurts) in the steppe near Astana. The animals of the aul have wandered off: sheep, horses and camels. You ride out on your horse, ask the people you meet where they saw the animals, find them, and lead them home.
Nobody fights and nothing can hurt you. You win by riding, listening and being kind.
One child rides alone, or two ride together, side by side on a split screen, as friends who search for the same animals.

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
* **the pastures**, patches of green grass where the horse can graze (section 4, "Water and grass for the horse"),
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

1. **The briefing at home** (30 s). Grandmother says which animals are missing, and tells about every one of them: where she saw them herself, or else whom to ask, and where that person stands ("Shepherd near the big rock saw a sheep."). The people she names are ringed on the map until the rider has talked to them. Their pictures appear as empty slots at the top of the screen, e.g., ○○○ sheep, ○ camel.
2. **Riding out.** The rider leaves the aul. The level is a large steppe, many screens wide, seen from above.
3. **Asking.** The rider rides up to a yurt or a person and stops. The person tells her where they saw some of the animals.
4. **Searching and listening.** Following the clues, the rider rides towards the landmarks. When she comes near an animal, she hears it before she sees it.
5. **Gathering.** When she comes close enough, the animal joins her and follows.
6. **Bringing them home.** She can bring the animals home one by one or all at once. Each animal that enters the pen at the aul fills its slot.
7. **The end.** When all the slots are full, Grandmother thanks her, and the rider chooses her reward (section 8). After the thanks, a squat or the button OK (held with the hand, as in the menus) goes on; with two players, either rider can press it.

### The map

* The map of the level shows the landmarks, the yurts, the home aul and the rider, painted like a hand-drawn map on felt or paper. **It never shows the animals.**
* A small map sits in a corner of the screen. The player opens it large and closes it again with a key (C for now). Open question: a gesture to open it without the keyboard. The map is drawn smoothly at the resolution of the screen, not in the game's pixels: the landmarks, the yurts and the pen as their paintings seen from above, the people as round portraits, the clues as dashed areas with a card of their animals and how many, ticked once they are home, the rider as an arrow, and a compass rose.
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
* **The rings show it:** a lost animal on the screen has a dashed white ring around it, turning slowly, which marks how close the rider must come. While she stays inside, a red arc fills the ring, and when it is full, the animal joins. An animal which follows the rider has a soft green ring which pulses, so the player sees at a glance who follows her.
* **Horses are shy:** they join only if the rider comes slowly (the horse walking, not galloping). If she gallops at them, they trot away a little, and she can try again.
* **The followers** walk behind the rider in a loose line or herd. They keep up with a walk and a trot, but at a gallop the slow animals (sheep, camels) fall behind and call out; they never get lost, and they catch up when the rider slows down.
* **The pen.** At home, the animals run into the pen by themselves when the rider rides through the gate.

### Water and grass for the horse

The horse gets thirsty and hungry while it runs, so a ride is also about caring for it.

* **Two bars:** water and food, next to the speed bar, each with its picture (a drop of water and a tuft of grass). They empty slowly while the horse moves, faster at a gallop.
* **Too thirsty or too hungry:** when a bar is empty, the horse can only walk slowly, however fast the player squats. It never stops, so a child is never stuck.
* **Drinking:** the horse drinks by itself when the rider stands at fresh water: a river, a lake or a spring, but **not a salt lake**. The water bar fills while it drinks.
* **Eating:** the horse grazes by itself when the rider stands on a pasture, where the grass is green enough. The steppe elsewhere is too dry. The food bar fills while it eats.
* **Showing, not telling:** when a bar runs low, it blinks, and the horse shows it: a small bubble with a drop or a tuft of grass rises above it, it lowers its head and snorts. While it drinks or eats, the bar fills visibly and the horse dips its head.
* **On the map:** the water is blue already; the pastures are marked in green, so the player can plan where to rest.
* The levels place the water and the pastures so that a careful rider never runs dry; the later levels space them out more.

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

**Built:** all ten levels, in `data/levels/` (2200 x 1600 pixels in level 2, growing to 3600 x 2600 in level 10, with the grandmother, a shepherd and a beekeeper giving the clues). The Esil of level 6 flows across the whole steppe (`River`, `data/landmarks/river.tres`): the painted stretch of the river repeated along it, with the painted ford at each of its two fords, the only places where the horse crosses; the horse drinks on its banks, and the small map shows it as a band broken by the fords. The salt lake of level 7 is the painted lake made milky with a crust of salt (`assets/pictures/landmarks/salt_lake.png`, `data/landmarks/salt_lake.tres`); the horse does not drink there. The two-step clues of level 8 are told in words: the grandmother sends the rider to the shepherd at the well, who sends her on to the beekeeper by the birch grove. The tests check every level (`LevelMap.problems`), and that everything in it can be reached from the start.

### Stars

Each level gives one to three stars, for being reasonably fast. There is never a "game over": the level only ends when all the animals are home. Stars only change which rewards are offered (section 8), and any level can be replayed, for better stars, but a level gives its gift only once, so that riding it again is no mine of finery.

## 5. Controls: squats and reaching across

### The exercise

The player stands facing the camera, about 2 to 3 m away, so that the camera sees the whole upper body. The camera has to see the head and the hands.

### Speed: squats

* **The horse goes as fast as the player squats.** We follow the height of her eyes. Her head goes down and up in swings; a swing counts once the head turned back by a quarter of the player's unit (the unit is 4.4 distances between her eyes, about the width of her shoulders, followed slowly, so that it does not matter how close to the camera she stands). Each down-and-up is one squat. There is no standing height to compare with: squatting fast, players bounce up higher than they stand.
* **The effort sets the speed:** every swing adds its size to the effort, which fades over about 1.5 s; the effort is how far her head travels up and down per second. Deeper squats and faster squats both make the horse faster. On the recordings of a player (`dev/squats/`, replayed in the tests):

  | Squatting | The effort (units per second) | The horse |
  |---|---|---|
  | none (standing still) | 0 | stops about 2 s after her last squat |
  | calm (a squat every 1.3 to 1.7 s, 0.5 to 0.7 deep) | 0.6 to 1.1 | walks |
  | brisk (every 1 to 1.2 s, about 0.8 deep) | 1.15 to 1.8 | trots |
  | fast (every 0.8 to 0.9 s, about 0.9 deep, bouncing) | from 1.8 | gallops |

  The horse runs at full speed at an effort of 2.5. A slow squat (up to about 3.5 s) keeps the horse going: while the head is down, the horse waits up to 2 s for it to come up.

* **A tiny nod does nothing:** it is smaller than the quarter of the unit.
* **Gentle changes.** The horse speeds up over about a quarter of a second and slows down a little faster, so that it stops promptly once no swing came for a second; it never stops instantly, except with the brake.
* **The line in the camera picture** shows how far down the eyes must go in a squat: a swing below her usual height (each squat's top moves the usual height a little, and standing still, it follows her head, e.g., after she stepped closer). It is gold with an arrow down, and green while her eyes are below it. It moves slowly, so that it does not jump from squat to squat.
* **Jumps:** a jump counts when the eyes rise 0.65 units above the height where the player stands still (on a recording, a gallop bounced up to 0.46 above it, and jumps rose 0.86 and more); the next counts once she came back down. A light blue dashed line with an arrow up shows the height in the camera picture and turns gold during a jump, and the small figure jumps (painted, `assets/pictures/girl/jump_*.png`). The tops of the squats do not move this height, so that bouncing in a gallop does not lift the line. The player's head may leave the top of the picture in a jump, so she should stand far enough from the camera. On the keyboard, J jumps (keypad 0 for the second player).
* **The horse jumps** when the player jumps (`Rider.jump`, the painted frames from above in `assets/pictures/top_down/horses/<n>/jump_*.png`): it keeps its speed and heading in the air, so a jump from a gallop flies longer (about 0.95 s against 0.55 s from a walk) and much farther; the horse and the girl grow nearer to us as they fly, and their shadow stays on the ground. A rearing horse does not jump.
* **A creek** (`Creek`, in "Grandmother's camel" and "The foals") runs across the steppe without a ford: the horse crosses it only by jumping, and Grandmother says so. A jump from a trot or a gallop carries it over; one from a stand or a walk falls short, splashes, and leaves the horse on the bank it jumped from. At the creek, the small figure shows the jump (not the turn). After two jumps which fell short, every jump carries the horse over, so that a child who can not jump high or run up is never stuck.
* **Settling at a new height:** a head which stays down longer than the slowest squat (2 s) is no squat: the player stands at a new height (she settled into her stance, or stepped closer), and the swings start from there.
* The horse never goes backwards, and a child is never stuck.

### The brake: both hands above the head

* **Both hands up above the head** stop the horse at once, and it stands until the next squat, which starts a walk again. A walking or trotting horse simply halts, as a real horse does within a stride or two; only a galloping horse, stopped hard, rears up on its hind legs, its front legs in the air, for about 1.4 s. (A real horse stops from a gallop over a few strides and does not rear to stop; it rears from fear or excitement, which a hard stop at speed can provoke. The rearing is the game's dramatic sign of the hard stop.)
* Both hands must be clearly above the head (0.4 of the width of the shoulders above the eyes) for 0.15 s, so that a hand brushing the hair does not brake; one hand up does nothing.
* It is the way to stop quickly, e.g., next to a person or a lost animal; the horse also stops by itself when the player stands still.
* Down on the keyboard brakes, too.
* **The pictures:** the painted girl raising both hands above her head (`assets/pictures/girl/hands_up_*.png`), the bay horse rearing up from the side in five frames (`assets/pictures/horse/rear_*.png`), in How to Play, and each of the four horses rearing up seen from above (`assets/pictures/top_down/horses/<preset>/rear.png`), in the level.

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

In the level, the game never writes "do squats" or "pull the reins". It shows the movement and lets the player discover the rest; only the instruction says it in one short line under the animation.

* **The instruction** (section 6) is an animation with one short line of text for each part: the rider gets off the horse, does squats next to it, and the horse starts walking, then trotting, then galloping. Then she pulls the reins with both hands to the left, and the horse turns left; then to the right, and it turns right. Then she gallops off again and jumps, and the horse, seen from above, jumps with her over a creek, twice. Last, she raises both hands above her head: the horse rears up and stops at once. Both hands to one side is the natural way to turn: the hand which crosses the axis of the head turns the horse, the other stays on its own side.
* **The HUD never covers the rider.** Every piece of it (the conversation, the camera picture with the small figure, the missing animals, the map, the speed bar, the water and the food, the status of the camera) has its home on the screen; when the rider comes near a piece, at the edges of the steppe where the view no longer keeps her in its middle, the piece glides to the nearest free spot at the edges of the screen (a corner, the middle of an edge, or its home mirrored), and back home once she is clearly away (`HudLayout`). The conversation and the button OK stay where they open, and the other pieces make room for them.
* **The camera picture** in a corner of the screen (with one player, the bottom right) shows the player herself, with her chosen hat and braids drawn over her face (section 6). Next to it, a small figure of the rider does what the game measures of the player while the camera sees her, so that she sees at once whether her squat was seen; without the camera, it does the movement the game is waiting for.
* **When the horse stands still** for a few seconds, the figure squats slowly and invitingly, and the horse looks back at the player and stamps a hoof.
* **The speed bar** (section 6) fills with each squat and empties when the player stops, so the link between squatting and speed is visible at a glance.
* **The horse's movement echoes the player's:** each squat is visible as one stride, and the rider's figure on the horse bobs up and down in time with the player's squats.
* **A hint for turning** appears only when the rider rides off the map edge or into the same obstacle twice: a ghostly arm reaching across, with a curved arrow.

### Menus: the hand cursor

* In the menus, the conversations and the character creator, every raised hand moves its own cursor (a big bird, easy to see from two metres away); a bird held still on a button for 3 s clicks it, whichever hand it belongs to. The hand comes from the hand detector (YOLOX, the same run which finds the heads for the face overlay), which runs on every frame while a menu shows the bird, as in Bird Dog; the hand is smoothed with a 1€ filter. The pose only tells where the shoulders are: the bottom of the screen lies at the shoulders, and a hand resting lower does not count.
* **The player sees herself:** behind the buttons, the camera picture shows dimly, mirrored, so that her hand in the picture lies right under the bird.
* **Sticky buttons:** a bird on a button is drawn towards its middle and leaves only when the hand moves clearly beyond the edge, since the hands of children are hard to hold still; it glides instead of jumping.
* **Clicking:** holding the cursor still over a button for about 3 s fills a ring around it, and then the button clicks. Hovering grows the button.
* The buttons are big, with at most four on a screen.

### Fallbacks

* **Keyboard** for development and testing: Space or ↑ is one squat (tapping faster makes the horse faster), ← and → turn, ↓ brakes. With two players, the first rides with W (or Space), A, D and S, and the second with the arrows.
* **Mouse** in the menus.
* Without a camera, the game offers the keyboard mode.

### Safety

* The instruction shows good squats: the feet shoulder-width apart, the knees over the toes, the back straight, and not lower than the thighs level with the floor.
* After each level, there is a natural rest (the reward screen).
* Clear space: the game asks for a free space of about 2 × 2 m around the player before the first level.

## 6. Screens

### The flow

1. **The intro screen:** the painting of the rider and her horse, with the title "The Steppe Rescue" and "Find the lost animals and bring them home!" painted in, and the buttons Play, Levels, Settings and How to Play. The buttons are drawn by the game, so they can be translated; the painted title stays in English (open question 7).
2. **Choose the language:** English, Русский, Қазақша, as three big cards with the name of each language in itself (no flags). The choice is remembered.
3. **One or two riders?** (for a new journey; see "Two players" below), and **create the rider and the horse** of every player (once for each journey).
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

The camera picture in the corner of the screen shows the player, mirrored, **dressed as her rider**: a face landmark detector finds the face, and the game draws the chosen hat, the braids, the earrings and other finery over it, so that they move and turn with the player's head. Her body wears the rider's painted coat, sleeves and boots, warped along her shoulders, elbows, hands, hips, knees and ankles (each sleeve runs as one strip along a smooth curve through the shoulder, the elbow and the hand, so that it bends softly, comes out from under the coat at the shoulder, which it rounds, and stays in front of the coat when the arm reaches across the body) (`PaintedBody`; drawn in the colors of the looks for a rider without paintings); a painted fist sits on each hand which the detector sees, holding the braided rein: hanging low, held in front of the chest, or raised above the shoulders, as high as the hand is, its wrist turned towards the elbow, which sags between her fists and is pulled straight when she turns. The sleeves reach to her fists, so that every child sees which hands are hers (the movement test also marks each hand with its player and side, e.g., "1L").

* The overlay follows the head's position, size and tilt.
* The finery won at the end of a level (earrings, a hat with owl feathers, ...) also appears on the overlay.
* The overlay is also shown big in the character creator, so the player sees herself in her new looks before the first ride.
* If the face is lost for a moment, the overlay stays where it was and fades out after about 0.5 s.

### The view while riding

* **Top-down**, looking straight down at the steppe. The rider and her horse stay in the middle of the screen, and the steppe scrolls under them. The world doesn't rotate; the horse turns.
* **On the screen:**
  * the slots of the missing animals at the top (empty, following, home),
  * **the speed bar**: a horizontal bar with three horse icons along it, a horse walking at the left, a horse trotting in the middle and a horse galloping at the right. The bar fills from the left with the horse's speed, and the icon the fill has reached lights up and moves. This is how the player sees that squatting faster makes the horse go faster,
  * the water and food bars of the horse, next to the speed bar (section 4),
  * the small map in a corner,
  * the camera picture with the face overlay and the small figure in the other corner,
  * the edge icons of the animals the rider hears.
* **The conversations** open when the rider stops next to a person: the portrait, the greeting, and the clue with its pictures. The clue is drawn on the map at the same time. Riding on closes the conversation. A long talk (Grandmother's, with everyone to ask) comes in pages short enough to stay above the rider, with a dot for each page; a squat turns the page, and the squat on the last page closes it.
* **The landscape** has things to ride around: lakes, rivers (crossed only at fords), groves and fences. The horse slides along them and never gets stuck.

### Two players

Two children can ride together, as in Bird Dog and Ergo Chaos. **It is a game of friends, not a race:** they search for the same animals, and the mission is over when all the animals are home, whoever brought them.

* **How many:** a new journey asks "How many riders?" right after its name, with two big cards, "1 · One rider" and "2 · Two riders" (`scenes/player_count/`). The journey keeps the answer; a journey of one player stays one, and two stay two.
* **The camera** is split down the middle: the player on the left of the mirrored picture is the first player, the one on the right the second (`PlayerSplit` in C#). Each has her own squats, reins, brake and face overlay; in her half, the vision follows the person closest to the camera.
* **Each her own rider:** the players create their riders one after the other, each on the whole screen ("Player 1", "Player 2"), with the hand cursor of her own half of the camera picture. **They never ride the same:** the painted rider and the painted horse which the first player chose are dim in the creator of the second, with the first player's name on the rider, and can not be chosen (nor by Random). The second rider is called Dana and her horse Zhuldyz (Жұлдыз, "star") by default.
* **Each her own wardrobe:** each rider wins her own finery and chooses what she wears. At the end of a level, each player chooses her own gift, one after the other, at her own home; the level has given its gifts once both chose. The settings open the wardrobe of each rider.
* **The split screen** in the level: each player has a half of the screen (480 × 540), as in Bird Dog. Two SubViewports show the one steppe (they share its World2D), each following its own rider (`LevelPlayer`). Each half has its own small map (in its outer top corner, showing the partner in indigo), speed bar, water and food, the edge icons of what *she* hears, and the warning at the edge of the steppe. The slots of the animals, shared, stay at the top in the middle, and the camera picture sits at the bottom in the middle, with a line down its middle; the small figure of each player stands on her side of it. The panels of the right half are mirrored.
* **The conversations are separate:** a rider who stops next to a person talks to them in her own half, by her own name, and her own squat closes it; the other rider rides on meanwhile. Grandmother sends both out at the start and thanks each by her name at the end. What a person tells goes on the maps of both, since they search together.
* **The animals** join the rider who stays near them and follow her; each rider brings her own followers home. A galloping rider scares the shy horses, whichever rider she is.
* **The stars** are shared: the time runs from the first stride of either rider.

### The level select

A large painted map of the steppe around the home aul, with the numbered spot of each level along the path, and the list of all the levels at its side, each with its number, its name and its stars; the levels not open yet are listed, too, dim and with a lock. Finished levels can be replayed; finishing a level unlocks the next. Levels first asks for the journey (once each start), so that the map shows the progress of the journey which rides.

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

* **Journeys** (sessions, like the voyages of Bird Dog): a journey is one playthrough with its name, how many players ride (1 or 2), the rider and her horse of each player with her own finery won and worn, the stars of each level, and the levels whose gifts were chosen. The players keep as many journeys as they like, so several children can share a computer, and a class can start afresh.
* **Choosing:** on the way from Play (once each start), "Your journeys" offers **Continue** the last journey (it shows its name, its rider and her stars), **+ New journey**, and the three other most recent journeys; Change rider opens the creator for the rider of the current one. **Delete** removes a journey for good, in three steps, so that a hand resting on the screen never deletes one by chance: Delete, then the card of the journey, then Delete again in the question (or Keep). The settings open the same screen. Without any journey, Play goes straight to naming the first one.
* **Naming:** a new journey is named first; the name starts as the date and the time (e.g., "2026-11-10 14:05"), so that OK is enough, and the first key replaces it. The big keys on the screen have the letters of the language, the digits, "-", ":" and a space. Then the players choose whether one or two ride, and their riders are created.
* **The files:** every journey is JSON in `user://saves/<id>.json`, with a format version (so that later versions can convert old saves), the name, the times it was created and updated, the number of players, the riders (each with her finery) and the progress. Format 1 had a single rider with her finery in the progress; it is read as a journey of one player. The id is the date and the time of its creation. A save is written to a temporary file first and then renamed, so that a crash never destroys the last good save; it is written whenever something changes. `user://settings.cfg` keeps the language and the last journey. The riders of the older versions, kept in the settings, became journeys once.
* The language is remembered for the computer, not per journey.
* A level in progress is not saved: a level is short enough to finish in one go.

## 10. Languages and text

* **The languages:** English, Russian and Kazakh, all three from the first version. Kazakh is written in Cyrillic (the alphabet in use in schools today); a Latin-script Kazakh can be added later as its own language.
* **Adding a language** is one entry in the list of languages and one translation file. No code names a language.
* **The font** is a pixel font that must cover Latin, Russian Cyrillic and the Kazakh letters (ә, ғ, қ, ң, ө, ұ, ү, һ, і). Pixel fonts with all the Kazakh letters are rare: we use GNU Unifont (SIL Open Font License) at 16 pixels, and a test checks that it has every letter of every translation.
* **All the texts are in translation files** (one per language), from the very first screen. The clues are written once as patterns with placeholders ("I saw {animal} between {landmark_a} and {landmark_b}"), and the translators translate the patterns and the names of the animals and the landmarks.
* **Grammar in the patterns:** Russian needs the cases and the numbers ("две овцы", "пять овец", "у родника", "между кустами и родником"), and Kazakh the case endings ("бұлақтың жанында", "тасқа жақын"). So the names of the landmarks and the animals carry their forms in each case, and the patterns pick the right one. The rider is a girl, so the Russian texts which address her use the feminine ("ты нашла").
* **Kazakh words in the other languages:** some words stay Kazakh in all three languages, where they add colour and are explained by a picture (*әже*, *тақия*, *шапан*). The names of the tack keep their Kazakh name as a subtitle in the reward cards.
* **Proofreading:** the Russian and the Kazakh are reviewed by native speakers before release.
* **Short lines:** at most two short sentences per line, with pictures of the animals and the landmarks in the line.

## 11. Art and sound

### Art

* **Pixel art.** The whole game is pixel art: the steppe, the landmarks, the rider, the horse, the animals, the people, the portraits, the icons, the speed bar, the map and the interface.
  * The game lays out its screens in 960 × 540 logical pixels and draws them at 1920 × 1080, two pixels of the screen per logical pixel, so the pixel art has the fine pixels of a 1080p screen: a portrait is 128 × 128 pixels. The picture is scaled by whole numbers with nearest-neighbour filtering, so that the pixels stay crisp. (We started at 640 × 360, then 960 × 540, but the pixels were too coarse to draw the people and the ornaments well. On the 1366 × 768 screens of many school laptops, the game is shown at 960 × 540, with a border.)
  * **Vectors first, then pixels.** Every picture which the game draws (the rider and her horse, the animals, the people, the landmarks, the icons, the ornaments, the intro picture) is first drawn as vectors (SVG), with the shading in three shades of each color, and then pixelated at the size it is shown: each pixel takes the palette color of most of its 3 × 3 samples, and the dark outline goes around. So a picture shown bigger gets more pixels, not bigger ones, and only the colors of the palette appear. The photographs (the portraits) are the exception: they stay photographs, pixelized in the palette, and are never traced into vectors.
  * One limited palette for the whole game, taken from the colours of the intro picture and the steppe: golden grass, sky blue, crimson, emerald, ochre, white felt and dark outlines.
  * **Top-down sprites:** the rider and the horse have sprites in 8 directions with walk, trot and gallop cycles; the animals in 8 directions with a walk and an idle (grazing) cycle. The pieces of finery (section 8) and the looks from the creator are separate sprite layers drawn over the base sprites, so that every combination works without drawing each one.
  * **The portraits** in the conversations and the preview in the creator are larger pixel-art pictures, in the same palette.
  * **The face overlay** draws the hat, the braids and the finery as pixel-art sprites over the camera picture, which is itself shown pixelated (at a low resolution, in the palette), so that it fits the game.
* **The intro screen** is a painting (`assets/pictures/intro/painting.png`): the rider on her bay horse in the steppe near Astana, with the city and the Bayterek on the horizon, the yurts and the swallows. It is the one picture which is not pixel art; it is shown as painted, at the resolution of the screen. The default looks of the rider are those of the painted girl. The buttons are drawn by the game in the pixel font, so that they can be translated.
* **The font** is a pixel font with Latin, Cyrillic and the Kazakh letters (GNU Unifont, section 10).
* **The ornaments** follow the traditional Kazakh patterns (*ою-өрнек*): the ram's horn, the wave, the four-pointed star. They frame the conversations, the reward cards and the map.
* **No text in the pictures** that the player has to read, since the game is translated. The intro picture is used without its text, and the game writes the title and the buttons on top.

### Sound

* **The steppe:** wind in the grass, larks, the hooves of the horse (walk, trot and gallop sound different), the creak of the saddle.
* **The animals:** each kind has a few calls, used both for hearing them from afar and when they follow.
* **The music:** gentle dombra and kobyz music, public domain or CC0 only, quiet in the background; a short celebration tune for the rewards.
* There are no voices.

# Software architecture

## 12. Technical outline

* **Godot 4.6 (.NET)**, with the Compatibility renderer (OpenGL), which suits the old school laptops. The vision is in C#; the game is in GDScript.
* **The vision** runs ONNX models on the CPU:
  * **a head and hand detector**: YOLOX-Body-Head-Hand nano (Apache-2.0) at 320x256, on every camera frame, with the face landmarks (YuNet) in each head. The squats follow the head (the eyes; the head box when the face is lost, e.g., looking down in a deep squat), and the reins and the brake follow the hands, on every frame.
  * **a body pose model** with the standard 17 key points (the nose, the eyes, the ears, the shoulders, the elbows, the wrists, ...): RTMO-t of MMPose (Apache-2.0). It is too slow on a school laptop to follow the movements, so it only tells which head and which hands are whose, and the left hand from the right one (which the turning needs), and dresses the body. It runs as often as the computer manages while the faces and the hands keep up with the camera (`PoseScheduler`): from four to twenty times a second, faster while the face tracker stays within its frame, and at once slower when it falls behind; the status line shows the rate. Without the face models, it does it all, as often as it can.
  * **a face landmark model** for the overlay: YuNet (MIT), run on a small crop around the head the detector found. It gives the eyes, the nose and the corners of the mouth, from which we compute the position, the size and the tilt of the head.
* **New in C#, without any Godot dependency, so that it can be unit-tested:**
  * `HeadGauge`: the height of the head and the unit of length of the player from the face tracker (the eyes and their distance; the head box, calibrated against them, when the face is lost).
  * `HandTracker`: follows the hands of the detector from frame to frame; whenever a pose comes, it matches its wrists to the hands of the same frame, which tells whose hand each is and which, and follows them again up to now.
  * `BodyFollower`: the body of the last pose, moved with the head between the poses (the shoulders and the hips fully down and up but only halfway sideways, since a turned head does not move the shoulders; the knees halfway, the feet not), with the hands of the `HandTracker`, for dressing the body. Each elbow keeps its place in the arm (how far along the line from the shoulder to the hand, and how far off it), averaged over the poses, so that it neither jumps with the jitter of the pose nor flips sides when the arm is straight; a big change, the arm bending, is followed quickly. Every joint, and the hands in the picture, are smoothed with a 1€ filter (`OneEuroFilter`, in the unit of the player): a still body much, so that it does not jitter, a moving one little, so that it does not lag; the elbows, which jitter most, are smoothed most. The riding takes the hands as they are, to stay quick.
  * `SquatMeter`: from the height of the head over time, it finds the swings and the squats, sums their sizes into the effort, and gives a speed in [0, 1], the gait, and the line which shows how far down the head must go. The keyboard adds the effort of a squat per key.
  * `Reins`: from the head axis and the hands, it gives the turn in [-1, 1] (negative to the left).
  * `FaceTracker`: the head detector and the face landmarks together, on every frame. Once it found the face, it follows it with the face landmarks alone in a crop around where it was (about 3 ms instead of 25 ms), and runs the head detector only when the face is lost and four times a second, to check that it still follows the player's head.
  * `FaceAnchor`: from the face landmarks, the anchor of the overlay (the point between the eyes, the distance between the eyes, and the tilt), smoothed, held briefly and faded out when the face is lost.
  * `VisionService` (the only part which depends on Godot) runs the camera, the pose on one background thread and the face on another, and offers plain getters to GDScript, each for one player (with two players, `PlayerSplit` gives each her half of the picture, and `FaceTracker` follows a face in each half).
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
  * `data/levels/<nn>_<id>.tscn`: each level as a scene of data nodes (the landmarks, the people with their clues, the herds of lost animals, the pen at home and the start), so that it can be edited in the Godot editor,
  * `data/landmarks/` and `data/animals/`: the kinds of the landmarks and the animals, with their names; the names of the landmarks carry their grammatical forms in the translations (section 10),
  * `data/finery/`: the pieces for the rider and the horse, with their steps,
  * `translations/`: `messages.pot`, `ru.po`, `kk.po`.
* **The tests:**
  * unit tests for `SquatMeter` and `Reins`, on synthetic movements now and on recordings of real players later, and of the models on a test photo,
  * a check of every level: each animal is covered by a clue, each clue points to exactly one area, and every animal is reachable,
  * a check that every text has a translation in Russian and Kazakh,
  * a headless run of a level in keyboard mode.
* **Performance:** the game must run on old school laptops with integrated graphics while the vision runs. The steppe that doesn't move is drawn once, and the grass and the water are shaders.
* There is no network access.

## 13. The first thing we build: the movement test

Before the game, a test scene with only the camera, the two detectors and the measurements on the screen: the head's height over time, the counted squats, the speed of a horse, the turn from the hands, and the face overlay with a single hat. We record players of seven to ten, and tune the thresholds on those recordings.

**Built** (`scenes/movement_test/`): the mirrored camera picture with the skeleton, the axis of the head, the hands (red when across) and the embroidered skullcap over the face; the speed bar with the three horse icons; the turn gauge; and the depth of the squats over the last 8 seconds, with the counted squats marked. The keyboard plays without a camera. The thresholds are first guesses and wait for the play-tests:

* the squats follow section 5, "Speed: squats" (`SquatMeter`): a swing of the head counts from a quarter of the unit, and the effort (how far the head travels per second) sets the speed; the constants were tuned on a recording of a player at a walk, a trot and a gallop (`dev/squats/record_squats.gd`, `dev/squats/analyze.py`), which the tests replay; on the keyboard, a key every 2 s walks, every second trots and twice a second gallops; both hands above the head brake, and the horse rears up (`Brake`, `Rider.rear`),
* a hand starts to turn at 0.1 of the width of the shoulders across the axis of the head, and turns fully at 0.6.

## 14. The second thing we build: the first level

The tutorial level, "The lamb by the spring" (section 4), to test the whole loop of the game with the camera.

**Built** (`scenes/level/`, the main scene for now, with the level in `data/levels/01_the_lamb_by_the_spring.tscn`): Grandmother sends the rider out and gives the clue; the steppe scrolls under the rider, who rides with the squats and the hands; the lamb grazes near the spring, is heard at the edge of the screen when it is off the screen, joins the rider who stays next to it for a second, follows her, and runs into the pen when she rides up to the gate; Grandmother thanks her with one to three stars. The slots of the animals are at the top, the speed bar and the camera picture at the bottom, the small map in a corner opens large with C, and the clue is drawn on it. Escape quits on the second press. Not yet: the sounds and the rewards.

## 15. The third thing we build: water and food, and the screens before the level

**Built:**

* **Water and food for the horse** (section 4, `scenes/level/horse_needs.gd`, `scenes/needs_bars/`): the two bars next to the speed bar empty while the horse runs, faster at a gallop; an empty bar makes the horse walk slowly, but never stop. The horse drinks while it stands at a spring or a lake (`fresh_water` of the landmark kind), and grazes while it stands on a pasture (`data/landmarks/pasture.tres`). A low bar blinks, and a bubble with a drop or a tuft of grass rises above the horse. The pastures are green on the map. Every level must have fresh water and a pasture (`LevelMap.problems()`).
* **The screens before the level** (section 6): the intro (`scenes/intro/`, the main scene) with Play, Levels, How to Play and Settings; the choice of the language (`scenes/language_select/`), the first time; and the creator of the rider and her horse (`scenes/rider_creator/`), the first time, with the names written on the keyboard or on the big keys of the alphabet of the language, a row with arrows for each look, Random and Ready!. The language and the rider are saved (`scenes/profile/`); the level greets the rider by her name, and she rides in her looks.
* **The instruction** (sections 5 and 6, `scenes/instruction/`), the first time on the way from Play, and from How to Play: without words, the rider gets off her horse into a frame like the camera picture, squats slowly, steadily and briskly with good form, and the horse walks, trots and gallops, with the speed bar under it; then she reaches across with her right hand, and the horse, seen from above, turns left under a curved arrow. It repeats until Ready!.
* **The level select** (section 6, `scenes/level_select/`): the painted map of the steppe around the home aul, with the rider by the yurts and the path from the aul past the spots of the levels; the list of all the levels at the left shows the number, the name and the stars of each, and pointing at a row rings its spot on the map; the next level is crimson; the levels not open yet are dim, with a lock, and a stone on their spot. A level is played only in a journey where it is open (a level chosen before the journey leads to the level select of the chosen one). The levels are the scenes of `data/levels/` in the order of their names (`LevelList`); finishing a level keeps its best stars and opens the next one. Play goes to the next level not finished yet, or to the level select once all are; after Grandmother's thanks, a squat goes on to the level select (until the reward screen is built).
* **The settings** (`scenes/settings/`): the language and the rider with her horse, next to the big camera picture with the face overlay, so that the player can check that the camera sees her (without a camera, her rider stands there).
* **The face overlay** (section 6, `FrontView`): the hat, the hair (two braids, one braid, a bun, short, loose, in her hair colour) and the finery the rider wears from the start, the earrings (*сырға*) and the owl feathers (*үкі*) on the *тақия*, follow the head in the camera picture.
* **The hand cursor** (section 5, `scenes/menu/`): the raised hand moves a bird; holding it still over a button for 3 s fills a ring around the button and clicks it. The mouse clicks, too.
* **The art at 1920 × 1080, vectors first** (section 11, `scenes/pixel/`): the pictures are SVG, pixelated by `Pixelate` with the help of `PixelQuantizer` in C#; the rider and her horse are drawn from the side in all their looks (`SideView`), with the ornaments (`Ornaments`); the portraits are 128 × 128; Grandmother's portrait is retouched into a gentle smile.

**Not yet:** see section 16.

## 16. The fourth thing we build: the rewards and the living steppe

**Built:**

* **The finery** (section 8, `Finery` in `scenes/profile/finery.gd`): twelve pieces in steps, eighteen steps in all. For the horse: the saddle (silver studs, then carved and painted), the saddle cloth (embroidered, then with tassels), the bridle (silver plates, then coloured tassels), the breastplate, the silver stirrups, and the mane (braided, with ribbons, then the owl-feather tassel). For the rider: the owl feathers on her hat, the coat (gold trims, then the ram's horn), the earrings, the bracelets, the belt with silver plates and the embroidered boots. The rider starts plain (a plain leather saddle, a plain belt and boots, no earrings, no feathers) and grows more splendid level by level. The finery is drawn wherever she is: from the side (`SideView`), from the front (`FrontView`: the overlay and the figure), on the intro, in the creator, on the level select and in the speed bar. The profile keeps it.
* **The reward** (section 8, `scenes/reward/`): after Grandmother's thanks, a squat leads home, where the rider stands next to her horse in front of the yurts, in all her finery. Three pieces are offered on big cards, each a close-up of the piece on her own horse or on her, with its name and the Kazakh word under it. Two or three stars offer the higher steps first, one star the first steps. The chosen piece joins the picture with a burst of golden stars, and Go on leads to the level select. Once everything is won, nothing more is offered.
* **The face overlay big in the creator** (section 6): while the camera runs, the creator shows the player big in the camera picture, dressed in the looks as she chooses them.
* **The small figure** (section 5, `scenes/level/coach.gd`) next to the camera picture in the level. While the camera sees the player, it follows her frame by frame: it goes as deep as her head goes down (standing, going down, deep, the deepest), pulls the reins as she does, and raises its hands while she brakes; after the edge of the steppe, the curved arrow still shows which way to pull. Without the camera, it stands and echoes each squat of the player. It squats slowly and invitingly when the horse has stood still for 3 s, or when a conversation waits for a squat to close it. It reaches across her head under a curved arrow after the rider ran into the edge of the steppe.
* **The free space** (section 5, `scenes/free_space/`): before the first level of each start, while the camera is on, the game asks for room. The rider squats and reaches across on a square of floor marked 2 m × 2 m, with one short line of text.
* **The wild animals** (section 7, `scenes/level/wildlife.gd`, `wild_shapes.gd`), decoration, not animals to gather:
  * herds of saigas (*ақбөкен*) and roe deer, hares (which run in zigzags), corsac foxes and swarms of locusts (*саранша*) graze and run or hop away from the rider who comes near, from farther the faster she rides;
  * the marmots stand by their burrows, dive in as she passes and peek out again after she has left;
  * the larks fly up from the grass and land farther on;
  * the golden eagles (150 to 220 px up) and the saker falcons (100 to 160 px) circle high above, and two small flocks of swallows (25 to 60 px) dart around the steppe on their own, in wide random arcs; each bird rises and sinks slowly, and the higher it flies, the farther and fainter its shadow on the ground, and the bigger the bird (nearer to us, looking from above).
  * They are drawn from above in 16 headings, and only those on the screen.

**Built since, too:**

* **The wardrobe** (section 8, `scenes/wardrobe/`): at home, the rider and her horse stand in a golden light (the home around them is dimmed), dressed as she chooses; on the right, the panel "Wearing" holds a golden card for each piece she wears, and the panel "Not wearing" one for each piece she won but took off; pressing a card moves the piece to the other panel, for free. It opens from the reward and from the settings; what she wears shows over her face in the camera picture and, for the home, at home.
* **The sounds** (section 11, the autoload `Sounds`), all synthesized in code, so the game has no sound files and needs no licenses for them: the melody of "Көзімнің қарасы" by Abai (1845–1904, in the public domain) plucked on a synthesized dombra (Karplus-Strong) over a soft strum of its open strings, looping quietly (`dev/music/kozimnin_karasi.py` also writes it as `assets/music/kozimnin_karasi.mid`); the celebration tune at the end of a level and when a gift is chosen; a chime when an animal joins; a click on the buttons; the hooves in step with the horse, louder at a gallop; the stamp of the impatient horse; and the wind of the steppe in the level. The settings switch them on and off.
* **The decorations of the home** (section 8): the felt carpet (*сырмақ*), the carved door and the dombra are pieces of the finery, shown at home in front of the yurt once won. They are offered only once their pictures exist (`assets/pictures/finery/carpet_1.png`, `door_1.png`, `dombra_1.png`).
* **The impatient horse** (section 5): when the horse has stood still for 3 s, it turns its head back to the player and stamps a hoof every 2 s, with a thud and a little dust.
* **The dust** (`GallopDust`, `scenes/level/dust.gdshader`): a galloping horse raises dust behind it, in billowing clouds drawn by a shader (lit from the top left, with their shadow on the ground, swelling and fading into wisps), puffs kicked up at each stride from one hind hoof after the other, and fine grit; a trot raises only a few small puffs, and a jump none.
* **The hint for turning** (section 5) shows also when the rider runs into the same obstacle a second time: the small figure pulls the reins under a curved arrow.
* **The wild animals** are paintings (see below).

* **The journeys** (section 9, `scenes/sessions/`, `scenes/session_name/`, `Profile`): each journey has its own name, rider, stars, finery and progress, saved as JSON; Play first asks which journey goes on (once each start), and a new journey is named, then its rider is created; a journey can be deleted, after a question.
* **The finery on the painted rider and horse**: at home and in the creator, the pieces she wears are laid over the painted pair (the saddle cloth, the saddle, the stirrups, the breastplate, the bridle and the owl-feather tassel on the horse; the owl feathers, the belt, the bracelets and the boots on the girl; see `Reward.dress`). The coat and the braided mane show only on their cards, the earrings only in the camera picture.
* **The decorations of the home** are painted (`assets/pictures/finery/carpet_1.png`, `door_1.png`, `dombra_1.png`).

* **The chosen rider and horse from above** in the level (`assets/pictures/top_down/horses/` in the 13 frames of their run, `assets/pictures/top_down/girls/`, see `PaintedTopDown.draw_rider`): the girl of each preset sits on the horse of each preset, both centred on the seat of the saddle. The instruction keeps one rider (the first girl on the bay horse).

* **The finery from above** in the level (`assets/pictures/top_down/finery/`): the saddles, the saddle cloths, the bridles, the breastplate, the stirrups, the braided manes and the owl feathers on her hat, laid over the chosen pair as she wears them. They were painted on a grid of flat templates of the horse and the rider (`dev/pictures/top_down_template_grid.png`) and cut with `dev/pictures/cut_top_down_finery.py`.

**Not yet:**

* the finery on the girl of the instruction (left as it is, on purpose).

**Also built since:** the painting on the intro screen (section 11), the painting of the steppe at sunset behind the instruction (`assets/pictures/instruction/background.png`) the painted girl riding in on her horse (`rider_on_horse.png`) before she jumps off, the painted horse in its walk, trot and gallop, seven frames each (`assets/pictures/horse/`, see `PaintedHorse`), in the instruction and on the speed bar of the level (always the bay horse), the rider on her horse and the lost animals (sheep, lamb, horse, camel; walking and grazing) from above in the level (to the measures of a real steppe horse, about 2.4 m from the nose to the croup and 0.65 m across the barrel: the paintings made the girl and the people as wide as the horse, so they are drawn at 0.65 of their size, and the horse 1.15 times wider, see `PaintedTopDown`), the painted ground of the level, the painted landmarks (`assets/pictures/landmarks/`) and the painted wild animals (`assets/pictures/top_down/wild/`), the painted pen at home (`assets/pictures/home/pen.png`), the painted icons of the animals and the landmarks (`assets/pictures/icons/`), the minimap on painted parchment and the painted map of the level select with the levels along its path (`assets/pictures/maps/`), the reward at home in front of the painted yurt (`assets/pictures/home/reward.png`) with painted gifts on its cards (`assets/pictures/finery/`), the painted water, grass, star, heart and the bird of the hand cursor (`assets/pictures/icons/`), the buttons and panels on painted felt stretched as a nine-patch with a seamless felt in the middle (`assets/pictures/ui/`, `assets/pictures/felt/`, see `Ornaments`), the painted hair and hat of each rider over the player's face in the camera picture, with the earrings and the owl feathers once won (`assets/pictures/overlay/`, see `FrontView.painted_overlay`; painted on a face template, `dev/pictures/`, and aligned by its eyes); the painted clothes of each rider on the player's body in the camera picture, the fists and the rein (`assets/pictures/body/`, see `PaintedBody`; painted over gray templates with registration dots, cut and aligned by `dev/pictures/cut_body.py`, the fists by `dev/pictures/cut_fists.py`; `dev/pictures/body_poses.gd` draws them all in the poses of the game, to review); all the paintings are generated with ChatGPT (see THIRD_PARTY_NOTICES.md), the creator with four painted riders and four painted horses to choose from (`assets/pictures/riders/`, `assets/pictures/horses/`, see `Looks.PRESETS` and `Looks.HORSE_PRESETS`: each sets the looks it shows, e.g., for the face overlay; the instruction and the small figure always show the girl in the brown coat on the bay horse, whichever rider and horse the player chose, since painting every pair in every pose is not worth it; the level shows the chosen pair from above), the painted people, from above in the level and as portraits in the conversations (`assets/pictures/people/`; the photographs of `assets/pictures/portraits/` are no longer used), and the painted girl squatting in it, in six frames and pulling the reins to the left and to the right, six frames each (`assets/pictures/girl/`, see `PaintedGirl`; also the small figure in the level and the request for room), the default rider of the painting, and the instruction with one line of text for each part and the reins pulled with both hands to the left and to the right (section 5). `dev/pictures/export_art.gd` exports every picture of the game big, with a manifest of its use, for redrawing.

## 17. Open questions

1. **Only a girl?** The story is about a girl. Should the player also be able to choose a boy rider?
2. **Two players?** Built (section 6, "Two players"). Still open: should the free space ask for a wider room (about 4 × 2 m) with two players?
3. **The menus:** is holding the cursor still for 3 s good enough, or should a fist be needed for a click?
4. **The clues on the map:** should a clue be drawn automatically on the map (as described above), or should the child remember it?
5. **Stars by time:** or no stars at all, so that there is no pressure?
6. **Kazakh in Latin script** as well as Cyrillic?
7. **The title of the intro painting** is painted in English. Should there be a version of the painting for each language, or the painting without its title, with the title written by the game?
8. **The pixel art:** the painting sets a much richer style. Should the sprites (see `dev/pictures/export_art.gd`) be redrawn to match it, as pictures instead of the vectors in code?
