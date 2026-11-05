using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class CompletionFriendStreakTests
{
    [Theory]
    [InlineData("2026-11-02", true, "ACTIVE", 5)]
    [InlineData("2026-10-30", true, "ACTIVE", 1)]
    [InlineData("2026-11-03", true, "ACTIVE", 4)]
    [InlineData("2026-11-02", false, "ACTIVE", 4)]
    [InlineData("2026-11-02", true, "PENDING", 4)]
    public async Task Extend_RequiresBothActiveAndRunsOncePerDay(string last, bool partnerActive, string status, int expected)
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var id = CanonicalWire.RowId("p_friend_streaks", "pair");
        fixture.Driver.Rows[("p_friend_streaks", id)] = new() { ["pairId"] = "pair", ["userAId"] = "alice", ["userBId"] = "bob", ["inviterId"] = "alice", ["status"] = status,
            ["startDay"] = "2026-10-30", ["lastExtendedDay"] = last, ["length"] = 4, ["endedAt"] = null, ["revision"] = 0 };
        fixture.Driver.Rows[("p_day_activity", CanonicalWire.RowId("p_day_activity", "bob", "2026-11-03"))] = new() { ["userId"] = "bob", ["day"] = "2026-11-03", ["active"] = partnerActive, ["protected"] = !partnerActive };
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        for (var i = 0; i < 2; i++) await store.TransactAsync(async (tx, ct) => { await ProgressCompletionEffects.ExtendFriendStreaksAsync(tx, "alice", "2026-11-03", ct); return 0; });
        var row = fixture.Driver.Rows[("p_friend_streaks", id)]; Assert.Equal(expected, row.Number("length"));
        if (expected == 1) Assert.Equal("2026-11-03", row.Text("startDay"));
        Assert.Equal(expected is 1 or 5 ? 1 : 0, fixture.Driver.Commits);
    }
}
