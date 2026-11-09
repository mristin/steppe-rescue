using Godot;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;

using SteppeRescue.Vision;

/// <summary>
/// Capture the webcam, find the player's pose and face on background threads,
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
/// main thread feeds into the <see cref="SquatMeter"/>, the <see cref="Reins"/>
/// and the <see cref="FaceAnchorFilter"/> in <see cref="_Process"/>.
/// </para>
/// <para>
/// The keyboard works with or without the camera: Space (or Up) is a squat,
/// and Left and Right turn. The game (GDScript) uses only the plain getters.
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

    public readonly SquatMeter Squats = new();
    public readonly Reins Reins = new();
    public readonly FaceAnchorFilter Face = new();

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

    private float _keyboardTurn;
    private bool _keyboardTurning;

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
            if (face.Face != null)
            {
                Face.Observe(face.Timestamp, FaceAnchor.FromLandmarks(face.Face, face.Width));
            }
        }

        _keyboardTurning = false;
        if (Input.IsKeyPressed(Key.Left))
        {
            _keyboardTurn = -1f;
            _keyboardTurning = true;
        }
        else if (Input.IsKeyPressed(Key.Right))
        {
            _keyboardTurn = 1f;
            _keyboardTurning = true;
        }

        Squats.Update(now);
        Reins.Update(now);
        Face.Update(now);
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is InputEventKey key && key.Pressed && !key.Echo
            && (key.Keycode == Key.Space || key.Keycode == Key.Up))
        {
            SquatByKeyboard();
        }
    }

    private void Consume(VisionSnapshot snapshot)
    {
        var player = snapshot.Player;
        if (player == null)
        {
            return;
        }

        const float threshold = 0.5f;
        var head = player.Head(threshold);
        var unit = player.Unit(threshold);
        if (head == null || unit == null)
        {
            return;
        }

        double t = snapshot.Timestamp;
        Squats.Observe(t, head.Value.Y, unit.Value);

        float? leftWrist = player.Has(BodyPart.LeftWrist, threshold) ? player[BodyPart.LeftWrist].X : null;
        float? rightWrist = player.Has(BodyPart.RightWrist, threshold) ? player[BodyPart.RightWrist].X : null;
        Reins.Observe(t, head.Value.X, unit.Value, leftWrist, rightWrist);
    }

    // NOTE (mristin):
    // The getters below are the API for GDScript. The positions are normalized to
    // [0, 1] of the *mirrored* camera picture, as the player sees herself.

    public string GetStatus() => Status.ToString();

    public string GetStatusMessage() => StatusMessage;

    public bool IsRunning() => Status == ServiceStatus.Running;

    public Texture2D? GetCameraTexture() => CameraTexture;

    /// <summary>The speed of the horse in [0, 1].</summary>
    public float GetSpeed() => Squats.Speed;

    /// <summary>The gait of the horse: 0 stands, 1 walks, 2 trots, 3 gallops.</summary>
    public int GetGait() => (int)Squats.Gait;

    /// <summary>The speeds from which the horse walks, trots and gallops.</summary>
    public Vector3 GetGaitThresholds() => new(SquatMeter.WalkFrom, SquatMeter.TrotFrom, SquatMeter.GallopFrom);

    /// <summary>How deep the player is in the squat now, in [0, 1].</summary>
    public float GetSquatDepth() => Squats.Depth;

    public int GetSquatCount() => Squats.Count;

    /// <summary>The turn in [-1, 1]: negative turns left, positive turns right.</summary>
    public float GetTurn()
    {
        return _keyboardTurning ? _keyboardTurn : Reins.Turn;
    }

    /// <summary>How far each hand reaches across, in [0, 1]: (left, right).</summary>
    public Vector2 GetHandsAcross() => new(Reins.LeftAcross, Reins.RightAcross);

    /// <summary>Whether a player is in the picture now.</summary>
    public bool HasPlayer()
    {
        var snapshot = Latest;
        return snapshot?.Player != null && Now - snapshot.Timestamp < 0.5;
    }

    /// <summary>The 17 key points in the mirrored picture, normalized; empty without a player.</summary>
    public Vector2[] GetKeypoints()
    {
        var snapshot = Latest;
        if (snapshot?.Player == null)
        {
            return Array.Empty<Vector2>();
        }

        var points = new Vector2[Pose.KeypointCount];
        for (int i = 0; i < Pose.KeypointCount; i++)
        {
            var keypoint = snapshot.Player.Keypoints[i];
            points[i] = new Vector2(1f - keypoint.X / snapshot.Width, keypoint.Y / snapshot.Height);
        }

        return points;
    }

    /// <summary>The scores of the key points of <see cref="GetKeypoints"/>.</summary>
    public float[] GetKeypointScores()
    {
        var snapshot = Latest;
        if (snapshot?.Player == null)
        {
            return Array.Empty<float>();
        }

        var scores = new float[Pose.KeypointCount];
        for (int i = 0; i < Pose.KeypointCount; i++)
        {
            scores[i] = snapshot.Player.Keypoints[i].Score;
        }

        return scores;
    }

    /// <summary>
    /// The anchor of the looks over the face: "center" (normalized), "eye_distance"
    /// (normalized to the width), "angle" (radians, clockwise) and "alpha" (0 hides it).
    /// </summary>
    public Godot.Collections.Dictionary GetFaceAnchor()
    {
        var snapshot = Latest;
        float width = snapshot?.Width ?? 640;
        float height = snapshot?.Height ?? 480;
        var anchor = Face.Anchor;
        return new Godot.Collections.Dictionary
        {
            ["center"] = new Vector2(anchor.X / width, anchor.Y / height),
            ["eye_distance"] = anchor.EyeDistance / width,
            ["angle"] = anchor.Angle,
            ["alpha"] = Face.Alpha,
        };
    }

    /// <summary>How long the latest pose took, in milliseconds.</summary>
    public double GetInferenceMs() => Latest?.InferenceMs ?? 0.0;

    /// <summary>How long the latest heads and face took, in milliseconds.</summary>
    public double GetFaceMs() => LatestFace?.InferenceMs ?? 0.0;

    /// <summary>Count a squat as if Space was pressed, e.g., in the tests.</summary>
    public void SquatByKeyboard() => Squats.RegisterSquat(Now, _keyboardSquatDepth);

    /// <summary>Forget the squats and the turns, e.g., at the start of a level.</summary>
    public void ResetRiding()
    {
        Squats.Reset();
        Reins.Reset();
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

            while (_running)
            {
                var frame = NextFrame(_poseSlot);
                if (frame != null)
                {
                    Volatile.Write(ref _latest, vision.Process(frame));
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
                var frame = NextFrame(_faceSlot);
                if (frame == null)
                {
                    continue;
                }

                // NOTE (mristin):
                // The pose tells which head is the player's; it may be a few frames
                // old, which is close enough to tell the heads apart.
                var head = Latest?.Player?.Head(0.5f);
                Volatile.Write(ref _latestFace, tracker.Track(frame, head?.X, head?.Y));
            }
        }
        catch (Exception exception)
        {
            // NOTE (mristin):
            // The faces only dress up the picture, so the riding goes on without them.
            GD.PushWarning($"The face tracking stopped: {exception}");
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
