using System;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>Enumerate the gaits of the horse, from the slowest.</summary>
    public enum Gait
    {
        Stand = 0,
        Walk = 1,
        Trot = 2,
        Gallop = 3,
    }

    /// <summary>
    /// Count the squats from the height of the head over time, and turn their
    /// rate and depth into the speed of the horse.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The depth is measured in the unit of the player (see
    /// <see cref="Pose.Unit"/>), below the standing height of the head. The
    /// standing height follows the highest head: it jumps up at once, and sinks
    /// only slowly, so that a slow squat does not drag it down, while a player
    /// who steps closer to the camera is followed after a few seconds.
    /// </para>
    /// <para>
    /// A squat counts when the head went down at least by
    /// <see cref="CountDepth"/> and came back up within <see cref="ReturnDepth"/>
    /// of the standing height. The time since the previous squat (the period) sets
    /// the target speed (see <see cref="SpeedOfPeriod"/>), and a shallow squat
    /// counts a little less than a deep one. The horse then speeds up and slows
    /// down gently towards the target.
    /// </para>
    /// <para>
    /// The keyboard (and the tests) can register a squat directly with
    /// <see cref="RegisterSquat"/>, which goes through the same rules.
    /// </para>
    /// </remarks>
    public sealed class SquatMeter
    {
        /// <summary>The time constant of smoothing the height of the head, in seconds.</summary>
        public double SmoothingTau = 0.08;

        /// <summary>How fast the standing height sinks, in units per second.</summary>
        public float BaselineSink = 0.1f;

        /// <summary>The head must go down at least this much (in units) for a squat to count.</summary>
        public float CountDepth = 0.5f;

        /// <summary>A squat this deep (in units) or deeper counts in full.</summary>
        public float FullDepth = 1.0f;

        /// <summary>The squat ends when the head comes back within this much (in units).</summary>
        public float ReturnDepth = 0.2f;

        /// <summary>The period which we assume before the first squat, in seconds.</summary>
        public double FirstPeriod = 3.0;

        /// <summary>After this long without a squat (in seconds), the horse stops.</summary>
        public double MaxPause = 4.5;

        /// <summary>
        /// A squat may come this late (in seconds) before the horse slows down, so
        /// that it keeps its momentum between the squats.
        /// </summary>
        public double Grace = 0.75;

        /// <summary>How fast the horse speeds up to a walk, in the full speed per second.</summary>
        public float Acceleration = 0.35f;

        /// <summary>
        /// How fast the horse speeds up beyond the walk, in the full speed per second,
        /// so that it takes a few brisk squats, not two, to gallop.
        /// </summary>
        public float FastAcceleration = 0.18f;

        /// <summary>How fast the horse slows down, in the full speed per second.</summary>
        public float Deceleration = 0.6f;

        /// <summary>
        /// How fast a galloping horse slows down, in the full speed per second: it
        /// keeps its momentum for a moment, and then stops at <see cref="Deceleration"/>.
        /// </summary>
        public float GallopDeceleration = 0.25f;

        /// <summary>A shallow squat (at <see cref="CountDepth"/>) counts this much.</summary>
        public float ShallowFactor = 0.6f;

        /// <summary>The speed of the horse in [0, 1].</summary>
        public float Speed { get; private set; }

        /// <summary>The speed which the horse is heading to, in [0, 1].</summary>
        public float TargetSpeed { get; private set; }

        /// <summary>How deep the head is now, in [0, 1] of <see cref="FullDepth"/>.</summary>
        public float Depth { get; private set; }

        /// <summary>How deep the head is now below the standing height, in units.</summary>
        public float RawDepth { get; private set; }

        /// <summary>How many squats were counted.</summary>
        public int Count { get; private set; }

        /// <summary>The time between the last two squats, in seconds.</summary>
        public double Period { get; private set; } = double.NaN;

        /// <summary>Whether the head went deep enough for the current squat to count.</summary>
        public bool IsDown { get; private set; }

        private double _smoothedY = double.NaN;
        private double _baselineY = double.NaN;
        private double _lastObserved = double.NaN;
        private double _lastSquat = double.NaN;
        private double _lastUpdate = double.NaN;
        private float _deepest;
        private float _lastFactor = 1f;

        /// <summary>The horse walks from this speed on.</summary>
        public const float WalkFrom = 0.05f;

        /// <summary>The horse trots from this speed on.</summary>
        public const float TrotFrom = 0.45f;

        /// <summary>The horse gallops from this speed on.</summary>
        public const float GallopFrom = 0.8f;

        /// <summary>The gait of the horse at the given speed.</summary>
        public static Gait GaitOf(float speed)
        {
            if (speed < WalkFrom)
            {
                return Gait.Stand;
            }

            if (speed < TrotFrom)
            {
                return Gait.Walk;
            }

            return speed < GallopFrom ? Gait.Trot : Gait.Gallop;
        }

        /// <summary>The gait of the horse now.</summary>
        public Gait Gait => GaitOf(Speed);

        private static readonly (double Period, float Speed)[] _speedTable =
        {
            (1.2, 1.0f),
            (1.5, 0.85f),
            (2.0, 0.62f),
            (3.0, 0.35f),
            (4.0, 0.2f),
        };

        /// <summary>
        /// Map the time between two squats (in seconds) to the speed of a full,
        /// deep squatting: a squat every 3 s walks, every 2 s trots, and every
        /// 1.5 s or faster gallops.
        /// </summary>
        public static float SpeedOfPeriod(double period)
        {
            if (period <= _speedTable[0].Period)
            {
                return _speedTable[0].Speed;
            }

            for (int i = 1; i < _speedTable.Length; i++)
            {
                var (p1, s1) = _speedTable[i];
                if (period <= p1)
                {
                    var (p0, s0) = _speedTable[i - 1];
                    float t = (float)((period - p0) / (p1 - p0));
                    return s0 + (s1 - s0) * t;
                }
            }

            return _speedTable[^1].Speed;
        }

        /// <summary>
        /// Observe the height of the head (in frame pixels, growing downwards) and
        /// the unit of the player (in frame pixels) at the time <paramref name="t"/>.
        /// </summary>
        public void Observe(double t, float headY, float unit)
        {
            if (unit <= 0f || float.IsNaN(headY) || float.IsNaN(unit))
            {
                return;
            }

            // NOTE (mristin):
            // After a long gap (the player left the picture), we start afresh, so
            // that the standing height is not taken from a different position.
            if (double.IsNaN(_smoothedY) || t - _lastObserved > 1.0)
            {
                _smoothedY = headY;
                _baselineY = headY;
                IsDown = false;
                _deepest = 0f;
            }
            else
            {
                double dt = Math.Max(0.0, t - _lastObserved);
                double alpha = 1.0 - Math.Exp(-dt / SmoothingTau);
                _smoothedY += (headY - _smoothedY) * alpha;

                // NOTE (mristin):
                // The standing height jumps up with the head, but sinks only slowly.
                _baselineY = Math.Min(_smoothedY, _baselineY + BaselineSink * unit * dt);
            }

            _lastObserved = t;

            float depth = (float)((_smoothedY - _baselineY) / unit);
            RawDepth = depth;
            Depth = Math.Clamp(depth / FullDepth, 0f, 1f);

            if (depth >= CountDepth)
            {
                IsDown = true;
            }

            if (IsDown)
            {
                _deepest = Math.Max(_deepest, depth);
                if (depth <= ReturnDepth)
                {
                    RegisterSquat(t, _deepest);
                    IsDown = false;
                    _deepest = 0f;
                }
            }
        }

        /// <summary>
        /// Count a squat of the given depth (in units) at the time
        /// <paramref name="t"/>, e.g., from the keyboard.
        /// </summary>
        public void RegisterSquat(double t, float depth)
        {
            Period = double.IsNaN(_lastSquat) ? FirstPeriod : Math.Max(0.05, t - _lastSquat);
            _lastSquat = t;
            Count++;

            float over = Math.Clamp((depth - CountDepth) / Math.Max(1e-3f, FullDepth - CountDepth), 0f, 1f);
            _lastFactor = ShallowFactor + (1f - ShallowFactor) * over;
        }

        /// <summary>Advance the speed of the horse to the time <paramref name="t"/>.</summary>
        public void Update(double t)
        {
            double dt = double.IsNaN(_lastUpdate) ? 0.0 : Math.Max(0.0, t - _lastUpdate);
            _lastUpdate = t;

            if (double.IsNaN(_lastSquat))
            {
                TargetSpeed = 0f;
            }
            else
            {
                double since = t - _lastSquat;

                // NOTE (mristin):
                // While no new squat comes, the period effectively grows (after the
                // grace), so the horse slows down gradually instead of keeping its pace.
                double period = Math.Max(Period, since - Grace);
                TargetSpeed = since > MaxPause ? 0f : SpeedOfPeriod(period) * _lastFactor;
            }

            float rate = TargetSpeed > Speed
                ? Speed < WalkFrom + 0.1f ? Acceleration : FastAcceleration
                : Speed > GallopFrom ? GallopDeceleration : Deceleration;
            float step = rate * (float)dt;
            Speed = TargetSpeed > Speed
                ? Math.Min(TargetSpeed, Speed + step)
                : Math.Max(TargetSpeed, Speed - step);
        }

        /// <summary>Forget everything, e.g., at the start of a level.</summary>
        public void Reset()
        {
            Speed = 0f;
            TargetSpeed = 0f;
            Depth = 0f;
            RawDepth = 0f;
            Count = 0;
            Period = double.NaN;
            IsDown = false;
            _smoothedY = double.NaN;
            _baselineY = double.NaN;
            _lastObserved = double.NaN;
            _lastSquat = double.NaN;
            _lastUpdate = double.NaN;
            _deepest = 0f;
            _lastFactor = 1f;
        }
    }
}  // namespace SteppeRescue.Vision
