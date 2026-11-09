using System;
using System.Collections.Generic;
using System.Diagnostics;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>Hold what the vision found in one frame; immutable.</summary>
    public sealed class VisionSnapshot
    {
        /// <summary>The time of the frame, on the clock of the vision service.</summary>
        public double Timestamp { get; init; }

        public int Width { get; init; }
        public int Height { get; init; }

        /// <summary>The pose of the player, or null if nobody is in the picture.</summary>
        public Pose? Player { get; init; }

        /// <summary>How many persons the pose estimator found.</summary>
        public int PersonCount { get; init; }

        /// <summary>How long the pose took, in milliseconds.</summary>
        public double InferenceMs { get; init; }
    }

    /// <summary>Run the pose estimator on a frame and pick the player.</summary>
    /// <remarks>
    /// <para>
    /// The face runs separately in <see cref="FaceTracker"/>, since the pose is
    /// too slow for the looks to stick to the face.
    /// </para>
    /// <para>The instance is not thread-safe; use it from a single thread only.</para>
    /// </remarks>
    public sealed class RiderVision : IDisposable
    {
        /// <summary>Use only the key points of at least this score.</summary>
        public float KeypointThreshold = 0.5f;

        private readonly RtmoPoseEstimator _poses;
        private readonly List<Pose> _found = new();

        /// <param name="poseModel">The bytes of the RTMO model.</param>
        public RiderVision(byte[] poseModel, int threads = 2)
        {
            _poses = new RtmoPoseEstimator(poseModel, threads);
        }

        public VisionSnapshot Process(Frame frame)
        {
            var stopwatch = Stopwatch.StartNew();
            _poses.Estimate(frame, _found);
            var player = PlayerSelection.Pick(_found, KeypointThreshold, frame.Width);

            return new VisionSnapshot
            {
                Timestamp = frame.Timestamp,
                Width = frame.Width,
                Height = frame.Height,
                Player = player,
                PersonCount = _found.Count,
                InferenceMs = stopwatch.Elapsed.TotalMilliseconds,
            };
        }

        public void Dispose()
        {
            _poses.Dispose();
        }
    }
}  // namespace SteppeRescue.Vision
