using System;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>
    /// Measure the height of the player's head and the unit of the player from
    /// the face tracker alone, for the <see cref="SquatMeter"/>: the squats then
    /// follow the head on every frame, and do not need the body pose.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The face tracker gives the landmarks of the face on most frames, and only
    /// the box of the head when the face is lost (e.g., when the player looks
    /// down in a deep squat). The height is the one of the eyes, and the unit is
    /// a multiple of the distance between the eyes, as in
    /// <see cref="Pose.Unit"/>, so that the thresholds of the squats stay the
    /// same.
    /// </para>
    /// <para>
    /// The box of the head sits differently on the head than the eyes. Whenever
    /// the head detector and the landmarks saw the same head in a frame, we learn
    /// where the eyes are in the box and how the unit relates to its width, so
    /// that the height does not jump when the tracker switches between them
    /// (which would count a squat that never was).
    /// </para>
    /// </remarks>
    public sealed class HeadGauge
    {
        /// <summary>The shoulders are about this many distances between the eyes wide.</summary>
        public const float UnitPerEyeDistance = 4.4f;

        /// <summary>How much of the difference a calibration takes over, in [0, 1].</summary>
        public float Learning = 0.2f;

        /// <summary>The time constant of smoothing the unit, in seconds.</summary>
        public double UnitTau = 0.5;

        /// <summary>The eyes below the center of the head box, in its heights.</summary>
        public float EyesBelowCenter { get; private set; } = 0f;

        /// <summary>The unit in the widths of the head box.</summary>
        public float UnitPerHeadWidth { get; private set; } = 2f;

        /// <summary>The x of the middle between the eyes in the frame (pixels), or NaN.</summary>
        public float X { get; private set; } = float.NaN;

        /// <summary>The height of the eyes in the frame (pixels, growing downwards), or NaN.</summary>
        public float Y { get; private set; } = float.NaN;

        /// <summary>The unit of the player in frame pixels, or NaN.</summary>
        public float Unit { get; private set; } = float.NaN;

        private double _measuredAt = double.NaN;

        /// <summary>
        /// Measure the head at the time <paramref name="t"/> from the landmarks
        /// of the face, if found, else from the box of the head, if found.
        /// </summary>
        /// <param name="t">The time of the frame, in seconds.</param>
        /// <param name="face">The landmarks of the face, or null.</param>
        /// <param name="head">The box of the head, or null.</param>
        /// <param name="detected">
        /// Whether the head detector found <paramref name="head"/> in this frame
        /// (and it is not merely the square around the face which we follow).
        /// </param>
        /// <returns>Whether the head was measured.</returns>
        public bool Measure(double t, FaceLandmarks? face, BoundingBox? head, bool detected)
        {
            float x;
            float y;
            float unit;
            if (face != null)
            {
                float dx = face.RightEyeX - face.LeftEyeX;
                float dy = face.RightEyeY - face.LeftEyeY;
                float eyes = MathF.Sqrt(dx * dx + dy * dy);
                if (eyes <= 1f)
                {
                    return false;
                }

                x = (face.RightEyeX + face.LeftEyeX) * 0.5f;
                y = (face.RightEyeY + face.LeftEyeY) * 0.5f;
                unit = eyes * UnitPerEyeDistance;

                if (detected && head != null && !head.Value.IsEmpty)
                {
                    var box = head.Value;
                    EyesBelowCenter += ((y - box.CenterY) / box.Height - EyesBelowCenter) * Learning;
                    UnitPerHeadWidth += (unit / box.Width - UnitPerHeadWidth) * Learning;
                }
            }
            else if (head != null && !head.Value.IsEmpty)
            {
                var box = head.Value;
                x = box.CenterX;
                y = box.CenterY + EyesBelowCenter * box.Height;
                unit = box.Width * UnitPerHeadWidth;
            }
            else
            {
                return false;
            }

            // NOTE (mristin):
            // The unit is smoothed, since the distance between the eyes shrinks a
            // little whenever the player turns her head. After a gap, we start
            // afresh, as the squat meter does.
            if (float.IsNaN(Unit) || double.IsNaN(_measuredAt) || t - _measuredAt > 1.0)
            {
                Unit = unit;
            }
            else
            {
                double alpha = 1.0 - Math.Exp(-Math.Max(0.0, t - _measuredAt) / UnitTau);
                Unit += (float)((unit - Unit) * alpha);
            }

            X = x;
            Y = y;
            _measuredAt = t;
            return true;
        }
    }
}  // namespace SteppeRescue.Vision
