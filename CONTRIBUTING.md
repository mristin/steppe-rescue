# Contributing

Thank you for helping with The Steppe Rescue!
This guide explains how to set up the development environment, how to run and test the game, and how to prepare a pull request.

## Overview

The game is made with [Godot] 4.6 (.NET), written in GDScript and C#:

* The vision runs in C# (`scenes/vision/`).
  It finds the player's pose with RTMO on one background thread, and her face with YOLOX (the heads) and YuNet (the landmarks) on another, all through ONNX Runtime.
  The pose is too slow for the looks to stick to the face, so the face runs on every camera frame, next to it.
  The core (`scenes/vision/core/`) does not depend on Godot, so we unit-test it with plain .NET in `tests/SteppeRescue.Tests/`.
  It also turns the pose into the riding: `SquatMeter` counts the squats and gives the speed of the horse, `Reins` gives the turn from the hands, and `FaceAnchor` says where to draw the looks over the face.
  The node `VisionService` runs it all in the game and offers plain getters to GDScript; the autoload `Vision` keeps it running across the scenes.
* The game itself is in GDScript (`scenes/`).
  The level (`scenes/level/`) plays a level of `data/levels/`.
  A level is a scene of data nodes (`scenes/level_map/`): the landmarks, the people with their clues, the herds of the lost animals, the pen at home and the start; edit it in the Godot editor.
  The test `tests/godot/test_level.gd` checks every level, e.g., that a clue points to every herd.
* The development tools live in `dev/`.

The game is pixel art.
It renders at 960x540 and scales up by whole numbers (2x on a 1080p screen) with the nearest-neighbor filter.
Draw with the colors of `Palette` (`scenes/pixel/palette.gd`) only.
The screens are laid out in 960x540 logical pixels and drawn at 1920x1080, two pixels of the screen per logical pixel (`Pixelate.DENSITY`).

**Draw vectors first, then pixelate.**
Every picture is drawn as SVG in logical pixels, with the colors of the palette named in braces (e.g., `fill="{crimson}"`), and pixelated by `Pixelate` (`scenes/pixel/pixelate.gd`) at the size it is shown: Godot renders the SVG, and `PixelQuantizer` (C#) gives each pixel the palette color of most of its 3x3 samples and adds the outline.
Ask for a picture at the scale you draw it, instead of scaling a texture up: a texture reports its logical size, so `draw_texture` puts each of its pixels on a pixel of the screen.
The icons are in `scenes/pixel/icons.gd`, the rider and her horse from the side in `side_view.gd`, the rider from the front (the face overlay and the figure) in `front_view.gd`, the finery in steps in both (see `scenes/profile/finery.gd`), the creatures from above in `top_down.gd` (the wild ones in `scenes/level/wild_shapes.gd`), the landmarks in `scenes/level_map/landmark.gd`, the ornamented panels in `ornaments.gd`, the steppe behind the menus in `scenes/intro/intro_picture.gd` and the map of the level select in `scenes/level_select/steppe_map.gd`.
The paintings are the exception: the intro (`assets/pictures/intro/painting.png`) and the steppe behind the instruction (`assets/pictures/instruction/background.png`), 1920 x 1080 each, the girl squatting and pulling the reins (`assets/pictures/girl/`), the rider and the lost animals from above (`assets/pictures/top_down/`, see `PaintedTopDown`), the ground of the level (`assets/pictures/ground/steppe.png`, a seamless tile) and the horse in its gaits (`assets/pictures/horse/`, big and small), cut out of sprite sheets with transparency, shown as painted, at two screen pixels per logical pixel.
To export every picture big, with a manifest of where and how the game uses it (e.g., to redraw them), run `$GODOT --headless --path . --script dev/pictures/export_art.gd -- <folder>`.
To review them, render them all into one sheet with `$GODOT --headless --path . --script dev/pictures/contact_sheet.gd -- sheet.png`, or take a screenshot of a screen as it shows on a 1080p display with `$GODOT --path . --windowed --resolution 1920x1080 --script dev/pictures/screenshot.gd -- res://scenes/intro/intro.tscn shot.png 8 --no-camera`.
To review how the painted clothes sit on the body in the camera picture (the coat, the sleeves, the fists), draw every rider in the poses of the game with `$GODOT --path . --windowed --script dev/pictures/body_poses.gd -- poses.png`.

The portraits of the people are photographs, and stay photographs: they are pixelized, never traced into vectors.
They come from old photographs in the public domain: put the photo in `assets/pictures/sources/`, add it with its crop and its source to `sources.json` there and to [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), and run `venv/bin/python dev/pictures/pixelize.py`, which makes them 128x128.
A source may also outline the person (`figure`) when she is as pale as the paper behind, retouch the photo with a smooth warp (`retouch`, e.g., Grandmother's smile), and lift the shadows (`gamma`); see the docstring of `pixelize.py`.

The tools for the development (like these) live in `dev/`, which Godot ignores, so that they are never released with the game.
To record how your movements look to the vision (for tuning the squats), run `$GODOT --path . --script dev/squats/record_squats.gd` in front of the camera. It walks you through a plan of actions, a CSV in `dev/squats/plans/`: `squats.csv` (the default: stand, walk, trot, gallop and stop, three rounds, the second closer to the camera, the third farther) or `jumps.csv` (pass `-- --plan=res://dev/squats/plans/jumps.csv`: gallop against jumps, with a call to jump that the recording marks). It writes only numbers (never the pictures) into `~/Downloads/squat_recordings/`; `dev/squats/analyze.py <recording>` summarizes it per step (add `--plot out.png` to draw it, `--extract out.csv` for the replay tests).
Use only pictures in the public domain or under CC0.
The text is set in GNU Unifont at 16 pixels, imported without anti-aliasing.

[Godot]: https://godotengine.org

## Setting up the development environment

You need:

* [Git] and [Git LFS], since we keep the ONNX models, the fonts and the images in LFS,
* the [.NET 8 SDK],
* the **.NET** build of [Godot 4.6.2] (also called "mono"; the standard build can not run C#), and
* [Python] 3.10 or newer, for the formatter, the linter and the translation tools.

[Git]: https://git-scm.com
[Git LFS]: https://git-lfs.com
[.NET 8 SDK]: https://dotnet.microsoft.com/download/dotnet/8.0
[Godot 4.6.2]: https://godotengine.org/download/archive/4.6.2-stable/
[Python]: https://www.python.org/downloads/

### Clone the repository

```
git lfs install
git clone https://github.com/mristin/steppe-rescue.git
cd steppe-rescue
git lfs pull
```

### Install Godot

Download the .NET build of Godot 4.6.2 and unpack it anywhere.
Our scripts find Godot through the `GODOT` environment variable, or as `godot` on your path, e.g.:

```
export GODOT=~/apps/Godot_v4.6.2-stable_mono_linux_x86_64/Godot_v4.6.2-stable_mono_linux.x86_64
```

### Restore and build the C# code

```
dotnet restore SteppeRescue.sln
dotnet build SteppeRescue.sln
```

### Set up the Python environment

The tools which keep the code tidy and the translations in order are written in Python, pinned in `dev/requirements.txt`.
Install them in a virtual environment in `venv/` (it is ignored by Git):

```
python3 -m venv venv
venv/bin/pip install -r dev/requirements.txt
touch venv/.gdignore
```

**Do not skip the `.gdignore`!**
Godot scans every directory of the project, and would otherwise try to import the files of the virtual environment.

## Running the game

Open the project in the Godot editor (Import, then select `project.godot`), and press F5.
The game needs a webcam which supports 640x480.
Without one, play with the keyboard: Space (or Up) is a squat, Left and Right turn, Down brakes, J jumps.
With two players, the first rides with W (or Space), A, D and S and jumps with J, and the second with Up, Left, Right and Down and jumps with keypad 0.

Start the game with `-- --no-camera` to switch the camera off, with `-- --lang=ru` (or `kk`, `en`) to choose the language, with `-- --new-rider` to create the rider again, and with `-- --settings=user://other.cfg` to keep the language in another file and the journeys in `user://other_saves/` (the tests do so, to leave yours alone).

## Translations

Every text which a player sees goes through `tr()`, and lives in the translation files in `translations/`: `messages.pot`, `ru.po` and `kk.po`.
After you add or change a text, run:

```
venv/bin/python dev/translations/extract.py
```

It updates the files and keeps the existing translations.
Put a comment starting with `# TRANSLATORS:` right above a `tr()` to explain the text to the translators, e.g., what a placeholder like `{count}` stands for.
`dev/translations/check.py` reports what is still to translate or to review, and fails on broken placeholders.

The texts of the data (the levels, the animals) are collected from their fields, listed in `DATA_FIELDS` of `extract.py`.
The names of the landmarks are translated in several grammatical forms, one per context ("near": "у родника", "of": "родника", "and": "родником", "between": "родником").
A clue like `I saw {animals} near {landmark@near}.` takes the form "near" of the landmark's name; see `scenes/languages/grammar.gd`.

A translation marked as fuzzy has not been reviewed by a native speaker yet.
The game still shows it; remove the mark once a native speaker has checked it.
The languages are listed in `translations/languages.json`; adding a language means adding it there and running `extract.py`.

## Pre-commit checks

Before you commit, run:

```
venv/bin/python dev/continuous_integration/precommit.py --overwrite
```

The script:

1. re-formats the code (`reformat`): the GDScripts with `gdformat`, the C# code with `dotnet format` and the Python scripts in `dev/` with `black`,
2. lints the GDScripts with `gdlint` (`lint`),
3. updates and checks the translations (`translations`),
4. runs the C# unit tests (`dotnet-test`),
5. builds the C# part of the game, so that Godot can load it (`build`),
6. imports the project with Godot (`import`),
7. type-checks every GDScript with Godot (`check-scripts`),
8. runs the Godot tests in `tests/godot/` (`godot-test`), and
9. starts the main scene headless for a moment (`smoke-scenes`).

Without `--overwrite`, the script only checks and changes no files; this is what the continuous integration runs.
Select or skip steps with `--select` and `--skip`, and run only some Godot tests with `--only`.

### The Godot tests

Each Godot test in `tests/godot/` (and its subdirectories), named `test_*.gd`, is a script extending `SceneTree`, which runs the game headless without the camera, checks the behavior, prints `RESULT: OK` and quits with zero on success.
We run them with `--fixed-fps 60`, so a minute of play takes only a second or two.
Without the camera, the vision measures the squats in game time, so the tests can squat with the keyboard (`SquatByKeyboard`).

To run a single test directly:

```
$GODOT --headless --fixed-fps 60 --path . --script tests/godot/test_movement_test.gd -- --no-camera
```

The end-to-end tests in `tests/godot/end2end/` play the whole game, from a new player at the intro through every level to the end, and once more after a restart, as players do: `test_one_player.gd` alone, and `test_two_players.gd` on the split screen.
They click the buttons with the mouse (or hold the hand still over them) and ride only with the keys (`rider_bot.gd`, finding the way with `navigator.gd`): they talk to every person, turn every page of every conversation, bring every animal home, let the horse drink and graze, choose the gifts, and take random detours (How to Play, the settings, the wardrobe, other looks and names, the language, the big map, riding a level again).
All the way, they check the contracts of the game, which run only in the tests: those of the menus, the flow and the saving in `screen_contracts.gd` (e.g., the journey in memory is the one on the disk, each level gives one gift to each rider, every text is in the language of the game), what outlives the screens, the sounds and the vision in `contract_book.gd` (e.g., no node leaks, the wind blows exactly in a level), and those of the levels in `level_contracts.gd`, `level_motion_contracts.gd` and `level_view_contracts.gd` (e.g., the followers walk around the water, a horse never teleports and drinks only while it stands, nothing of the HUD covers a rider, the riders and the lost animals stay out of the lakes, every animal is lost, follows one rider or is home, a horse in the air keeps its speed, a rider hears every lost animal near her and off her screen, the small figure does what the player does).
The random choices come from a seed, so that a failure repeats; try others with `-- --seed=<n>`.
The game runs three times faster than the fixed frame rate gives (`-- --time-scale=<x>`), so each test plays about 25 minutes of the game in a minute and a half.

```
$GODOT --headless --fixed-fps 60 --path . --script tests/godot/end2end/test_one_player.gd -- --no-camera --settings=user://tests/one_player.cfg --seed=7
```

## Continuous integration

GitHub Actions runs the pre-commit checks (without `--overwrite`) on every pull request and on every push to `main`; see `.github/workflows/ci.yaml`.

## Exporting the game

The export presets live in `export_presets.cfg`; there are presets for Linux, Windows and macOS.
They include the ONNX models, the JSON data and the translations explicitly (`include_filter="*.onnx, *.json, *.po"`), since Godot does not export them as resources otherwise, and they exclude the tests, the development tools and the build outputs (`build/`, `dist/`, `notices/`).

Install the .NET export templates of Godot 4.6.2 (in the editor: Editor, Manage Export Templates), and run, e.g.:

```
mkdir -p build/linux
$GODOT --headless --path . --export-release "Linux" build/linux/steppe-rescue.x86_64
```

Godot builds the C# part for each platform itself (`dotnet publish`), including the native libraries of ONNX Runtime.
Mind that Godot exits with zero even if that build fails, and then writes a package without the C# part; check its output for `ERROR`.

The macOS app is universal and runs on the Intel and the Apple Silicon Macs.
We stay with ONNX Runtime 1.19, the last version whose libraries for macOS run on macOS 11 on both (from 1.20 on, they need macOS 13.3, and from 1.24 on, there is none for the Intel Macs); see `SteppeRescue.csproj`.
On macOS 10.15, which .NET 8 still runs on, the game reports that the camera failed, and the keys still ride.
ONNX Runtime 1.16 would run there, too, but runs the pose 15-20% slower; our models (opset 11) give the same keypoints on 1.16, 1.19 and 1.24.
The app is signed ad hoc and not notarized, so the players open it the first time with a right click and Open.

### The camera on Windows

Godot 4.6 implements no camera on Windows, so we use [CameraServerExtension] there, and only there, from `addons/CameraServerExtension/` (the prebuilt Windows x86_64 library of its release 2026.03.27).
Godot reports an error on every platform which an extension lists no library for, so the directory is hidden from Godot (`.gdignore`); the vision service loads the extension itself on Windows (`StartCameraExtension` in `scenes/vision/vision_service/VisionService.cs`), from the directory of the executable, or from the project in the editor.
Hence, when you export for Windows by hand, copy `CameraServerExtension.gdextension` and `libcameraserver-extension.windows.dll` next to the executable, as `.github/workflows/publish.yaml` does.
If the package lies in the project (e.g., in `build/`), put a `.gdignore` there first (`touch build/.gdignore`), or Godot tries to load the extension, and fails, on the other platforms.

Drop the extension once Godot supports the camera on Windows itself ([godotengine/godot#108538]).

[CameraServerExtension]: https://github.com/j20001970/godot-cameraserver-extension
[godotengine/godot#108538]: https://github.com/godotengine/godot/pull/108538

### Releases

When you publish a release on GitHub, the workflow `.github/workflows/publish.yaml` exports the game for Linux, Windows and macOS, adds our license, [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the license texts of the distributed components, and attaches the packages to the release.

You can also start the workflow by hand (Actions, Publish, Run workflow).
Without a tag, it only tries out the packaging and uploads the packages as the artifacts of the run.
With the tag of an existing release, e.g., `v0.1.0`, it also attaches the packages to that release; they are then built from the branch the workflow runs on, not from the tag.

## Third-party components

When you add a third-party component (a model, a font, a picture, a sound), list it in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) with its license, and put its license text next to it.
We only use components whose licenses allow us to distribute them with the game.

## Commit messages

We follow Chris Beams' [guidelines on commit messages]:

1) Separate subject from body with a blank line
2) Limit the subject line to 50 characters
3) Capitalize the subject line
4) Do not end the subject line with a period
5) Use the imperative mood in the subject line
6) Wrap the body at 72 characters
7) Use the body to explain *what* and *why* vs. *how*

[guidelines on commit messages]: https://chris.beams.io/posts/git-commit/
