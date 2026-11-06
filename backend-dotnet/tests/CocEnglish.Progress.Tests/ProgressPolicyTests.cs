using CocEnglish.Progress.Domain;
using Xunit;

namespace CocEnglish.Progress.Tests;

public sealed class ProgressPolicyTests
{
    [Theory]
    [InlineData("ch1_404040000000000000000000", 5, "COMMON,COMMON,COMMON,COMMON")]
    [InlineData("ch1_3f4040000000000000000000", 10, "COMMON,RARE,RARE,RARE")]
    [InlineData("ch1_003f40000000000000000000", 20, "COMMON,RARE,EPIC,EPIC")]
    [InlineData("ch1_3f3f3f000000000000000000", 40, "COMMON,RARE,EPIC,MEGA")]
    public void Chest_KeepsVersionedNodeRollBoundaries(string operation, long gems, string tiers)
    {
        var receipt = QuestChestPolicy.Receipt(operation, 5)!;
        Assert.Equal(gems, receipt.Gems);
        Assert.Equal(tiers.Split(','), receipt.Tiers);
        Assert.Equal(operation, receipt.ReceiptId);
    }

    [Theory]
    [InlineData("ch1_000000000000000000000000", 0)]
    [InlineData("ch1_000000000000000000000000", -1)]
    [InlineData("ch1_FF0000000000000000000000", 5)]
    [InlineData("ch2_000000000000000000000000", 5)]
    [InlineData("ch1_000000", 5)]
    public void Chest_InvalidVersionIdentityOrNonpositiveRewardHasNoChest(string operation, long gems) => Assert.Null(QuestChestPolicy.Receipt(operation, gems));

    [Fact]
    public void Chest_NewOperationsAreDistinctVersionedTwelveByteIdentities()
    {
        var identities = Enumerable.Range(0, 8).Select(_ => QuestChestPolicy.NewOperation()).ToArray();
        Assert.Equal(8, identities.Distinct(StringComparer.Ordinal).Count());
        Assert.All(identities, value => Assert.Matches("^ch1_[0-9a-f]{24}$", value));
    }
}
