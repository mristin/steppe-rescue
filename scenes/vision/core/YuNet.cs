using System;

namespace SteppeRescue.Vision
{
    /// <summary>Hold the five landmarks of a face, in frame pixels.</summary>
    /// <remarks>
    /// "Right" and "left" are those of the person, as YuNet reports them: the
    /// right eye of a person facing the camera is on the left of the (not
    /// mirrored) frame.
    /// </remarks>
    public sealed class FaceLandmarks
    {
        public BoundingBox Box { get; init; }
        public float Score { get; init; }

        public float RightEyeX { get; init; }
        public float RightEyeY { get; init; }
        public float LeftEyeX { get; init; }
        public float LeftEyeY { get; init; }
        public float NoseX { get; init; }
        public float NoseY { get; init; }
        public float MouthRightX { get; init; }
        public float MouthRightY { get; init; }
        public float MouthLeftX { get; init; }
        public float MouthLeftY { get; init; }

        public override string ToString() =>
            $"face {Box} ({Score:F2}): eyes ({RightEyeX:F0}, {RightEyeY:F0}) ({LeftEyeX:F0}, {LeftEyeY:F0}), " +
            $"nose ({NoseX:F0}, {NoseY:F0}), mouth ({MouthRightX:F0}, {MouthRightY:F0}) " +
            $"({MouthLeftX:F0}, {MouthLeftY:F0})";
    }

    /// <summary>Pre- and post-process for the YuNet face detector.</summary>
    /// <remarks>
    /// <para>See: https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet</para>
    /// <para>
    /// We run YuNet only on a square crop around the head which the pose estimator found, so
    /// the input is small and the face fills most of it. The model has, for every
    /// stride (8, 16, 32), the outputs <c>cls</c>, <c>obj</c> (one value per
    /// anchor point, sigmoid applied), <c>bbox</c> (4) and <c>kps</c> (10), with
    /// the anchor points row by row.
    /// </para>
    /// </remarks>
    public static class YuNet
    {
        public static readonly int[] Strides = { 8, 16, 32 };

        /// <summary>
        /// Crop the square <paramref name="crop"/> (in frame pixels; it may reach
        /// beyond the frame, which we fill with black) and resize it into the
        /// planar BGR float input of the model of <paramref name="size"/> x
        /// <paramref name="size"/>, in [0, 255].
        /// </summary>
        public static void Preprocess(Frame frame, BoundingBox crop, int size, float[] target)
        {
            int plane = size * size;
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
            float scaleX = crop.Width / size;
            float scaleY = crop.Height / size;

            for (int y = 0; y < size; y++)
            {
                float sy = crop.Y1 + (y + 0.5f) * scaleY - 0.5f;
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
                    float sx = crop.X1 + (x + 0.5f) * scaleX - 0.5f;
                    if (!insideY || sx < -0.5f || sx > width - 0.5f)
                    {
                        target[index] = 0f;
                        target[plane + index] = 0f;
                        target[2 * plane + index] = 0f;
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
                        // YuNet was trained on images loaded with OpenCV, so it
                        // expects the BGR order: R goes to the last plane.
                        target[(2 - c) * plane + index] = p0 + (p1 - p0) * fy;
                    }
                }
            }
        }

        /// <summary>
        /// Decode the outputs of a stride and keep the best face if it beats
        /// <paramref name="best"/>; the coordinates are mapped back from the input
        /// of <paramref name="size"/> into the <paramref name="crop"/> in the frame.
        /// </summary>
        /// <returns>The better of <paramref name="best"/> and the best face of this stride.</returns>
        public static FaceLandmarks? DecodeBest(
            int stride,
            ReadOnlySpan<float> cls,
            ReadOnlySpan<float> obj,
            ReadOnlySpan<float> bbox,
            ReadOnlySpan<float> kps,
            int size,
            BoundingBox crop,
            float scoreThreshold,
            FaceLandmarks? best
        )
        {
            int grid = size / stride;
            int count = grid * grid;
            if (cls.Length != count || obj.Length != count || bbox.Length != 4 * count
                || kps.Length != 10 * count)
            {
                throw new ArgumentException(
                    $"Expected {count} anchor points for the stride {stride} at the input {size}, " +
                    $"but got cls {cls.Length}, obj {obj.Length}, bbox {bbox.Length}, kps {kps.Length}."
                );
            }

            int bestIndex = -1;
            float bestScore = Math.Max(scoreThreshold, best?.Score ?? 0f);
            for (int i = 0; i < count; i++)
            {
                float score = MathF.Sqrt(Math.Clamp(cls[i], 0f, 1f) * Math.Clamp(obj[i], 0f, 1f));
                if (score > bestScore)
                {
                    bestScore = score;
                    bestIndex = i;
                }
            }

            if (bestIndex < 0)
            {
                return best;
            }

            int column = bestIndex % grid;
            int row = bestIndex / grid;
            float scaleX = crop.Width / size;
            float scaleY = crop.Height / size;
            float X(float raw) => crop.X1 + (raw + column) * stride * scaleX;
            float Y(float raw) => crop.Y1 + (raw + row) * stride * scaleY;

            ReadOnlySpan<float> b = bbox.Slice(4 * bestIndex, 4);
            ReadOnlySpan<float> k = kps.Slice(10 * bestIndex, 10);
            return new FaceLandmarks
            {
                Box = BoundingBox.FromCenter(
                    X(b[0]), Y(b[1]), MathF.Exp(b[2]) * stride * scaleX, MathF.Exp(b[3]) * stride * scaleY
                ),
                Score = bestScore,
                RightEyeX = X(k[0]),
                RightEyeY = Y(k[1]),
                LeftEyeX = X(k[2]),
                LeftEyeY = Y(k[3]),
                NoseX = X(k[4]),
                NoseY = Y(k[5]),
                MouthRightX = X(k[6]),
                MouthRightY = Y(k[7]),
                MouthLeftX = X(k[8]),
                MouthLeftY = Y(k[9]),
            };
        }
    }
}  // namespace SteppeRescue.Vision
