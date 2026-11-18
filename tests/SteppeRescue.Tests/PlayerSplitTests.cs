using System;

using SteppeRescue.Vision;
using Xunit;

namespace SteppeRescue.Tests
{
    public class PlayerSplitTests
    {
        private const int Width = 640;

        /// <summary>A person whose head is at the x of the (not mirrored) frame, this wide.</summary>
        private static Pose PersonAt(float x, float shoulders)
        {
            var keypoints = new Keypoint[Pose.KeypointCount];
            for (int i = 0; i < keypoints.Length; i++)
            {
                keypoints[i] = new Keypoint(x, 300f, 0f);
            }

            keypoints[(int)BodyPart.Nose] = new Keypoint(x, 100f, 0.9f);
            keypoints[(int)BodyPart.LeftShoulder] = new Keypoint(x + shoulders * 0.5f, 180f, 0.9f);
            keypoints[(int)BodyPart.RightShoulder] = new Keypoint(x - shoulders * 0.5f, 180f, 0.9f);
            return new Pose(keypoints, new BoundingBox(x - 50f, 50f, x + 50f, 450f), 0.9f);
        }

        [Fact]
        public void One_player_plays_the_whole_picture()
        {
            Assert.Equal(0, PlayerSplit.PlayerOf(10f, Width, 1));
            Assert.Equal(0, PlayerSplit.PlayerOf(630f, Width, 1));
        }

        [Fact]
        public void The_first_of_two_players_stands_in_the_left_half_of_the_mirrored_picture()
        {
            // NOTE (mristin):
            // The right half of the (not mirrored) frame is the left half of the
            // mirrored picture, which the players see.
            Assert.Equal(0, PlayerSplit.PlayerOf(500f, Width, 2));
            Assert.Equal(1, PlayerSplit.PlayerOf(100f, Width, 2));
        }

        [Fact]
        public void Each_of_two_players_gets_the_person_in_her_half()
        {
            var left = PersonAt(480f, 100f);
            var right = PersonAt(160f, 120f);
            var poses = new[] { right, left };

            Assert.Same(left, PlayerSelection.Pick(poses, 0.5f, Width, 0, 2));
            Assert.Same(right, PlayerSelection.Pick(poses, 0.5f, Width, 1, 2));

            // NOTE (mristin):
            // A single player is the closest person, wherever she stands.
            Assert.Same(right, PlayerSelection.Pick(poses, 0.5f, Width));
        }

        [Fact]
        public void A_player_without_a_person_in_her_half_is_not_found()
        {
            var poses = new[] { PersonAt(160f, 120f) };
            Assert.Null(PlayerSelection.Pick(poses, 0.5f, Width, 0, 2));
        }
    }
}
