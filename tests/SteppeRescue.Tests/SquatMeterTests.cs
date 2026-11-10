using System;

using SteppeRescue.Vision;
using Xunit;

namespace SteppeRescue.Tests
{
    public class SquatMeterTests
    {
        private const float Unit = 100f;
        private const float StandingY = 150f;
        private const double Fps = 30.0;

        /// <summary>
        /// Simulate a player who squats with the given period and depth (in units)
        /// for the given time, sampled at the frame rate of a webcam.
        /// </summary>
        private static SquatMeter Squat(double period, float depth, double duration, double start = 0.0,
            SquatMeter? meter = null)
        {
            meter ??= new SquatMeter();
            for (double t = start; t < start + duration; t += 1.0 / Fps)
            {
                double phase = ((t - start) % period) / period;

                // NOTE (mristin):
                // Down and up like a cosine, from standing at the phase 0.
                float y = StandingY + depth * Unit * (float)(0.5 - 0.5 * Math.Cos(2.0 * Math.PI * phase));
                meter.Observe(t, y, Unit);
                meter.Update(t);
            }

            return meter;
        }

        /// <summary>Stand still from <paramref name="start"/> on, and return the time when the horse stopped.</summary>
        private static double TimeToStop(SquatMeter meter, double start, Action<double>? at = null)
        {
            for (double t = start; t < start + 20.0; t += 1.0 / Fps)
            {
                meter.Observe(t, StandingY, Unit);
                meter.Update(t);
                at?.Invoke(t - start);
                if (meter.Speed == 0f)
                {
                    return t - start;
                }
            }

            return double.PositiveInfinity;
        }

        [Fact]
        public void A_walking_horse_stops_soon_after_the_squats()
        {
            var meter = Squat(period: 4.0, depth: 1.2f, duration: 16.0);
            Assert.Equal(Gait.Walk, meter.Gait);

            // NOTE (mristin):
            // The last squat ended at the end of the period, so the horse may walk
            // on until the next squat would be due, but no longer than the pause.
            Assert.InRange(TimeToStop(meter, 16.0), 0.2, 1.5);
        }

        [Fact]
        public void A_galloping_horse_stops_at_once_after_the_squats()
        {
            var meter = Squat(period: 1.3, depth: 1.2f, duration: 15.0);
            Assert.Equal(Gait.Gallop, meter.Gait);

            double stopped = TimeToStop(meter, 15.0);
            Assert.InRange(stopped, 0.2, 1.5);
        }

        [Fact]
        public void A_trotting_horse_stops_soon_after_the_squats()
        {
            var meter = Squat(period: 2.5, depth: 1.2f, duration: 15.0);
            Assert.Equal(Gait.Trot, meter.Gait);
            Assert.InRange(TimeToStop(meter, 15.0), 0.2, 1.5);
        }

        [Fact]
        public void Two_or_three_brisk_squats_gallop()
        {
            var meter = new SquatMeter();
            for (int squats = 1; squats <= 8; squats++)
            {
                Squat(period: 1.2, depth: 1.2f, duration: 1.2, start: (squats - 1) * 1.2, meter: meter);
                if (squats <= 1)
                {
                    Assert.NotEqual(Gait.Gallop, meter.Gait);
                }

                if (squats == 3)
                {
                    // NOTE (mristin):
                    // Children manage two or three brisk squats, not more.
                    Assert.Equal(Gait.Gallop, meter.Gait);
                }
            }

            Assert.Equal(Gait.Gallop, meter.Gait);
        }

        [Fact]
        public void Standing_still_does_not_move_the_horse()
        {
            var meter = Squat(period: 2.0, depth: 0f, duration: 10.0);
            Assert.Equal(0, meter.Count);
            Assert.Equal(0f, meter.Speed);
            Assert.Equal(Gait.Stand, meter.Gait);
        }

        [Fact]
        public void Nodding_does_not_count()
        {
            var meter = Squat(period: 1.0, depth: 0.2f, duration: 10.0);
            Assert.Equal(0, meter.Count);
            Assert.Equal(0f, meter.Speed);
        }

        [Theory]
        [InlineData(4.0, Gait.Walk)]
        [InlineData(2.5, Gait.Trot)]
        [InlineData(1.8, Gait.Gallop)]
        public void Faster_squats_make_a_faster_gait(double period, Gait expected)
        {
            var meter = Squat(period, depth: 1.2f, duration: 20.0);
            Assert.InRange(meter.Count, (int)(20.0 / period) - 2, (int)(20.0 / period) + 1);
            Assert.Equal(expected, meter.Gait);
        }

        [Fact]
        public void Shallow_squats_count_less_than_deep_ones()
        {
            var shallow = Squat(period: 2.0, depth: 0.7f, duration: 20.0);
            var deep = Squat(period: 2.0, depth: 1.2f, duration: 20.0);
            Assert.True(shallow.Count > 0);
            Assert.True(shallow.Speed < deep.Speed, $"{shallow.Speed} should be < {deep.Speed}");
        }

        [Fact]
        public void The_horse_slows_down_and_stops_after_the_squats_stop()
        {
            var meter = Squat(period: 1.5, depth: 1.2f, duration: 15.0);
            float galloping = meter.Speed;
            Assert.Equal(Gait.Gallop, meter.Gait);

            // NOTE (mristin):
            // The player stands still.
            float previous = galloping;
            for (double t = 15.0; t < 25.0; t += 1.0 / Fps)
            {
                meter.Observe(t, StandingY, Unit);
                meter.Update(t);
                Assert.True(meter.Speed <= previous + 1e-6f);
                previous = meter.Speed;
            }

            Assert.Equal(Gait.Stand, meter.Gait);
        }

        [Fact]
        public void The_speed_changes_gently()
        {
            var meter = new SquatMeter();
            meter.RegisterSquat(0.0, 1.2f);
            for (double t = 0.0; t < 1.2; t += 1.0 / Fps)
            {
                meter.Update(t);
            }

            float walking = meter.Speed;
            Assert.Equal(Gait.Walk, meter.Gait);

            // NOTE (mristin):
            // The second squat comes quickly, which asks for a gallop, but the
            // horse only speeds up gradually.
            meter.RegisterSquat(1.2, 1.2f);
            meter.Update(1.2);
            meter.Update(1.3);
            Assert.True(meter.TargetSpeed > 0.9f);
            Assert.True(
                meter.Speed < walking + 0.1f, $"The horse jumped from {walking} to {meter.Speed}."
            );
        }

        [Fact]
        public void Stepping_closer_does_not_count_as_squats()
        {
            // NOTE (mristin):
            // The player steps back and forth: the head goes a bit down and up,
            // but so does the unit, and slowly.
            var meter = new SquatMeter();
            for (double t = 0.0; t < 20.0; t += 1.0 / Fps)
            {
                float closer = (float)(0.5 - 0.5 * Math.Cos(2.0 * Math.PI * t / 10.0));
                float unit = Unit * (1f + 0.3f * closer);
                meter.Observe(t, StandingY + 0.3f * Unit * closer, unit);
                meter.Update(t);
            }

            Assert.Equal(0, meter.Count);
        }

        [Fact]
        public void Speed_of_period_is_monotonic()
        {
            float previous = float.PositiveInfinity;
            for (double period = 0.5; period < 6.0; period += 0.1)
            {
                float speed = SquatMeter.SpeedOfPeriod(period);
                Assert.True(speed <= previous);
                previous = speed;
            }
        }
    }
}
