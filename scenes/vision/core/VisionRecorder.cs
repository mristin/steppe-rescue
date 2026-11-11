using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;

// NOTE (mristin):
// The files in core/ must not depend on Godot so that we can unit-test the
// vision outside of the engine. See tests/SteppeRescue.Tests.

namespace SteppeRescue.Vision
{
    /// <summary>
    /// Record what the vision measured, as JSON lines, to study and tune the
    /// squats on real players (see dev/squats/).
    /// </summary>
    /// <remarks>
    /// <para>
    /// Only numbers are recorded: where the eyes, the head and the joints are,
    /// and what the squats make of them. The camera pictures are never
    /// recorded.
    /// </para>
    /// <para>
    /// Every line is one JSON object with its "kind": "start" (the size of the
    /// frames), "face" (on every frame of the face tracker: for each player the
    /// eyes, the head box, whether the head detector found it in this frame,
    /// the head height and the unit of the <see cref="HeadGauge"/>, and the
    /// depth, the count and the speed of the <see cref="SquatMeter"/>) and
    /// "pose" (the 17 key points of each player, as x, y and score). Each line
    /// has the time "t" in seconds and the "label" of what the player was asked
    /// to do.
    /// </para>
    /// <para>The instance is not thread-safe; use it from a single thread only.</para>
    /// </remarks>
    public sealed class VisionRecorder : IDisposable
    {
        private readonly StreamWriter _writer;

        /// <summary>What the player is asked to do now, e.g., "walk 1".</summary>
        public string Label = "";

        /// <summary>How many lines were written.</summary>
        public int Lines { get; private set; }

        public VisionRecorder(string path)
        {
            var directory = Path.GetDirectoryName(Path.GetFullPath(path));
            if (!string.IsNullOrEmpty(directory))
            {
                Directory.CreateDirectory(directory);
            }

            _writer = new StreamWriter(path, append: false) { AutoFlush = false };
        }

        /// <summary>Write the start of the recording.</summary>
        public void RecordStart(double t, int width, int height, int players)
        {
            Write(new Dictionary<string, object?>
            {
                ["kind"] = "start",
                ["t"] = t,
                ["label"] = Label,
                ["width"] = width,
                ["height"] = height,
                ["players"] = players,
                ["time"] = DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss"),
            });
        }

        /// <summary>Write what the face tracker found and what the squats made of it.</summary>
        public void RecordFace(
            FaceSnapshot face, IReadOnlyList<HeadGauge> heads, IReadOnlyList<SquatMeter> squats, int players
        )
        {
            var list = new List<object?>();
            for (int i = 0; i < players; i++)
            {
                var landmarks = i < face.Faces.Count ? face.Faces[i] : null;
                var head = i < face.Heads.Count ? face.Heads[i] : null;
                list.Add(new Dictionary<string, object?>
                {
                    ["eyes"] = landmarks == null
                        ? null
                        : new[] { landmarks.LeftEyeX, landmarks.LeftEyeY, landmarks.RightEyeX, landmarks.RightEyeY },
                    ["head"] = head == null ? null : new[] { head.Value.X1, head.Value.Y1, head.Value.X2, head.Value.Y2 },
                    ["detected"] = face.HeadCount >= 0,
                    ["gauge_y"] = Number(heads[i].Y),
                    ["gauge_unit"] = Number(heads[i].Unit),
                    ["depth"] = squats[i].RawDepth,
                    ["count"] = squats[i].Count,
                    ["speed"] = squats[i].Speed,
                });
            }

            Write(new Dictionary<string, object?>
            {
                ["kind"] = "face",
                ["t"] = face.Timestamp,
                ["label"] = Label,
                ["ms"] = face.InferenceMs,
                ["players"] = list,
            });
        }

        /// <summary>Write the poses of the players.</summary>
        public void RecordPose(VisionSnapshot snapshot)
        {
            var list = new List<object?>();
            foreach (var pose in snapshot.Players)
            {
                if (pose == null)
                {
                    list.Add(null);
                    continue;
                }

                var points = new float[Pose.KeypointCount * 3];
                for (int k = 0; k < Pose.KeypointCount; k++)
                {
                    points[k * 3] = pose.Keypoints[k].X;
                    points[k * 3 + 1] = pose.Keypoints[k].Y;
                    points[k * 3 + 2] = pose.Keypoints[k].Score;
                }

                list.Add(points);
            }

            Write(new Dictionary<string, object?>
            {
                ["kind"] = "pose",
                ["t"] = snapshot.Timestamp,
                ["label"] = Label,
                ["ms"] = snapshot.InferenceMs,
                ["players"] = list,
            });
        }

        private static float? Number(float value) => float.IsNaN(value) ? null : value;

        private void Write(Dictionary<string, object?> line)
        {
            _writer.WriteLine(JsonSerializer.Serialize(line));
            Lines++;
        }

        public void Dispose()
        {
            _writer.Flush();
            _writer.Dispose();
        }
    }
}  // namespace SteppeRescue.Vision
