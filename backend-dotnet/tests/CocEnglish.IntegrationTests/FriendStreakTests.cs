using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class FriendStreakTests
{
    [Theory]
    [InlineData(4, true)]
    [InlineData(5, false)]
    [InlineData(6, false)]
    public async Task Invitation_EnforcesOpenRelationshipCapacityAtFive(int count, bool allowed)
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        await Seed(store, fixture);
        for (var i = 0; i < count; i++) fixture.Driver.Rows[("p_friend_streaks", "existing-" + i)] = new()
        { ["userAId"] = i % 2 == 0 ? "alice" : "other", ["userBId"] = i % 2 == 0 ? "other" : "alice", ["status"] = i % 2 == 0 ? "ACTIVE" : "PENDING" };
        var commits = fixture.Driver.Commits;
        if (allowed) Assert.Equal("PENDING", (await store.TransactAsync((tx, ct) => new ProgressFriendStreaks().InviteAsync(tx, "alice", "bob", ct))).Status);
        else
        {
            Assert.Equal("FRIEND_STREAK_LIMIT", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => new ProgressFriendStreaks().InviteAsync(tx, "alice", "bob", ct)))).Code);
            Assert.Equal(commits, fixture.Driver.Commits);
        }
    }
    [Theory]
    [InlineData(true, "ACTIVE")]
    [InlineData(false, "DECLINED")]
    public async Task Invitation_OnlyRecipientRespondsAndRepeatsDoNotRewrite(bool accept, string status)
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        await Seed(store, fixture);
        var app = new ProgressFriendStreaks();
        var invite = await store.TransactAsync((tx, ct) => app.InviteAsync(tx, "alice", "bob", ct));
        Assert.Equal(CanonicalWire.RowId("operation", "friend-streak", "alice", "bob"), invite.PairId);
        Assert.Equal("PENDING", invite.Status);
        Assert.Equal("bob", invite.FriendUserId);
        Assert.Equal(0, invite.Length);
        Assert.Null(invite.StartDay);
        var commits = fixture.Driver.Commits;
        Assert.Equal(invite, await store.TransactAsync((tx, ct) => app.InviteAsync(tx, "alice", "bob", ct)));
        Assert.Equal(commits, fixture.Driver.Commits);
        Assert.Equal("REVISION_CONFLICT", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.RespondAsync(tx, "alice", invite.PairId, accept, ct)))).Code);
        var result = await store.TransactAsync((tx, ct) => app.RespondAsync(tx, "bob", invite.PairId, accept, ct));
        Assert.Equal(status, result.Status);
        Assert.Equal("alice", result.FriendUserId);
        Assert.Equal(accept ? "2026-11-03" : null, result.StartDay);
        commits = fixture.Driver.Commits;
        Assert.Equal(result, await store.TransactAsync((tx, ct) => app.RespondAsync(tx, "bob", invite.PairId, accept, ct)));
        Assert.Equal(commits, fixture.Driver.Commits);
        var page = await store.TransactAsync((tx, ct) => app.ListAsync(tx, "bob", ct));
        Assert.Equal(accept ? 1 : 0, page.Items.Count);
        Assert.Null(page.NextCursor);
    }

    [Theory]
    [InlineData("self", "VALIDATION_ERROR")]
    [InlineData("no-mutual", "PROFILE_UNAVAILABLE")]
    [InlineData("child", "FORBIDDEN")]
    [InlineData("target-child", "PROFILE_UNAVAILABLE")]
    [InlineData("opt-out", "PROFILE_UNAVAILABLE")]
    [InlineData("blocked", "USER_BLOCKED")]
    public async Task Invitation_DenialsDoNotCreateRelationship(string state, string code)
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        await Seed(store, fixture);
        if (state == "no-mutual") fixture.Driver.Rows.Remove(("p_follows", CanonicalWire.RowId("p_follows", "bob", "alice")));
        if (state == "child") fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))]["ageBand"] = "CHILD";
        if (state == "target-child") fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))]["ageBand"] = "CHILD";
        if (state == "opt-out") fixture.Driver.Rows[("p_preferences", CanonicalWire.RowId("p_preferences", "bob"))]["friendStreakInvites"] = false;
        if (state == "blocked") fixture.Driver.Rows[("p_blocks", CanonicalWire.RowId("p_blocks", "bob", "alice"))] = new();
        var commits = fixture.Driver.Commits;
        Assert.Equal(code, (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => new ProgressFriendStreaks().InviteAsync(tx, "alice", state == "self" ? "alice" : "bob", ct)))).Code);
        Assert.Equal(commits, fixture.Driver.Commits);
        Assert.DoesNotContain(fixture.Driver.Rows, p => p.Key.Table == "p_friend_streaks");
    }

    private static async Task Seed(OwnerStore store, ProgressApiFixture fixture)
    {
        fixture.Driver.Rows.Clear();
        foreach (var user in new[] { "alice", "bob" }) await store.TransactAsync((tx, ct) => new ProgressWrites().InitializeProfileAsync(tx, user, ct));
        foreach (var (a, b) in new[] { ("alice", "bob"), ("bob", "alice") })
            fixture.Driver.Rows[("p_follows", CanonicalWire.RowId("p_follows", a, b))] = new() { ["fromUserId"] = a, ["toUserId"] = b, ["status"] = "ACTIVE" };
    }
}
