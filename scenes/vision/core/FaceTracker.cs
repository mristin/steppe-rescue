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

        /// <summary>The head of the player, or null if not found.</summary>
        public BoundingBox? Head { get; init; }

        /// <summary>The landmarks of the player's face, or null if not found.</summary>
        public FaceLandmarks? Face { get; init; }

        /// <summary>How many heads the detector found; -1 when we only followed the face.</summary>
        public int HeadCount { get; init; }

        /// <summary>
        /// The hands the head detector found in this frame, in frame pixels; null
        /// when the detector did not run (we only followed the face).
        /// </summary>
        public IReadOnlyList<BoundingBox>? Hands { get; init; }

        /// <summary>How long the heads and the face took, in milliseconds.</summary>
        public double InferenceMs { get; init; }
    }

    /// <summary>
    /// Find the player's face in every frame, fast enough for the looks to stick
    /// to it: YOLOX finds the heads in the whole frame, we pick the player's
    /// head, and YuNet finds the landmarks of the face in it.
    /// </summary>
    /// <remarks>
    /// <para>
    /// YOLOX is the slow part (about 15 ms on a school laptop, against 1.5 ms of
    /// YuNet on a head crop). Once we found the face, we therefore follow it with
    /// YuNet alone, in a crop around where it was in the previous frame, and run
    /// YOLOX only when the face is lost, and every <see cref="RecheckEvery"/> to
    /// make sure we still follow the player's head.
    /// </para>
    /// <para>
    /// The pose estimator is too slow to run on every frame, so it runs on its
    /// own thread, and the face tracker runs next to it. The pose tells us,
    /// through the hint, which of the heads belongs to the player.
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

        /// <summary>Run the head detector at least this often while following the face, in seconds.</summary>
        public double RecheckEvery = 0.25;

        /// <summary>
        /// Run the head detector on every frame, for its hands (e.g., for the
        /// cursor of the menus), instead of following the face with YuNet alone.
        /// </summary>
        public volatile bool WantHands;

        /// <summary>Follow the face in a square of this many face sizes around it.</summary>
        public float FollowScale = 1.6f;

        private BoundingBox? _previous;
        private double _previousAt = double.NaN;

        /// <summary>The square around the face we follow, or null if we follow none.</summary>
        private BoundingBox? _following;
        private double _detectedAt = double.NaN;
        private int _headCount;

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

        /// <summary>Find the player's face in the frame.</summary>
        /// <param name="frame">The camera frame.</param>
        /// <param name="hintX">The x of the player's head from the pose, if known.</param>
        /// <param name="hintY">The y of the player's head from the pose, if known.</param>
        public FaceSnapshot Track(Frame frame, float? hintX = null, float? hintY = null)
        {
            var stopwatch = Stopwatch.StartNew();

            if (!WantHands && _following != null && frame.Timestamp - _detectedAt < RecheckEvery)
            {
                var followed = _faces.DetectOne(frame, _following.Value);
                if (followed != null)
                {
                    var square = followed.Box.ExpandToSquare(FollowScale);
                    _following = square;
                    _previous = square;
                    _previousAt = frame.Timestamp;
                    return Snapshot(frame, square, followed, -1, null, stopwatch);
                }
            }

            _heads.Detect(frame, _found);
            _headCount = _found.Count;
            _detectedAt = frame.Timestamp;

            float? x = hintX;
            float? y = hintY;
            if ((x == null || y == null) && _previous != null && frame.Timestamp - _previousAt <= FollowFor)
            {
                x = _previous.Value.CenterX;
                y = _previous.Value.CenterY;
            }

            var head = Pick(_found, x, y);

            FaceLandmarks? face = null;
            if (head != null)
            {
                face = _faces.DetectOne(frame, head.Value);
                _previous = head;
                _previousAt = frame.Timestamp;
            }

            _following = face?.Box.ExpandToSquare(FollowScale);
            var hands = new List<BoundingBox>(_heads.Hands.Count);
            foreach (var hand in _heads.Hands)
            {
                hands.Add(hand.Box);
            }
            return Snapshot(frame, head, face, _headCount, hands, stopwatch);
        }

        private static FaceSnapshot Snapshot(
            Frame frame,
            BoundingBox? head,
            FaceLandmarks? face,
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
                Head = head,
                Face = face,
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
