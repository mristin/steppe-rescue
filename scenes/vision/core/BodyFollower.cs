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
    /// fully (a squat lowers them as much as the head), the knees halfway, and
    /// the feet stay where they stand. The hands are where the detector sees
    /// them, and the elbows bend so that the arms keep their lengths.
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
        /// The joints of the body now (null for a joint not seen), with the hands
        /// of the <see cref="HandTracker"/> if it sees them.
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
                var point = _posed[(int)joint];
                return point == null ? null : (point.Value.X + dx * share, point.Value.Y + dy * share);
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
        /// the shoulder), and bend the elbow so that the arm keeps its lengths,
        /// to the same side as in the pose.
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
            if (shoulder == null || posedShoulder == null || posedElbow == null)
            {
                return;
            }

            var s = shoulder.Value;
            var ps = posedShoulder.Value;
            var pe = posedElbow.Value;
            if (hand == null || posedHand == null)
            {
                result[(int)elbowJoint] = (pe.X + s.X - ps.X, pe.Y + s.Y - ps.Y);
                return;
            }

            var h = hand.Value;
            var ph = posedHand.Value;
            float upper = Distance(ps, pe);
            float fore = Distance(pe, ph);
            float reach = Distance(s, h);
            if (upper < 1f || fore < 1f || reach < 1e-3f)
            {
                result[(int)elbowJoint] = (pe.X + s.X - ps.X, pe.Y + s.Y - ps.Y);
                return;
            }

            // NOTE (mristin):
            // The two-bone solution: the elbow lies on the circles around the
            // shoulder and the hand; a stretched arm reaches straight.
            float d = Math.Clamp(reach, Math.Abs(upper - fore) + 1e-3f, upper + fore - 1e-3f);
            float along = (upper * upper - fore * fore + d * d) / (2f * d);
            float off = MathF.Sqrt(MathF.Max(0f, upper * upper - along * along));
            float ux = (h.X - s.X) / reach;
            float uy = (h.Y - s.Y) / reach;

            float cross = (ph.X - ps.X) * (pe.Y - ps.Y) - (ph.Y - ps.Y) * (pe.X - ps.X);
            float sign = cross >= 0f ? 1f : -1f;

            // NOTE (mristin):
            // The perpendicular (-uy, ux) lies on the side of the positive cross
            // product, as the posed elbow does.
            result[(int)elbowJoint] = (s.X + ux * along - uy * off * sign, s.Y + uy * along + ux * off * sign);
        }

        private static float Distance((float X, float Y) a, (float X, float Y) b)
        {
            float dx = a.X - b.X;
            float dy = a.Y - b.Y;
            return MathF.Sqrt(dx * dx + dy * dy);
        }
    }
}  // namespace SteppeRescue.Vision
