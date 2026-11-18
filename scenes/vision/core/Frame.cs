using System;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>Hold a camera frame copied out of the engine.</summary>
    /// <remarks>The frame is immutable once published to the inference thread.</remarks>
    public sealed class Frame
    {
        /// <summary>Pixels as RGB8, row by row, <em>not</em> mirrored.</summary>
        public readonly byte[] Rgb;
        public readonly int Width;
        public readonly int Height;

        /// <summary>Capture time in seconds, on the clock of the vision service.</summary>
        public readonly double Timestamp;

        public Frame(byte[] rgb, int width, int height, double timestamp)
        {
            if (width <= 0 || height <= 0)
            {
                throw new ArgumentException($"Invalid frame size {width}x{height}.");
            }

            if (rgb.Length < width * height * 3)
            {
                throw new ArgumentException(
                    $"Expected an RGB8 frame of {width}x{height}, " +
                    $"but got only {rgb.Length} bytes.",
                    nameof(rgb)
                );
            }

            Rgb = rgb;
            Width = width;
            Height = height;
            Timestamp = timestamp;
        }
    }
}  // namespace SteppeRescue.Vision
