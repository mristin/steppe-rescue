using System;
using System.Collections.Generic;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>Enumerate the 17 COCO key points, in the order of the model's output.</summary>
    /// <remarks>
    /// "Left" and "right" are those of the person: the right wrist of a person
    /// facing the camera is on the left of the (not mirrored) frame.
    /// </remarks>
    public enum BodyPart
    {
        Nose = 0,
        LeftEye = 1,
        RightEye = 2,
        LeftEar = 3,
        RightEar = 4,
        LeftShoulder = 5,
        RightShoulder = 6,
        LeftElbow = 7,
        RightElbow = 8,
        LeftWrist = 9,
        RightWrist = 10,
        LeftHip = 11,
        RightHip = 12,
        LeftKnee = 13,
        RightKnee = 14,
        LeftAnkle = 15,
        RightAnkle = 16,
    }

    /// <summary>Hold a key point in the pixels of the (not mirrored) frame.</summary>
    public readonly struct Keypoint
    {
        public readonly float X;
        public readonly float Y;
        public readonly float Score;

        public Keypoint(float x, float y, float score)
        {
            X = x;
            Y = y;
            Score = score;
        }

        public override string ToString() => $"({X:F1}, {Y:F1}) {Score:F2}";
    }

    /// <summary>Hold the pose of one person as found in a frame.</summary>
    public sealed class Pose
    {
        public const int KeypointCount = 17;

        /// <summary>The key points, indexed by <see cref="BodyPart"/>.</summary>
        public readonly Keypoint[] Keypoints;

        /// <summary>The box of the person in the frame.</summary>
        public readonly BoundingBox Box;

        /// <summary>How sure the model is that this is a person.</summary>
        public readonly float Score;

        public Pose(Keypoint[] keypoints, BoundingBox box, float score)
        {
            if (keypoints.Length != KeypointCount)
            {
                throw new ArgumentException(
                    $"Expected {KeypointCount} key points, but got {keypoints.Length}.",
                    nameof(keypoints)
                );
            }

            Keypoints = keypoints;
            Box = box;
            Score = score;
        }

        public Keypoint this[BodyPart part] => Keypoints[(int)part];

        /// <summary>Check that the key point is confident enough to be used.</summary>
        public bool Has(BodyPart part, float threshold) => Keypoints[(int)part].Score >= threshold;

        private static readonly BodyPart[] _headParts =
        {
            BodyPart.Nose,
            BodyPart.LeftEye,
            BodyPart.RightEye,
            BodyPart.LeftEar,
            BodyPart.RightEar,
        };

        /// <summary>
        /// Compute the center of the head as the mean of its confident key points
        /// (the nose, the eyes and the ears), or null if none is confident.
        /// </summary>
        public (float X, float Y)? Head(float threshold)
        {
            float sumX = 0f;
            float sumY = 0f;
            int count = 0;
            foreach (var part in _headParts)
            {
                var keypoint = this[part];
                if (keypoint.Score >= threshold)
                {
                    sumX += keypoint.X;
                    sumY += keypoint.Y;
                    count++;
                }
            }

            return count == 0 ? null : (sumX / count, sumY / count);
        }

        /// <summary>
        /// Estimate the unit of length of this person in frame pixels: the width
        /// of the shoulders, or, if a shoulder is missing, a multiple of the
        /// distance between the ears or the eyes; null if none is available.
        /// </summary>
        /// <remarks>
        /// We measure every threshold in this unit, so that the game works whether
        /// the player stands close to the camera or far from it.
        /// </remarks>
        public float? Unit(float threshold)
        {
            float? Distance(BodyPart a, BodyPart b)
            {
                if (!Has(a, threshold) || !Has(b, threshold))
                {
                    return null;
                }

                float dx = this[a].X - this[b].X;
                float dy = this[a].Y - this[b].Y;
                float distance = MathF.Sqrt(dx * dx + dy * dy);
                return distance > 1f ? distance : null;
            }

            // NOTE (mristin):
            // The factors are the typical ratios for children and adults: the
            // shoulders are about twice as wide as the head (ear to ear), and the
            // ears are about twice as far apart as the eyes.
            return Distance(BodyPart.LeftShoulder, BodyPart.RightShoulder)
                ?? Distance(BodyPart.LeftEar, BodyPart.RightEar) * 2.2f
                ?? Distance(BodyPart.LeftEye, BodyPart.RightEye) * 4.4f;
        }
    }

    /// <summary>
    /// Assign the persons to the players by the half of the picture, as in Bird
    /// Dog and Ergo Chaos: with two players, each plays in their own half.
    /// </summary>
    /// <remarks>
    /// The players see the picture mirrored, so player 0, who plays the left
    /// half of the screen, stands in the right half of the (not mirrored) frame.
    /// </remarks>
    public static class PlayerSplit
    {
        /// <summary>The most players who play together.</summary>
        public const int MaxPlayers = 2;

        /// <summary>The player whose half holds the point of the (not mirrored) frame.</summary>
        public static int PlayerOf(float x, int frameWidth, int playerCount)
        {
            if (playerCount <= 1)
            {
                return 0;
            }

            float mirrored = 1f - x / Math.Max(1, frameWidth);
            return mirrored < 0.5f ? 0 : 1;
        }

        /// <summary>
        /// The middle of the part of the frame of the player, as a fraction of the
        /// width of the (not mirrored) frame.
        /// </summary>
        public static float MiddleOf(int player, int playerCount)
        {
            if (playerCount <= 1)
            {
                return 0.5f;
            }

            return player == 0 ? 0.75f : 0.25f;
        }
    }

    /// <summary>Pick the player among the persons in the frame.</summary>
    public static class PlayerSelection
    {
        /// <summary>
        /// Pick the person with a head and the largest unit (that is, the
        /// closest to the camera), preferring the one near the center; null if
        /// no person has a head.
        /// </summary>
        public static Pose? Pick(IReadOnlyList<Pose> poses, float threshold, int frameWidth)
        {
            return Pick(poses, threshold, frameWidth, 0, 1);
        }

        /// <summary>
        /// Pick the player among the persons whose heads are in the player's
        /// half of the frame (or anywhere, with one player): the one with the
        /// largest unit, preferring the one near the middle of the half; null if
        /// no person there has a head.
        /// </summary>
        public static Pose? Pick(
            IReadOnlyList<Pose> poses,
            float threshold,
            int frameWidth,
            int player,
            int playerCount
        )
        {
            Pose? best = null;
            float bestScore = float.NegativeInfinity;
            float middle = PlayerSplit.MiddleOf(player, playerCount) * frameWidth;
            foreach (var pose in poses)
            {
                var head = pose.Head(threshold);
                var unit = pose.Unit(threshold);
                if (head == null || unit == null)
                {
                    continue;
                }

                if (PlayerSplit.PlayerOf(head.Value.X, frameWidth, playerCount) != player)
                {
                    continue;
                }

                // NOTE (mristin):
                // We penalize the distance from the middle a little, so that a
                // parent standing next to the child does not steal the horse.
                float offCenter = MathF.Abs(head.Value.X - middle) / frameWidth;
                float score = unit.Value * (1f - 0.5f * offCenter);
                if (score > bestScore)
                {
                    bestScore = score;
                    best = pose;
                }
            }

            return best;
        }
    }
}  // namespace SteppeRescue.Vision
