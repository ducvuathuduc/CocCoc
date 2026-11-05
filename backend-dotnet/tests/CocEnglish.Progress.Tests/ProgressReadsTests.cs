using System.Globalization;
using System.Text.Json.Nodes;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.Progress.Tests;

public sealed class ProgressReadsTests
{
    [Theory]
    [InlineData("FREE", "ACTIVE", null, "FREE", "ACTIVE", false, false, true)]
    [InlineData("SUPER", "ACTIVE", null, "SUPER", "ACTIVE", true, false, true)]
    [InlineData("MAX", "GRACE", "2026-11-03T23:30:00.001Z", "MAX", "GRACE", true, true, true)]
    [InlineData("MAX", "CANCELED", "2026-11-03T23:30:00.001Z", "MAX", "CANCELED", true, true, true)]
    [InlineData("MAX", "ACTIVE", "2026-11-03T23:30:00.000Z", "FREE", "EXPIRED", false, false, false)]
    [InlineData("MAX", "HOLD", "2026-11-03T23:30:00.001Z", "MAX", "HOLD", false, false, true)]
    [InlineData("SUPER", "REVOKED", null, "SUPER", "REVOKED", false, false, true)]
    public async Task Entitlement_ProjectsExactExpiryAndIndependentAccessFlags(string plan, string status, string? expires,
        string expectedPlan, string expectedStatus, bool premium, bool conversations, bool renewal)
    {
        var driver = Fixture();
        driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "alice"))] = new()
        { ["userId"] = "alice", ["plan"] = plan, ["status"] = status, ["source"] = "PURCHASE", ["expiresAt"] = expires, ["autoRenew"] = true, ["familyGroupId"] = "family", ["revision"] = 4 };
        var result = await Service(driver).GetEntitlementAsync("alice", CancellationToken.None);
        Assert.Equal(expectedPlan, result.Plan);
        Assert.Equal(expectedStatus, result.Status);
        Assert.Equal(premium, result.UnlimitedEnergy);
        Assert.Equal(premium, result.AdFree);
        Assert.Equal(conversations, result.Conversations);
        Assert.Equal(renewal, result.AutoRenew);
        Assert.Equal("PURCHASE", result.Source);
        Assert.Equal("family", result.FamilyGroupId);
        Assert.Equal(4, result.Revision);
        Assert.Equal(Now, result.AsOf);
    }

    [Fact]
    public async Task Entitlement_MissingRowProjectsFreeWithoutCreatingData()
    {
        var driver = Fixture();
        var result = await Service(driver).GetEntitlementAsync("alice", CancellationToken.None);
        Assert.Equal("FREE", result.Plan);
        Assert.Equal("NONE", result.Source);
        Assert.Equal("ACTIVE", result.Status);
        Assert.False(result.UnlimitedEnergy);
        Assert.False(result.AdFree);
        Assert.False(result.Conversations);
        Assert.False(result.AutoRenew);
        Assert.Null(result.ExpiresAt);
        Assert.Null(result.FamilyGroupId);
        Assert.Single(driver.Rows);
    }
    private static readonly DateTimeOffset Now = DateTimeOffset.Parse("2026-11-03T23:30:00Z", CultureInfo.InvariantCulture);

    [Fact]
    public async Task GetMe_PromotesEffectiveZoneAndReturnsOnlyPrivateContractProjection()
    {
        var driver = Fixture();
        driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))]["pendingZone"] = "Asia/Ho_Chi_Minh";
        driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))]["zoneEffectiveAt"] = "2026-11-03T00:00:00.000Z";
        driver.Rows[("p_achievements", "a")] = JsonNode.Parse("""{"userId":"alice","achievementId":"xp","earnedAt":"2026-11-01T00:00:00Z"}""")!.AsObject();
        driver.Rows[("p_achievements", "b")] = JsonNode.Parse("""{"userId":"alice","achievementId":"xp","earnedAt":"2026-11-02T00:00:00Z"}""")!.AsObject();
        var profile = await Service(driver).GetMeAsync("alice", CancellationToken.None);
        Assert.Equal("alice", profile.UserId);
        Assert.Equal("Alice", profile.Nickname);
        Assert.Equal("Asia/Ho_Chi_Minh", profile.LearningZone);
        Assert.Null(profile.PendingZone);
        Assert.Null(profile.ZoneEffectiveAt);
        Assert.Equal(["xp"], profile.AchievementIds);
        Assert.Equal(3, profile.Revision);
        Assert.DoesNotContain("private@example.test", System.Text.Json.JsonSerializer.Serialize(profile));
    }

    [Theory]
    [InlineData("missing")]
    [InlineData("tombstoned")]
    [InlineData("deleted")]
    public async Task AllReads_RejectMissingDeletedOrTombstonedProfile(string state)
    {
        var driver = Fixture();
        if (state == "missing") driver.Rows.Remove(("p_profiles", CanonicalWire.RowId("p_profiles", "alice")));
        if (state == "tombstoned") driver.Rows[("p_deletions", CanonicalWire.RowId("p_deletions", "alice"))] = new() { ["userId"] = "alice" };
        if (state == "deleted") driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))]["deletedAt"] = "2026-11-01T00:00:00Z";
        var service = Service(driver);
        Assert.Equal("PROFILE_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => service.GetMeAsync("alice", CancellationToken.None))).Code);
        Assert.Equal("PROFILE_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => service.GetRewardsAsync("alice", null, CancellationToken.None))).Code);
        Assert.Equal("PROFILE_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => service.GetLearningStatsAsync("alice", CancellationToken.None))).Code);
        Assert.Equal("PROFILE_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => service.GetQuestsAsync("alice", 0, 20, CancellationToken.None))).Code);
        Assert.Equal("PROFILE_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => service.GetPreferencesAsync("alice", CancellationToken.None))).Code);
        Assert.Equal("PROFILE_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => service.GetEntitlementAsync("alice", CancellationToken.None))).Code);
    }

    [Theory]
    [InlineData(null, false, "credited", null)]
    [InlineData("completion", false, "pending", null)]
    [InlineData("completion", true, "capped", 0)]
    public async Task Rewards_UsesOwnLedgerAndDistinguishesPendingCappedAndAggregate(string? completion, bool hasLedger, string status, int? award)
    {
        var driver = Fixture();
        driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))] = JsonNode.Parse("""{"studyXp":44,"leagueXpLifetime":33,"gems":20,"freezeSlots":0,"currentStreak":8,"lastQualifiedDay":"2026-11-02","revision":2}""")!.AsObject();
        driver.Rows[("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", "bob", "completion", "FIRST"))] = new() { ["studyXpDelta"] = 999, ["capped"] = false };
        if (hasLedger) driver.Rows[("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", "alice", "completion", "FIRST"))] = new() { ["studyXpDelta"] = 0, ["capped"] = true };
        var rewards = await Service(driver).GetRewardsAsync("alice", completion, CancellationToken.None);
        Assert.Equal(status, rewards.Status);
        Assert.Equal(award, rewards.AwardXp);
        Assert.Equal(44, rewards.StudyXp);
        Assert.Equal(33, rewards.LeagueXp);
        Assert.Equal(8, rewards.CurrentStreak);
        Assert.Equal(Now, rewards.AsOf);
    }

    [Theory]
    [InlineData(0, 0)]
    [InlineData(1, 8)]
    public async Task Rewards_DisplayPreservesStreakOnlyWhenFreezeCoversMissedDays(int freezes, int expected)
    {
        var driver = Fixture();
        driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))] = new()
        { ["currentStreak"] = 8, ["lastQualifiedDay"] = "2026-11-01", ["freezeSlots"] = freezes };
        Assert.Equal(expected, (await Service(driver).GetRewardsAsync("alice", null, CancellationToken.None)).CurrentStreak);
    }

    [Fact]
    public async Task Statistics_Fills28DaysAndUsesEffectiveHistoryWithoutChangingPastKeys()
    {
        var driver = Fixture();
        driver.Rows[("p_zone_history", "zone")] = new() { ["userId"] = "alice", ["zone"] = "Asia/Ho_Chi_Minh", ["effectiveAt"] = "2026-11-03T23:30:00.000Z" };
        driver.Rows[("p_day_activity", "alice-day")] = new()
        { ["userId"] = "alice", ["day"] = "2026-11-03", ["studyXp"] = 18, ["completedLessons"] = 1, ["originalCorrect"] = 8, ["trackedOriginalCorrect"] = 8, ["trackedOriginalCount"] = 13, ["active"] = true };
        driver.Rows[("p_day_activity", "bob-day")] = new() { ["userId"] = "bob", ["day"] = "2026-11-04", ["studyXp"] = 9999 };
        var stats = await Service(driver).GetLearningStatsAsync("alice", CancellationToken.None);
        Assert.Equal("Asia/Ho_Chi_Minh", stats.LearningZone);
        Assert.Equal(28, stats.Days.Count);
        Assert.Equal("2026-11-04", stats.Days[^1].Day);
        Assert.Equal(0, stats.Days[^1].StudyXp);
        Assert.Equal(18, stats.Days.Sum(d => d.StudyXp));
        Assert.Equal(8, stats.Days.Sum(d => d.TrackedOriginalCorrect));
        Assert.Equal(13, stats.Days.Sum(d => d.TrackedOriginalCount));
        Assert.All(driver.Queries, q => Assert.Equal("alice", q.Where!["userId"]));
        var zoneQuery = Assert.Single(driver.Queries, q => q.LessThan?.ContainsKey("effectiveAt") == true);
        Assert.Equal("2026-11-03T23:30:00.001Z", zoneQuery.LessThan!["effectiveAt"]);
    }

    [Fact]
    public async Task Statistics_BackwardsZoneTravelPreservesLatestCreditedDayAndLegacyAccuracyIsZero()
    {
        var driver = Fixture();
        driver.Rows[("p_day_activity", "legacy")] = new() { ["userId"] = "alice", ["day"] = "2026-11-04", ["studyXp"] = 25, ["originalCorrect"] = 10, ["active"] = true };
        var stats = await Service(driver).GetLearningStatsAsync("alice", CancellationToken.None);
        Assert.Equal("2026-11-04", stats.Days[^1].Day);
        Assert.Equal(25, stats.Days[^1].StudyXp);
        Assert.Equal(10, stats.Days[^1].OriginalCorrect);
        Assert.Equal(0, stats.Days[^1].TrackedOriginalCount);
        Assert.Equal(0, stats.Days[^1].TrackedOriginalCorrect);
    }

    private static ProgressReads Service(Driver driver) => new(new(driver, new Clock()));
    [Theory]
    [InlineData("2026-11-01T23:59:59.999Z", "2026-10-26")]
    [InlineData("2026-11-02T00:00:00.000Z", "2026-11-02")]
    public async Task Quests_WeekChangesExactlyAtMondayUtcDespiteLocalMonday(string instant, string week)
    {
        var driver = Fixture();
        driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))]["learningZone"] = "Asia/Ho_Chi_Minh";
        foreach (var period in new[] { "2026-10-26", "2026-11-02" })
            driver.Rows[("p_quests", period)] = new() { ["userId"] = "alice", ["period"] = "WEEK", ["periodKey"] = period, ["questId"] = "friend_" + period, ["target"] = 10, ["metricValue"] = 1 };
        var service = new ProgressReads(new OwnerStore(driver, new Clock(DateTimeOffset.Parse(instant, CultureInfo.InvariantCulture))));
        var page = await service.GetQuestsAsync("alice", 0, 20, CancellationToken.None);
        Assert.Equal("2026-11-02", page.Items[0].PeriodKey);
        Assert.Equal("2026-11", page.Items[3].PeriodKey);
        Assert.Equal(week, page.Items[4].PeriodKey);
        Assert.Equal(5, page.Items.Count);
    }
    [Fact]
    public async Task Preferences_DefaultsAreReturnedWithoutCreatingRows()
    {
        var driver = Fixture();
        var response = await Service(driver).GetPreferencesAsync("alice", CancellationToken.None);
        Assert.Empty(response.NotificationsOff);
        Assert.Equal(1200, response.ReminderMinute);
        Assert.True(response.SmartScheduling);
        Assert.True(response.SoundEffects);
        Assert.True(response.Haptics);
        Assert.True(response.MotivationalMessages);
        Assert.True(response.ListeningExercises);
        Assert.True(response.SpeakingExercises);
        Assert.True(response.FriendStreakInvites);
        Assert.Equal(0, response.Revision);
        Assert.Equal(Now, response.AsOf);
        Assert.Single(driver.Rows);
    }

    [Fact]
    public async Task Preferences_UsesPersistedFalseValuesAndOnlyOwnSettings()
    {
        var driver = Fixture();
        driver.Rows[("p_preferences", CanonicalWire.RowId("p_preferences", "alice"))] = JsonNode.Parse("""{"userId":"alice","notificationsOffJson":"[\"PUSH\",\"EMAIL\"]","smartScheduling":false,"reminderMinute":0,"soundEffects":false,"haptics":false,"motivationalMessages":false,"listeningExercises":false,"speakingExercises":false,"friendStreakInvites":false,"revision":7}""")!.AsObject();
        driver.Rows[("p_preferences", CanonicalWire.RowId("p_preferences", "bob"))] = new() { ["reminderMinute"] = 999 };
        var response = await Service(driver).GetPreferencesAsync("alice", CancellationToken.None);
        Assert.Equal(new[] { "PUSH", "EMAIL" }, response.NotificationsOff);
        Assert.Equal(0, response.ReminderMinute);
        Assert.False(response.SmartScheduling);
        Assert.False(response.SoundEffects);
        Assert.False(response.Haptics);
        Assert.False(response.MotivationalMessages);
        Assert.False(response.ListeningExercises);
        Assert.False(response.SpeakingExercises);
        Assert.False(response.FriendStreakInvites);
        Assert.Equal(7, response.Revision);
    }
    [Fact]
    public async Task Quests_DefaultCatalogUsesEffectiveLearningDayButFriendWeekUsesUtc()
    {
        var driver = Fixture();
        var profile = driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))];
        profile["pendingZone"] = "Asia/Ho_Chi_Minh";
        profile["zoneEffectiveAt"] = "2026-11-03T00:00:00.000Z";
        driver.Rows[("p_quests", CanonicalWire.RowId("p_quests", "alice", "DAY", "2026-11-04", "daily_lessons"))] = new() { ["metricValue"] = 2, ["claimed"] = true };
        driver.Rows[("p_quests", "friend")] = new() { ["userId"] = "alice", ["period"] = "WEEK", ["periodKey"] = "2026-11-02", ["questId"] = "friend_pair", ["target"] = 10, ["metricValue"] = 3, ["claimed"] = false };
        driver.Rows[("p_quests", "other")] = new() { ["userId"] = "bob", ["period"] = "WEEK", ["periodKey"] = "2026-11-02", ["questId"] = "friend_other", ["target"] = 10, ["metricValue"] = 999 };
        driver.Rows[("p_quests", "not-friend")] = new() { ["userId"] = "alice", ["period"] = "WEEK", ["periodKey"] = "2026-11-02", ["questId"] = "unknown" };
        var result = await Service(driver).GetQuestsAsync("alice", 0, 20, CancellationToken.None);
        Assert.Equal(new[] { "daily_lessons", "daily_correct", "daily_review", "monthly_active_days", "friend_pair" }, result.Items.Select(q => q.QuestId));
        Assert.Equal("2026-11-04", result.Items[0].PeriodKey);
        Assert.Equal(2, result.Items[0].MetricValue);
        Assert.True(result.Items[0].Claimed);
        Assert.Equal("2026-11", result.Items[3].PeriodKey);
        Assert.Equal(new long[] { 2, 15, 1, 20, 10 }, result.Items.Select(q => q.Target));
        Assert.Equal(new long[] { 5, 5, 5, 0, 10 }, result.Items.Select(q => q.RewardGems));
        Assert.Equal(3, result.Items[4].MetricValue);
        Assert.Equal("2026-11-02", result.Items[4].PeriodKey);
        Assert.Equal(Now, result.AsOf);
        Assert.Null(result.NextCursor);
    }

    [Fact]
    public async Task Quests_PaginatesCatalogAndReturnsEmptyBeyondEnd()
    {
        var service = Service(Fixture());
        var first = await service.GetQuestsAsync("alice", 0, 2, CancellationToken.None);
        Assert.Equal(new[] { "daily_lessons", "daily_correct" }, first.Items.Select(q => q.QuestId));
        Assert.Equal("eyJvIjoyfQ", first.NextCursor);
        var second = await service.GetQuestsAsync("alice", 2, 2, CancellationToken.None);
        Assert.Equal(new[] { "daily_review", "monthly_active_days" }, second.Items.Select(q => q.QuestId));
        Assert.Null(second.NextCursor);
        var end = await service.GetQuestsAsync("alice", 99999, 1, CancellationToken.None);
        Assert.Empty(end.Items);
        Assert.Null(end.NextCursor);
    }
    private static Driver Fixture()
    {
        var driver = new Driver();
        driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))] = JsonNode.Parse("""{"userId":"alice","nickname":"Alice","avatarId":null,"publicOptIn":false,"dailyGoal":10,"learningZone":"UTC","pendingZone":null,"zoneEffectiveAt":null,"revision":3,"deletedAt":null,"email":"private@example.test"}""")!.AsObject();
        return driver;
    }

    private sealed class Clock(DateTimeOffset? instant = null) : TimeProvider { public override DateTimeOffset GetUtcNow() => instant ?? Now; }
    private sealed class Driver : IRowDriver
    {
        public string Owner => "progress";
        public bool Configured => true;
        public Dictionary<(string Table, string Id), JsonObject> Rows { get; } = [];
        public List<RowQuery> Queries { get; } = [];
        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken ct) => Task.FromResult(Rows.TryGetValue((table, id), out var row) ? new RowDocument(id, row.DeepClone().AsObject(), "v1") : null);
        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken ct)
        {
            Queries.Add(query);
            var rows = Rows.Where(p => p.Key.Table == table)
                .Where(p => query.Where is null || query.Where.All(q => p.Value[q.Key]?.ToString() == q.Value?.ToString()))
                .Where(p => query.LessThan is null || query.LessThan.All(q => StringComparer.Ordinal.Compare(p.Value[q.Key]?.ToString(), q.Value?.ToString()) < 0))
                .Select(p => new RowDocument(p.Key.Id, p.Value.DeepClone().AsObject(), "v1")).ToArray();
            return Task.FromResult<IReadOnlyList<RowDocument>>(rows);
        }
        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken ct) => throw new NotSupportedException();
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken ct) => throw new InvalidOperationException("Reads must not mutate storage");
    }
}
