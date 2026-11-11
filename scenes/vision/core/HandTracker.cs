using System;
using System.Collections.Generic;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>Enumerate the sides of the body, of the player herself.</summary>
    public enum HandSide
    {
        Left = 0,
        Right = 1,
    }

    /// <summary>
    /// Follow the hands of the players on every frame of the hand detector, and
    /// tell whose hand each is, and which: the left or the right.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The hand detector (YOLOX) finds the hands on every frame, but not whose
    /// they are. The body pose knows it, from the wrists, but it is too slow to
    /// run on every frame, so it runs only a few times a second. Whenever a pose
    /// comes, we match its wrists to the hands which the detector found in the
    /// same frame; between the poses, each hand follows the nearest hand of the
    /// next frame.
    /// </para>
    /// <para>
    /// The pose comes later than the frame it saw. We therefore keep the hands of
    /// the last frames, match the pose in its own frame, and follow the hands
    /// again from there up to now.
    /// </para>
    /// <para>
    /// The positions are in the pixels of the (not mirrored) frame. The distances
    /// are measured in the unit of each player (see <see cref="Pose.Unit"/>).
    /// </para>
    /// </remarks>
    public sealed class HandTracker
    {
        /// <summary>A hand moves at most this far (in units) from one frame to the next.</summary>
        public float Gate = 0.6f;

        /// <summary>A hand of the detector is this close (in units) to where the pose expects it.</summary>
        public float PoseGate = 0.8f;

        /// <summary>We keep a hand this long (in seconds) after the detector lost it.</summary>
        public double Keep = 0.3;

        /// <summary>We keep the frames this long (in seconds), to match the poses which come late.</summary>
        public double History = 1.0;

        /// <summary>A pose matches a frame this close in time (in seconds).</summary>
        public double SameFrame = 0.1;

        /// <summary>
        /// The middle of the hand is this far beyond the wrist, as a share of the
        /// forearm.
        /// </summary>
        public float WristToHand = 0.3f;

        /// <summary>Use only the key points of the pose of at least this score.</summary>
        public float KeypointThreshold = 0.5f;

        private struct Track
        {
            public bool Has;
            public float X;
            public float Y;
            public double SeenAt;
        }

        private sealed class Step
        {
            public double T;
            public BoundingBox[] Hands = Array.Empty<BoundingBox>();

            /// <summary>The tracks after this frame.</summary>
            public Track[] Tracks = Array.Empty<Track>();
        }

        private Track[] _tracks = new Track[PlayerSplit.MaxPlayers * 2];
        private readonly float[] _units = { float.NaN, float.NaN };
        private readonly List<Step> _steps = new();

        private static int Index(int player, HandSide side) => player * 2 + (int)side;

        /// <summary>Set the unit of the player in frame pixels (e.g., from the <see cref="HeadGauge"/>).</summary>
        public void SetUnit(int player, float unit)
        {
            if (player >= 0 && player < _units.Length)
            {
                _units[player] = unit;
            }
        }

        private float UnitOf(int track)
        {
            float unit = _units[track / 2];
            return float.IsNaN(unit) || unit <= 0f ? 100f : unit;
        }

        /// <summary>Forget all the hands.</summary>
        public void Reset()
        {
            _tracks = new Track[PlayerSplit.MaxPlayers * 2];
            _steps.Clear();
        }

        /// <summary>Observe the hands which the detector found in the frame of the time <paramref name="t"/>.</summary>
        public void Observe(double t, IReadOnlyList<BoundingBox> hands)
        {
            var copy = new BoundingBox[hands.Count];
            for (int i = 0; i < copy.Length; i++)
            {
                copy[i] = hands[i];
            }

            Follow(_tracks, t, copy);
            _steps.Add(new Step { T = t, Hands = copy, Tracks = (Track[])_tracks.Clone() });
            while (_steps.Count > 0 && t - _steps[0].T > History)
            {
                _steps.RemoveAt(0);
            }
        }

        /// <summary>Follow each hand to the nearest hand of the frame, the nearest pairs first.</summary>
        private void Follow(Track[] tracks, double t, BoundingBox[] hands)
        {
            var pairs = new List<(float Cost, int Track, int Hand)>();
            for (int i = 0; i < tracks.Length; i++)
            {
                if (!tracks[i].Has || t - tracks[i].SeenAt > Keep)
                {
                    continue;
                }

                float unit = UnitOf(i);
                for (int j = 0; j < hands.Length; j++)
                {
                    float dx = hands[j].CenterX - tracks[i].X;
                    float dy = hands[j].CenterY - tracks[i].Y;
                    float cost = MathF.Sqrt(dx * dx + dy * dy) / unit;
                    if (cost <= Gate)
                    {
                        pairs.Add((cost, i, j));
                    }
                }
            }

            Assign(tracks, t, hands, pairs);
        }

        private static void Assign(
            Track[] tracks, double t, BoundingBox[] hands, List<(float Cost, int Track, int Hand)> pairs
        )
        {
            pairs.Sort((a, b) => a.Cost.CompareTo(b.Cost));
            var trackDone = new bool[tracks.Length];
            var handDone = new bool[hands.Length];
            foreach (var (_, track, hand) in pairs)
            {
                if (trackDone[track] || handDone[hand])
                {
                    continue;
                }

                trackDone[track] = true;
                handDone[hand] = true;
                tracks[track] = new Track
                {
                    Has = true,
                    X = hands[hand].CenterX,
                    Y = hands[hand].CenterY,
                    SeenAt = t,
                };
            }
        }

        /// <summary>
        /// Where the pose expects the middle of the hand: a little beyond the wrist,
        /// along the forearm; null if the wrist is not seen.
        /// </summary>
        public (float X, float Y)? Expected(Pose pose, HandSide side)
        {
            var wristPart = side == HandSide.Left ? BodyPart.LeftWrist : BodyPart.RightWrist;
            var elbowPart = side == HandSide.Left ? BodyPart.LeftElbow : BodyPart.RightElbow;
            if (!pose.Has(wristPart, KeypointThreshold))
            {
                return null;
            }

            var wrist = pose[wristPart];
            if (!pose.Has(elbowPart, KeypointThreshold))
            {
                return (wrist.X, wrist.Y);
            }

            var elbow = pose[elbowPart];
            return (wrist.X + (wrist.X - elbow.X) * WristToHand, wrist.Y + (wrist.Y - elbow.Y) * WristToHand);
        }

        /// <summary>
        /// Observe the poses of the players (null for a player not seen) in the
        /// frame of the time <paramref name="t"/>: tell the hands of that frame
        /// apart by their wrists, and follow them again up to now.
        /// </summary>
        public void ObservePoses(double t, IReadOnlyList<Pose?> poses)
        {
            int at = -1;
            double best = SameFrame;
            for (int i = 0; i < _steps.Count; i++)
            {
                double dt = Math.Abs(_steps[i].T - t);
                if (dt <= best)
                {
                    best = dt;
                    at = i;
                }
            }

            if (at < 0)
            {
                return;
            }

            var step = _steps[at];
            var tracks = (Track[])step.Tracks.Clone();
            var pairs = new List<(float Cost, int Track, int Hand)>();
            for (int player = 0; player < poses.Count && player < PlayerSplit.MaxPlayers; player++)
            {
                var pose = poses[player];
                if (pose == null)
                {
                    continue;
                }

                foreach (var side in new[] { HandSide.Left, HandSide.Right })
                {
                    int index = Index(player, side);

                    // NOTE (mristin):
                    // The pose decides about the hands of its player: a hand which
                    // it does not match is not hers.
                    tracks[index] = default;
                    var expected = Expected(pose, side);
                    if (expected == null)
                    {
                        continue;
                    }

                    float unit = UnitOf(index);
                    for (int j = 0; j < step.Hands.Length; j++)
                    {
                        float dx = step.Hands[j].CenterX - expected.Value.X;
                        float dy = step.Hands[j].CenterY - expected.Value.Y;
                        float cost = MathF.Sqrt(dx * dx + dy * dy) / unit;
                        if (cost <= PoseGate)
                        {
                            pairs.Add((cost, index, j));
                        }
                    }
                }
            }

            Assign(tracks, step.T, step.Hands, pairs);
            step.Tracks = (Track[])tracks.Clone();

            for (int i = at + 1; i < _steps.Count; i++)
            {
                Follow(tracks, _steps[i].T, _steps[i].Hands);
                _steps[i].Tracks = (Track[])tracks.Clone();
            }

            _tracks = tracks;
        }

        /// <summary>The middle of the hand of the player at the time <paramref name="now"/>, or null if unknown.</summary>
        public (float X, float Y)? Hand(int player, HandSide side, double now)
        {
            if (player < 0 || player >= PlayerSplit.MaxPlayers)
            {
                return null;
            }

            var track = _tracks[Index(player, side)];
            if (!track.Has || now - track.SeenAt > Keep)
            {
                return null;
            }

            return (track.X, track.Y);
        }
    }
}  // namespace SteppeRescue.Vision
