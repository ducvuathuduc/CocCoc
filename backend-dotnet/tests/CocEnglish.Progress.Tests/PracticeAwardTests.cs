using CocEnglish.Progress.Domain;
using Xunit;

namespace CocEnglish.Progress.Tests;

public sealed class PracticeAwardTests
{
    [Theory]
    [InlineData(20, 0, 0, 1, 20, false)]
    [InlineData(40, 0, 0, 3, 100, true)]
    [InlineData(10, 1195, 0, 1, 5, true)]
    [InlineData(10, 0, 99, 1, 1, true)]
    [InlineData(0, 1200, 100, 3, 0, false)]
    [InlineData(10, 0, 0, 8, 30, false)]
    [InlineData(10, 0, 0, 0, 10, false)]
    public void Award_RespectsBothCapsAndBoostBounds(int xp, int dayXp, int practiceXp, int boost, int expected, bool capped)
    {
        var result = PracticePolicy.Award(xp, dayXp, practiceXp, boost);
        Assert.Equal(expected, result.StudyXp); Assert.Equal(expected, result.LeagueXp); Assert.Equal(capped, result.Capped);
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(101)]
    public void Award_RejectsXpOutsideProducerRange(int xp) => Assert.Throws<ArgumentOutOfRangeException>(() => PracticePolicy.Award(xp, 0, 0, 1));
}
