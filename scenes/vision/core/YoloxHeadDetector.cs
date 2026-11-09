using System;
using System.Collections.Generic;
using System.Linq;

using Microsoft.ML.OnnxRuntime;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>Hold a detected box with its score, in frame pixels.</summary>
    public readonly struct Detection
    {
        public readonly BoundingBox Box;
        public readonly float Score;

        public Detection(BoundingBox box, float score)
        {
            Box = box;
            Score = score;
        }

        public override string ToString() => $"{Box} score {Score:F2}";
    }

    public static class NonMaximumSuppression
    {
        /// <summary>
        /// Greedily keep the best-scoring detections and drop the ones that overlap
        /// them more than <paramref name="iouThreshold"/>.
        /// </summary>
        /// <remarks>The candidates are sorted in place.</remarks>
        public static void Apply(
            List<Detection> candidates, float iouThreshold, int maxCount, List<Detection> kept
        )
        {
            kept.Clear();
            candidates.Sort((a, b) => b.Score.CompareTo(a.Score));

            foreach (var candidate in candidates)
            {
                if (kept.Count >= maxCount)
                {
                    break;
                }

                bool overlaps = false;
                foreach (var other in kept)
                {
                    if (BoundingBox.IntersectionOverUnion(candidate.Box, other.Box) > iouThreshold)
                    {
                        overlaps = true;
                        break;
                    }
                }

                if (!overlaps)
                {
                    kept.Add(candidate);
                }
            }
        }
    }

    /// <summary>Pre- and post-process for YOLOX-Body-Head-Hand.</summary>
    /// <remarks>
    /// <para>See: https://github.com/PINTO0309/PINTO_model_zoo/tree/main/426_YOLOX-Body-Head-Hand</para>
    /// <para>
    /// We use the model without the built-in post-processing. Its output has a
    /// row per anchor point (strides 8, 16 and 32, row-major) with
    /// <c>(cx, cy, w, h, objectness, p(body), p(head), p(hand))</c>. The box is
    /// relative to the grid; the sigmoid is already applied to the scores. The
    /// frame sits in the top-left corner of the input, padded at the bottom and
    /// the right with <see cref="PadValue"/>.
    /// </para>
    /// </remarks>
    public static class Yolox
    {
        public const int ClassBody = 0;
        public const int ClassHead = 1;
        public const int ClassHand = 2;
        public const int RowLength = 8;

        /// <summary>The padding value of the YOLOX training pipeline.</summary>
        public const float PadValue = 114f;

        public static readonly int[] Strides = { 8, 16, 32 };

        public static int AnchorCount(int inputWidth, int inputHeight)
        {
            int count = 0;
            foreach (int stride in Strides)
            {
                count += (inputWidth / stride) * (inputHeight / stride);
            }

            return count;
        }

        /// <summary>The input pixels per frame pixel when the frame is fitted into the input.</summary>
        public static float Scale(int frameWidth, int frameHeight, int inputWidth, int inputHeight)
        {
            return Math.Min((float)inputWidth / frameWidth, (float)inputHeight / frameHeight);
        }

        /// <summary>
        /// Fit the RGB8 frame into the top-left corner of the planar BGR float input
        /// of the model, in [0, 255], and return the scale.
        /// </summary>
        public static float Preprocess(Frame frame, int inputWidth, int inputHeight, float[] target)
        {
            int plane = inputWidth * inputHeight;
            if (target.Length < 3 * plane)
            {
                throw new ArgumentException(
                    $"Expected the target of length {3 * plane}, but got {target.Length}.",
                    nameof(target)
                );
            }

            byte[] rgb = frame.Rgb;
            int width = frame.Width;
            int height = frame.Height;
            float scale = Scale(width, height, inputWidth, inputHeight);
            float inverse = 1f / scale;
            float contentWidth = width * scale;
            float contentHeight = height * scale;

            // NOTE (mristin):
            // We sample at the pixel centers (like cv2.resize) and pre-compute the
            // columns once, since this runs for every frame.
            Span<int> xs0 = stackalloc int[inputWidth];
            Span<int> xs1 = stackalloc int[inputWidth];
            Span<float> fxs = stackalloc float[inputWidth];
            for (int x = 0; x < inputWidth; x++)
            {
                float sx = Math.Clamp((x + 0.5f) * inverse - 0.5f, 0f, width - 1);
                int x0 = (int)sx;
                xs0[x] = x0 * 3;
                xs1[x] = Math.Min(x0 + 1, width - 1) * 3;
                fxs[x] = sx - x0;
            }

            for (int y = 0; y < inputHeight; y++)
            {
                bool insideY = y + 0.5f < contentHeight;
                float sy = Math.Clamp((y + 0.5f) * inverse - 0.5f, 0f, height - 1);
                int y0 = (int)sy;
                int y1 = Math.Min(y0 + 1, height - 1);
                float fy = sy - y0;
                int row0 = y0 * width * 3;
                int row1 = y1 * width * 3;

                for (int x = 0; x < inputWidth; x++)
                {
                    int index = y * inputWidth + x;
                    if (!insideY || x + 0.5f >= contentWidth)
                    {
                        target[index] = PadValue;
                        target[plane + index] = PadValue;
                        target[2 * plane + index] = PadValue;
                        continue;
                    }

                    float fx = fxs[x];
                    for (int c = 0; c < 3; c++)
                    {
                        float p00 = rgb[row0 + xs0[x] + c];
                        float p01 = rgb[row0 + xs1[x] + c];
                        float p10 = rgb[row1 + xs0[x] + c];
                        float p11 = rgb[row1 + xs1[x] + c];
                        float p0 = p00 + (p01 - p00) * fx;
                        float p1 = p10 + (p11 - p10) * fx;

                        // NOTE (mristin):
                        // The model was trained on images loaded with OpenCV, so it
                        // expects the BGR order: R goes to the last plane.
                        target[(2 - c) * plane + index] = p0 + (p1 - p0) * fy;
                    }
                }
            }

            return scale;
        }

        /// <summary>
        /// Decode the raw output into the detections of a single class, in frame
        /// pixels, before the non-maximum suppression.
        /// </summary>
        public static void Decode(
            ReadOnlySpan<float> output,
            int inputWidth,
            int inputHeight,
            float scale,
            int frameWidth,
            int frameHeight,
            int classIndex,
            float scoreThreshold,
            List<Detection> candidates
        )
        {
            int expected = AnchorCount(inputWidth, inputHeight) * RowLength;
            if (output.Length != expected)
            {
                throw new ArgumentException(
                    $"Expected the YOLOX output of {expected} values for the input " +
                    $"{inputWidth}x{inputHeight}, but got {output.Length}."
                );
            }

            float inverse = 1f / scale;
            int row = 0;
            foreach (int stride in Strides)
            {
                int gridWidth = inputWidth / stride;
                int gridHeight = inputHeight / stride;
                for (int gy = 0; gy < gridHeight; gy++)
                {
                    for (int gx = 0; gx < gridWidth; gx++, row++)
                    {
                        int offset = row * RowLength;
                        float score = output[offset + 4] * output[offset + 5 + classIndex];
                        if (score < scoreThreshold)
                        {
                            continue;
                        }

                        float cx = (output[offset] + gx) * stride * inverse;
                        float cy = (output[offset + 1] + gy) * stride * inverse;
                        float w = MathF.Exp(output[offset + 2]) * stride * inverse;
                        float h = MathF.Exp(output[offset + 3]) * stride * inverse;

                        var box = new BoundingBox(
                            Math.Clamp(cx - w * 0.5f, 0f, frameWidth),
                            Math.Clamp(cy - h * 0.5f, 0f, frameHeight),
                            Math.Clamp(cx + w * 0.5f, 0f, frameWidth),
                            Math.Clamp(cy + h * 0.5f, 0f, frameHeight)
                        );
                        if (!box.IsEmpty)
                        {
                            candidates.Add(new Detection(box, score));
                        }
                    }
                }
            }
        }
    }

    /// <summary>
    /// Detect the heads with YOLOX-Body-Head-Hand (nano) through ONNX Runtime.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The model is small and fast (a few milliseconds at 320x256), so it keeps up
    /// with the camera, while the pose estimator is too slow for the looks to
    /// stick to the face.
    /// </para>
    /// <para>The instance is not thread-safe; use it from a single thread only.</para>
    /// </remarks>
    public sealed class YoloxHeadDetector : IDisposable
    {
        /// <summary>
        /// The heads are big and clear, so we can be strict; at 0.4, nano took a
        /// piece of the equipment in a photo of a space station for a head.
        /// </summary>
        public float ScoreThreshold = 0.5f;

        public float NmsIouThreshold = 0.45f;
        public int MaxHeads = 8;

        public readonly int InputWidth;
        public readonly int InputHeight;

        private readonly InferenceSession _session;
        private readonly RunOptions _runOptions = new();
        private readonly string[] _inputNames;
        private readonly string[] _outputNames;
        private readonly float[] _input;
        private readonly OrtValue _inputValue;
        private readonly List<Detection> _candidates = new();

        public YoloxHeadDetector(byte[] model, int inputWidth = 320, int inputHeight = 256, int threads = 1)
        {
            if (inputWidth <= 0 || inputHeight <= 0 || inputWidth % 32 != 0 || inputHeight % 32 != 0)
            {
                throw new ArgumentException(
                    $"The YOLOX input size must be positive multiples of 32, got {inputWidth}x{inputHeight}."
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

            // NOTE (mristin):
            // Spinning threads burn the CPU which the game needs for rendering.
            options.AddSessionConfigEntry("session.intra_op.allow_spinning", "0");

            _session = new InferenceSession(model, options);
            try
            {
                if (_session.InputMetadata.Count != 1 || _session.OutputMetadata.Count != 1)
                {
                    throw new InvalidOperationException(
                        "Expected YOLOX without post-processing to have one input and " +
                        $"one output, but got {_session.InputMetadata.Count} and " +
                        $"{_session.OutputMetadata.Count}."
                    );
                }

                var input = _session.InputMetadata.First();
                int[] dimensions = input.Value.Dimensions;
                if (dimensions.Length != 4 || dimensions[1] != 3)
                {
                    throw new InvalidOperationException(
                        "Expected the YOLOX input of shape [N, 3, H, W], but got " +
                        $"[{string.Join(", ", dimensions)}]."
                    );
                }

                // NOTE (mristin):
                // A fixed-shape model dictates the input size.
                if (dimensions[2] > 0 && dimensions[3] > 0)
                {
                    inputHeight = dimensions[2];
                    inputWidth = dimensions[3];
                }

                _inputNames = new[] { input.Key };
                _outputNames = new[] { _session.OutputMetadata.Keys.First() };
                InputWidth = inputWidth;
                InputHeight = inputHeight;
                _input = new float[3 * inputWidth * inputHeight];

                // NOTE (mristin):
                // The OrtValue pins our buffer, so we only refill it for every frame.
                _inputValue = OrtValue.CreateTensorValueFromMemory(
                    _input, new long[] { 1, 3, inputHeight, inputWidth }
                );
            }
            catch
            {
                _session.Dispose();
                throw;
            }
        }

        /// <summary>Detect the heads, after the non-maximum suppression, in frame pixels.</summary>
        public void Detect(Frame frame, List<Detection> heads)
        {
            float scale = Yolox.Preprocess(frame, InputWidth, InputHeight, _input);

            using var outputs = _session.Run(_runOptions, _inputNames, new[] { _inputValue }, _outputNames);

            _candidates.Clear();
            Yolox.Decode(
                outputs[0].GetTensorDataAsSpan<float>(),
                InputWidth,
                InputHeight,
                scale,
                frame.Width,
                frame.Height,
                Yolox.ClassHead,
                ScoreThreshold,
                _candidates
            );
            NonMaximumSuppression.Apply(_candidates, NmsIouThreshold, MaxHeads, heads);
        }

        public void Dispose()
        {
            _inputValue.Dispose();
            _runOptions.Dispose();
            _session.Dispose();
        }
    }
}  // namespace SteppeRescue.Vision
