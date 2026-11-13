# The Steppe Rescue

**The Steppe Rescue is a free riding and searching game for children of about seven to ten, played by doing squats in front of a webcam.**

You are a girl from a small aul in the steppe near Astana.
The animals of the aul have wandered off, and you ride out on your horse to find them and bring them home.
Squat to make the horse go, and reach across your body with one hand to turn it.

The game is in English, Russian and Kazakh.
See [DESIGN.md](DESIGN.md) for the whole design.

**No network access.**
The game runs entirely on your computer and works offline.
The webcam images are processed locally, in memory, and are never saved or sent anywhere.

## Status

We are building the first level, "The lamb by the spring" (sections 14 and 15 of the design): you choose your language and create your rider and her horse, Grandmother sends you out to find the lamb, you ride with the squats and turn with your hands, your horse drinks at the spring and grazes on the pasture when it gets thirsty or hungry, the lamb follows you once you stay next to it, and you bring it into the pen.
Start the project in Godot and step in front of the webcam: raise a hand to move the bird over a button and hold it still to click (the mouse works, too).
In the level, you can also use the keyboard: Space is a squat, the arrows turn, Down brakes, J jumps (over the creek in the third level), C opens the map, L switches the language, R rides the level again and Escape twice quits.
Two children can ride together on a split screen, each in her half of the camera picture (section 6 of the design, "Two players"); then the first rides with W, A, D and S, and the second with the arrows.

The movement test (`scenes/movement_test/movement_test.tscn`, section 13 of the design) shows what the camera sees: the pose, the hat over the face, the speed bar from the squats and the turn from the hands.

## Download

Download the game for Linux, Windows or macOS from the [releases].
Unzip the package and start the game.

[releases]: https://github.com/mristin/steppe-rescue/releases

The macOS package runs on Apple Silicon.
On Intel Macs, the camera tracking does not work, since ONNX Runtime provides no library for them.

The camera on Windows is experimental: Godot 4.6 has no camera on Windows, so the Windows package brings [CameraServerExtension] along.
Virtual cameras (e.g., the one of OBS Studio) do not work there.
If the camera does not work, ride with the keyboard.

[CameraServerExtension]: https://github.com/j20001970/godot-cameraserver-extension

You need a webcam which supports 640x480.

## Acknowledgments

We track the player with the following models (each model directory contains its license):

* [RTMO] (tiny, 416x416, trained on the Body7 datasets, Apache-2.0) finds the pose: the head and the wrists.
* [YOLOX-Body-Head-Hand] (nano, Apache-2.0) finds the heads quickly, on every camera frame.
* [YuNet] (MIT) finds the landmarks of the face in the head, on which we draw the rider's looks.

The text is set in [GNU Unifont] (SIL Open Font License 1.1), one of the few pixel fonts with all the Kazakh letters.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for all the components and their licenses.

[RTMO]: https://github.com/open-mmlab/mmpose/tree/main/projects/rtmo
[YOLOX-Body-Head-Hand]: https://github.com/PINTO0309/PINTO_model_zoo/tree/main/426_YOLOX-Body-Head-Hand
[YuNet]: https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet
[GNU Unifont]: https://unifoundry.com/unifont/

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

The game is licensed under the MIT License; see [LICENSE](LICENSE).
