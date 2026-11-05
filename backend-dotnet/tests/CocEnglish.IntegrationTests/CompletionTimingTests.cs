using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class CompletionTimingTests
{
    [Theory]
    [InlineData("2026-11-03T09:59:59.999Z", "UTC", 1)]
    [InlineData("2026-11-03T10:00:00.000Z", "Asia/Ho_Chi_Minh", 2)]
    [InlineData("2026-11-03T10:14:59.999Z", "Asia/Ho_Chi_Minh", 3)]
    [InlineData("2026-11-03T10:15:00.000Z", "Asia/Ho_Chi_Minh", 3)]
    [InlineData("2026-11-03T10:20:00.000Z", "Asia/Ho_Chi_Minh", 1)]
    public async Task EventTime_SelectsEffectiveZoneAndHighestActiveBoost(string instant, string expectedZone, int expectedBoost)
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        fixture.Driver.Rows[("p_zone_history", "zone")] = new() { ["userId"] = "alice", ["zone"] = "Asia/Ho_Chi_Minh", ["effectiveAt"] = "2026-11-03T10:00:00.000Z" };
        fixture.Driver.Rows[("p_boosts", "first")] = new() { ["userId"] = "alice", ["kind"] = "XP_BOOST", ["multiplier"] = 2, ["startsAt"] = "2026-11-03T10:00:00.000Z", ["endsAt"] = "2026-11-03T10:15:00.000Z" };
        fixture.Driver.Rows[("p_boosts", "second")] = new() { ["userId"] = "alice", ["kind"] = "HAPPY_HOUR", ["multiplier"] = 3, ["startsAt"] = "2026-11-03T10:10:00.000Z", ["endsAt"] = "2026-11-03T10:20:00.000Z" };
        var when = DateTimeOffset.Parse(instant);
        var result = await store.TransactAsync(async (tx, ct) => (await ProgressCompletionEffects.ZoneAtAsync(tx, "alice", when, ct), await ProgressCompletionEffects.BoostAtAsync(tx, "alice", when, ct)));
        Assert.Equal(expectedZone, result.Item1); Assert.Equal(expectedBoost, result.Item2); Assert.Equal(0, fixture.Driver.Commits);
    }
}
