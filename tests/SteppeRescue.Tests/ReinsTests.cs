using System;

using SteppeRescue.Vision;
using Xunit;

namespace SteppeRescue.Tests
{
    public class ReinsTests
    {
        private const float HeadX = 320f;
        private const float Unit = 100f;

        // NOTE (mristin):
        // In the not mirrored frame, the right hand at rest is on the left of
        // the head, and the left hand on the right.
        private const float RightAtRest = HeadX - 80f;
        private const float LeftAtRest = HeadX + 80f;

        [Fact]
        public void Hands_at_rest_do_not_turn()
        {
            var (turn, left, right) = new Reins().Classify(HeadX, Unit, LeftAtRest, RightAtRest);
            Assert.Equal(0f, turn);
            Assert.Equal(0f, left);
            Assert.Equal(0f, right);
        }

        [Fact]
        public void Right_hand_across_turns_left()
        {
            var (turn, _, right) = new Reins().Classify(HeadX, Unit, LeftAtRest, HeadX + 40f);
            Assert.True(turn < 0f);
            Assert.True(right > 0f);
        }

        [Fact]
        public void Left_hand_across_turns_right()
        {
            var (turn, left, _) = new Reins().Classify(HeadX, Unit, HeadX - 40f, RightAtRest);
            Assert.True(turn > 0f);
            Assert.True(left > 0f);
        }

        [Fact]
        public void Farther_across_turns_harder()
        {
            var reins = new Reins();
            var (gentle, _, _) = reins.Classify(HeadX, Unit, null, HeadX + 20f);
            var (hard, _, _) = reins.Classify(HeadX, Unit, null, HeadX + 50f);
            var (full, _, _) = reins.Classify(HeadX, Unit, null, HeadX + 200f);
            Assert.True(hard < gentle);
            Assert.Equal(-1f, full);
        }

        [Fact]
        public void Crossed_arms_do_not_turn()
        {
            var (turn, left, right) = new Reins().Classify(HeadX, Unit, HeadX - 50f, HeadX + 50f);
            Assert.Equal(0f, turn);
            Assert.True(left > 0f);
            Assert.True(right > 0f);
        }

        [Fact]
        public void Missing_hands_do_not_turn()
        {
            var (turn, _, _) = new Reins().Classify(HeadX, Unit, null, null);
            Assert.Equal(0f, turn);
        }

        [Fact]
        public void The_turn_is_smoothed_and_times_out()
        {
            var reins = new Reins();
            reins.Observe(0.0, HeadX, Unit, LeftAtRest, HeadX + 200f);
            reins.Update(0.0);
            reins.Update(0.03);
            Assert.InRange(reins.Turn, -0.9f, -0.01f);

            for (double t = 0.03; t < 0.4; t += 0.03)
            {
                reins.Observe(t, HeadX, Unit, LeftAtRest, HeadX + 200f);
                reins.Update(t);
            }

            Assert.True(reins.Turn < -0.9f);

            // NOTE (mristin):
            // The player leaves the picture.
            for (double t = 0.4; t < 2.0; t += 0.03)
            {
                reins.Update(t);
            }

            Assert.Equal(0f, reins.Turn);
        }
    }
}
