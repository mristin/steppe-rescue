using System;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>
    /// Turn the hands reaching across the axis of the head into the turning of
    /// the horse, like pulling the reins.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The axis of the head is the vertical line through the center of the head.
    /// When the right hand crosses to the other side of it, the horse turns left;
    /// when the left hand crosses, the horse turns right. The farther across,
    /// the harder the turn. Both hands across (crossed arms) do not turn.
    /// </para>
    /// <para>
    /// "Left" and "right" are those of the player's body. The positions are given
    /// in the pixels of the (not mirrored) frame, where the right hand of a player
    /// facing the camera is on the left.
    /// </para>
    /// </remarks>
    public sealed class Reins
    {
        /// <summary>A hand must cross this far (in units) to start turning.</summary>
        public float StartAcross = 0.1f;

        /// <summary>A hand this far across (in units) turns in full.</summary>
        public float FullAcross = 0.6f;

        /// <summary>The time constant of smoothing the turn, in seconds.</summary>
        public double SmoothingTau = 0.12;

        /// <summary>Without any hands for this long (in seconds), the turn goes back to zero.</summary>
        public double Timeout = 0.5;

        /// <summary>The smoothed turn in [-1, 1]: negative turns left, positive turns right.</summary>
        public float Turn { get; private set; }

        /// <summary>The turn of the latest observation, before smoothing.</summary>
        public float RawTurn { get; private set; }

        /// <summary>How far the left hand is across, in [0, 1].</summary>
        public float LeftAcross { get; private set; }

        /// <summary>How far the right hand is across, in [0, 1].</summary>
        public float RightAcross { get; private set; }

        private double _lastObserved = double.NaN;
        private double _lastUpdate = double.NaN;

        /// <summary>Map how far a hand is across (in units) to [0, 1].</summary>
        public float Amount(float across)
        {
            return Math.Clamp((across - StartAcross) / Math.Max(1e-3f, FullAcross - StartAcross), 0f, 1f);
        }

        /// <summary>
        /// Compute the turn of the hands: the x of the head axis, the unit of the
        /// player, and the x of the wrists (null if not seen), all in frame pixels.
        /// </summary>
        public (float Turn, float Left, float Right) Classify(
            float headX, float unit, float? leftWristX, float? rightWristX
        )
        {
            // NOTE (mristin):
            // In the not mirrored frame, the player's left side is on the right.
            float left = leftWristX.HasValue ? Amount((headX - leftWristX.Value) / unit) : 0f;
            float right = rightWristX.HasValue ? Amount((rightWristX.Value - headX) / unit) : 0f;

            float turn = left > 0f && right > 0f ? 0f : left - right;
            return (turn, left, right);
        }

        /// <summary>Observe the head and the wrists at the time <paramref name="t"/>.</summary>
        public void Observe(double t, float headX, float unit, float? leftWristX, float? rightWristX)
        {
            if (unit <= 0f)
            {
                return;
            }

            var (turn, left, right) = Classify(headX, unit, leftWristX, rightWristX);
            RawTurn = turn;
            LeftAcross = left;
            RightAcross = right;
            _lastObserved = t;
        }

        /// <summary>Advance the smoothed turn to the time <paramref name="t"/>.</summary>
        public void Update(double t)
        {
            double dt = double.IsNaN(_lastUpdate) ? 0.0 : Math.Max(0.0, t - _lastUpdate);
            _lastUpdate = t;

            if (double.IsNaN(_lastObserved) || t - _lastObserved > Timeout)
            {
                RawTurn = 0f;
                LeftAcross = 0f;
                RightAcross = 0f;
            }

            double alpha = 1.0 - Math.Exp(-dt / SmoothingTau);
            Turn += (float)((RawTurn - Turn) * alpha);
            if (MathF.Abs(Turn) < 1e-3f && RawTurn == 0f)
            {
                Turn = 0f;
            }
        }

        /// <summary>Forget everything.</summary>
        public void Reset()
        {
            Turn = 0f;
            RawTurn = 0f;
            LeftAcross = 0f;
            RightAcross = 0f;
            _lastObserved = double.NaN;
            _lastUpdate = double.NaN;
        }
    }
}  // namespace SteppeRescue.Vision
