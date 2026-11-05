using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LeagueResultTests
{
    [Fact]
    public async Task Result_DefaultProjectionDoesNotCreateStateAndUnknownSeenIsRejected()
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var app = new ProgressLeagueResults();
        var result = await store.TransactAsync((tx, ct) => app.GetAsync(tx, "alice", ct));
        Assert.Equal(0, result.Tier);
        Assert.Equal("LEAGUE", result.Stage);
        Assert.Equal(0, result.WeeksParticipated);
        Assert.Null(result.LastResult);
        Assert.False(result.Unseen);
        Assert.Equal("NOT_FOUND", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.SeenAsync(tx, "alice", "2026-10-26", ct)))).Code);
        Assert.Equal(0, fixture.Driver.Commits);
    }

    [Fact]
    public async Task Result_OnlyLatestWeekCanBeSeenAndRepeatedSeenDoesNotRewrite()
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var id = CanonicalWire.RowId("p_league_profiles", "alice");
        fixture.Driver.Rows[("p_league_profiles", id)] = System.Text.Json.Nodes.JsonNode.Parse("""{"userId":"alice","tier":3,"stage":"LEAGUE","weeksParticipated":5,"topThreeFinishes":2,"diamondWeeks":0,"lastSettledWeekId":"2026-10-26","resultSeenWeekId":null,"lastResultJson":"{\"weekId\":\"2026-10-26\",\"previousTier\":2,\"tier\":3,\"rank\":1,\"outcome\":\"PROMOTED\",\"gemsAwarded\":20}"}""")!.AsObject();
        var app = new ProgressLeagueResults();
        var result = await store.TransactAsync((tx, ct) => app.GetAsync(tx, "alice", ct));
        Assert.True(result.Unseen);
        Assert.Equal(3, result.Tier);
        Assert.Equal(5, result.WeeksParticipated);
        Assert.Equal(2, result.TopThreeFinishes);
        Assert.Equal(20, result.LastResult!.GemsAwarded);
        Assert.Equal(1, result.LastResult.Rank);
        Assert.Equal("PROMOTED", result.LastResult.Outcome);
        Assert.Equal("NOT_FOUND", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.SeenAsync(tx, "alice", "2026-10-19", ct)))).Code);
        Assert.Equal("completed", await store.TransactAsync((tx, ct) => app.SeenAsync(tx, "alice", "2026-10-26", ct)));
        Assert.Equal("replayed", await store.TransactAsync((tx, ct) => app.SeenAsync(tx, "alice", "2026-10-26", ct)));
        Assert.False((await store.TransactAsync((tx, ct) => app.GetAsync(tx, "alice", ct))).Unseen);
        Assert.Equal(1, fixture.Driver.Commits);
    }
}
