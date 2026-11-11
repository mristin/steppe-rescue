using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;

using SteppeRescue.Vision;
using Xunit;

namespace SteppeRescue.Tests
{
    public class SquatMeterTests
    {
        private const float Unit = 100f;
        private const float StandingY = 150f;
        private const double Fps = 18.0;

        /// <summary>
        /// Simulate a player who squats with the given period and depth (in units)
        /// for the given time, sampled at the frame rate of the face tracker.
        /// </summary>
        private static SquatMeter Squat(
            double period,
            float depth,
            double duration,
            double start = 0.0,
            SquatMeter? meter = null,
            float unit = Unit,
            Action<double, SquatMeter>? each = null
        )
        {
            meter ??= new SquatMeter();
            for (double t = start; t < start + duration; t += 1.0 / Fps)
            {
                double phase = ((t - start) % period) / period;

                // NOTE (mristin):
                // Down and up like a cosine, from standing at the phase 0.
                float y = StandingY * unit / Unit
                    + depth * unit * (float)(0.5 - 0.5 * Math.Cos(2.0 * Math.PI * phase));
                meter.Observe(t, y, unit);
                meter.Update(t);
                each?.Invoke(t, meter);
            }

            return meter;
        }

        /// <summary>Stand still from <paramref name="start"/> for the duration.</summary>
        private static SquatMeter Stand(SquatMeter meter, double start, double duration, Action<double>? each = null)
        {
            for (double t = start; t < start + duration; t += 1.0 / Fps)
            {
                meter.Observe(t, StandingY, Unit);
                meter.Update(t);
                each?.Invoke(t);
            }

            return meter;
        }

        [Fact]
        public void Standing_still_does_not_move_the_horse()
        {
            var meter = new SquatMeter();
            var random = new Random(1);
            for (double t = 0.0; t < 10.0; t += 1.0 / Fps)
            {
                // NOTE (mristin):
                // The tracker jitters by a few hundredths of the unit.
                meter.Observe(t, StandingY + (float)(random.NextDouble() - 0.5) * 0.1f * Unit, Unit);
                meter.Update(t);
            }

            Assert.Equal(0, meter.Count);
            Assert.Equal(0f, meter.Speed);
        }

        [Fact]
        public void A_squat_counts_when_the_head_comes_back_up()
        {
            var meter = Squat(period: 1.4, depth: 0.5f, duration: 0.7);
            Assert.Equal(0, meter.Count);
            Squat(period: 1.4, depth: 0.5f, duration: 0.7, start: 0.7, meter: meter);
            Assert.Equal(1, meter.Count);
            Assert.Equal(Gait.Walk, meter.Gait);
        }

        [Fact]
        public void Nodding_does_not_count()
        {
            var meter = Squat(period: 1.0, depth: 0.15f, duration: 10.0);
            Assert.Equal(0, meter.Count);
            Assert.Equal(0f, meter.Speed);
        }

        [Theory]
        [InlineData(1.4, 0.6f, Gait.Walk)]
        [InlineData(1.1, 0.8f, Gait.Trot)]
        [InlineData(0.85, 0.95f, Gait.Gallop)]
        public void Faster_and_deeper_squats_make_a_faster_gait(double period, float depth, Gait expected)
        {
            // NOTE (mristin):
            // The periods and the depths of a player's walk, trot and gallop, as
            // recorded (see dev/squats/).
            var meter = Squat(period, depth, duration: 12.0);
            Assert.Equal(expected, meter.Gait);
        }

        [Fact]
        public void Deeper_squats_at_the_same_rhythm_are_faster()
        {
            var shallow = Squat(period: 1.2, depth: 0.4f, duration: 10.0);
            var deep = Squat(period: 1.2, depth: 0.9f, duration: 10.0);
            Assert.Equal(shallow.Count, deep.Count);
            Assert.True(deep.Speed > shallow.Speed + 0.1f, $"{deep.Speed} against {shallow.Speed}");
        }

        [Fact]
        public void It_does_not_matter_how_far_from_the_camera_the_player_stands()
        {
            // NOTE (mristin):
            // Twice as close, the squats are twice as big in pixels, and so is
            // the unit.
            var far = Squat(period: 1.1, depth: 0.8f, duration: 10.0, unit: 80f);
            var close = Squat(period: 1.1, depth: 0.8f, duration: 10.0, unit: 160f);
            Assert.Equal(far.Count, close.Count);
            Assert.Equal(far.Speed, close.Speed, 3);
        }

        [Fact]
        public void Bouncing_up_higher_than_standing_still_counts()
        {
            // NOTE (mristin):
            // Squatting fast, the player comes up higher than she stood.
            var meter = new SquatMeter();
            Stand(meter, 0.0, 1.0);
            for (double t = 1.0; t < 11.0; t += 1.0 / Fps)
            {
                double phase = ((t - 1.0) % 0.85) / 0.85;
                float y = StandingY - 0.3f * Unit
                    + 0.95f * Unit * (float)(0.5 - 0.5 * Math.Cos(2.0 * Math.PI * phase));
                meter.Observe(t, y, Unit);
                meter.Update(t);
            }

            Assert.InRange(meter.Count, 11, 12);
            Assert.Equal(Gait.Gallop, meter.Gait);
        }

        [Fact]
        public void The_horse_stops_soon_after_the_squats_stop()
        {
            var meter = Squat(period: 0.85, depth: 0.95f, duration: 8.5);
            Assert.Equal(Gait.Gallop, meter.Gait);
            double stopped = double.NaN;
            Stand(meter, 8.5, 5.0, t =>
            {
                if (double.IsNaN(stopped) && meter.Gait == Gait.Stand)
                {
                    stopped = t - 8.5;
                }
            });

            Assert.InRange(stopped, 0.5, 2.5);
        }

        [Fact]
        public void The_horse_does_not_stop_in_the_middle_of_a_slow_squat()
        {
            float slowest = float.PositiveInfinity;
            Squat(period: 3.0, depth: 0.8f, duration: 15.0, each: (t, meter) =>
            {
                if (t > 3.0)
                {
                    slowest = Math.Min(slowest, meter.Speed);
                }
            });

            Assert.True(slowest > 0f, "the horse stopped in the middle of a slow squat");
        }

        [Fact]
        public void The_speed_changes_gently()
        {
            float biggest = 0f;
            float previous = 0f;
            Squat(period: 0.85, depth: 0.95f, duration: 6.0, each: (_, meter) =>
            {
                biggest = Math.Max(biggest, meter.Speed - previous);
                previous = meter.Speed;
            });

            Assert.True(biggest < 0.15f, $"The speed jumped by {biggest} in a frame.");
        }

        [Fact]
        public void The_line_stays_steady_between_squats()
        {
            // NOTE (mristin):
            // Her tops vary by a fifth of the unit from squat to squat (she
            // bounces higher at times); the line moves much less.
            var meter = new SquatMeter();
            Stand(meter, 0.0, 1.0);
            Assert.Equal(StandingY + meter.SwingDepth * Unit, meter.Line, 3);
            float lowest = float.PositiveInfinity;
            float highest = float.NegativeInfinity;
            bool reached = false;
            for (double t = 1.0; t < 13.0; t += 1.0 / Fps)
            {
                int squat = (int)((t - 1.0) / 1.2);
                double phase = ((t - 1.0) % 1.2) / 1.2;
                float top = StandingY - (squat % 2 == 0 ? 0f : 0.2f * Unit);
                float y = top + 0.8f * Unit * (float)(0.5 - 0.5 * Math.Cos(2.0 * Math.PI * phase));
                meter.Observe(t, y, Unit);
                meter.Update(t);
                reached |= meter.BelowLine;
                if (t > 4.0)
                {
                    lowest = Math.Min(lowest, meter.Line);
                    highest = Math.Max(highest, meter.Line);
                }
            }

            Assert.True(reached, "the eyes never went below the line");
            Assert.True(highest - lowest < 0.1f * Unit, $"the line moved by {highest - lowest}");
        }

        [Fact]
        public void The_line_follows_the_player_who_stepped_closer()
        {
            // NOTE (mristin):
            // Standing still, her head is suddenly a third of a unit lower, e.g.,
            // after she stepped closer and the camera looks down on her.
            var meter = new SquatMeter();
            Stand(meter, 0.0, 2.0);
            for (double t = 2.0; t < 10.0; t += 1.0 / Fps)
            {
                meter.Observe(t, StandingY + 0.3f * Unit, Unit);
                meter.Update(t);
            }

            float expected = StandingY + 0.3f * Unit + meter.SwingDepth * Unit;
            Assert.InRange(meter.Line, expected - 0.03f * Unit, expected + 0.03f * Unit);
        }

        [Theory]
        [InlineData(2.0, Gait.Walk)]
        [InlineData(1.0, Gait.Trot)]
        [InlineData(0.5, Gait.Gallop)]
        public void Tapping_faster_on_the_keyboard_is_faster(double every, Gait expected)
        {
            var meter = new SquatMeter();
            int frames = (int)Math.Round(every * 30.0);
            for (int frame = 0; frame < 300; frame++)
            {
                double t = frame / 30.0;
                if (frame % frames == 0)
                {
                    meter.RegisterSquat(t);
                }

                meter.Update(t);
            }

            // NOTE (mristin):
            // Right after a key, so that a slow walk did not fade in between.
            meter.RegisterSquat(10.0);
            meter.Update(10.1);
            Assert.Equal(expected, meter.Gait);
        }
    }

    /// <summary>
    /// Replay a player's recorded squats (see dev/squats/) through the head gauge
    /// and the squat meter, as the game does.
    /// </summary>
    public class SquatRecordingTests
    {
        private sealed record Frame(double T, string Label, FaceLandmarks? Face, BoundingBox? Head, bool Detected);

        private static List<Frame> Load(string name)
        {
            var frames = new List<Frame>();
            var lines = File.ReadAllLines(TestData.Path(name));
            foreach (var line in lines.Skip(1))
            {
                var cells = line.Split(',');
                float F(int i) => float.Parse(cells[i], CultureInfo.InvariantCulture);
                FaceLandmarks? face = null;
                if (cells[2] != "")
                {
                    face = new FaceLandmarks
                    {
                        LeftEyeX = F(2),
                        LeftEyeY = F(3),
                        RightEyeX = F(4),
                        RightEyeY = F(5),
                    };
                }

                BoundingBox? head = cells[6] != "" ? new BoundingBox(F(6), F(7), F(8), F(9)) : null;
                frames.Add(new Frame(
                    double.Parse(cells[0], CultureInfo.InvariantCulture), cells[1], face, head, cells[10] == "1"
                ));
            }

            return frames;
        }

        /// <summary>
        /// For each step: the squats counted, the gait in each frame after its
        /// first 4 s, and how long after the last squat of the step (or its start)
        /// the horse stood.
        /// </summary>
        private static Dictionary<string, (int Squats, List<Gait> Gaits, double StoppedAfter)> Replay(string name)
        {
            var gauge = new HeadGauge();
            var meter = new SquatMeter();
            var result = new Dictionary<string, (int Squats, List<Gait> Gaits, double StoppedAfter)>();
            string label = "";
            double start = 0.0;
            int count = 0;
            var gaits = new List<Gait>();
            double stopped = double.NaN;
            double lastSquat = 0.0;
            foreach (var frame in Load(name))
            {
                if (frame.Label != label)
                {
                    if (label != "")
                    {
                        result[label] = (meter.Count - count, gaits, stopped);
                    }

                    label = frame.Label;
                    start = frame.T;
                    count = meter.Count;
                    gaits = new List<Gait>();
                    stopped = double.NaN;
                    lastSquat = frame.T;
                }

                int before = meter.Count;

                if (gauge.Measure(frame.T, frame.Face, frame.Head, frame.Detected))
                {
                    meter.Observe(frame.T, gauge.Y, gauge.Unit);
                }

                meter.Update(frame.T);
                if (meter.Count > before)
                {
                    lastSquat = frame.T;
                    stopped = double.NaN;
                }

                if (frame.T - start > 4.0)
                {
                    gaits.Add(meter.Gait);
                }

                if (double.IsNaN(stopped) && meter.Gait == Gait.Stand)
                {
                    stopped = frame.T - lastSquat;
                }
            }

            result[label] = (meter.Count - count, gaits, stopped);
            return result;
        }

        private static double Share(List<Gait> gaits, Func<Gait, bool> which) =>
            gaits.Count == 0 ? 0.0 : gaits.Count(which) / (double)gaits.Count;

        [Fact]
        public void A_recorded_player_walks_trots_gallops_and_stops()
        {
            var steps = Replay("squats_walk_trot_gallop.csv");
            foreach (var step in new[] { "stand 1", "stand 3" })
            {
                Assert.Equal(0, steps[step].Squats);
                Assert.True(Share(steps[step].Gaits, g => g == Gait.Stand) == 1.0, $"{step} moved the horse");
            }

            foreach (var round in new[] { 1, 2, 3 })
            {
                // NOTE (mristin):
                // Every squat counts (she squatted about 11 to 15 times in 20 s
                // at a walk, 15 to 20 at a trot and 17 or 18 in 15 s at a gallop).
                Assert.InRange(steps[$"walk {round}"].Squats, 10, 16);
                Assert.InRange(steps[$"trot {round}"].Squats, 14, 21);
                Assert.InRange(steps[$"gallop {round}"].Squats, 16, 19);

                var walk = steps[$"walk {round}"].Gaits;
                Assert.True(
                    Share(walk, g => g == Gait.Walk || g == Gait.Trot) > 0.9, $"walk {round} did not walk"
                );
                var gallop = steps[$"gallop {round}"].Gaits;
                Assert.True(Share(gallop, g => g == Gait.Gallop) > 0.8, $"gallop {round} did not gallop");
            }

            // NOTE (mristin):
            // In the first round, she trotted hardly faster than she walked.
            foreach (var round in new[] { 2, 3 })
            {
                var trot = steps[$"trot {round}"].Gaits;
                Assert.True(Share(trot, g => g == Gait.Trot) > 0.6, $"trot {round} did not trot");
                Assert.True(
                    Share(steps[$"walk {round}"].Gaits, g => g == Gait.Walk) > 0.6, $"walk {round} did not walk"
                );
            }

            // NOTE (mristin):
            // She often finished her squat after the call to stop (and went on
            // squatting through the first stop); the horse stands soon after
            // her last squat. In the third stop, she sank from bouncing high
            // into her stance, which looks like the start of a slow squat, so
            // the horse waits a little longer for her to come up.
            Assert.InRange(steps["stop 2"].StoppedAfter, 0.0, 2.0);
            Assert.InRange(steps["stop 3"].StoppedAfter, 0.0, 3.5);
        }
    }
}  // namespace SteppeRescue.Tests
