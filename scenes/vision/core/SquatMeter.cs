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
    /// Turn the up and down of the head into the speed of the horse: the more
    /// the player squats, deeper and faster, the faster the horse.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The head goes down and up in swings. A swing counts once the head turned
    /// back by at least <see cref="SwingDepth"/> (in the unit of the player, see
    /// <see cref="Pose.Unit"/>, so that it does not matter how far from the
    /// camera she stands): it went down from its last top, or up from its last
    /// bottom. There is no standing height to compare with, since players
    /// bounce up higher than they stand when they squat fast. Each squat (a
    /// swing down and back up) is counted when the head came back up.
    /// </para>
    /// <para>
    /// Every swing adds its size to the <see cref="Effort"/>, which fades with
    /// <see cref="EffortTau"/>: so the effort is about how far the head travels
    /// up and down per second. Deeper squats and faster squats both make it
    /// bigger. It fades quickly once no swing came for <see cref="StopAfter"/>
    /// while the head is up, so that the horse stops when the player stands
    /// still (but not in the middle of a slow squat).
    /// </para>
    /// <para>
    /// The speed of the horse heads for the effort over <see cref="FullEffort"/>,
    /// in [0, 1], and the gaits split it (see <see cref="GaitOf"/>). The
    /// constants come from recordings of players (see dev/squats/): a walk
    /// moved the head about 0.7 to 1 units a second, a trot 1 to 1.6, and a
    /// gallop 2.1 to 2.4.
    /// </para>
    /// <para>
    /// The keyboard (and the tests) can register a squat with
    /// <see cref="RegisterSquat"/>: the effort of the keys goes with how often
    /// they come (see <see cref="KeyboardEffort"/>).
    /// </para>
    /// </remarks>
    public sealed class SquatMeter
    {
        /// <summary>The head must turn back this far (in units) for a swing to count.</summary>
        public float SwingDepth = 0.25f;

        /// <summary>The time constant (in seconds) with which the effort fades.</summary>
        public double EffortTau = 1.5;

        /// <summary>Without a swing for this long (in seconds), the effort fades quickly...</summary>
        public double StopAfter = 1.0;

        /// <summary>...with this time constant, in seconds.</summary>
        public double StopTau = 0.2;

        /// <summary>The effort (in units per second) at which the horse runs at full speed.</summary>
        public float FullEffort = 2.5f;

        /// <summary>The time constant (in seconds) with which the speed rises to the effort...</summary>
        public double SpeedTau = 0.25;

        /// <summary>...and falls to it, a little quicker, so that the horse stops promptly.</summary>
        public double SlowDownTau = 0.15;

        /// <summary>How fast the brake stops the horse, in the full speed per second.</summary>
        public float BrakeDeceleration = 5.0f;

        /// <summary>
        /// The effort of a key pressed every second, in units per second; the
        /// effort of the keyboard goes with how often the keys come: a key every
        /// 2 s walks, every second trots, and twice a second gallops.
        /// </summary>
        public float KeyboardEffort = 1.4f;

        /// <summary>The first key counts as if the one before came this long before, in seconds.</summary>
        public double KeyboardFirstPeriod = 2.0;

        /// <summary>
        /// After a squat from the keyboard, the horse waits this long (in seconds)
        /// for the next one before it stops, since a key is a whole squat.
        /// </summary>
        public double KeyboardStopAfter = 2.2;

        /// <summary>
        /// A squat may take this long (in seconds) from one swing to the next
        /// before the horse stops in its middle, e.g., when the player stays down.
        /// </summary>
        public double SlowestSquat = 2.0;

        /// <summary>The depth (in units) shown as the deepest squat (see <see cref="Depth"/>).</summary>
        public float FullDepth = 0.8f;

        /// <summary>The speed of the horse in [0, 1].</summary>
        public float Speed { get; private set; }

        /// <summary>The speed which the horse is heading to, in [0, 1].</summary>
        public float TargetSpeed => Math.Clamp(Effort / FullEffort, 0f, 1f);

        /// <summary>How far the head travels up and down, in units per second, fading.</summary>
        public float Effort { get; private set; }

        /// <summary>How deep the head is below its last top now, in [0, 1] of <see cref="FullDepth"/>.</summary>
        public float Depth { get; private set; }

        /// <summary>How deep the head is below its last top now, in units.</summary>
        public float RawDepth { get; private set; }

        /// <summary>How many squats were counted.</summary>
        public int Count { get; private set; }

        /// <summary>Whether the head goes down (else up, or still).</summary>
        public bool IsDown { get; private set; }

        /// <summary>The highest head since it last went up, in frame pixels (growing down); NaN before.</summary>
        public float Top { get; private set; } = float.NaN;

        /// <summary>The lowest head since it last went down, in frame pixels; NaN before.</summary>
        public float Bottom { get; private set; } = float.NaN;

        /// <summary>The unit of the player, as last observed, in frame pixels; NaN before.</summary>
        public float Unit { get; private set; } = float.NaN;

        /// <summary>The height of the head as last observed, in frame pixels; NaN before.</summary>
        public float HeadY { get; private set; } = float.NaN;

        /// <summary>
        /// The usual height of the head when the player is up, in frame pixels;
        /// NaN before: each top of a squat moves it by <see cref="LineLearning"/>,
        /// and while she stands still, it follows her head (see
        /// <see cref="LineFollowTau"/>), e.g., after she stepped closer.
        /// </summary>
        public float UsualTop { get; private set; } = float.NaN;

        /// <summary>
        /// The line which shows the player how far down her eyes must go: a swing
        /// below her usual top. It moves slowly, so that it does not jump from
        /// squat to squat; NaN before the head was seen.
        /// </summary>
        public float Line => float.IsNaN(UsualTop) || float.IsNaN(Unit) ? float.NaN : UsualTop + SwingDepth * Unit;

        /// <summary>Whether the head is below the <see cref="Line"/> now.</summary>
        public bool BelowLine => !float.IsNaN(Line) && HeadY >= Line;

        /// <summary>How much of each new top of a squat the <see cref="UsualTop"/> takes over.</summary>
        public float LineLearning = 0.3f;

        /// <summary>
        /// The time constant (in seconds) with which the <see cref="UsualTop"/>
        /// follows the head while the player stands still.
        /// </summary>
        public double LineFollowTau = 2.0;

        /// <summary>The horse walks from this speed on.</summary>
        public const float WalkFrom = 0.04f;

        /// <summary>The horse trots from this speed on (an effort of about 1.15).</summary>
        public const float TrotFrom = 0.46f;

        /// <summary>The horse gallops from this speed on (an effort of about 1.8).</summary>
        public const float GallopFrom = 0.72f;

        private double _lastSwing = double.NegativeInfinity;
        private double _stopAfter = double.NaN;
        private double _lastKey = double.NaN;
        private double _wentDown = double.NaN;
        private double _keyPeriod = double.NaN;
        private double _lastObserved = double.NaN;
        private double _lastUpdate = double.NaN;
        private double _lastSpeedUpdate = double.NaN;

        /// <summary>The gait of the horse at the given speed.</summary>
        public static Gait GaitOf(float speed)
        {
            if (speed >= GallopFrom)
            {
                return Gait.Gallop;
            }

            if (speed >= TrotFrom)
            {
                return Gait.Trot;
            }

            return speed >= WalkFrom ? Gait.Walk : Gait.Stand;
        }

        /// <summary>The gait of the horse now.</summary>
        public Gait Gait => GaitOf(Speed);

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
            // After a long gap (the player left the picture), we start afresh.
            Unit = unit;
            HeadY = headY;
            if (float.IsNaN(Top) || t - _lastObserved > 1.0)
            {
                Top = headY;
                Bottom = headY;
                UsualTop = headY;
                IsDown = false;
            }
            else if (IsDown && t - _wentDown > SlowestSquat && t - _lastSwing > SlowestSquat)
            {
                // NOTE (mristin):
                // The head stayed down longer than the slowest squat: the player
                // stands at a new height (e.g., she settled into her stance, or
                // stepped closer), and we start from there.
                Top = headY;
                Bottom = headY;
                IsDown = false;
            }
            else if (!IsDown && t - _lastSwing > StopAfter)
            {
                // NOTE (mristin):
                // Standing still, the usual top follows the head slowly.
                UsualTop += (headY - UsualTop) * (float)(1.0 - Math.Exp(-(t - _lastObserved) / LineFollowTau));
            }

            _lastObserved = t;
            Fade(t);

            float swing = SwingDepth * unit;
            if (!IsDown)
            {
                Top = Math.Min(Top, headY);
                if (headY - Top >= swing)
                {
                    // NOTE (mristin):
                    // The head turned down: the swing up to the top is complete.
                    if (Bottom > Top)
                    {
                        AddSwing(t, (Bottom - Top) / unit);
                    }

                    UsualTop += (Top - UsualTop) * LineLearning;
                    IsDown = true;
                    _wentDown = t;
                    Bottom = headY;
                }
            }
            else
            {
                Bottom = Math.Max(Bottom, headY);
                if (Bottom - headY >= swing)
                {
                    // NOTE (mristin):
                    // The head came back up: the swing down is complete, and so
                    // is the squat.
                    AddSwing(t, (Bottom - Top) / unit);
                    Count++;
                    IsDown = false;
                    Top = headY;
                }
            }

            RawDepth = Math.Max(0f, (headY - Top) / unit);
            Depth = Math.Clamp(RawDepth / FullDepth, 0f, 1f);
        }

        private void AddSwing(double t, float size)
        {
            Effort += (float)(size / EffortTau);
            _lastSwing = t;
            _stopAfter = StopAfter;
        }

        /// <summary>Count a squat from the keyboard (or the tests) at the time <paramref name="t"/>.</summary>
        public void RegisterSquat(double t)
        {
            _keyPeriod = double.IsNaN(_lastKey) || t - _lastKey > KeyboardStopAfter
                ? KeyboardFirstPeriod
                : Math.Max(0.2, t - _lastKey);
            _lastKey = t;
            _lastSwing = t;
            _stopAfter = KeyboardStopAfter;
            Fade(t);
            Count++;
        }

        /// <summary>Let the effort fade up to the time <paramref name="t"/>.</summary>
        private void Fade(double t)
        {
            if (!double.IsNaN(_lastUpdate) && t > _lastUpdate)
            {
                // NOTE (mristin):
                // In the middle of a slow squat, no swing ends for a while, but
                // the player is still squatting.
                double since = t - _lastSwing;
                double stopAfter = double.IsNaN(_stopAfter) ? StopAfter : _stopAfter;
                bool stopped = since > (IsDown ? Math.Max(SlowestSquat, stopAfter) : stopAfter);
                double tau = stopped ? StopTau : EffortTau;
                Effort *= (float)Math.Exp(-(t - _lastUpdate) / tau);
            }

            if (double.IsNaN(_lastUpdate) || t > _lastUpdate)
            {
                _lastUpdate = t;
            }

            // NOTE (mristin):
            // The keys set the effort by how often they come, and it drops as the
            // next key is late.
            if (!double.IsNaN(_lastKey) && t - _lastKey <= KeyboardStopAfter)
            {
                double period = Math.Max(_keyPeriod, t - _lastKey);
                Effort = Math.Max(Effort, (float)(KeyboardEffort / period));
            }
        }

        /// <summary>Let the speed follow the effort up to the time <paramref name="t"/>.</summary>
        public void Update(double t)
        {
            Fade(t);
            double dt = double.IsNaN(_lastSpeedUpdate) ? 0.0 : Math.Max(0.0, t - _lastSpeedUpdate);
            _lastSpeedUpdate = t;
            double tau = TargetSpeed >= Speed ? SpeedTau : SlowDownTau;
            Speed += (TargetSpeed - Speed) * (float)(1.0 - Math.Exp(-dt / tau));
            if (Speed < 0.01f && TargetSpeed < 0.01f)
            {
                Speed = 0f;
            }
        }

        /// <summary>Brake for <paramref name="dt"/> seconds: the horse stops, and the effort is gone.</summary>
        public void Halt(double dt)
        {
            // NOTE (mristin):
            // The horse stands until the next squat, also from the keyboard.
            Effort = 0f;
            _lastKey = double.NaN;
            Speed = Math.Max(0f, Speed - BrakeDeceleration * (float)dt);
        }

        /// <summary>Forget the squats, e.g., at the start of a level.</summary>
        public void Reset()
        {
            Speed = 0f;
            Effort = 0f;
            Depth = 0f;
            RawDepth = 0f;
            Count = 0;
            IsDown = false;
            Top = float.NaN;
            Bottom = float.NaN;
            Unit = float.NaN;
            HeadY = float.NaN;
            UsualTop = float.NaN;
            _lastSwing = double.NegativeInfinity;
            _stopAfter = double.NaN;
            _lastKey = double.NaN;
            _keyPeriod = double.NaN;
            _wentDown = double.NaN;
            _lastObserved = double.NaN;
            _lastUpdate = double.NaN;
            _lastSpeedUpdate = double.NaN;
        }
    }
}  // namespace SteppeRescue.Vision
