using System;
using System.Collections.Generic;

using SteppeRescue.Vision;
using Xunit;

namespace SteppeRescue.Tests
{
    public class HandTrackerTests
    {
        private const double Fps = 30.0;
        private const float Unit = 100f;

        /// <summary>A pose with the head, the shoulders, the elbows and the wrists of a player at <paramref name="x"/>.</summary>
        internal static Pose PoseAt(
            float x, (float X, float Y) leftWrist, (float X, float Y) rightWrist, float headY = 100f
        )
        {
            var points = new Keypoint[Pose.KeypointCount];
            void Set(BodyPart part, float px, float py) => points[(int)part] = new Keypoint(px, py, 0.9f);

            // NOTE (mristin):
            // The player faces the camera: her left is on the right of the frame.
            Set(BodyPart.Nose, x, headY);
            Set(BodyPart.LeftEye, x + 10f, headY - 5f);
            Set(BodyPart.RightEye, x - 10f, headY - 5f);
            Set(BodyPart.LeftShoulder, x + Unit * 0.5f, headY + 60f);
            Set(BodyPart.RightShoulder, x - Unit * 0.5f, headY + 60f);
            Set(BodyPart.LeftElbow, (x + Unit * 0.5f + leftWrist.X) * 0.5f, (headY + 60f + leftWrist.Y) * 0.5f);
            Set(BodyPart.RightElbow, (x - Unit * 0.5f + rightWrist.X) * 0.5f, (headY + 60f + rightWrist.Y) * 0.5f);
            Set(BodyPart.LeftWrist, leftWrist.X, leftWrist.Y);
            Set(BodyPart.RightWrist, rightWrist.X, rightWrist.Y);
            Set(BodyPart.LeftHip, x + Unit * 0.4f, headY + 200f);
            Set(BodyPart.RightHip, x - Unit * 0.4f, headY + 200f);
            Set(BodyPart.LeftKnee, x + Unit * 0.4f, headY + 300f);
            Set(BodyPart.RightKnee, x - Unit * 0.4f, headY + 300f);
            Set(BodyPart.LeftAnkle, x + Unit * 0.4f, headY + 400f);
            Set(BodyPart.RightAnkle, x - Unit * 0.4f, headY + 400f);
            return new Pose(points, new BoundingBox(x - Unit, headY - 50f, x + Unit, headY + 420f), 0.9f);
        }

        private static BoundingBox Box(float x, float y) => BoundingBox.FromCenter(x, y, 30f, 30f);

        private static HandTracker NewTracker()
        {
            var tracker = new HandTracker();
            tracker.SetUnit(0, Unit);
            tracker.SetUnit(1, Unit);
            return tracker;
        }

        [Fact]
        public void Knows_no_hand_before_a_pose()
        {
            var tracker = NewTracker();
            tracker.Observe(0.0, new[] { Box(400f, 300f), Box(240f, 300f) });
            Assert.Null(tracker.Hand(0, HandSide.Left, 0.0));
        }

        [Fact]
        public void A_late_pose_tells_the_hands_apart_and_they_are_followed_up_to_now()
        {
            var tracker = NewTracker();
            var poseFrames = new List<double>();
            for (int i = 0; i <= 10; i++)
            {
                double t = i / Fps;

                // NOTE (mristin):
                // Her left hand (on the right of the frame) rises; her right hand
                // stays.
                tracker.Observe(t, new[] { Box(240f, 300f), Box(400f, 300f - i * 10f) });
                if (i == 7)
                {
                    // NOTE (mristin):
                    // The pose of the first frame comes only now.
                    var pose = PoseAt(320f, (390f, 290f), (250f, 290f));
                    tracker.ObservePoses(0.0, new Pose?[] { pose });
                }
            }

            double now = 10 / Fps;
            var left = tracker.Hand(0, HandSide.Left, now);
            var right = tracker.Hand(0, HandSide.Right, now);
            Assert.NotNull(left);
            Assert.NotNull(right);
            Assert.Equal(400f, left!.Value.X, 3);
            Assert.Equal(200f, left.Value.Y, 3);
            Assert.Equal(240f, right!.Value.X, 3);
        }

        [Fact]
        public void A_pose_corrects_hands_which_were_mixed_up()
        {
            var tracker = NewTracker();
            tracker.Observe(0.0, new[] { Box(240f, 300f), Box(400f, 300f) });
            tracker.ObservePoses(0.0, new Pose?[] { PoseAt(320f, (250f, 290f), (390f, 290f)) });
            Assert.Equal(240f, tracker.Hand(0, HandSide.Left, 0.0)!.Value.X, 3);

            tracker.Observe(0.25, new[] { Box(240f, 300f), Box(400f, 300f) });
            tracker.ObservePoses(0.25, new Pose?[] { PoseAt(320f, (390f, 290f), (250f, 290f)) });
            Assert.Equal(400f, tracker.Hand(0, HandSide.Left, 0.25)!.Value.X, 3);
            Assert.Equal(240f, tracker.Hand(0, HandSide.Right, 0.25)!.Value.X, 3);
        }

        [Fact]
        public void The_hands_of_two_players_stay_theirs()
        {
            var tracker = NewTracker();
            var hands = new[] { Box(130f, 300f), Box(270f, 300f), Box(370f, 300f), Box(510f, 300f) };
            tracker.Observe(0.0, hands);
            tracker.ObservePoses(
                0.0,
                new Pose?[]
                {
                    PoseAt(450f, (520f, 290f), (380f, 290f)),
                    PoseAt(200f, (260f, 290f), (140f, 290f)),
                }
            );

            Assert.Equal(510f, tracker.Hand(0, HandSide.Left, 0.0)!.Value.X, 3);
            Assert.Equal(370f, tracker.Hand(0, HandSide.Right, 0.0)!.Value.X, 3);
            Assert.Equal(270f, tracker.Hand(1, HandSide.Left, 0.0)!.Value.X, 3);
            Assert.Equal(130f, tracker.Hand(1, HandSide.Right, 0.0)!.Value.X, 3);
        }

        [Fact]
        public void A_lost_hand_is_forgotten_after_a_moment()
        {
            var tracker = NewTracker();
            tracker.Observe(0.0, new[] { Box(240f, 300f), Box(400f, 300f) });
            tracker.ObservePoses(0.0, new Pose?[] { PoseAt(320f, (390f, 290f), (250f, 290f)) });
            for (int i = 1; i <= 15; i++)
            {
                tracker.Observe(i / Fps, new[] { Box(240f, 300f) });
            }

            Assert.Null(tracker.Hand(0, HandSide.Left, 15 / Fps));
            Assert.NotNull(tracker.Hand(0, HandSide.Right, 15 / Fps));
        }
    }

    public class BodyFollowerTests
    {
        private static (float X, float Y) Get((float X, float Y)?[] joints, Joint joint) => joints[(int)joint]!.Value;

        [Fact]
        public void Nothing_shows_before_a_pose()
        {
            var body = new BodyFollower();
            Assert.Equal(0f, body.Alpha(0.0));
            Assert.All(body.Joints(null, null), joint => Assert.Null(joint));
        }

        [Fact]
        public void The_body_squats_with_the_head_and_the_feet_stay()
        {
            var body = new BodyFollower();
            body.ObserveHead(0.0, 320f, 97f);
            body.ObservePose(0.0, HandTrackerTests.PoseAt(320f, (390f, 290f), (250f, 290f)));
            body.ObserveHead(0.2, 320f, 197f);

            var joints = body.Joints(null, null);
            Assert.Equal(260f, Get(joints, Joint.LeftShoulder).Y, 3);
            Assert.Equal(400f, Get(joints, Joint.LeftHip).Y, 3);
            Assert.Equal(450f, Get(joints, Joint.LeftKnee).Y, 3);
            Assert.Equal(500f, Get(joints, Joint.LeftAnkle).Y, 3);
            Assert.Equal(1f, body.Alpha(0.2));
            Assert.Equal(0f, body.Alpha(2.0));
        }

        [Fact]
        public void The_elbow_bends_so_that_the_arm_keeps_its_lengths()
        {
            var body = new BodyFollower();
            body.ObserveHead(0.0, 320f, 97f);
            body.ObservePose(0.0, HandTrackerTests.PoseAt(320f, (390f, 290f), (250f, 290f)));

            var shoulder = (X: 370f, Y: 160f);
            var posedElbow = (X: (370f + 390f) * 0.5f, Y: (160f + 290f) * 0.5f);
            float upper = Distance(shoulder, posedElbow);

            // NOTE (mristin):
            // She raises her left hand above her head.
            var joints = body.Joints((420f, 40f), null);
            var elbow = Get(joints, Joint.LeftElbow);
            Assert.Equal(upper, Distance(shoulder, elbow), 1);
            Assert.Equal((420f, 40f), Get(joints, Joint.LeftHand));
        }

        private static float Distance((float X, float Y) a, (float X, float Y) b)
        {
            float dx = a.X - b.X;
            float dy = a.Y - b.Y;
            return MathF.Sqrt(dx * dx + dy * dy);
        }
    }
}  // namespace SteppeRescue.Tests
