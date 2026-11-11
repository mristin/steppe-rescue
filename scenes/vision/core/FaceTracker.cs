using System;
using System.Collections.Generic;
using System.Diagnostics;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>Hold what the face tracker found in one frame; immutable.</summary>
    public sealed class FaceSnapshot
    {
        /// <summary>The time of the frame, on the clock of the vision service.</summary>
        public double Timestamp { get; init; }

        public int Width { get; init; }
        public int Height { get; init; }

        /// <summary>The head of the (first) player, or null if not found.</summary>
        public BoundingBox? Head => Heads.Count > 0 ? Heads[0] : null;

        /// <summary>The landmarks of the (first) player's face, or null if not found.</summary>
        public FaceLandmarks? Face => Faces.Count > 0 ? Faces[0] : null;

        /// <summary>The head of each player, or null for a player whose head was not found.</summary>
        public IReadOnlyList<BoundingBox?> Heads { get; init; } = Array.Empty<BoundingBox?>();

        /// <summary>The landmarks of the face of each player, or null if not found.</summary>
        public IReadOnlyList<FaceLandmarks?> Faces { get; init; } = Array.Empty<FaceLandmarks?>();

        /// <summary>How many heads the detector found; -1 when we only followed the faces.</summary>
        public int HeadCount { get; init; }

        /// <summary>
        /// The hands the head detector found in this frame, in frame pixels; null
        /// when the detector did not run (we only followed the faces).
        /// </summary>
        public IReadOnlyList<BoundingBox>? Hands { get; init; }

        /// <summary>How long the heads and the faces took, in milliseconds.</summary>
        public double InferenceMs { get; init; }
    }

    /// <summary>
    /// Find the players' faces in every frame, fast enough for the looks to
    /// stick to them: YOLOX finds the heads in the whole frame, we pick the head
    /// of each player, and YuNet finds the landmarks of the face in it.
    /// </summary>
    /// <remarks>
    /// <para>
    /// YOLOX is the slow part (about 15 ms on a school laptop, against 1.5 ms of
    /// YuNet on a head crop). Once we found the faces, we therefore follow them
    /// with YuNet alone, each in a crop around where it was in the previous
    /// frame, and run YOLOX only when a face is lost, and every
    /// <see cref="RecheckEvery"/> to make sure we still follow the players'
    /// heads.
    /// </para>
    /// <para>
    /// The pose estimator is too slow to run on every frame, so it runs on its
    /// own thread, and the face tracker runs next to it. The pose tells us,
    /// through the hints, which of the heads belongs to which player. With two
    /// players, each player's head is in their own half of the frame (see
    /// <see cref="PlayerSplit"/>).
    /// </para>
    /// <para>The instance is not thread-safe; use it from a single thread only.</para>
    /// </remarks>
    public sealed class FaceTracker : IDisposable
    {
        /// <summary>Follow the previous head at most this long without a hint, in seconds.</summary>
        public double FollowFor = 0.5;

        private readonly YoloxHeadDetector _heads;
        private readonly YuNetFaceLandmarker _faces;
        private readonly List<Detection> _found = new();
        private readonly List<Detection> _half = new();

        /// <summary>Run the head detector at least this often while following the faces, in seconds.</summary>
        public double RecheckEvery = 0.25;

        /// <summary>
        /// Run the head detector on every frame, for its hands (e.g., for the
        /// cursor of the menus), instead of following the faces with YuNet alone.
        /// </summary>
        public volatile bool WantHands;

        /// <summary>Follow a face in a square of this many face sizes around it.</summary>
        public float FollowScale = 1.6f;

        /// <summary>What we know of the face of one player.</summary>
        private sealed class PlayerTrack
        {
            public BoundingBox? Previous;
            public double PreviousAt = double.NaN;

            /// <summary>The square around the face we follow, or null if we follow none.</summary>
            public BoundingBox? Following;
        }

        private readonly PlayerTrack[] _tracks = { new(), new() };
        private double _detectedAt = double.NaN;

        /// <param name="headModel">The bytes of the YOLOX-Body-Head-Hand model.</param>
        /// <param name="faceModel">The bytes of the YuNet model.</param>
        public FaceTracker(byte[] headModel, byte[] faceModel)
        {
            _heads = new YoloxHeadDetector(headModel);
            try
            {
                _faces = new YuNetFaceLandmarker(faceModel);
            }
            catch
            {
                _heads.Dispose();
                throw;
            }
        }

        /// <summary>Find the face of the single player in the frame.</summary>
        /// <param name="frame">The camera frame.</param>
        /// <param name="hintX">The x of the player's head from the pose, if known.</param>
        /// <param name="hintY">The y of the player's head from the pose, if known.</param>
        public FaceSnapshot Track(Frame frame, float? hintX = null, float? hintY = null)
        {
            return TrackAll(frame, new (float X, float Y)?[] { Hint(hintX, hintY) });
        }

        private static (float X, float Y)? Hint(float? x, float? y)
        {
            return x != null && y != null ? (x.Value, y.Value) : null;
        }

        /// <summary>Find the faces of the players (as many as the hints) in the frame.</summary>
        /// <param name="frame">The camera frame.</param>
        /// <param name="hints">The head of each player from the pose, if known.</param>
        public FaceSnapshot TrackAll(Frame frame, IReadOnlyList<(float X, float Y)?> hints)
        {
            var stopwatch = Stopwatch.StartNew();
            int count = Math.Clamp(hints.Count, 1, PlayerSplit.MaxPlayers);
            var heads = new BoundingBox?[count];
            var faces = new FaceLandmarks?[count];

            bool allFollowed = !WantHands && frame.Timestamp - _detectedAt < RecheckEvery;
            for (int i = 0; i < count && allFollowed; i++)
            {
                var track = _tracks[i];
                var followed = track.Following != null ? _faces.DetectOne(frame, track.Following.Value) : null;
                if (followed == null)
                {
                    allFollowed = false;
                    break;
                }

                var square = followed.Box.ExpandToSquare(FollowScale);
                track.Following = square;
                track.Previous = square;
                track.PreviousAt = frame.Timestamp;
                heads[i] = square;
                faces[i] = followed;
            }

            if (allFollowed)
            {
                return Snapshot(frame, heads, faces, -1, null, stopwatch);
            }

            _heads.Detect(frame, _found);
            _detectedAt = frame.Timestamp;

            for (int i = 0; i < count; i++)
            {
                var track = _tracks[i];
                float? x = i < hints.Count ? hints[i]?.X : null;
                float? y = i < hints.Count ? hints[i]?.Y : null;
                if ((x == null || y == null) && track.Previous != null
                    && frame.Timestamp - track.PreviousAt <= FollowFor)
                {
                    x = track.Previous.Value.CenterX;
                    y = track.Previous.Value.CenterY;
                }

                _half.Clear();
                foreach (var detection in _found)
                {
                    if (PlayerSplit.PlayerOf(detection.Box.CenterX, frame.Width, count) == i)
                    {
                        _half.Add(detection);
                    }
                }

                var head = Pick(_half, x, y);
                FaceLandmarks? face = null;
                if (head != null)
                {
                    face = _faces.DetectOne(frame, head.Value);
                    track.Previous = head;
                    track.PreviousAt = frame.Timestamp;
                }

                track.Following = face?.Box.ExpandToSquare(FollowScale);
                heads[i] = head;
                faces[i] = face;
            }

            var hands = new List<BoundingBox>(_heads.Hands.Count);
            foreach (var hand in _heads.Hands)
            {
                hands.Add(hand.Box);
            }

            return Snapshot(frame, heads, faces, _found.Count, hands, stopwatch);
        }

        private static FaceSnapshot Snapshot(
            Frame frame,
            BoundingBox?[] heads,
            FaceLandmarks?[] faces,
            int headCount,
            IReadOnlyList<BoundingBox>? hands,
            Stopwatch stopwatch
        )
        {
            return new FaceSnapshot
            {
                Timestamp = frame.Timestamp,
                Width = frame.Width,
                Height = frame.Height,
                Heads = heads,
                Faces = faces,
                HeadCount = headCount,
                Hands = hands,
                InferenceMs = stopwatch.Elapsed.TotalMilliseconds,
            };
        }

        /// <summary>
        /// Pick the head nearest to the point, measured in head widths, or the
        /// largest head without a point; null if there are no heads.
        /// </summary>
        public static BoundingBox? Pick(IReadOnlyList<Detection> heads, float? x, float? y)
        {
            BoundingBox? best = null;
            float bestCost = float.PositiveInfinity;
            foreach (var head in heads)
            {
                var box = head.Box;
                float cost;
                if (x != null && y != null)
                {
                    float dx = box.CenterX - x.Value;
                    float dy = box.CenterY - y.Value;
                    cost = MathF.Sqrt(dx * dx + dy * dy) / Math.Max(1f, box.Width);
                }
                else
                {
                    cost = -box.Area;
                }

                if (cost < bestCost)
                {
                    bestCost = cost;
                    best = box;
                }
            }

            return best;
        }

        public void Dispose()
        {
            _faces.Dispose();
            _heads.Dispose();
        }
    }
}  // namespace SteppeRescue.Vision
