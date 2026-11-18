using System;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>
    /// Tell when the player raises both hands above her head: the brake, which
    /// stops the horse at once, and it rears up.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Both wrists must be clearly above the head (see <see cref="Above"/>) for
    /// a moment (see <see cref="Confirm"/>), so that a hand which only brushes
    /// the hair does not brake; the brake lets go a moment after the hands come
    /// down (see <see cref="Release"/>), so that a flicker of the pose does not
    /// let it go.
    /// </para>
    /// <para>The y of the positions grows downwards, in the pixels of the frame.</para>
    /// </remarks>
    public sealed class Brake
    {
        /// <summary>The wrists must be this far above the head (its eyes and ears), in units.</summary>
        public float Above = 0.4f;

        /// <summary>The hands must be up this long to brake, in seconds.</summary>
        public double Confirm = 0.15;

        /// <summary>The brake lets go after the hands are down this long, in seconds.</summary>
        public double Release = 0.3;

        /// <summary>Whether the player brakes now.</summary>
        public bool Pulled { get; private set; }

        /// <summary>How many times the player braked.</summary>
        public int Count { get; private set; }

        private double _upSince = double.NaN;
        private double _lastUp = double.NaN;

        /// <summary>Whether both hands are up in this observation.</summary>
        public bool HandsUp(float headY, float unit, float? leftWristY, float? rightWristY)
        {
            if (unit <= 0f || leftWristY == null || rightWristY == null)
            {
                return false;
            }

            float line = headY - Above * unit;
            return leftWristY.Value < line && rightWristY.Value < line;
        }

        /// <summary>Observe the head and the wrists at the time <paramref name="t"/>.</summary>
        public void Observe(double t, float headY, float unit, float? leftWristY, float? rightWristY)
        {
            if (HandsUp(headY, unit, leftWristY, rightWristY))
            {
                if (double.IsNaN(_upSince))
                {
                    _upSince = t;
                }

                _lastUp = t;
            }
            else
            {
                _upSince = double.NaN;
            }
        }

        /// <summary>Pull the brake from the keyboard (held) at the time <paramref name="t"/>.</summary>
        public void Hold(double t)
        {
            if (double.IsNaN(_upSince))
            {
                _upSince = t - Confirm;
            }

            _lastUp = t;
        }

        /// <summary>Let go of the brake held from the keyboard.</summary>
        public void LetGo()
        {
            _upSince = double.NaN;
        }

        /// <summary>Decide whether the player brakes at the time <paramref name="t"/>.</summary>
        public void Update(double t)
        {
            bool recent = !double.IsNaN(_lastUp) && t - _lastUp < Release;
            bool held = !double.IsNaN(_upSince) && t - _upSince >= Confirm && recent;
            bool pulled = held || (Pulled && recent);
            if (pulled && !Pulled)
            {
                Count++;
            }

            Pulled = pulled;
        }

        /// <summary>Forget everything, also how many times the player braked.</summary>
        public void Reset()
        {
            Count = 0;
            Pulled = false;
            _upSince = double.NaN;
            _lastUp = double.NaN;
        }
    }
}  // namespace SteppeRescue.Vision
