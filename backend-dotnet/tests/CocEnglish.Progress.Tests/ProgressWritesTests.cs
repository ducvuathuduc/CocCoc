using System.Text.Json.Nodes;
using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.Progress.Tests;

public sealed class ProgressWritesTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Deletion_AtomicallyTombstonesAndEnqueuesExactlyOneOwnerEvent(bool hasProfile)
    {
        var driver = new Driver();
        var store = new OwnerStore(driver, new Clock());
        var app = new ProgressWrites();
        if (hasProfile) await store.TransactAsync((tx, ct) => app.InitializeProfileAsync(tx, "alice", ct));
        var result = await store.TransactAsync((tx, ct) => app.RequestDeletionAsync(tx, "alice", ct));
        Assert.Equal("REQUESTED", result.Status);
        Assert.True(Guid.TryParse(result.RequestId, out _));
        Assert.Equal(DateTimeOffset.Parse("2026-11-03T10:00:00Z"), result.RequestedAt);
        var tombstone = driver.Rows[("p_deletions", CanonicalWire.RowId("p_deletions", "alice"))];
        Assert.Equal(result.RequestId, tombstone.Text("requestId"));
        Assert.Equal("[]", tombstone.Text("ownerAcksJson"));
        Assert.Null(tombstone["completedAt"]);
        if (hasProfile)
        {
            var profile = driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))];
            Assert.False(profile.Flag("publicOptIn"));
            Assert.Equal("2026-11-03T10:00:00.000Z", profile.Text("deletedAt"));
        }
        var outbox = Assert.Single(driver.Rows, p => p.Key.Table == "p_outbox");
        Assert.Equal(CanonicalWire.RowId("p_outbox", outbox.Value.Text("eventId")!), outbox.Key.Id);
        Assert.Equal("account.deleted.v1", outbox.Value.Text("type"));
        Assert.Equal("alice", outbox.Value.Text("aggregateId"));
        Assert.Equal("PENDING", outbox.Value.Text("status"));
        Assert.Equal(0, outbox.Value.Number("attempt"));
        Assert.Equal("2026-11-03T10:00:00.000Z", outbox.Value.Text("nextAttemptAt"));
        var payload = JsonNode.Parse(outbox.Value.Text("payloadJson")!)!.AsObject();
        Assert.Equal(2, payload.Count);
        Assert.Equal("alice", payload.Text("userId"));
        Assert.Equal(result.RequestId, payload.Text("requestId"));
        var commits = driver.Commits;
        var repeat = await store.TransactAsync((tx, ct) => app.RequestDeletionAsync(tx, "alice", ct));
        Assert.Equal(result, repeat);
        Assert.Equal(commits, driver.Commits);
        Assert.Single(driver.Rows, p => p.Key.Table == "p_outbox");
    }
    [Fact]
    public async Task ProfileUpdate_NormalizesNicknameAndDistinguishesAvatarClearFromOmission()
    {
        var driver = new Driver();
        var store = new OwnerStore(driver, new Clock());
        var app = new ProgressWrites();
        await store.TransactAsync((tx, ct) => app.InitializeProfileAsync(tx, "alice", ct));
        var result = await store.TransactAsync((tx, ct) => app.UpdateProfileAsync(tx, "alice", new(0, "  Cafe\u0301\t Việt \n ", "avatar-1", true, 15) { HasAvatarId = true }, ct));
        Assert.Equal("Café Việt", result.Nickname);
        Assert.Equal("avatar-1", result.AvatarId);
        Assert.Equal(15, result.DailyGoal);
        Assert.True(result.PublicOptIn);
        Assert.Equal(1, result.Revision);
        var omitted = await store.TransactAsync((tx, ct) => app.UpdateProfileAsync(tx, "alice", new(1, DailyGoal: 20), ct));
        Assert.Equal("avatar-1", omitted.AvatarId);
        Assert.Equal("Café Việt", omitted.Nickname);
        var cleared = await store.TransactAsync((tx, ct) => app.UpdateProfileAsync(tx, "alice", new(2) { HasAvatarId = true }, ct));
        Assert.Null(cleared.AvatarId);
        Assert.Equal(3, cleared.Revision);
        Assert.Equal("2026-11-03T10:00:00.000Z", driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))].Text("createdAt"));
    }

    [Fact]
    public async Task ProfileUpdate_SchedulesImmutableZoneAtNextUtcMidnightAndRateLimitsExactly24Hours()
    {
        var driver = new Driver();
        var clock = new Clock();
        var store = new OwnerStore(driver, clock);
        var app = new ProgressWrites();
        await store.TransactAsync((tx, ct) => app.InitializeProfileAsync(tx, "alice", ct));
        var scheduled = await store.TransactAsync((tx, ct) => app.UpdateProfileAsync(tx, "alice", new(0, LearningZone: "Asia/Ho_Chi_Minh"), ct));
        Assert.Equal("UTC", scheduled.LearningZone);
        Assert.Equal("Asia/Ho_Chi_Minh", scheduled.PendingZone);
        Assert.Equal(DateTimeOffset.Parse("2026-11-04T00:00:00Z"), scheduled.ZoneEffectiveAt);
        Assert.Equal("Asia/Ho_Chi_Minh", driver.Rows[("p_zone_history", CanonicalWire.RowId("p_zone_history", "alice", "2026-11-04T00:00:00.000Z"))].Text("zone"));
        clock.Now = clock.Now.AddDays(1).AddMilliseconds(-1);
        var limited = await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.UpdateProfileAsync(tx, "alice", new(1, LearningZone: "Europe/Paris"), ct)));
        Assert.Equal("RATE_LIMITED", limited.Code);
        Assert.Equal(1, limited.RetryAfterSeconds);
        Assert.Equal(2, driver.Commits);
        clock.Now = clock.Now.AddMilliseconds(1);
        var changed = await store.TransactAsync((tx, ct) => app.UpdateProfileAsync(tx, "alice", new(1, LearningZone: "Europe/Paris"), ct));
        Assert.Equal("Asia/Ho_Chi_Minh", changed.LearningZone);
        Assert.Equal("Europe/Paris", changed.PendingZone);
        Assert.Equal(DateTimeOffset.Parse("2026-11-05T00:00:00Z"), changed.ZoneEffectiveAt);
        Assert.Equal(3, driver.Rows.Count(p => p.Key.Table == "p_zone_history"));
    }

    [Theory]
    [InlineData("child", "FORBIDDEN")]
    [InlineData("nickname", "VALIDATION_ERROR")]
    [InlineData("zone", "INVALID_TIMEZONE")]
    [InlineData("revision", "REVISION_CONFLICT")]
    public async Task ProfileUpdate_InvalidBusinessChangesDoNotWrite(string scenario, string code)
    {
        var driver = new Driver();
        var store = new OwnerStore(driver, new Clock());
        var app = new ProgressWrites();
        await store.TransactAsync((tx, ct) => app.InitializeProfileAsync(tx, "alice", ct));
        driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))]["ageBand"] = "CHILD";
        var patch = scenario switch { "child" => new ProfilePatchRequest(0, PublicOptIn: true), "nickname" => new(0, Nickname: " \t\uFEFF"), "zone" => new(0, LearningZone: "Pacific Standard Time"), _ => new(1) };
        var error = await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.UpdateProfileAsync(tx, "alice", patch, ct)));
        Assert.Equal(code, error.Code);
        Assert.Equal(1, driver.Commits);
        Assert.Equal(0, driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))].Number("revision"));
    }
    [Fact]
    public async Task Initialize_CreatesFullOwnerStateAndDoesNotCreditAgainOnAnotherRequest()
    {
        var driver = new Driver();
        var store = new OwnerStore(driver, new Clock());
        var app = new ProgressWrites();
        var profile = await store.TransactAsync((tx, ct) => app.InitializeProfileAsync(tx, "alice", ct));
        Assert.Equal("alice", profile.UserId);
        Assert.Equal("usera63f23edd9cc", profile.Nickname);
        Assert.Equal("UTC", profile.LearningZone);
        Assert.False(profile.PublicOptIn);
        Assert.Equal(10, profile.DailyGoal);
        Assert.Equal(0, profile.Revision);
        Assert.Empty(profile.AchievementIds);
        Assert.Equal(7, driver.Rows.Count);
        Assert.Equal(20, driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("gems"));
        var ledger = Assert.Single(driver.Rows, p => p.Key.Table == "p_reward_ledger").Value;
        Assert.Equal("INITIAL", ledger.Text("kind"));
        Assert.Equal(20, ledger.Number("gemsDelta"));
        Assert.Equal(0, ledger.Number("studyXpDelta"));
        Assert.Equal("FREE", driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "alice"))].Text("plan"));
        Assert.Equal(1200, driver.Rows[("p_preferences", CanonicalWire.RowId("p_preferences", "alice"))].Number("reminderMinute"));
        Assert.Equal("1970-01-01T00:00:00.000Z", Assert.Single(driver.Rows, p => p.Key.Table == "p_zone_history").Value.Text("effectiveAt"));
        var repeat = await store.TransactAsync((tx, ct) => app.InitializeProfileAsync(tx, "alice", ct));
        Assert.Equal(System.Text.Json.JsonSerializer.Serialize(profile), System.Text.Json.JsonSerializer.Serialize(repeat));
        Assert.Equal(1, driver.Commits);
        Assert.Equal(20, driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("gems"));
    }

    [Fact]
    public async Task Initialize_PreservesEarlierRewardsAndExistingPreferencesAndRejectsTombstone()
    {
        var driver = new Driver();
        var store = new OwnerStore(driver, new Clock());
        var app = new ProgressWrites();
        await store.TransactAsync((tx, ct) => app.InitializeProfileAsync(tx, "alice", ct));
        driver.Rows.Remove(("p_profiles", CanonicalWire.RowId("p_profiles", "alice")));
        var reward = driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))];
        reward["studyXp"] = 35; reward["gems"] = 9;
        // Simulate events arriving before profile initialization, without an initial credit ledger.
        driver.Rows.Remove(driver.Rows.Keys.Single(k => k.Table == "p_reward_ledger"));
        driver.Rows[("p_preferences", CanonicalWire.RowId("p_preferences", "alice"))]["haptics"] = false;
        await store.TransactAsync((tx, ct) => app.InitializeProfileAsync(tx, "alice", ct));
        var result = driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))];
        Assert.Equal(29, result.Number("gems"));
        Assert.Equal(35, result.Number("studyXp"));
        Assert.False(driver.Rows[("p_preferences", CanonicalWire.RowId("p_preferences", "alice"))].Flag("haptics"));
        driver.Rows[("p_deletions", CanonicalWire.RowId("p_deletions", "alice"))] = new() { ["userId"] = "alice" };
        var commits = driver.Commits;
        Assert.Equal("PROFILE_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.InitializeProfileAsync(tx, "alice", ct)))).Code);
        Assert.Equal(commits, driver.Commits);
    }
    [Fact]
    public async Task Preferences_CreateDefaultsAndChangeOnlySuppliedFieldsInOneCommit()
    {
        var driver = Fixture();
        var store = new OwnerStore(driver, new Clock());
        var writes = new ProgressWrites();
        var result = await store.TransactAsync((tx, ct) => writes.UpdatePreferencesAsync(tx, "alice", new(0, ["EMAIL"], SoundEffects: false, ReminderMinute: 0), ct));
        Assert.False(result.SoundEffects);
        Assert.True(result.SmartScheduling);
        Assert.Equal(0, result.ReminderMinute);
        Assert.Equal(new[] { "EMAIL" }, result.NotificationsOff);
        Assert.Equal(0, result.Revision);
        var row = driver.Rows[("p_preferences", CanonicalWire.RowId("p_preferences", "alice"))];
        Assert.Equal("[\"EMAIL\"]", row.Text("notificationsOffJson"));
        Assert.Equal("2026-11-03T10:00:00.000Z", row.Text("createdAt"));
        Assert.Equal(1, driver.Commits);
        var changed = await store.TransactAsync((tx, ct) => writes.UpdatePreferencesAsync(tx, "alice", new(0, [], SmartScheduling: false, ReminderMinute: 1439), ct));
        Assert.Equal(1, changed.Revision);
        Assert.Empty(changed.NotificationsOff);
        Assert.False(changed.SoundEffects);
        Assert.False(changed.SmartScheduling);
        Assert.Equal(1439, changed.ReminderMinute);
        Assert.True(changed.FriendStreakInvites);
    }

    [Fact]
    public async Task Preferences_RevisionMismatchDoesNotWriteOrCreateDefaults()
    {
        var driver = Fixture();
        var store = new OwnerStore(driver, new Clock());
        var error = await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => new ProgressWrites().UpdatePreferencesAsync(tx, "alice", new(1), ct)));
        Assert.Equal("REVISION_CONFLICT", error.Code);
        Assert.Equal(0, error.Details.Number("currentRevision"));
        Assert.Equal(0, driver.Commits);
        Assert.Single(driver.Rows);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Writes_RejectMissingOrDeletedProfileWithoutSideEffects(bool deleted)
    {
        var driver = Fixture();
        if (deleted) driver.Rows[("p_deletions", CanonicalWire.RowId("p_deletions", "alice"))] = new() { ["userId"] = "alice" };
        else driver.Rows.Clear();
        var store = new OwnerStore(driver, new Clock());
        Assert.Equal("PROFILE_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => new ProgressWrites().UpdatePreferencesAsync(tx, "alice", new(0), ct)))).Code);
        Assert.Equal("PROFILE_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => new ProgressWrites().UpdateProfileAsync(tx, "alice", new(0), ct)))).Code);
        Assert.Equal("PROFILE_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync(async (tx, ct) => { await new ProgressWrites().SendFeedbackAsync(tx, "alice", new("bug", "text", "1", "ANDROID"), "key", ct); return 0; }))).Code);
        Assert.Equal(0, driver.Commits);
    }

    [Fact]
    public async Task Feedback_StoresExactUnicodeTextAndVerifiedSubjectAtDeterministicId()
    {
        var driver = Fixture();
        await new OwnerStore(driver, new Clock()).TransactAsync(async (tx, ct) =>
        {
            await new ProgressWrites().SendFeedbackAsync(tx, "alice", new("bug", "Lỗi tiếng Việt 😀", "1.2", "ANDROID"), "key", ct);
            return 0;
        });
        var row = driver.Rows[("p_feedback", CanonicalWire.RowId("p_feedback", "alice", "key"))];
        Assert.Equal("alice", row.Text("userId"));
        Assert.Equal("Lỗi tiếng Việt 😀", row.Text("message"));
        Assert.Equal("OPEN", row.Text("status"));
        Assert.Equal("1.2", row.Text("appVersion"));
        Assert.Equal("ANDROID", row.Text("platform"));
        Assert.Equal(1, driver.Commits);
    }

    private static Driver Fixture()
    {
        var driver = new Driver();
        driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))] = new() { ["userId"] = "alice", ["learningZone"] = "UTC" };
        return driver;
    }
    private sealed class Clock : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = DateTimeOffset.Parse("2026-11-03T10:00:00Z");
        public override DateTimeOffset GetUtcNow() => Now;
    }
    private sealed class Driver : IRowDriver
    {
        public string Owner => "progress";
        public bool Configured => true;
        public int Commits { get; private set; }
        public Dictionary<(string Table, string Id), JsonObject> Rows { get; } = [];
        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken ct) => Task.FromResult(Rows.TryGetValue((table, id), out var row) ? new RowDocument(id, row.DeepClone().AsObject(), "version") : null);
        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken ct) => Task.FromResult<IReadOnlyList<RowDocument>>(Rows.Where(p => p.Key.Table == table && (query.Where is null || query.Where.All(q => p.Value[q.Key]?.ToString() == q.Value?.ToString()))).Select(p => new RowDocument(p.Key.Id, p.Value.DeepClone().AsObject(), "version")).ToArray());
        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken ct) => throw new NotSupportedException();
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken ct)
        {
            Commits++;
            foreach (var write in writes) Rows[(write.Table, write.Id)] = write.Data!.DeepClone().AsObject();
            return Task.CompletedTask;
        }
    }
}
