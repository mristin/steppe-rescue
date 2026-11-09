using System;

using SteppeRescue.Vision;
using Xunit;

namespace SteppeRescue.Tests
{
    public class RiderVisionTests
    {
        [Fact]
        public void Letterbox_centers_a_landscape_frame()
        {
            var box = new RtmoPoseEstimator.Letterbox(640, 480, 416);
            Assert.Equal(0.65f, box.Scale, 3);
            Assert.Equal(0f, box.PadX, 3);
            Assert.Equal(52f, box.PadY, 3);
            Assert.Equal(320f, box.ToFrameX(208f), 2);
            Assert.Equal(240f, box.ToFrameY(208f), 2);
        }

        [Fact]
        public void Finds_the_astronaut_and_her_face()
        {
            using var vision = new RiderVision(TestData.LoadModel(TestData.Rtmo));
            using var tracker = new FaceTracker(
                TestData.LoadModel(TestData.Yolox), TestData.LoadModel(TestData.YuNet)
            );
            var frame = TestData.LoadFrame("astronaut_640x480.png");

            var snapshot = vision.Process(frame);

            Assert.NotNull(snapshot.Player);
            var player = snapshot.Player!;
            var head = player.Head(vision.KeypointThreshold);
            Assert.NotNull(head);

            // NOTE (mristin):
            // The astronaut's face is in the upper part of the picture, left of the
            // middle (see the photo).
            Assert.InRange(head!.Value.X, 150f, 400f);
            Assert.InRange(head.Value.Y, 50f, 260f);

            // Her right eye is on the left of the (not mirrored) frame.
            Assert.True(player.Has(BodyPart.LeftEye, vision.KeypointThreshold));
            Assert.True(player.Has(BodyPart.RightEye, vision.KeypointThreshold));
            Assert.True(player[BodyPart.RightEye].X < player[BodyPart.LeftEye].X);

            Assert.NotNull(player.Unit(vision.KeypointThreshold));

            // NOTE (mristin):
            // Without the hint, the tracker takes the largest head; with it, the
            // nearest one; and then it follows the face without the head detector.
            // All are hers.
            var detected = tracker.Track(frame);
            var followed = tracker.Track(TestData.LoadFrame("astronaut_640x480.png", 0.1));
            var rechecked = tracker.Track(
                TestData.LoadFrame("astronaut_640x480.png", 0.5), head.Value.X, head.Value.Y
            );
            Assert.True(detected.HeadCount > 0);
            Assert.Equal(-1, followed.HeadCount);
            Assert.True(rechecked.HeadCount > 0);

            foreach (var faces in new[] { detected, followed, rechecked })
            {
                Assert.NotNull(faces.Head);
                Assert.NotNull(faces.Face);
                var face = faces.Face!;
                Assert.InRange(face.NoseX, head.Value.X - 60f, head.Value.X + 60f);
                Assert.InRange(face.NoseY, head.Value.Y - 60f, head.Value.Y + 60f);
                Assert.True(face.RightEyeX < face.LeftEyeX);
            }
        }

        [Fact]
        public void Face_tracker_picks_the_head_nearest_to_the_hint()
        {
            var heads = new[]
            {
                new Detection(BoundingBox.FromCenter(100f, 100f, 80f, 80f), 0.9f),
                new Detection(BoundingBox.FromCenter(400f, 120f, 50f, 50f), 0.9f),
            };

            Assert.Equal(100f, FaceTracker.Pick(heads, null, null)!.Value.CenterX, 3);
            Assert.Equal(400f, FaceTracker.Pick(heads, 390f, 130f)!.Value.CenterX, 3);
            Assert.Null(FaceTracker.Pick(System.Array.Empty<Detection>(), 390f, 130f));
        }

        [Fact]
        public void Face_anchor_is_mirrored_and_upright()
        {
            var face = new FaceLandmarks
            {
                RightEyeX = 300f,
                RightEyeY = 200f,
                LeftEyeX = 340f,
                LeftEyeY = 200f,
            };

            var anchor = FaceAnchor.FromLandmarks(face, 640);

            Assert.Equal(320f, anchor.X, 3);
            Assert.Equal(200f, anchor.Y, 3);
            Assert.Equal(40f, anchor.EyeDistance, 3);
            Assert.Equal(0f, anchor.Angle, 3);
        }

        [Fact]
        public void Face_anchor_filter_fades_out_after_the_face_is_lost()
        {
            var filter = new FaceAnchorFilter();
            filter.Observe(0.0, new FaceAnchor(100f, 100f, 20f, 0f));
            filter.Update(0.0);
            Assert.Equal(1f, filter.Alpha);

            filter.Update(0.2);
            Assert.Equal(1f, filter.Alpha);

            filter.Update(0.4);
            Assert.InRange(filter.Alpha, 0.01f, 0.99f);

            filter.Update(1.0);
            Assert.Equal(0f, filter.Alpha);
        }
    }
}
