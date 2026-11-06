using CocEnglish.Progress.Domain;
using Xunit;

namespace CocEnglish.Progress.Tests;

public sealed class LeaguePolicyTests
{
    [Theory]
    [InlineData(1, 9, 4, "STAY", 4)]
    [InlineData(1, 10, 4, "PROMOTE", 5)]
    [InlineData(5, 30, 4, "PROMOTE", 5)]
    [InlineData(6, 30, 4, "STAY", 4)]
    [InlineData(25, 30, 4, "STAY", 4)]
    [InlineData(26, 30, 4, "DEMOTE", 3)]
    [InlineData(30, 30, 0, "STAY", 0)]
    [InlineData(1, 30, 9, "STAY", 9)]
    public void Movement_PreservesSmallCohortAndTierBoundaries(int rank, int size, long tier, string expected, long next)
    {
        var movement = LeaguePolicy.Movement(rank, size, tier);
        Assert.Equal(expected, movement);
        Assert.Equal(next, LeaguePolicy.NextTier(tier, movement));
    }
}
