using System;
using System.Collections.Generic;
using System.Linq;

using Microsoft.ML.OnnxRuntime;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>Find the poses of the persons in a frame with RTMO through ONNX Runtime.</summary>
    /// <remarks>
    /// <para>
    /// RTMO is a one-stage pose estimator of MMPose: it finds all the persons and
    /// their 17 COCO key points in one run. See scenes/vision/rtmo/model/rtmo.json.
    /// </para>
    /// <para>The instance is not thread-safe; use it from a single thread only.</para>
    /// </remarks>
    public sealed class RtmoPoseEstimator : IDisposable
    {
        public const int InputSize = 416;

        /// <summary>The value of the padding, as in the preprocessing of MMPose.</summary>
        public const float PadValue = 114f;

        private readonly InferenceSession _session;
        private readonly RunOptions _runOptions = new();
        private readonly string[] _inputNames;
        private readonly string[] _outputNames = { "dets", "keypoints" };
        private readonly float[] _input = new float[3 * InputSize * InputSize];
        private readonly OrtValue _inputValue;

        /// <summary>Keep only the persons of at least this score.</summary>
        public float PersonThreshold = 0.3f;

        public RtmoPoseEstimator(byte[] model, int threads = 2)
        {
            OnnxRuntimePrivacy.DisableTelemetry();

            using var options = new SessionOptions
            {
                GraphOptimizationLevel = GraphOptimizationLevel.ORT_ENABLE_ALL,
                LogSeverityLevel = OrtLoggingLevel.ORT_LOGGING_LEVEL_ERROR,
                ExecutionMode = ExecutionMode.ORT_SEQUENTIAL,
                IntraOpNumThreads = threads,
                InterOpNumThreads = 1,
            };
            options.AddSessionConfigEntry("session.intra_op.allow_spinning", "0");

            _session = new InferenceSession(model, options);
            try
            {
                if (_session.InputMetadata.Count != 1)
                {
                    throw new InvalidOperationException(
                        $"Expected RTMO to have one input, but got {_session.InputMetadata.Count}."
                    );
                }

                foreach (string name in _outputNames)
                {
                    if (!_session.OutputMetadata.ContainsKey(name))
                    {
                        throw new InvalidOperationException(
                            $"Expected RTMO to have the output {name}, but got: " +
                            string.Join(", ", _session.OutputMetadata.Keys)
                        );
                    }
                }

                _inputNames = new[] { _session.InputMetadata.Keys.First() };
                _inputValue = OrtValue.CreateTensorValueFromMemory(
                    _input, new long[] { 1, 3, InputSize, InputSize }
                );
            }
            catch
            {
                _session.Dispose();
                throw;
            }
        }

        /// <summary>Describe how a frame is fitted into the input of the model.</summary>
        public readonly struct Letterbox
        {
            public readonly float Scale;
            public readonly float PadX;
            public readonly float PadY;

            public Letterbox(int width, int height, int size)
            {
                Scale = Math.Min((float)size / width, (float)size / height);
                PadX = (size - width * Scale) * 0.5f;
                PadY = (size - height * Scale) * 0.5f;
            }

            public float ToFrameX(float x) => (x - PadX) / Scale;
            public float ToFrameY(float y) => (y - PadY) / Scale;
        }

        /// <summary>
        /// Fit the frame into the planar BGR float input of the model, keeping the
        /// aspect ratio, centered and padded with <see cref="PadValue"/>.
        /// </summary>
        public static Letterbox Preprocess(Frame frame, int size, float[] target)
        {
            int plane = size * size;
            if (target.Length < 3 * plane)
            {
                throw new ArgumentException(
                    $"Expected the target of length {3 * plane}, but got {target.Length}.",
                    nameof(target)
                );
            }

            var box = new Letterbox(frame.Width, frame.Height, size);
            byte[] rgb = frame.Rgb;
            int width = frame.Width;
            int height = frame.Height;
            float inverse = 1f / box.Scale;

            for (int y = 0; y < size; y++)
            {
                float sy = (y + 0.5f - box.PadY) * inverse - 0.5f;
                bool insideY = sy >= -0.5f && sy <= height - 0.5f;
                sy = Math.Clamp(sy, 0f, height - 1);
                int y0 = (int)sy;
                int y1 = Math.Min(y0 + 1, height - 1);
                float fy = sy - y0;
                int row0 = y0 * width * 3;
                int row1 = y1 * width * 3;

                for (int x = 0; x < size; x++)
                {
                    int index = y * size + x;
                    float sx = (x + 0.5f - box.PadX) * inverse - 0.5f;
                    if (!insideY || sx < -0.5f || sx > width - 0.5f)
                    {
                        target[index] = PadValue;
                        target[plane + index] = PadValue;
                        target[2 * plane + index] = PadValue;
                        continue;
                    }

                    sx = Math.Clamp(sx, 0f, width - 1);
                    int x0 = (int)sx;
                    int x1 = Math.Min(x0 + 1, width - 1);
                    float fx = sx - x0;
                    for (int c = 0; c < 3; c++)
                    {
                        float p00 = rgb[row0 + x0 * 3 + c];
                        float p01 = rgb[row0 + x1 * 3 + c];
                        float p10 = rgb[row1 + x0 * 3 + c];
                        float p11 = rgb[row1 + x1 * 3 + c];
                        float p0 = p00 + (p01 - p00) * fx;
                        float p1 = p10 + (p11 - p10) * fx;

                        // NOTE (mristin):
                        // MMPose loads the images with OpenCV, so the model
                        // expects the BGR order: R goes to the last plane.
                        target[(2 - c) * plane + index] = p0 + (p1 - p0) * fy;
                    }
                }
            }

            return box;
        }

        /// <summary>Find the poses of all the persons in the frame.</summary>
        public void Estimate(Frame frame, List<Pose> result)
        {
            result.Clear();
            var box = Preprocess(frame, InputSize, _input);

            using var outputs = _session.Run(_runOptions, _inputNames, new[] { _inputValue }, _outputNames);

            ReadOnlySpan<float> dets = outputs[0].GetTensorDataAsSpan<float>();
            ReadOnlySpan<float> keypoints = outputs[1].GetTensorDataAsSpan<float>();
            int persons = dets.Length / 5;
            if (keypoints.Length != persons * Pose.KeypointCount * 3)
            {
                throw new InvalidOperationException(
                    $"Expected {persons * Pose.KeypointCount * 3} key point values for {persons} " +
                    $"person(s), but got {keypoints.Length}."
                );
            }

            for (int p = 0; p < persons; p++)
            {
                float score = dets[5 * p + 4];
                if (score < PersonThreshold)
                {
                    continue;
                }

                var points = new Keypoint[Pose.KeypointCount];
                for (int k = 0; k < Pose.KeypointCount; k++)
                {
                    int i = (p * Pose.KeypointCount + k) * 3;
                    points[k] = new Keypoint(
                        box.ToFrameX(keypoints[i]), box.ToFrameY(keypoints[i + 1]), keypoints[i + 2]
                    );
                }

                var personBox = new BoundingBox(
                    box.ToFrameX(dets[5 * p]),
                    box.ToFrameY(dets[5 * p + 1]),
                    box.ToFrameX(dets[5 * p + 2]),
                    box.ToFrameY(dets[5 * p + 3])
                );
                result.Add(new Pose(points, personBox, score));
            }
        }

        public void Dispose()
        {
            _inputValue.Dispose();
            _runOptions.Dispose();
            _session.Dispose();
        }
    }
}  // namespace SteppeRescue.Vision
