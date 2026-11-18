using System;
using System.Collections.Generic;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>Enumerate the joints of the body which the rider's clothes are drawn on.</summary>
    public enum Joint
    {
        LeftShoulder = 0,
        RightShoulder = 1,
        LeftElbow = 2,
        RightElbow = 3,
        LeftHand = 4,
        RightHand = 5,
        LeftHip = 6,
        RightHip = 7,
        LeftKnee = 8,
        RightKnee = 9,
        LeftAnkle = 10,
        RightAnkle = 11,
    }

    /// <summary>
    /// Follow the body of the player on every frame, to dress her as her rider
    /// in the camera picture, although the pose comes only a few times a second.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The head is followed on every frame (see <see cref="HeadGauge"/>), and
    /// the hands, too (see <see cref="HandTracker"/>). Between the poses, the
    /// body of the last pose moves with the head: the shoulders and the hips
    /// fully down and up (a squat lowers them as much as the head) but only
    /// halfway sideways (a turned head does not move the shoulders), the knees
    /// halfway, and the feet stay where they stand. The hands are where the
    /// detector sees them, and each elbow keeps its place in the arm: how far
    /// along the line from the shoulder to the hand and how far off it, as the
    /// poses saw it on average, so that it does not jump when a pose jitters.
    /// </para>
    /// <para>
    /// The pose jitters, the elbows most, so <see cref="Update"/> smooths every
    /// joint once a frame with a <see cref="OneEuroFilter"/>: a still body is
    /// smoothed much, a moving one little, so that it does not lag. The hands
    /// which the caller gives are taken as they are (they are smoothed already).
    /// </para>
    /// <para>The positions are in the pixels of the (not mirrored) frame.</para>
    /// </remarks>
    public sealed class BodyFollower
    {
        public const int JointCount = 12;

        /// <summary>The body shows fully this long (in seconds) after the pose...</summary>
        public double Hold = 0.6;

        /// <summary>...and then fades out over this long, in seconds.</summary>
        public double FadeOut = 0.4;

        /// <summary>Use only the key points of the pose of at least this score.</summary>
        public float KeypointThreshold = 0.5f;

        /// <summary>The middle of the hand lies this far beyond the wrist, as a share of the forearm.</summary>
        public float WristToHand = 0.3f;

        /// <summary>Between the poses, the body follows this share of the head's moves sideways.</summary>
        public float SidewaysShare = 0.5f;

        /// <summary>How much of the elbow of a new pose is taken over, when it moved a little.</summary>
        public float ElbowLearning = 0.35f;

        /// <summary>The elbow moved this much in the arm (in its length) when the arm bent.</summary>
        public float ElbowBend = 0.35f;

        /// <summary>The elbow lies at most this far off the line from the shoulder to the hand.</summary>
        public float ElbowMaxOff = 0.6f;

        /// <summary>
        /// Where the elbow lies in each arm (left, right): along the line from the
        /// shoulder to the hand, and off it to the side, in its length.
        /// </summary>
        private readonly (float Along, float Off)?[] _elbowInArm = new (float Along, float Off)?[2];

        /// <summary>The joints of the last <see cref="Update"/>, smoothed; null where not seen.</summary>
        public (float X, float Y)?[] Smoothed { get; private set; } = new (float X, float Y)?[JointCount];

        private readonly OneEuroFilter[] _filters = new OneEuroFilter[JointCount];

        public BodyFollower()
        {
            for (int i = 0; i < JointCount; i++)
            {
                bool elbow = i == (int)Joint.LeftElbow || i == (int)Joint.RightElbow;
                bool trunk = i <= (int)Joint.RightShoulder || i == (int)Joint.LeftHip || i == (int)Joint.RightHip;
                _filters[i] = new OneEuroFilter
                {
                    MinCutoff = elbow ? 0.6 : trunk ? 0.6 : 0.8,
                    Beta = elbow ? 0.4 : trunk ? 0.4 : 0.5,
                };
            }
        }

        private readonly List<(double T, float X, float Y)> _heads = new();
        private readonly (float X, float Y)?[] _posed = new (float X, float Y)?[JointCount];
        private (float X, float Y)? _headAtPose;
        private double _poseAt = double.NaN;

        /// <summary>Observe the head of the player at the time <paramref name="t"/>.</summary>
        public void ObserveHead(double t, float x, float y)
        {
            _heads.Add((t, x, y));
            while (_heads.Count > 0 && t - _heads[0].T > 1.5)
            {
                _heads.RemoveAt(0);
            }
        }

        private (float X, float Y)? HeadAt(double t)
        {
            (float X, float Y)? best = null;
            double bestDt = 0.15;
            foreach (var (time, x, y) in _heads)
            {
                double dt = Math.Abs(time - t);
                if (dt <= bestDt)
                {
                    bestDt = dt;
                    best = (x, y);
                }
            }

            return best;
        }

        /// <summary>Observe the pose of the player in the frame of the time <paramref name="t"/>.</summary>
        public void ObservePose(double t, Pose pose)
        {
            (float X, float Y)? Point(BodyPart part)
            {
                return pose.Has(part, KeypointThreshold) ? (pose[part].X, pose[part].Y) : null;
            }

            _posed[(int)Joint.LeftShoulder] = Point(BodyPart.LeftShoulder);
            _posed[(int)Joint.RightShoulder] = Point(BodyPart.RightShoulder);
            _posed[(int)Joint.LeftElbow] = Point(BodyPart.LeftElbow);
            _posed[(int)Joint.RightElbow] = Point(BodyPart.RightElbow);
            _posed[(int)Joint.LeftHip] = Point(BodyPart.LeftHip);
            _posed[(int)Joint.RightHip] = Point(BodyPart.RightHip);
            _posed[(int)Joint.LeftKnee] = Point(BodyPart.LeftKnee);
            _posed[(int)Joint.RightKnee] = Point(BodyPart.RightKnee);
            _posed[(int)Joint.LeftAnkle] = Point(BodyPart.LeftAnkle);
            _posed[(int)Joint.RightAnkle] = Point(BodyPart.RightAnkle);
            _posed[(int)Joint.LeftHand] = HandOf(
                Point(BodyPart.LeftWrist), _posed[(int)Joint.LeftElbow]
            );
            _posed[(int)Joint.RightHand] = HandOf(
                Point(BodyPart.RightWrist), _posed[(int)Joint.RightElbow]
            );

            _poseAt = t;
            _headAtPose = HeadAt(t) ?? pose.Head(KeypointThreshold);
            LearnElbow(0, Joint.LeftShoulder, Joint.LeftElbow, Joint.LeftHand);
            LearnElbow(1, Joint.RightShoulder, Joint.RightElbow, Joint.RightHand);
        }

        private (float X, float Y)? HandOf((float X, float Y)? wrist, (float X, float Y)? elbow)
        {
            if (wrist == null || elbow == null)
            {
                return wrist;
            }

            var w = wrist.Value;
            var e = elbow.Value;
            return (w.X + (w.X - e.X) * WristToHand, w.Y + (w.Y - e.Y) * WristToHand);
        }

        /// <summary>How visible the body is at the time <paramref name="now"/>, in [0, 1].</summary>
        public float Alpha(double now)
        {
            if (double.IsNaN(_poseAt))
            {
                return 0f;
            }

            double age = now - _poseAt;
            if (age <= Hold)
            {
                return 1f;
            }

            return (float)Math.Clamp(1.0 - (age - Hold) / FadeOut, 0.0, 1.0);
        }

        /// <summary>
        /// Follow the body to the time <paramref name="t"/>, with the hands (each
        /// null if not seen, smoothed already), and smooth its joints (see
        /// <see cref="Smoothed"/>); <paramref name="unit"/> is the unit of the
        /// player in frame pixels.
        /// </summary>
        public void Update(double t, (float X, float Y)? leftHand, (float X, float Y)? rightHand, float unit)
        {
            var joints = Joints(leftHand, rightHand);
            var smoothed = new (float X, float Y)?[JointCount];
            for (int i = 0; i < JointCount; i++)
            {
                var joint = joints[i];
                if (joint == null)
                {
                    _filters[i].Reset();
                    continue;
                }

                bool seenHand = (i == (int)Joint.LeftHand && leftHand != null)
                    || (i == (int)Joint.RightHand && rightHand != null);
                if (seenHand)
                {
                    _filters[i].Reset();
                    smoothed[i] = joint;
                    continue;
                }

                smoothed[i] = _filters[i].Filter(t, joint.Value.X, joint.Value.Y, unit);
            }

            Smoothed = smoothed;
        }

        /// <summary>
        /// The joints of the body now (null for a joint not seen), with the hands
        /// of the <see cref="HandTracker"/> if it sees them, not smoothed.
        /// </summary>
        public (float X, float Y)?[] Joints((float X, float Y)? leftHand, (float X, float Y)? rightHand)
        {
            var result = new (float X, float Y)?[JointCount];
            if (double.IsNaN(_poseAt))
            {
                return result;
            }

            float dx = 0f;
            float dy = 0f;
            if (_headAtPose != null && _heads.Count > 0)
            {
                var now = _heads[^1];
                dx = now.X - _headAtPose.Value.X;
                dy = now.Y - _headAtPose.Value.Y;
            }

            (float X, float Y)? Moved(Joint joint, float share)
            {
                // NOTE (mristin):
                // A squat moves the body down with the head, but a turned or a
                // tilted head moves the shoulders only a little sideways.
                var point = _posed[(int)joint];
                return point == null
                    ? null
                    : (point.Value.X + dx * share * SidewaysShare, point.Value.Y + dy * share);
            }

            result[(int)Joint.LeftShoulder] = Moved(Joint.LeftShoulder, 1f);
            result[(int)Joint.RightShoulder] = Moved(Joint.RightShoulder, 1f);
            result[(int)Joint.LeftHip] = Moved(Joint.LeftHip, 1f);
            result[(int)Joint.RightHip] = Moved(Joint.RightHip, 1f);
            result[(int)Joint.LeftKnee] = Moved(Joint.LeftKnee, 0.5f);
            result[(int)Joint.RightKnee] = Moved(Joint.RightKnee, 0.5f);
            result[(int)Joint.LeftAnkle] = Moved(Joint.LeftAnkle, 0f);
            result[(int)Joint.RightAnkle] = Moved(Joint.RightAnkle, 0f);

            Arm(result, Joint.LeftShoulder, Joint.LeftElbow, Joint.LeftHand, leftHand);
            Arm(result, Joint.RightShoulder, Joint.RightElbow, Joint.RightHand, rightHand);
            return result;
        }

        /// <summary>
        /// Put the hand where it is seen (else where the pose had it, moved with
        /// the shoulder), and the elbow where it lies in the arm (see
        /// <see cref="_elbowInArm"/>) along the line from the shoulder to the hand.
        /// </summary>
        private void Arm(
            (float X, float Y)?[] result, Joint shoulderJoint, Joint elbowJoint, Joint handJoint,
            (float X, float Y)? seen
        )
        {
            var shoulder = result[(int)shoulderJoint];
            var posedShoulder = _posed[(int)shoulderJoint];
            var posedElbow = _posed[(int)elbowJoint];
            var posedHand = _posed[(int)handJoint];

            (float X, float Y)? hand = seen;
            if (hand == null && posedHand != null && shoulder != null && posedShoulder != null)
            {
                hand = (
                    posedHand.Value.X + shoulder.Value.X - posedShoulder.Value.X,
                    posedHand.Value.Y + shoulder.Value.Y - posedShoulder.Value.Y
                );
            }

            result[(int)handJoint] = hand;
            if (shoulder == null)
            {
                return;
            }

            var s = shoulder.Value;
            var inArm = _elbowInArm[shoulderJoint == Joint.LeftShoulder ? 0 : 1];
            if (hand != null && inArm != null)
            {
                float vx = hand.Value.X - s.X;
                float vy = hand.Value.Y - s.Y;
                var (along, off) = inArm.Value;
                result[(int)elbowJoint] = (s.X + along * vx - off * vy, s.Y + along * vy + off * vx);
                return;
            }

            if (posedShoulder != null && posedElbow != null)
            {
                var ps = posedShoulder.Value;
                var pe = posedElbow.Value;
                result[(int)elbowJoint] = (pe.X + s.X - ps.X, pe.Y + s.Y - ps.Y);
            }
        }

        /// <summary>
        /// Learn where the elbow of the pose lies in the arm: how far along the
        /// line from the shoulder to the hand, and how far off it to the side, in
        /// the length of that line, averaged over the poses.
        /// </summary>
        private void LearnElbow(int arm, Joint shoulderJoint, Joint elbowJoint, Joint handJoint)
        {
            var shoulder = _posed[(int)shoulderJoint];
            var elbow = _posed[(int)elbowJoint];
            var hand = _posed[(int)handJoint];
            if (shoulder == null || elbow == null || hand == null)
            {
                return;
            }

            float vx = hand.Value.X - shoulder.Value.X;
            float vy = hand.Value.Y - shoulder.Value.Y;
            float ex = elbow.Value.X - shoulder.Value.X;
            float ey = elbow.Value.Y - shoulder.Value.Y;
            float length2 = vx * vx + vy * vy;
            if (length2 < 4f)
            {
                return;
            }

            // NOTE (mristin):
            // The elbow divided by the arm, as complex numbers: it stays the same
            // while the arm moves as a whole, and changes only when it bends.
            float along = Math.Clamp((ex * vx + ey * vy) / length2, -0.2f, 1.2f);
            float off = Math.Clamp((vx * ey - vy * ex) / length2, -ElbowMaxOff, ElbowMaxOff);
            var known = _elbowInArm[arm];
            if (known == null)
            {
                _elbowInArm[arm] = (along, off);
                return;
            }

            // NOTE (mristin):
            // A small change is the jitter of the pose and is averaged away; a big
            // one is the arm bending, and is followed quickly.
            float change = MathF.Abs(along - known.Value.Along) + MathF.Abs(off - known.Value.Off);
            float rate = change > ElbowBend ? 0.7f : ElbowLearning;
            _elbowInArm[arm] = (
                known.Value.Along + (along - known.Value.Along) * rate,
                known.Value.Off + (off - known.Value.Off) * rate
            );
        }

        private static float Distance((float X, float Y) a, (float X, float Y) b)
        {
            float dx = a.X - b.X;
            float dy = a.Y - b.Y;
            return MathF.Sqrt(dx * dx + dy * dy);
        }
    }
}  // namespace SteppeRescue.Vision
