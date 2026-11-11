using Godot;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;

using SteppeRescue.Vision;

/// <summary>
/// Capture the webcam, find the players' poses and faces on background threads,
/// and turn them into the riding: the speed from the squats, the turn from the
/// hands, and the anchor of the looks over the face.
/// </summary>
/// <remarks>
/// <para>
/// Two threads run side by side. The pose thread runs RTMO, which is accurate
/// but slow, for the squats and the hands. The face thread runs the small
/// YOLOX head detector and YuNet on every camera frame, so that the looks stick
/// to the face; the pose only tells it which head belongs to the player.
/// </para>
/// <para>
/// The main thread only copies a camera frame when a thread asks for one, so
/// that we never queue frames (and latency) nor copy frames nobody processes;
/// both threads share the copy. The threads publish immutable snapshots
/// (<see cref="VisionSnapshot"/> and <see cref="FaceSnapshot"/>), which the
/// main thread feeds into the <see cref="SquatMeter"/> (through the
/// <see cref="HeadGauge"/>, from the faces), the <see cref="Reins"/>, the
/// <see cref="Brake"/> (from the poses) and the <see cref="FaceAnchorFilter"/>
/// in <see cref="_Process"/>.
/// </para>
/// <para>
/// One or two players ride together (see <see cref="SetPlayerCount"/>). With
/// two, each plays in their own half of the camera picture, as in Bird Dog
/// and Ergo Chaos: the player on the left of the mirrored picture is player 0,
/// the one on the right player 1 (see <see cref="PlayerSplit"/>). Each has
/// their own squats, reins, brake and face.
/// </para>
/// <para>
/// The keyboard works with or without the camera. Player 0: Space or W is a
/// squat, A and D turn, S brakes. Player 1: Up is a squat, Left and Right
/// turn, Down brakes; with a single player, the arrows ride player 0, too.
/// The game (GDScript) uses only the plain getters, which take the player.
/// </para>
/// </remarks>
public partial class VisionService : Node
{
    public enum ServiceStatus
    {
        Disabled,
        SearchingCamera,
        LoadingModels,
        Running,
        NoCamera,
        ModelsMissing,
        Failed,
    }

    public const string PoseModelPath = "res://scenes/vision/rtmo/model/rtmo_t_body7_416x416.onnx";

    public const string HeadModelPath =
        "res://scenes/vision/yolox/model/yolox_n_body_head_hand_Nx3xHxW.onnx";

    public const string FaceModelPath =
        "res://scenes/vision/yunet/model/face_detection_yunet_2023mar_dynamic.onnx";

    /// <summary>Give up waiting for the camera server after this many seconds.</summary>
    private const double _cameraSearchTimeout = 7.0;

    /// <summary>Wait this long after the first feed shows up, so that the others can follow.</summary>
    private const double _graceAfterFirstFeed = 1.0;

    /// <summary>A key press counts as a squat of this depth, in units.</summary>
    private const float _keyboardSquatDepth = 1.2f;

    [Export]
    public bool UseCamera = true;

    /// <summary>Prefer the feed with this index among the compatible ones.</summary>
    [Export]
    public int CameraIndex = 0;

    /// <summary>How many threads the pose estimator may use.</summary>
    [Export]
    public int Threads = 2;

    public ServiceStatus Status { get; private set; } = ServiceStatus.Disabled;

    public string StatusMessage { get; private set; } = "";

    /// <summary>The camera image (not mirrored), for the preview; null without a camera.</summary>
    public CameraTexture? CameraTexture { get; private set; }

    /// <summary>How many players ride together: 1 or 2.</summary>
    public int PlayerCount { get; private set; } = 1;

    /// <summary>The squats, the reins, the brake and the face of each player.</summary>
    public readonly SquatMeter[] Squats = { new(), new() };
    public readonly Reins[] Reins = { new(), new() };
    public readonly Brake[] Brakes = { new(), new() };
    public readonly FaceAnchorFilter[] Faces = { new(), new() };

    /// <summary>The head of each player from the face tracker, which the squats follow.</summary>
    public readonly HeadGauge[] Heads = { new(), new() };

    /// <summary>The hands of the players, from the hand detector, told apart by the poses.</summary>
    public readonly HandTracker Hands = new();

    /// <summary>The body of each player, to dress her as her rider in the camera picture.</summary>
    public readonly BodyFollower[] Bodies = { new(), new() };

    /// <summary>
    /// With the face tracker, the pose runs this often (in seconds): only to tell
    /// the players' hands apart and to dress their bodies.
    /// </summary>
    [Export]
    public double PoseEvery = 0.25;

    /// <summary>
    /// Whether the face tracker follows the heads and the hands; if not (its
    /// models are missing, or it failed), the squats, the reins and the brake
    /// follow the pose, which then runs as often as it can.
    /// </summary>
    private volatile bool _faceTracking;

    private readonly Stopwatch _clock = Stopwatch.StartNew();
    private double _gameTime;

    /// <summary>
    /// Seconds on the clock of the frame timestamps: the wall clock with the
    /// camera, and the game time without it, so that the tests, which run
    /// faster than the wall clock, measure the keyboard squats in game time.
    /// </summary>
    public double Now => UseCamera ? _clock.Elapsed.TotalSeconds : _gameTime;

    private VisionSnapshot? _latest;
    private VisionSnapshot? _consumed;
    private FaceSnapshot? _latestFace;

    /// <summary>The latest face snapshot in which the head detector ran, with its hands.</summary>
    private FaceSnapshot? _latestHands;

    private FaceSnapshot? _consumedFace;

    /// <summary>The latest pose, or null before the first one.</summary>
    public VisionSnapshot? Latest => Volatile.Read(ref _latest);

    /// <summary>The latest face, or null before the first one.</summary>
    public FaceSnapshot? LatestFace => Volatile.Read(ref _latestFace);

    private CameraFeed? _feed;
    private double _searchStarted = double.NaN;
    private double _firstFeedAt = double.NaN;

    /// <summary>Hand the camera frames over to one inference thread.</summary>
    private sealed class FrameSlot
    {
        public volatile bool Requested;
        public readonly AutoResetEvent Ready = new(false);
        private readonly object _lock = new();
        private Frame? _pending;

        public void Put(Frame frame)
        {
            lock (_lock)
            {
                _pending = frame;
            }

            Requested = false;
            Ready.Set();
        }

        public Frame? Take()
        {
            lock (_lock)
            {
                var frame = _pending;
                _pending = null;
                return frame;
            }
        }
    }

    private readonly List<Thread> _threads = new();
    private volatile bool _running;
    private readonly FrameSlot _poseSlot = new();
    private readonly FrameSlot _faceSlot = new();

    /// <summary>The keys of each player: the squat, left, right and the brake.</summary>
    private static readonly Key[][] _keys =
    {
        new[] { Key.W, Key.A, Key.D, Key.S },
        new[] { Key.Up, Key.Left, Key.Right, Key.Down },
    };

    private readonly float[] _keyboardTurn = new float[2];
    private readonly bool[] _keyboardBraking = new bool[2];
    private readonly bool[] _keyboardTurning = new bool[2];

    public override void _Ready()
    {
        if (!UseCamera)
        {
            SetStatus(ServiceStatus.Disabled, "The camera is switched off.");
            return;
        }

        if (!FileAccess.FileExists(PoseModelPath))
        {
            SetStatus(
                ServiceStatus.ModelsMissing,
                $"The pose model {PoseModelPath} is missing; run `git lfs pull`."
            );
            return;
        }

        CameraServer.MonitoringFeeds = true;
        _searchStarted = Now;
        SetStatus(ServiceStatus.SearchingCamera, "Looking for a camera...");
    }

    public override void _Process(double delta)
    {
        _gameTime += delta;
        double now = Now;

        if (Status == ServiceStatus.SearchingCamera)
        {
            SearchCamera(now);
        }

        var snapshot = Latest;
        if (snapshot != null && !ReferenceEquals(snapshot, _consumed))
        {
            _consumed = snapshot;
            Consume(snapshot);
        }

        var face = LatestFace;
        if (face != null && !ReferenceEquals(face, _consumedFace))
        {
            _consumedFace = face;
            for (int i = 0; i < face.Faces.Count && i < Faces.Length; i++)
            {
                var landmarks = face.Faces[i];
                if (landmarks != null)
                {
                    Faces[i].Observe(face.Timestamp, FaceAnchor.FromLandmarks(landmarks, face.Width));
                }

                // NOTE (mristin):
                // The squats follow the head on every frame of the face tracker,
                // which is faster and steadier than the pose.
                var head = i < face.Heads.Count ? face.Heads[i] : null;
                if (Heads[i].Measure(face.Timestamp, landmarks, head, face.HeadCount >= 0))
                {
                    Squats[i].Observe(face.Timestamp, Heads[i].Y, Heads[i].Unit);
                    Bodies[i].ObserveHead(face.Timestamp, Heads[i].X, Heads[i].Y);
                    Hands.SetUnit(i, Heads[i].Unit);
                }
            }

            if (face.Hands != null)
            {
                Hands.Observe(face.Timestamp, face.Hands);
                ConsumeHands(face.Timestamp);
            }
        }

        for (int i = 0; i < PlayerSplit.MaxPlayers; i++)
        {
            UpdateKeyboard(i, now);
            Squats[i].Update(now);
            Brakes[i].Update(now);
            if (Brakes[i].Pulled)
            {
                Squats[i].Halt(delta);
            }

            Reins[i].Update(now);
            Faces[i].Update(now);
        }
    }

    /// <summary>Turn and brake the player with the keys held down.</summary>
    private void UpdateKeyboard(int player, double now)
    {
        bool Held(int which)
        {
            if (Input.IsKeyPressed(_keys[player][which]))
            {
                return true;
            }

            // NOTE (mristin):
            // A single player rides with the arrows, too.
            return player == 0 && PlayerCount == 1 && Input.IsKeyPressed(_keys[1][which]);
        }

        _keyboardTurning[player] = false;
        if (Held(1))
        {
            _keyboardTurn[player] = -1f;
            _keyboardTurning[player] = true;
        }
        else if (Held(2))
        {
            _keyboardTurn[player] = 1f;
            _keyboardTurning[player] = true;
        }

        // NOTE (mristin):
        // The brake key (or the tests) brakes like both hands above the head.
        bool braking = Held(3);
        if (braking)
        {
            Brakes[player].Hold(now);
        }
        else if (_keyboardBraking[player])
        {
            Brakes[player].LetGo();
        }

        _keyboardBraking[player] = braking;
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is not InputEventKey key || !key.Pressed || key.Echo)
        {
            return;
        }

        if (key.Keycode == Key.Space || key.Keycode == Key.W)
        {
            SquatByKeyboard(0);
        }
        else if (key.Keycode == Key.Up)
        {
            SquatByKeyboard(PlayerCount > 1 ? 1 : 0);
        }
    }

    private void Consume(VisionSnapshot snapshot)
    {
        for (int i = 0; i < snapshot.Players.Count && i < PlayerSplit.MaxPlayers; i++)
        {
            var player = snapshot.Players[i];
            if (player == null)
            {
                continue;
            }

            Bodies[i].ObservePose(snapshot.Timestamp, player);
            if (!_faceTracking)
            {
                ConsumePlayer(i, player, snapshot.Timestamp);
            }
        }

        if (_faceTracking)
        {
            Hands.ObservePoses(snapshot.Timestamp, snapshot.Players);
        }
    }

    /// <summary>Turn and brake each player with her hands, which the hand tracker follows.</summary>
    private void ConsumeHands(double t)
    {
        for (int i = 0; i < PlayerCount; i++)
        {
            var head = Heads[i];
            if (float.IsNaN(head.Y) || float.IsNaN(head.Unit))
            {
                continue;
            }

            var left = Hands.Hand(i, HandSide.Left, t);
            var right = Hands.Hand(i, HandSide.Right, t);
            Reins[i].Observe(t, head.X, head.Unit, left?.X, right?.X);
            Brakes[i].Observe(t, head.Y, head.Unit, left?.Y, right?.Y);
        }
    }

    private void ConsumePlayer(int index, Pose player, double t)
    {
        const float threshold = 0.5f;
        var head = player.Head(threshold);
        var unit = player.Unit(threshold);
        if (head == null || unit == null)
        {
            return;
        }

        Squats[index].Observe(t, head.Value.Y, unit.Value);
        Bodies[index].ObserveHead(t, head.Value.X, head.Value.Y);

        float? leftWrist = player.Has(BodyPart.LeftWrist, threshold) ? player[BodyPart.LeftWrist].X : null;
        float? rightWrist = player.Has(BodyPart.RightWrist, threshold) ? player[BodyPart.RightWrist].X : null;
        Reins[index].Observe(t, head.Value.X, unit.Value, leftWrist, rightWrist);

        float? leftWristY = player.Has(BodyPart.LeftWrist, threshold) ? player[BodyPart.LeftWrist].Y : null;
        float? rightWristY = player.Has(BodyPart.RightWrist, threshold) ? player[BodyPart.RightWrist].Y : null;
        Brakes[index].Observe(t, head.Value.Y, unit.Value, leftWristY, rightWristY);
    }

    // NOTE (mristin):
    // The getters below are the API for GDScript. The positions are normalized to
    // [0, 1] of the *mirrored* camera picture, as the players see themselves.
    // Every getter about the riding takes the player: 0, or 1 with two players.

    public string GetStatus() => Status.ToString();

    public string GetStatusMessage() => StatusMessage;

    public bool IsRunning() => Status == ServiceStatus.Running;

    public Texture2D? GetCameraTexture() => CameraTexture;

    /// <summary>Set how many players ride together (1 or 2), and forget their riding.</summary>
    public void SetPlayerCount(int count)
    {
        int clamped = Math.Clamp(count, 1, PlayerSplit.MaxPlayers);
        if (clamped == PlayerCount)
        {
            return;
        }

        PlayerCount = clamped;
        Hands.Reset();
        ResetRiding();
    }

    public int GetPlayerCount() => PlayerCount;

    private static int Index(int player) => Math.Clamp(player, 0, PlayerSplit.MaxPlayers - 1);

    /// <summary>The speed of the player's horse in [0, 1].</summary>
    public float GetSpeed(int player) => Squats[Index(player)].Speed;

    /// <summary>The gait of the player's horse: 0 stands, 1 walks, 2 trots, 3 gallops.</summary>
    public int GetGait(int player) => (int)Squats[Index(player)].Gait;

    /// <summary>The speeds from which the horse walks, trots and gallops.</summary>
    public Vector3 GetGaitThresholds() => new(SquatMeter.WalkFrom, SquatMeter.TrotFrom, SquatMeter.GallopFrom);

    /// <summary>How deep the player is in the squat now, in [0, 1].</summary>
    public float GetSquatDepth(int player) => Squats[Index(player)].Depth;

    public int GetSquatCount(int player) => Squats[Index(player)].Count;

    /// <summary>The turn in [-1, 1]: negative turns left, positive turns right.</summary>
    public float GetTurn(int player)
    {
        int i = Index(player);
        return _keyboardTurning[i] ? _keyboardTurn[i] : Reins[i].Turn;
    }

    /// <summary>Whether the player brakes now, both hands above her head.</summary>
    public bool IsBraking(int player) => Brakes[Index(player)].Pulled;

    /// <summary>How many times the player braked.</summary>
    public int GetBrakeCount(int player) => Brakes[Index(player)].Count;

    /// <summary>Brake from the tests, as if both hands were up for a moment.</summary>
    public void BrakeByKeyboard(int player) => Brakes[Index(player)].Hold(Now);

    /// <summary>How far each hand of the player reaches across, in [0, 1]: (left, right).</summary>
    public Vector2 GetHandsAcross(int player)
    {
        int i = Index(player);
        return new(Reins[i].LeftAcross, Reins[i].RightAcross);
    }

    private Pose? PoseOf(VisionSnapshot? snapshot, int player)
    {
        if (snapshot == null || player < 0 || player >= snapshot.Players.Count)
        {
            return null;
        }

        return snapshot.Players[player];
    }

    /// <summary>Whether the player is in the picture now.</summary>
    public bool HasPlayer(int player)
    {
        var snapshot = Latest;
        return PoseOf(snapshot, player) != null && Now - snapshot!.Timestamp < 0.5;
    }

    /// <summary>The player's 17 key points in the mirrored picture, normalized; empty without her.</summary>
    public Vector2[] GetKeypoints(int player)
    {
        var snapshot = Latest;
        var pose = PoseOf(snapshot, player);
        if (pose == null)
        {
            return Array.Empty<Vector2>();
        }

        var points = new Vector2[Pose.KeypointCount];
        for (int i = 0; i < Pose.KeypointCount; i++)
        {
            var keypoint = pose.Keypoints[i];
            points[i] = new Vector2(1f - keypoint.X / snapshot!.Width, keypoint.Y / snapshot.Height);
        }

        return points;
    }

    /// <summary>
    /// The hands which YOLOX found lately (of all the players), as their
    /// centers in the mirrored picture, normalized; empty if none were found in
    /// the last 0.3 s.
    /// </summary>
    public Vector2[] GetHands()
    {
        var snapshot = Volatile.Read(ref _latestHands);
        if (snapshot?.Hands == null || Now - snapshot.Timestamp > 0.3)
        {
            return Array.Empty<Vector2>();
        }

        var hands = new Vector2[snapshot.Hands.Count];
        for (int i = 0; i < hands.Length; i++)
        {
            var box = snapshot.Hands[i];
            hands[i] = new Vector2(1f - box.CenterX / snapshot.Width, box.CenterY / snapshot.Height);
        }

        return hands;
    }

    private Variant Mirrored((float X, float Y)? point)
    {
        var snapshot = LatestFace;
        float width = snapshot?.Width ?? Latest?.Width ?? 640;
        float height = snapshot?.Height ?? Latest?.Height ?? 480;
        return point == null
            ? new Variant()
            : Variant.From(new Vector2(1f - point.Value.X / width, point.Value.Y / height));
    }

    /// <summary>
    /// The hands of the player in the mirrored picture, normalized: [left,
    /// right], each null if not seen (left and right of her body).
    /// </summary>
    public Godot.Collections.Array GetPlayerHands(int player)
    {
        int i = Index(player);
        double now = Now;
        return new Godot.Collections.Array
        {
            Mirrored(Hands.Hand(i, HandSide.Left, now)),
            Mirrored(Hands.Hand(i, HandSide.Right, now)),
        };
    }

    /// <summary>
    /// The body of the player, to dress her: "joints" (the 12 joints of
    /// <see cref="Joint"/> in the mirrored picture, normalized, each null if
    /// not seen) and "alpha" (0 hides it).
    /// </summary>
    public Godot.Collections.Dictionary GetBody(int player)
    {
        int i = Index(player);
        double now = Now;
        var joints = Bodies[i].Joints(Hands.Hand(i, HandSide.Left, now), Hands.Hand(i, HandSide.Right, now));
        var result = new Godot.Collections.Array();
        foreach (var joint in joints)
        {
            result.Add(Mirrored(joint));
        }

        return new Godot.Collections.Dictionary { { "joints", result }, { "alpha", Bodies[i].Alpha(now) } };
    }

    /// <summary>The scores of the key points of <see cref="GetKeypoints"/>.</summary>
    public float[] GetKeypointScores(int player)
    {
        var pose = PoseOf(Latest, player);
        if (pose == null)
        {
            return Array.Empty<float>();
        }

        var scores = new float[Pose.KeypointCount];
        for (int i = 0; i < Pose.KeypointCount; i++)
        {
            scores[i] = pose.Keypoints[i].Score;
        }

        return scores;
    }

    /// <summary>
    /// The anchor of the looks over the player's face: "center" (normalized),
    /// "eye_distance" (normalized to the width), "angle" (radians, clockwise)
    /// and "alpha" (0 hides it).
    /// </summary>
    public Godot.Collections.Dictionary GetFaceAnchor(int player)
    {
        var snapshot = Latest;
        float width = snapshot?.Width ?? 640;
        float height = snapshot?.Height ?? 480;
        var face = Faces[Index(player)];
        var anchor = face.Anchor;
        return new Godot.Collections.Dictionary
        {
            ["center"] = new Vector2(anchor.X / width, anchor.Y / height),
            ["eye_distance"] = anchor.EyeDistance / width,
            ["angle"] = anchor.Angle,
            ["alpha"] = player < PlayerCount ? face.Alpha : 0f,
        };
    }

    /// <summary>How long the latest pose took, in milliseconds.</summary>
    public double GetInferenceMs() => Latest?.InferenceMs ?? 0.0;

    /// <summary>How long the latest heads and faces took, in milliseconds.</summary>
    public double GetFaceMs() => LatestFace?.InferenceMs ?? 0.0;

    /// <summary>Count a squat of the player as if her key was pressed, e.g., in the tests.</summary>
    public void SquatByKeyboard(int player) => Squats[Index(player)].RegisterSquat(Now, _keyboardSquatDepth);

    /// <summary>Forget the squats and the turns of all the players, e.g., at the start of a level.</summary>
    public void ResetRiding()
    {
        for (int i = 0; i < PlayerSplit.MaxPlayers; i++)
        {
            Squats[i].Reset();
            Reins[i].Reset();
            Brakes[i].Reset();
        }
    }

    private void SearchCamera(double now)
    {
        int count = CameraServer.GetFeedCount();
        if (count > 0 && double.IsNaN(_firstFeedAt))
        {
            _firstFeedAt = now;
        }

        bool timeout = now - _searchStarted > _cameraSearchTimeout;
        bool graceOver = !double.IsNaN(_firstFeedAt) && now - _firstFeedAt > _graceAfterFirstFeed;
        if (!timeout && !graceOver)
        {
            return;
        }

        var candidates = new List<(CameraFeed Feed, int Format)>();
        for (int i = 0; i < count; i++)
        {
            CameraFeed feed = CameraServer.GetFeed(i);
            int format = FindFormat(feed);
            if (format >= 0)
            {
                candidates.Add((feed, format));
            }
        }

        GD.Print($"The camera server reports {count} feed(s), {candidates.Count} compatible.");

        if (candidates.Count == 0)
        {
            SetStatus(
                ServiceStatus.NoCamera,
                count == 0
                    ? "No camera found."
                    : "No camera supports 640x480, which the vision needs."
            );
            return;
        }

        var (chosen, formatIndex) = candidates[Math.Clamp(CameraIndex, 0, candidates.Count - 1)];
        StartCamera(chosen, formatIndex);
    }

    /// <summary>Find the 640x480 format, preferring YUYV; return -1 if there is none.</summary>
    private static int FindFormat(CameraFeed feed)
    {
        var formats = feed.GetFormats();
        int fallback = -1;
        for (int i = 0; i < formats.Count; i++)
        {
            var format = formats[i].AsGodotDictionary();
            int width = format.ContainsKey("width") ? format["width"].AsInt32() : 0;
            int height = format.ContainsKey("height") ? format["height"].AsInt32() : 0;
            string pixelFormat = format.ContainsKey("format") ? format["format"].AsString() : "";
            if (width != 640 || height != 480)
            {
                continue;
            }

            if (pixelFormat.StartsWith("YUYV"))
            {
                return i;
            }

            fallback = fallback < 0 ? i : fallback;
        }

        return fallback;
    }

    private void StartCamera(CameraFeed feed, int formatIndex)
    {
        GD.Print($"Starting the camera {feed.GetName()}, format #{formatIndex}: {feed.GetFormats()[formatIndex]}");
        _feed = feed;
        _feed.SetFormat(formatIndex, new Godot.Collections.Dictionary());
        _feed.FeedIsActive = true;

        CameraTexture = new CameraTexture { CameraFeedId = _feed.GetId(), CameraIsActive = true };
        _feed.FrameChanged += OnFrameChanged;

        SetStatus(ServiceStatus.LoadingModels, "Loading the models...");

        byte[] poseModel = FileAccess.GetFileAsBytes(PoseModelPath);
        int threads = Threads;
        _running = true;
        StartThread("Pose", () => PoseLoop(poseModel, threads));

        if (FileAccess.FileExists(HeadModelPath) && FileAccess.FileExists(FaceModelPath))
        {
            byte[] headModel = FileAccess.GetFileAsBytes(HeadModelPath);
            byte[] faceModel = FileAccess.GetFileAsBytes(FaceModelPath);
            _faceTracking = true;
            StartThread("Face", () => FaceLoop(headModel, faceModel));
        }
        else
        {
            GD.PushWarning("The head or the face model is missing; the faces stay bare.");
        }
    }

    private void StartThread(string name, ThreadStart loop)
    {
        var thread = new Thread(loop)
        {
            IsBackground = true,
            Name = name,
            Priority = ThreadPriority.BelowNormal,
        };
        _threads.Add(thread);
        thread.Start();
    }

    private void OnFrameChanged()
    {
        bool forPose = _poseSlot.Requested;
        bool forFace = _faceSlot.Requested;
        if ((!forPose && !forFace) || CameraTexture == null)
        {
            return;
        }

        Image? image = CameraTexture.GetImage();
        if (image == null || image.IsEmpty())
        {
            return;
        }

        if (image.GetFormat() != Image.Format.Rgb8)
        {
            image.Convert(Image.Format.Rgb8);
        }

        // NOTE (mristin):
        // We copy the raw bytes on the main thread so that the inference threads
        // never touch any engine objects. The threads only read the frame, so
        // they can share it.
        var frame = new Frame(image.GetData(), image.GetWidth(), image.GetHeight(), Now);
        if (forPose)
        {
            _poseSlot.Put(frame);
        }

        if (forFace)
        {
            _faceSlot.Put(frame);
        }
    }

    /// <summary>Ask for the next camera frame and wait for it; null on a timeout or the exit.</summary>
    private Frame? NextFrame(FrameSlot slot)
    {
        slot.Requested = true;
        if (!slot.Ready.WaitOne(500) || !_running)
        {
            return null;
        }

        return slot.Take();
    }

    private void PoseLoop(byte[] poseModel, int threads)
    {
        RiderVision? vision = null;
        try
        {
            vision = new RiderVision(poseModel, threads);
            Callable.From(() => SetStatus(ServiceStatus.Running, "")).CallDeferred();

            var started = Stopwatch.StartNew();
            while (_running)
            {
                // NOTE (mristin):
                // With the face tracker, the pose only tells the hands apart and
                // dresses the bodies, so it runs only now and then, and leaves the
                // processor to the faces and the hands.
                if (_faceTracking)
                {
                    int wait = (int)((PoseEvery - started.Elapsed.TotalSeconds) * 1000.0);
                    if (wait > 0)
                    {
                        Thread.Sleep(wait);
                    }
                }

                started.Restart();
                var frame = NextFrame(_poseSlot);
                if (frame != null)
                {
                    Volatile.Write(ref _latest, vision.Process(frame, PlayerCount));
                }
            }
        }
        catch (Exception exception)
        {
            GD.PushError($"The vision failed: {exception}");
            string message = $"The vision failed: {exception.Message}";
            Callable.From(() => SetStatus(ServiceStatus.Failed, message)).CallDeferred();
        }
        finally
        {
            vision?.Dispose();
        }
    }

    private void FaceLoop(byte[] headModel, byte[] faceModel)
    {
        FaceTracker? tracker = null;
        try
        {
            tracker = new FaceTracker(headModel, faceModel);
            while (_running)
            {
                // NOTE (mristin):
                // The reins and the brake follow the hands on every frame.
                tracker.WantHands = true;
                var frame = NextFrame(_faceSlot);
                if (frame == null)
                {
                    continue;
                }

                // NOTE (mristin):
                // The pose tells which head is whose; it may be a few frames
                // old, which is close enough to tell the heads apart.
                var latest = Latest;
                var hints = new (float X, float Y)?[PlayerCount];
                for (int i = 0; i < hints.Length; i++)
                {
                    hints[i] = PoseOf(latest, i)?.Head(0.5f);
                }

                var found = tracker.TrackAll(frame, hints);
                Volatile.Write(ref _latestFace, found);
                if (found.Hands != null)
                {
                    Volatile.Write(ref _latestHands, found);
                }
            }
        }
        catch (Exception exception)
        {
            // NOTE (mristin):
            // The faces only dress up the picture, so the riding goes on without them.
            GD.PushWarning($"The face tracking stopped: {exception}");
            _faceTracking = false;
        }
        finally
        {
            tracker?.Dispose();
        }
    }

    private void SetStatus(ServiceStatus status, string message)
    {
        Status = status;
        StatusMessage = message;
        GD.Print($"Vision: {status}: {message}");
    }

    public override void _ExitTree()
    {
        _running = false;
        _poseSlot.Ready.Set();
        _faceSlot.Ready.Set();
        foreach (var thread in _threads)
        {
            thread.Join(2000);
        }

        _threads.Clear();

        if (_feed != null)
        {
            _feed.FrameChanged -= OnFrameChanged;
            _feed.FeedIsActive = false;
            _feed = null;
        }

        if (CameraTexture != null)
        {
            CameraTexture.CameraIsActive = false;
        }
    }
}
