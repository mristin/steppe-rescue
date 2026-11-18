using System;
using System.IO;
using System.Text.Json;

using SteppeRescue.Vision;
using Xunit;

namespace SteppeRescue.Tests
{
    public class VisionRecorderTests
    {
        [Fact]
        public void Records_the_faces_and_the_poses_as_json_lines()
        {
            string path = Path.Combine(Path.GetTempPath(), $"recording-{Guid.NewGuid()}.jsonl");
            try
            {
                using (var recorder = new VisionRecorder(path))
                {
                    recorder.RecordStart(0.0, 640, 480, 1);
                    recorder.Label = "walk 1";
                    var face = new FaceSnapshot
                    {
                        Timestamp = 1.0,
                        Width = 640,
                        Height = 480,
                        Heads = new BoundingBox?[] { new BoundingBox(280f, 60f, 360f, 160f) },
                        Faces = new FaceLandmarks?[] { null },
                        HeadCount = 1,
                    };
                    var gauge = new HeadGauge();
                    gauge.Measure(1.0, null, new BoundingBox(280f, 60f, 360f, 160f), true);
                    recorder.RecordFace(face, new[] { gauge }, new[] { new SquatMeter() }, 1);
                    recorder.RecordPose(new VisionSnapshot
                    {
                        Timestamp = 1.0,
                        Width = 640,
                        Height = 480,
                        Players = new Pose?[] { HandTrackerTests.PoseAt(320f, (390f, 290f), (250f, 290f)) },
                    });
                    recorder.RecordMark(1.5, "jump");
                    Assert.Equal(4, recorder.Lines);
                }

                var lines = File.ReadAllLines(path);
                Assert.Equal(4, lines.Length);
                using var start = JsonDocument.Parse(lines[0]);
                Assert.Equal("start", start.RootElement.GetProperty("kind").GetString());
                Assert.Equal(640, start.RootElement.GetProperty("width").GetInt32());

                using var faceLine = JsonDocument.Parse(lines[1]);
                Assert.Equal("walk 1", faceLine.RootElement.GetProperty("label").GetString());
                var player = faceLine.RootElement.GetProperty("players")[0];
                Assert.Equal(JsonValueKind.Null, player.GetProperty("eyes").ValueKind);
                Assert.Equal(4, player.GetProperty("head").GetArrayLength());
                Assert.True(player.GetProperty("gauge_unit").GetSingle() > 0f);

                using var pose = JsonDocument.Parse(lines[2]);
                Assert.Equal(Pose.KeypointCount * 3, pose.RootElement.GetProperty("players")[0].GetArrayLength());

                using var mark = JsonDocument.Parse(lines[3]);
                Assert.Equal("mark", mark.RootElement.GetProperty("kind").GetString());
                Assert.Equal("jump", mark.RootElement.GetProperty("name").GetString());
            }
            finally
            {
                File.Delete(path);
            }
        }
    }
}  // namespace SteppeRescue.Tests
