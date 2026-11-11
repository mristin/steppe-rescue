using System;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>
    /// Decide how often the body pose runs: as often as the computer manages,
    /// as long as the faces and the hands, which the riding needs on every
    /// frame, keep up with the camera.
    /// </summary>
    /// <remarks>
    /// <para>
    /// While the face tracker processes its frames within
    /// <see cref="FaceBudget"/> of the time between two camera frames, the pose
    /// runs a little more often with each frame; as soon as it falls behind,
    /// the pose runs much less often (the interval grows by
    /// <see cref="BackOff"/>), so that the riding stays smooth. The pose also
    /// never keeps the processor busy for more than <see cref="PoseShare"/> of
    /// the time.
    /// </para>
    /// <para>
    /// The face thread reports to it and the pose thread asks it, so it is
    /// thread-safe.
    /// </para>
    /// </remarks>
    public sealed class PoseScheduler
    {
        /// <summary>The pose runs at most this often, in seconds.</summary>
        public double MinInterval = 0.05;

        /// <summary>The pose runs at least this often, in seconds.</summary>
        public double MaxInterval = 0.25;

        /// <summary>The faces keep up while they take at most this share of a camera frame.</summary>
        public double FaceBudget = 0.8;

        /// <summary>A face frame within the budget shortens the interval by this much, in seconds.</summary>
        public double Step = 0.002;

        /// <summary>A face frame over the budget lengthens the interval by this factor.</summary>
        public double BackOff = 1.5;

        /// <summary>The pose is busy at most this share of the time.</summary>
        public double PoseShare = 0.5;

        private readonly object _lock = new();
        private double _interval;
        private double _poseSeconds;

        public PoseScheduler()
        {
            _interval = MaxInterval;
        }

        /// <summary>How long to wait between the starts of two poses, in seconds.</summary>
        public double Interval
        {
            get
            {
                lock (_lock)
                {
                    return Math.Clamp(Math.Max(_interval, _poseSeconds / PoseShare), MinInterval, MaxInterval);
                }
            }
        }

        /// <summary>
        /// Observe that the face tracker took <paramref name="faceMs"/> for a frame,
        /// while the camera gives a frame every <paramref name="frameSeconds"/>.
        /// </summary>
        public void ObserveFace(double faceMs, double frameSeconds)
        {
            if (double.IsNaN(faceMs) || frameSeconds <= 0.0 || double.IsNaN(frameSeconds))
            {
                return;
            }

            lock (_lock)
            {
                if (faceMs / 1000.0 > FaceBudget * frameSeconds)
                {
                    _interval = Math.Min(MaxInterval, _interval * BackOff);
                }
                else
                {
                    _interval = Math.Max(MinInterval, _interval - Step);
                }
            }
        }

        /// <summary>Observe that the pose took <paramref name="poseMs"/>.</summary>
        public void ObservePose(double poseMs)
        {
            if (double.IsNaN(poseMs) || poseMs < 0.0)
            {
                return;
            }

            lock (_lock)
            {
                // NOTE (mristin):
                // Smooth it a little, since the poses vary.
                _poseSeconds = _poseSeconds <= 0.0 ? poseMs / 1000.0 : _poseSeconds * 0.7 + poseMs / 1000.0 * 0.3;
            }
        }

        /// <summary>Start again from the slowest rate, e.g., with another camera.</summary>
        public void Reset()
        {
            lock (_lock)
            {
                _interval = MaxInterval;
                _poseSeconds = 0.0;
            }
        }
    }
}  // namespace SteppeRescue.Vision
