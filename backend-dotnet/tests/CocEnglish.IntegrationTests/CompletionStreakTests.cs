using CocEnglish.Progress.Application;
using Microsoft.Extensions.DependencyInjection;
using CocEnglish.Shared.Persistence;
using System.Text.Json.Nodes;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class CompletionStreakTests
{
    [Theory]
    [InlineData("2026-11-02", "2026-11-03", 5, 6, "2026-10-29", 0)]
    [InlineData("2026-11-01", "2026-11-03", 5, 1, "2026-11-03", 5)]
    [InlineData(null, "2026-11-03", 0, 1, "2026-11-03", 0)]
    [InlineData("2026-11-03", "2026-11-03", 5, 5, "2026-10-29", 0)]
    public async Task Advance_HandlesConsecutiveGapAndSameDay(string? last, string day, int current, int expected, string start, int lost)
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var rewards = new JsonObject { ["lastQualifiedDay"] = last, ["currentStreak"] = current, ["bestStreak"] = current, ["streakStartDay"] = current > 0 ? "2026-10-29" : null };
        await scope.ServiceProvider.GetRequiredService<OwnerStore>().TransactAsync(async (tx, ct) => { await ProgressCompletionEffects.AdvanceStreakAsync(tx, "alice", rewards, day, ct); return 0; });
        Assert.Equal(expected, rewards.Number("currentStreak")); Assert.Equal(start, rewards.Text("streakStartDay")); Assert.Equal(lost, rewards.Number("lostStreak"));
    }

    [Fact]
    public async Task LateEvent_RebuildsStreakFromActiveAndProtectedDays()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        foreach (var day in new[] { "2026-11-01", "2026-11-03", "2026-11-04" })
            fixture.Driver.Rows[("p_day_activity", day)] = new() { ["userId"] = "alice", ["day"] = day, ["active"] = day != "2026-11-03", ["protected"] = day == "2026-11-03" };
        var rewards = new JsonObject { ["lastQualifiedDay"] = "2026-11-04", ["currentStreak"] = 2, ["bestStreak"] = 2, ["streakStartDay"] = "2026-11-03" };
        await scope.ServiceProvider.GetRequiredService<OwnerStore>().TransactAsync(async (tx, ct) => { await ProgressCompletionEffects.AdvanceStreakAsync(tx, "alice", rewards, "2026-11-02", ct); return 0; });
        Assert.Equal(4, rewards.Number("currentStreak")); Assert.Equal(4, rewards.Number("bestStreak")); Assert.Equal("2026-11-01", rewards.Text("streakStartDay"));
    }
}
