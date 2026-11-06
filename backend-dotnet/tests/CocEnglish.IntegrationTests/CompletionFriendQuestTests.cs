using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.DependencyInjection;
using System.Text.Json.Nodes;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class CompletionFriendQuestTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Completion_AwardsEachMemberOnce(bool paired)
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var pair = paired ? "pair" : "solo"; var quest = "friend_" + pair; const string week = "2026-11-02";
        var members = paired ? new[] { "alice", "bob" } : new[] { "alice" };
        foreach (var user in members) fixture.Driver.Rows[("p_quests", CanonicalWire.RowId("p_quests", user, "WEEK", week, quest))] = new() {
            ["userId"] = user, ["period"] = "WEEK", ["periodKey"] = week, ["questId"] = quest, ["metricValue"] = 9, ["target"] = 10, ["claimed"] = false, ["claimOperationId"] = null, ["revision"] = 0 };
        if (paired) fixture.Driver.Rows[("p_friend_quests", CanonicalWire.RowId("p_friend_quests", week, pair))] = new() { ["weekId"] = week, ["pairId"] = pair,
            ["templateId"] = "lessons10", ["userIdsJson"] = "[\"alice\",\"bob\"]", ["target"] = 10, ["count"] = 9, ["claimedUserIdsJson"] = "[]", ["membershipFrozenAt"] = "2026-11-02T00:00:00.000Z", ["revision"] = 0 };
        var rewards = new JsonObject { ["gems"] = 20 }; var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        for (var i = 0; i < 2; i++) await store.TransactAsync(async (tx, ct) => { await ProgressCompletionEffects.AdvanceFriendQuestAsync(tx, "alice", week, rewards, ct); return 0; });
        Assert.Equal(30, rewards.Number("gems"));
        Assert.Equal(members.Length, fixture.Driver.Rows.Count(r => r.Key.Table == "p_reward_ledger"));
        foreach (var user in members) { var row = fixture.Driver.Rows[("p_quests", CanonicalWire.RowId("p_quests", user, "WEEK", week, quest))]; Assert.True(row.Flag("claimed")); Assert.Equal(10, row.Number("metricValue")); }
        if (paired) Assert.Equal(10, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "bob"))].Number("gems"));
    }
}
