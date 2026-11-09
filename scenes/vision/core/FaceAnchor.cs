using System;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>
    /// Hold where to draw the rider's looks over the player's face: the point
    /// between the eyes, the distance between the eyes and the tilt of the head.
    /// </summary>
    /// <remarks>
    /// The anchor is in the pixels of the <em>mirrored</em> frame, as the player
    /// sees herself, so that the game can draw on it directly.
    /// </remarks>
    public readonly struct FaceAnchor
    {
        public readonly float X;
        public readonly float Y;

        /// <summary>The distance between the eyes, in pixels; the unit of the overlay.</summary>
        public readonly float EyeDistance;

        /// <summary>The tilt of the head in radians, clockwise on the screen.</summary>
        public readonly float Angle;

        public FaceAnchor(float x, float y, float eyeDistance, float angle)
        {
            X = x;
            Y = y;
            EyeDistance = eyeDistance;
            Angle = angle;
        }

        /// <summary>Compute the anchor from the landmarks of the (not mirrored) frame.</summary>
        public static FaceAnchor FromLandmarks(FaceLandmarks face, int frameWidth)
        {
            // NOTE (mristin):
            // We mirror the x axis. In the mirrored picture, the person's right eye
            // is on the right, so the vector from the left eye to the right eye
            // points to the right of the screen when the head is upright.
            float rightX = frameWidth - face.RightEyeX;
            float leftX = frameWidth - face.LeftEyeX;
            float dx = rightX - leftX;
            float dy = face.RightEyeY - face.LeftEyeY;
            return new FaceAnchor(
                (rightX + leftX) * 0.5f,
                (face.RightEyeY + face.LeftEyeY) * 0.5f,
                MathF.Sqrt(dx * dx + dy * dy),
                MathF.Atan2(dy, dx)
            );
        }
    }

    /// <summary>
    /// Smooth the face anchor over time, hold it briefly when the face is lost,
    /// and fade it out after that.
    /// </summary>
    public sealed class FaceAnchorFilter
    {
        /// <summary>The time constant of the smoothing, in seconds.</summary>
        public double SmoothingTau = 0.04;

        /// <summary>Keep the anchor this long after the face was lost, in seconds.</summary>
        public double Hold = 0.25;

        /// <summary>Then fade it out over this long, in seconds.</summary>
        public double FadeOut = 0.25;

        /// <summary>A jump farther than this many eye distances snaps instead of gliding.</summary>
        public float SnapDistance = 3f;

        public FaceAnchor Anchor { get; private set; }

        /// <summary>How visible the overlay is, in [0, 1].</summary>
        public float Alpha { get; private set; }

        private bool _has;
        private double _lastObserved = double.NaN;
        private double _lastUpdate = double.NaN;
        private FaceAnchor _target;

        public void Observe(double t, FaceAnchor anchor)
        {
            _target = anchor;
            _lastObserved = t;
            if (!_has)
            {
                Anchor = anchor;
                _has = true;
                return;
            }

            float dx = anchor.X - Anchor.X;
            float dy = anchor.Y - Anchor.Y;
            if (MathF.Sqrt(dx * dx + dy * dy) > SnapDistance * Math.Max(1f, anchor.EyeDistance))
            {
                Anchor = anchor;
            }
        }

        public void Update(double t)
        {
            double dt = double.IsNaN(_lastUpdate) ? 0.0 : Math.Max(0.0, t - _lastUpdate);
            _lastUpdate = t;
            if (!_has)
            {
                Alpha = 0f;
                return;
            }

            float a = (float)(1.0 - Math.Exp(-dt / SmoothingTau));
            float angle = Anchor.Angle + WrapAngle(_target.Angle - Anchor.Angle) * a;
            Anchor = new FaceAnchor(
                Anchor.X + (_target.X - Anchor.X) * a,
                Anchor.Y + (_target.Y - Anchor.Y) * a,
                Anchor.EyeDistance + (_target.EyeDistance - Anchor.EyeDistance) * a,
                angle
            );

            double since = t - _lastObserved;
            Alpha = since <= Hold
                ? 1f
                : (float)Math.Clamp(1.0 - (since - Hold) / FadeOut, 0.0, 1.0);
            if (Alpha <= 0f)
            {
                _has = false;
            }
        }

        private static float WrapAngle(float angle)
        {
            while (angle > MathF.PI)
            {
                angle -= 2f * MathF.PI;
            }

            while (angle < -MathF.PI)
            {
                angle += 2f * MathF.PI;
            }

            return angle;
        }
    }
}  // namespace SteppeRescue.Vision
