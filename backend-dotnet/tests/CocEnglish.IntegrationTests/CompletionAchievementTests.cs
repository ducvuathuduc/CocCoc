using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.DependencyInjection;
using System.Text.Json.Nodes;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class CompletionAchievementTests
{
    [Fact]
    public async Task Milestones_AwardMissingTiersOnceAndRespectVisibility()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        for (var i = 0; i < 4; i++) fixture.Driver.Rows[("p_first_rewards", "first" + i)] = new() { ["userId"] = "alice" };
        var rewards = new JsonObject { ["currentStreak"] = 7 };
        for (var i = 0; i < 2; i++) await store.TransactAsync(async (tx, ct) => { await ProgressCompletionEffects.GrantAchievementsAsync(tx, "alice", rewards, true, "event", "2026-11-03T10:00:00.000Z", false, ct); return 0; });
        Assert.Equal(3, fixture.Driver.Rows.Count(r => r.Key.Table == "p_achievements"));
        Assert.Equal(3, fixture.Driver.Rows.Count(r => r.Key.Table == "p_activity"));
        Assert.All(fixture.Driver.Rows.Where(r => r.Key.Table == "p_activity"), r => Assert.False(r.Value.Flag("visible")));
        Assert.True(fixture.Driver.Rows.ContainsKey(("p_achievements", CanonicalWire.RowId("p_achievements", "alice", "lessons", "1"))));
        Assert.True(fixture.Driver.Rows.ContainsKey(("p_achievements", CanonicalWire.RowId("p_achievements", "alice", "streak", "2"))));
        Assert.Equal(1, fixture.Driver.Commits);
    }
}
