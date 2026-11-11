using System;

using SteppeRescue.Vision;
using Xunit;

namespace SteppeRescue.Tests
{
    public class OneEuroFilterTests
    {
        private const double Fps = 30.0;
        private const float Unit = 100f;

        [Fact]
        public void Takes_the_first_point_as_it_is()
        {
            var filter = new OneEuroFilter();
            Assert.Equal((10f, 20f), filter.Filter(0.0, 10f, 20f, Unit));
        }

        [Fact]
        public void Calms_the_jitter_of_a_still_point()
        {
            var filter = new OneEuroFilter();
            var random = new Random(7);
            double raw = 0.0;
            double smoothed = 0.0;
            for (int i = 0; i < 90; i++)
            {
                // NOTE (mristin):
                // The pose jitters by a few hundredths of the unit around a still elbow.
                float jitter = (float)(random.NextDouble() - 0.5) * 0.08f * Unit;
                var (x, _) = filter.Filter(i / Fps, 300f + jitter, 200f, Unit);
                if (i > 30)
                {
                    raw += Math.Abs(jitter);
                    smoothed += Math.Abs(x - 300f);
                }
            }

            Assert.True(smoothed < raw * 0.5, $"the still point jitters by {smoothed} against {raw}");
        }

        [Fact]
        public void Follows_a_fast_movement_with_little_lag()
        {
            var filter = new OneEuroFilter();
            (float X, float Y) at = default;
            for (int i = 0; i <= 15; i++)
            {
                // NOTE (mristin):
                // The hand moves three units in half a second.
                at = filter.Filter(i / Fps, 300f + i * 0.2f * Unit, 200f, Unit);
            }

            Assert.InRange(at.X, 300f + 2.6f * Unit, 300f + 3f * Unit);
        }

        [Fact]
        public void Starts_afresh_after_a_reset()
        {
            var filter = new OneEuroFilter();
            filter.Filter(0.0, 0f, 0f, Unit);
            filter.Reset();
            Assert.Equal((500f, 500f), filter.Filter(0.1, 500f, 500f, Unit));
        }
    }

    public class BodySmoothingTests
    {
        [Fact]
        public void The_seen_hands_are_taken_as_they_are_and_the_elbows_are_smoothed()
        {
            var body = new BodyFollower();
            body.ObserveHead(0.0, 320f, 97f);
            body.ObservePose(0.0, HandTrackerTests.PoseAt(320f, (390f, 290f), (250f, 290f)));
            body.Update(0.0, (400f, 300f), null, 100f);
            var first = body.Smoothed[(int)Joint.LeftElbow]!.Value;

            // NOTE (mristin):
            // The next pose puts the elbow 10 pixels off, as the pose jitters.
            var pose = HandTrackerTests.PoseAt(320f, (390f, 290f), (250f, 290f));
            var points = (Keypoint[])pose.Keypoints.Clone();
            var posed = points[(int)BodyPart.LeftElbow];
            points[(int)BodyPart.LeftElbow] = new Keypoint(posed.X + 10f, posed.Y, 0.9f);
            body.ObservePose(1 / 30.0, new Pose(points, pose.Box, pose.Score));
            body.Update(1 / 30.0, (400f, 300f), null, 100f);

            Assert.Equal((400f, 300f), body.Smoothed[(int)Joint.LeftHand]!.Value);
            var smoothed = body.Smoothed[(int)Joint.LeftElbow]!.Value;
            float jump = MathF.Abs(smoothed.X - first.X) + MathF.Abs(smoothed.Y - first.Y);
            Assert.True(jump < 5f, $"the elbow jumps by {jump} of 10 pixels");
        }

        [Fact]
        public void A_joint_which_is_lost_is_not_shown()
        {
            var body = new BodyFollower();
            body.Update(0.0, null, null, 100f);
            Assert.All(body.Smoothed, joint => Assert.Null(joint));
        }
    }

    public class PoseSchedulerTests
    {
        private const double Frame = 1.0 / 30.0;

        [Fact]
        public void Runs_the_pose_more_often_while_the_faces_keep_up()
        {
            var scheduler = new PoseScheduler();
            Assert.Equal(scheduler.MaxInterval, scheduler.Interval, 6);
            scheduler.ObservePose(20.0);
            for (int i = 0; i < 300; i++)
            {
                scheduler.ObserveFace(15.0, Frame);
            }

            Assert.Equal(scheduler.MinInterval, scheduler.Interval, 6);
        }

        [Fact]
        public void Backs_off_at_once_when_the_faces_fall_behind()
        {
            var scheduler = new PoseScheduler();
            scheduler.ObservePose(20.0);
            for (int i = 0; i < 300; i++)
            {
                scheduler.ObserveFace(15.0, Frame);
            }

            double fast = scheduler.Interval;
            scheduler.ObserveFace(40.0, Frame);
            scheduler.ObserveFace(40.0, Frame);
            Assert.True(scheduler.Interval >= fast * 2.0, $"{scheduler.Interval} after {fast}");
        }

        [Fact]
        public void A_slow_pose_keeps_the_processor_free_half_of_the_time()
        {
            var scheduler = new PoseScheduler();
            for (int i = 0; i < 10; i++)
            {
                scheduler.ObservePose(80.0);
            }

            for (int i = 0; i < 300; i++)
            {
                scheduler.ObserveFace(10.0, Frame);
            }

            Assert.InRange(scheduler.Interval, 0.159, 0.161);
        }
    }
}  // namespace SteppeRescue.Tests
