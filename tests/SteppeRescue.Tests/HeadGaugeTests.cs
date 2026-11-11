using System;

using SteppeRescue.Vision;
using Xunit;

namespace SteppeRescue.Tests
{
    public class HeadGaugeTests
    {
        private const double Fps = 30.0;

        /// <summary>The face with the eyes this far apart, at the height <paramref name="eyesY"/>.</summary>
        private static FaceLandmarks Face(float eyesY, float eyes = 20f, float x = 300f)
        {
            return new FaceLandmarks
            {
                Box = BoundingBox.FromCenter(x, eyesY + 5f, eyes * 2.5f, eyes * 3f),
                Score = 0.9f,
                RightEyeX = x - eyes * 0.5f,
                RightEyeY = eyesY,
                LeftEyeX = x + eyes * 0.5f,
                LeftEyeY = eyesY,
            };
        }

        /// <summary>The box of the head of the same face: the eyes lie a little below its center.</summary>
        private static BoundingBox Head(float eyesY, float eyes = 20f, float x = 300f)
        {
            return BoundingBox.FromCenter(x, eyesY - eyes * 0.3f, eyes * 2.2f, eyes * 3f);
        }

        [Fact]
        public void Measures_the_eyes_and_the_unit_of_the_face()
        {
            var gauge = new HeadGauge();
            Assert.True(gauge.Measure(0.0, Face(150f), null, false));
            Assert.Equal(150f, gauge.Y, 3);
            Assert.Equal(20f * HeadGauge.UnitPerEyeDistance, gauge.Unit, 3);
        }

        [Fact]
        public void Measures_nothing_without_a_head()
        {
            var gauge = new HeadGauge();
            Assert.False(gauge.Measure(0.0, null, null, false));
            Assert.True(float.IsNaN(gauge.Y));
        }

        [Fact]
        public void Does_not_jump_when_the_face_is_lost_and_only_the_head_box_remains()
        {
            var gauge = new HeadGauge();
            double t = 0.0;

            // NOTE (mristin):
            // The detector and the landmarks see the head together four times a
            // second for two seconds, which calibrates the box.
            for (int i = 0; i < 60; i++, t += 1.0 / Fps)
            {
                gauge.Measure(t, Face(150f), Head(150f), i % 8 == 0);
            }

            // NOTE (mristin):
            // A squat counts from half a unit, so a few hundredths do not matter.
            gauge.Measure(t, null, Head(150f), true);
            const float unit = 20f * HeadGauge.UnitPerEyeDistance;
            Assert.InRange(gauge.Y, 150f - 0.03f * unit, 150f + 0.03f * unit);
            Assert.InRange(gauge.Unit, 20f * HeadGauge.UnitPerEyeDistance * 0.97f, 20f * HeadGauge.UnitPerEyeDistance * 1.03f);
        }

        [Fact]
        public void Squats_count_from_the_faces_alone()
        {
            var gauge = new HeadGauge();
            var meter = new SquatMeter();
            const float standing = 150f;
            const float unit = 20f * HeadGauge.UnitPerEyeDistance;
            const double period = 2.0;
            for (double t = 0.0; t < 10.0; t += 1.0 / Fps)
            {
                double phase = (t % period) / period;
                float y = standing + unit * (float)(0.5 - 0.5 * Math.Cos(2.0 * Math.PI * phase));

                // NOTE (mristin):
                // In the deepest part of the squat, the player looks down and the
                // face is lost, so that only the box of the head is found.
                bool lost = phase > 0.4 && phase < 0.6;
                bool measured = gauge.Measure(t, lost ? null : Face(y), Head(y), lost || (int)(t * Fps) % 8 == 0);
                Assert.True(measured);
                meter.Observe(t, gauge.Y, gauge.Unit);
                meter.Update(t);
            }

            Assert.Equal(5, meter.Count);
        }
    }
}  // namespace SteppeRescue.Tests
