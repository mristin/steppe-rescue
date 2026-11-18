using System;
using System.Linq;

using Microsoft.ML.OnnxRuntime;

// NOTE (mristin):
// This file must not depend on Godot so that we can unit-test the face landmarks
// outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>
    /// Find the five landmarks of the faces with YuNet through ONNX Runtime, on
    /// small crops around the head which the pose estimator found.
    /// </summary>
    /// <remarks>
    /// <para>
    /// We use the model with the dynamic input (made with dev/models/make_yunet_dynamic.py of bird-dog),
    /// so that a head crop costs about a millisecond.
    /// </para>
    /// <para>The instance is not thread-safe; use it from a single thread only.</para>
    /// </remarks>
    public sealed class YuNetFaceLandmarker : IDisposable
    {
        private static readonly string[] _outputNames = YuNet.Strides
            .SelectMany(s => new[] { $"cls_{s}", $"obj_{s}", $"bbox_{s}", $"kps_{s}" })
            .ToArray();

        private readonly InferenceSession _session;
        private readonly RunOptions _runOptions = new();
        private readonly string[] _inputNames;
        private readonly float[] _input;
        private readonly OrtValue _inputValue;

        /// <summary>The side of the square input; a multiple of 32.</summary>
        public readonly int InputSize;

        /// <summary>Make the square crop this much larger than the head box.</summary>
        public float CropScale = 1.4f;

        public float ScoreThreshold = 0.6f;

        public YuNetFaceLandmarker(byte[] model, int inputSize = 160, int threads = 1)
        {
            if (inputSize <= 0 || inputSize % 32 != 0)
            {
                throw new ArgumentException(
                    $"The YuNet input size must be a positive multiple of 32, got {inputSize}."
                );
            }

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
                        $"Expected YuNet to have one input, but got {_session.InputMetadata.Count}."
                    );
                }

                foreach (string name in _outputNames)
                {
                    if (!_session.OutputMetadata.ContainsKey(name))
                    {
                        throw new InvalidOperationException(
                            $"Expected YuNet to have the output {name}, but got: " +
                            string.Join(", ", _session.OutputMetadata.Keys)
                        );
                    }
                }

                _inputNames = new[] { _session.InputMetadata.Keys.First() };
                InputSize = inputSize;
                _input = new float[3 * inputSize * inputSize];
                _inputValue = OrtValue.CreateTensorValueFromMemory(
                    _input, new long[] { 1, 3, inputSize, inputSize }
                );
            }
            catch
            {
                _session.Dispose();
                throw;
            }
        }

        /// <summary>Find the landmarks of the face in the head box, or null if there is none.</summary>
        public FaceLandmarks? DetectOne(Frame frame, BoundingBox head)
        {
            var crop = head.ExpandToSquare(CropScale);
            YuNet.Preprocess(frame, crop, InputSize, _input);

            using var outputs = _session.Run(_runOptions, _inputNames, new[] { _inputValue }, _outputNames);

            FaceLandmarks? best = null;
            for (int i = 0; i < YuNet.Strides.Length; i++)
            {
                best = YuNet.DecodeBest(
                    YuNet.Strides[i],
                    outputs[4 * i].GetTensorDataAsSpan<float>(),
                    outputs[4 * i + 1].GetTensorDataAsSpan<float>(),
                    outputs[4 * i + 2].GetTensorDataAsSpan<float>(),
                    outputs[4 * i + 3].GetTensorDataAsSpan<float>(),
                    InputSize,
                    crop,
                    ScoreThreshold,
                    best
                );
            }

            // NOTE (mristin):
            // The nose must lie in the head; otherwise YuNet found another face
            // which the larger crop caught at its border.
            if (best != null
                && (best.NoseX < head.X1 || best.NoseX > head.X2 || best.NoseY < head.Y1
                    || best.NoseY > head.Y2))
            {
                return null;
            }

            return best;
        }

        public void Dispose()
        {
            _inputValue.Dispose();
            _runOptions.Dispose();
            _session.Dispose();
        }
    }
}  // namespace SteppeRescue.Vision
