using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class CompletionQuestTests
{
    [Fact]
    public async Task Increments_CreateCorrectPeriodsAndPreserveClaimedState()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var existing = CanonicalWire.RowId("p_quests", "alice", "DAY", "2026-11-03", "daily_lessons");
        fixture.Driver.Rows[("p_quests", existing)] = new() { ["userId"] = "alice", ["period"] = "DAY", ["periodKey"] = "2026-11-03", ["questId"] = "daily_lessons",
            ["metricValue"] = 2, ["target"] = 2, ["claimed"] = true, ["claimOperationId"] = "previous", ["revision"] = 0 };
        await store.TransactAsync(async (tx, ct) => { await ProgressCompletionEffects.BumpQuestsAsync(tx, "alice", "2026-11-03", 1, 4, 0, 1, ct); return 0; });
        var row = fixture.Driver.Rows[("p_quests", existing)];
        Assert.Equal(3, row.Number("metricValue")); Assert.True(row.Flag("claimed")); Assert.Equal("previous", row.Text("claimOperationId"));
        Assert.Equal(4, fixture.Driver.Rows[("p_quests", CanonicalWire.RowId("p_quests", "alice", "DAY", "2026-11-03", "daily_correct"))].Number("metricValue"));
        Assert.Equal(1, fixture.Driver.Rows[("p_quests", CanonicalWire.RowId("p_quests", "alice", "MONTH", "2026-11", "monthly_active_days"))].Number("metricValue"));
        Assert.False(fixture.Driver.Rows.ContainsKey(("p_quests", CanonicalWire.RowId("p_quests", "alice", "DAY", "2026-11-03", "daily_review"))));
    }
}
