using SteppeRescue.Vision;
using Xunit;

namespace SteppeRescue.Tests
{
    public class BrakeTests
    {
        private const float Unit = 100f;
        private const float HeadY = 200f;

        private static Brake Raise(float wristY, double from, double until, Brake? brake = null)
        {
            brake ??= new Brake();
            for (double t = from; t < until; t += 1.0 / 30.0)
            {
                brake.Observe(t, HeadY, Unit, wristY, wristY);
                brake.Update(t);
            }

            return brake;
        }

        [Fact]
        public void Both_hands_above_the_head_brake()
        {
            var brake = Raise(HeadY - 60f, 0.0, 0.5);
            Assert.True(brake.Pulled);
            Assert.Equal(1, brake.Count);
        }

        [Fact]
        public void Reset_forgets_the_brakes()
        {
            var brake = Raise(HeadY - 60f, 0.0, 0.5);
            brake.Reset();
            Assert.False(brake.Pulled);
            Assert.Equal(0, brake.Count);
        }

        [Fact]
        public void A_hand_at_the_hair_does_not_brake()
        {
            var brake = Raise(HeadY - 20f, 0.0, 2.0);
            Assert.False(brake.Pulled);
        }

        [Fact]
        public void One_hand_up_does_not_brake()
        {
            var brake = new Brake();
            for (double t = 0.0; t < 1.0; t += 1.0 / 30.0)
            {
                brake.Observe(t, HeadY, Unit, HeadY - 80f, HeadY + 100f);
                brake.Update(t);
            }

            Assert.False(brake.Pulled);
        }

        [Fact]
        public void A_flash_of_the_hands_does_not_brake()
        {
            var brake = Raise(HeadY - 60f, 0.0, 0.1);
            Assert.False(brake.Pulled);
        }

        [Fact]
        public void The_brake_lets_go_when_the_hands_come_down()
        {
            var brake = Raise(HeadY - 60f, 0.0, 0.5);
            Raise(HeadY + 150f, 0.5, 1.2, brake);
            Assert.False(brake.Pulled);
        }

        [Fact]
        public void The_brake_stops_a_galloping_horse_at_once()
        {
            var meter = new SquatMeter();
            for (int i = 0; i < 12; i++)
            {
                meter.RegisterSquat(i * 0.5);
                for (double t = i * 0.5; t < (i + 1) * 0.5; t += 1.0 / 30.0)
                {
                    meter.Update(t);
                }
            }

            Assert.Equal(Gait.Gallop, meter.Gait);
            double now = 12 * 0.5;
            for (int i = 0; i < 9; i++)
            {
                now += 1.0 / 30.0;
                meter.Update(now);
                meter.Halt(1.0 / 30.0);
            }

            Assert.Equal(0f, meter.Speed);

            // NOTE (mristin):
            // The horse stands until the next squat, which starts a walk.
            meter.Update(now + 2.0);
            Assert.Equal(0f, meter.Speed);
            meter.RegisterSquat(now + 2.0);
            meter.Update(now + 2.5);
            Assert.True(meter.Speed > 0f);
        }
    }
}  // namespace SteppeRescue.Tests
