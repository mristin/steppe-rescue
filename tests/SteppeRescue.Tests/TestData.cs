using System;
using System.IO;

using SteppeRescue.Vision;
using StbImageSharp;
using Xunit;

namespace SteppeRescue.Tests
{
    /// <summary>Load the models and the test images.</summary>
    /// <remarks>
    /// <para>The photos are public-domain NASA photos fitted into 640x480 frames:</para>
    /// <list type="bullet">
    /// <item>astronaut_640x480.png: Eileen Collins (scikit-image "astronaut")</item>
    /// </list>
    /// </remarks>
    public static class TestData
    {
        public const string Rtmo = "rtmo_t_body7_416x416.onnx";
        public const string Yolox = "yolox_n_body_head_hand_Nx3xHxW.onnx";
        public const string YuNet = "face_detection_yunet_2023mar_dynamic.onnx";

        public static string Path(string fileName)
        {
            return System.IO.Path.Combine(AppContext.BaseDirectory, "data", fileName);
        }

        public static byte[] LoadModel(string fileName)
        {
            string path = Path(fileName);
            Assert.True(File.Exists(path), $"The model {path} is missing; run `git lfs pull`.");

            byte[] model = File.ReadAllBytes(path);
            Assert.True(
                model.Length > 10_000,
                $"The model at {path} looks like a git-lfs pointer; run `git lfs pull`."
            );
            return model;
        }

        public static Frame LoadFrame(string fileName, double timestamp = 0.0)
        {
            using var stream = File.OpenRead(Path(fileName));
            var image = ImageResult.FromStream(stream, ColorComponents.RedGreenBlue);
            return new Frame(image.Data, image.Width, image.Height, timestamp);
        }
    }
}
