# Third-party notices

The Steppe Rescue is licensed under the MIT License; see [LICENSE](LICENSE).
This covers the code, the scenes and everything the game draws in code.

The game includes, or is built with, the following third-party components.
Each keeps its own license.

## Distributed with the game

### Godot Engine

* Version: 4.6.2 (.NET)
* License: MIT
* Copyright (c) 2014-present Godot Engine contributors; Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur
* Source: https://godotengine.org
* License text: [licenses/godot/LICENSE.txt](licenses/godot/LICENSE.txt)

Godot Engine itself includes third-party components under their own licenses.
Their notices are in [licenses/godot/COPYRIGHT.txt](licenses/godot/COPYRIGHT.txt), generated from the Godot binary with `dev/write_godot_licenses.gd`.

### .NET runtime

* License: MIT
* Copyright (c) .NET Foundation and Contributors
* Source: https://github.com/dotnet/runtime
* Third-party notices: https://github.com/dotnet/runtime/blob/main/THIRD-PARTY-NOTICES.TXT

### ONNX Runtime

* Package: `Microsoft.ML.OnnxRuntime` 1.24.4
* License: MIT
* Copyright (c) Microsoft Corporation
* Source: https://github.com/microsoft/onnxruntime

### RTMO (pose)

* File: `scenes/vision/rtmo/model/rtmo_t_body7_416x416.onnx`
* License: Apache License 2.0
* Copyright (c) OpenMMLab
* Source: MMPose, https://github.com/open-mmlab/mmpose/tree/main/projects/rtmo, the checkpoint `rtmo-t_8xb32-600e_body7-416x416-f48f75cb_20231219.pth`, exported to ONNX with MMDeploy 1.3.0; taken over from [ergo-chaos](https://github.com/mristin/ergo-chaos) (SHA-256 `20aad6e2e42359cac1c5b4a0b2da00e29bfe91a72a782fdcf287d273a04c1b24`)
* License text: [scenes/vision/rtmo/model/LICENSE](scenes/vision/rtmo/model/LICENSE)

The model was trained on the Body7 collection of datasets, some of which carry their own terms of use; check them before a commercial release.

### YOLOX-Body-Head-Hand (heads)

* File: `scenes/vision/yolox/model/yolox_n_body_head_hand_Nx3xHxW.onnx`
* License: Apache License 2.0
* Copyright (c) PINTO0309 (Katsuya Hyodo); based on YOLOX by Megvii (https://github.com/Megvii-BaseDetection/YOLOX)
* Source: https://github.com/PINTO0309/PINTO_model_zoo/tree/main/426_YOLOX-Body-Head-Hand, the nano model; taken over from [bird-dog](https://github.com/mristin/bird-dog) (SHA-256 `2cfe872bbf195743a5cac7a36c45c18f10422b01e7ca33cad486c9665283d6a1`)
* License text: [scenes/vision/yolox/model/LICENSE](scenes/vision/yolox/model/LICENSE)

We distribute the model unmodified.

### YuNet (face landmarks)

* File: `scenes/vision/yunet/model/face_detection_yunet_2023mar_dynamic.onnx`
* License: MIT
* Copyright (c) 2020 Shiqi Yu
* Source: https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet, file `face_detection_yunet_2023mar.onnx` (SHA-256 `8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4`); taken over from [bird-dog](https://github.com/mristin/bird-dog)
* License text: [scenes/vision/yunet/model/LICENSE](scenes/vision/yunet/model/LICENSE)

**Altered:** the height and the width of the input were made dynamic, so that it runs on small head crops; the graph and the weights are unchanged.

### GNU Unifont

* File: `assets/fonts/unifont/unifont-16.0.04.otf`
* License: SIL Open Font License 1.1 (dual-licensed with the GNU GPL 2+ with the font embedding exception; we use it under the OFL)
* Copyright (c) Roman Czyborra, Paul Hardy and the Unifont contributors
* Source: https://unifoundry.com/pub/unifont/unifont-16.0.04/font-builds/unifont-16.0.04.otf (SHA-256 `0e3981ab552231b5a2a870f2b61741903a4bf25c23ef5aeb05fdced1b3c7af4d`)
* License text: [assets/fonts/unifont/OFL-1.1.txt](assets/fonts/unifont/OFL-1.1.txt)

## Used only for the development

* The test photo `tests/SteppeRescue.Tests/data/astronaut_640x480.png` is a public-domain NASA photo of Eileen Collins (the scikit-image "astronaut"), fitted into a 640x480 frame.
* xUnit (Apache-2.0), StbImageSharp (public domain), gdtoolkit (MIT), black (MIT) and polib (MIT).
