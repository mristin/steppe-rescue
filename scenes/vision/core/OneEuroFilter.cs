using System;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>
    /// Smooth a noisy point with little lag: the faster it moves, the less we
    /// smooth (Casiez, Roussel and Vogel, "1€ Filter", CHI 2012), as the hand
    /// cursor of the menus does.
    /// </summary>
    /// <remarks>
    /// The speed is measured in the unit of the player (see
    /// <see cref="Pose.Unit"/>) per second, so that the filter behaves the same
    /// whether she stands close to the camera or far from it.
    /// </remarks>
    public sealed class OneEuroFilter
    {
        /// <summary>The cutoff of a still point, in Hz: lower smooths more.</summary>
        public double MinCutoff = 1.0;

        /// <summary>How much the cutoff rises with the speed, in Hz per unit per second.</summary>
        public double Beta = 0.7;

        /// <summary>The cutoff of the speed itself, in Hz.</summary>
        public double DerivativeCutoff = 1.0;

        private double _x = double.NaN;
        private double _y = double.NaN;
        private double _speed;
        private double _last = double.NaN;

        /// <summary>Forget the point, e.g., when it was lost.</summary>
        public void Reset()
        {
            _x = double.NaN;
            _y = double.NaN;
            _speed = 0.0;
            _last = double.NaN;
        }

        /// <summary>Filter the point (x, y) seen at the time <paramref name="t"/>, of a player of the unit.</summary>
        public (float X, float Y) Filter(double t, float x, float y, float unit)
        {
            if (double.IsNaN(_last) || double.IsNaN(_x))
            {
                _x = x;
                _y = y;
                _last = t;
                return (x, y);
            }

            double dt = t - _last;
            if (dt <= 1e-6)
            {
                return ((float)_x, (float)_y);
            }

            _last = t;
            double scale = unit > 0f && !float.IsNaN(unit) ? unit : 100.0;
            double dx = x - _x;
            double dy = y - _y;
            double speed = Math.Sqrt(dx * dx + dy * dy) / scale / dt;
            _speed += Alpha(DerivativeCutoff, dt) * (speed - _speed);
            double alpha = Alpha(MinCutoff + Beta * _speed, dt);
            _x += alpha * dx;
            _y += alpha * dy;
            return ((float)_x, (float)_y);
        }

        private static double Alpha(double cutoff, double dt)
        {
            double tau = 1.0 / (2.0 * Math.PI * cutoff);
            return 1.0 / (1.0 + tau / dt);
        }
    }
}  // namespace SteppeRescue.Vision
