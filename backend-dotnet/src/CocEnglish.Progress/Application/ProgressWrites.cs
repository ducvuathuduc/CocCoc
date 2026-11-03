using CocEnglish.Contracts;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Security;
using System.Text.Json.Nodes;
using System.Globalization;
using System.Text.RegularExpressions;

namespace CocEnglish.Progress.Application;

public sealed class ProgressWrites
{
    public async Task<DeletionReceiptResponse> RequestDeletionAsync(OwnerSession tx, string userId, CancellationToken ct)
    {
        var id = CanonicalWire.RowId("p_deletions", userId);
        if (await tx.GetAsync("p_deletions", id, ct) is { } existing)
            return new(existing.Text("requestId")!, existing.Text("status")!, DateTimeOffset.Parse(existing.Text("requestedAt")!, CultureInfo.InvariantCulture));
        var requestId = Guid.NewGuid().ToString();
        tx.Put("p_deletions", id, new()
        {
            ["userId"] = userId, ["requestId"] = requestId, ["status"] = "REQUESTED", ["ownerAcksJson"] = "[]",
            ["requestedAt"] = tx.NowIso, ["completedAt"] = null
        });
        var profileId = CanonicalWire.RowId("p_profiles", userId);
        if (await tx.GetAsync("p_profiles", profileId, ct) is { } profile)
        {
            profile["publicOptIn"] = false;
            profile["deletedAt"] = tx.NowIso;
            tx.Put("p_profiles", profileId, profile);
        }
        var eventId = Guid.NewGuid().ToString();
        tx.Put("p_outbox", CanonicalWire.RowId("p_outbox", eventId), new()
        {
            ["eventId"] = eventId, ["type"] = "account.deleted.v1", ["schemaVersion"] = 1, ["aggregateId"] = userId,
            ["occurredAt"] = tx.NowIso, ["payloadJson"] = CanonicalWire.Stringify(new JsonObject { ["userId"] = userId, ["requestId"] = requestId }),
            ["attempt"] = 0, ["nextAttemptAt"] = tx.NowIso, ["leaseOwner"] = null, ["leaseUntil"] = null, ["status"] = "PENDING", ["ackAt"] = null
        });
        return new(requestId, "REQUESTED", tx.Now);
    }

    public async Task<ProfileResponse> UpdateProfileAsync(OwnerSession tx, string userId, ProfilePatchRequest patch, CancellationToken ct)
    {
        var next = await ProgressReads.RequireProfile(tx, userId, ct);
        var current = next.Number("revision");
        if (patch.ExpectedRevision != current) throw new ServiceException("REVISION_CONFLICT", new() { ["currentRevision"] = current });
        if (patch.Nickname is { } rawName)
        {
            // ECMAScript WhiteSpace + LineTerminator, rather than the broader .NET \s set.
            var nickname = Regex.Replace(rawName.Normalize(), "[\u0009-\u000D\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF]+", " ").Trim(' ');
            if (nickname.Length is 0 or > 40) throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "nickname" });
            next["nickname"] = nickname;
        }
        if (patch.HasAvatarId) next["avatarId"] = patch.AvatarId;
        if (patch.DailyGoal is { } goal) next["dailyGoal"] = goal;
        if (patch.PublicOptIn is { } optIn)
        {
            if (optIn && next.Text("ageBand") == "CHILD") throw new ServiceException("FORBIDDEN", new() { ["field"] = "publicOptIn" });
            next["publicOptIn"] = optIn;
        }
        if (patch.LearningZone is { } zone && zone != next.Text("learningZone"))
        {
            if (zone.Length is 0 or > 64 || !TimeZoneInfo.TryFindSystemTimeZoneById(zone, out _) ||
                !zone.Equals("UTC", StringComparison.OrdinalIgnoreCase) && TimeZoneInfo.TryConvertWindowsIdToIanaId(zone, out _))
                throw new ServiceException("INVALID_TIMEZONE");
            var last = DateTimeOffset.Parse(next.Text("lastZoneChangedAt") ?? "1970-01-01T00:00:00.000Z", CultureInfo.InvariantCulture);
            var wait = last.AddDays(1) - tx.Now;
            if (wait > TimeSpan.Zero) throw new ServiceException("RATE_LIMITED", new() { ["field"] = "learningZone" }, retryAfterSeconds: (int)Math.Ceiling(wait.TotalSeconds));
            var effective = OwnerSchema.Iso(new DateTimeOffset(tx.Now.UtcDateTime.Date.AddDays(1), TimeSpan.Zero));
            var historyId = CanonicalWire.RowId("p_zone_history", userId, effective);
            if (await tx.GetAsync("p_zone_history", historyId, ct) is not null) throw new ServiceException("RATE_LIMITED", new() { ["field"] = "learningZone" });
            next["pendingZone"] = zone;
            next["zoneEffectiveAt"] = effective;
            next["lastZoneChangedAt"] = tx.NowIso;
            tx.Put("p_zone_history", historyId, new() { ["userId"] = userId, ["zone"] = zone, ["effectiveAt"] = effective });
        }
        tx.Put("p_profiles", CanonicalWire.RowId("p_profiles", userId), next);
        next["revision"] = current + 1;
        return await ProgressReads.ProfileView(tx, next, ct);
    }

    public async Task<ProfileResponse> InitializeProfileAsync(OwnerSession tx, string userId, CancellationToken ct)
    {
        const string epoch = "1970-01-01T00:00:00.000Z";
        if (await tx.GetAsync("p_deletions", CanonicalWire.RowId("p_deletions", userId), ct) is not null) throw new ServiceException("PROFILE_UNAVAILABLE");
        var profileId = CanonicalWire.RowId("p_profiles", userId);
        if (await tx.GetAsync("p_profiles", profileId, ct) is { } existing) return await ProgressReads.ProfileView(tx, existing, ct);
        var username = "user" + CanonicalWire.RowId("operation", "username", userId)[..12];
        var profile = new JsonObject
        {
            ["userId"] = userId, ["username"] = username, ["nickname"] = username, ["avatarId"] = null,
            ["avatarConfigJson"] = null, ["publicOptIn"] = false, ["ageBand"] = "ADULT", ["emailVerifiedSnapshot"] = false,
            ["dailyGoal"] = 10, ["learningZone"] = "UTC", ["pendingZone"] = null, ["zoneEffectiveAt"] = null,
            ["lastZoneChangedAt"] = epoch, ["onboardingJson"] = null, ["deletedAt"] = null
        };
        tx.Put("p_profiles", profileId, profile);
        var rewardsId = CanonicalWire.RowId("p_rewards", userId);
        var rewards = await tx.GetAsync("p_rewards", rewardsId, ct) ?? new JsonObject
        {
            ["userId"] = userId, ["studyXp"] = 0, ["leagueXpLifetime"] = 0, ["gems"] = 0, ["freezeSlots"] = 0,
            ["currentStreak"] = 0, ["bestStreak"] = 0, ["streakStartDay"] = null, ["lastQualifiedDay"] = null,
            ["lostStreak"] = 0, ["lostStreakDay"] = null, ["streakGoal"] = 0, ["streakGoalStartDay"] = null
        };
        rewards["gems"] = rewards.Number("gems") + 20;
        tx.Put("p_rewards", rewardsId, rewards);
        var operation = CanonicalWire.RowId("operation", "initialize", userId);
        var day = tx.Now.UtcDateTime.ToString("yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
        tx.Put("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", userId, operation, "INITIAL"), new()
        {
            ["eventId"] = operation, ["completionId"] = operation, ["userId"] = userId, ["rewardIdentity"] = "initialize", ["kind"] = "INITIAL",
            ["studyXpDelta"] = 0, ["leagueXpDelta"] = 0, ["gemsDelta"] = 20, ["learningDay"] = day, ["leagueWeek"] = day,
            ["occurredAt"] = tx.NowIso, ["capped"] = false
        });
        await Ensure("p_zone_history", CanonicalWire.RowId("p_zone_history", userId, epoch), new() { ["userId"] = userId, ["zone"] = "UTC", ["effectiveAt"] = epoch });
        await Ensure("p_preferences", CanonicalWire.RowId("p_preferences", userId), DefaultPreferences(userId));
        await Ensure("p_league_profiles", CanonicalWire.RowId("p_league_profiles", userId), new()
        {
            ["userId"] = userId, ["tier"] = 0, ["stage"] = "LEAGUE", ["weeksParticipated"] = 0, ["topThreeFinishes"] = 0,
            ["diamondWeeks"] = 0, ["lastSettledWeekId"] = null, ["lastResultJson"] = null, ["resultSeenWeekId"] = null
        });
        await Ensure("p_entitlements", CanonicalWire.RowId("p_entitlements", userId), new()
        {
            ["userId"] = userId, ["plan"] = "FREE", ["source"] = "NONE", ["status"] = "ACTIVE", ["expiresAt"] = null,
            ["autoRenew"] = false, ["familyGroupId"] = null, ["purchaseId"] = null, ["giftId"] = null
        });
        profile["revision"] = 0;
        return await ProgressReads.ProfileView(tx, profile, ct);

        async Task Ensure(string table, string id, JsonObject row)
        {
            if (await tx.GetAsync(table, id, ct) is null) tx.Put(table, id, row);
        }
    }

    public async Task<PreferencesResponse> UpdatePreferencesAsync(OwnerSession tx, string userId, PreferencesPatchRequest patch, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, userId, ct);
        var id = CanonicalWire.RowId("p_preferences", userId);
        var stored = await tx.GetAsync("p_preferences", id, ct);
        var current = stored?.Number("revision") ?? 0;
        if (patch.ExpectedRevision != current) throw new ServiceException("REVISION_CONFLICT", new() { ["currentRevision"] = current });
        var next = stored ?? DefaultPreferences(userId);
        if (patch.NotificationsOff is not null) next["notificationsOffJson"] = CanonicalWire.Stringify(new JsonArray(patch.NotificationsOff.Select(value => (JsonNode?)JsonValue.Create(value)).ToArray()));
        if (patch.ReminderMinute is { } minute) next["reminderMinute"] = minute;
        Set("smartScheduling", patch.SmartScheduling);
        Set("soundEffects", patch.SoundEffects);
        Set("haptics", patch.Haptics);
        Set("motivationalMessages", patch.MotivationalMessages);
        Set("listeningExercises", patch.ListeningExercises);
        Set("speakingExercises", patch.SpeakingExercises);
        Set("friendStreakInvites", patch.FriendStreakInvites);
        tx.Put("p_preferences", id, next);
        next["revision"] = stored is null ? 0 : current + 1;
        return PreferencesView(next, tx.Now);
        void Set(string key, bool? value) { if (value is { } flag) next[key] = flag; }
    }

    public async Task SendFeedbackAsync(OwnerSession tx, string userId, FeedbackRequest request, string key, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, userId, ct);
        tx.Put("p_feedback", CanonicalWire.RowId("p_feedback", userId, key), new()
        {
            ["userId"] = userId, ["topic"] = request.Topic, ["message"] = request.Message,
            ["appVersion"] = request.AppVersion, ["platform"] = request.Platform, ["status"] = "OPEN"
        });
    }

    internal static JsonObject DefaultPreferences(string userId) => new()
    {
        ["userId"] = userId, ["notificationsOffJson"] = "[]", ["smartScheduling"] = true, ["reminderMinute"] = 1200,
        ["soundEffects"] = true, ["haptics"] = true, ["motivationalMessages"] = true, ["listeningExercises"] = true,
        ["speakingExercises"] = true, ["friendStreakInvites"] = true
    };

    internal static PreferencesResponse PreferencesView(JsonObject row, DateTimeOffset now) => new(
        System.Text.Json.JsonSerializer.Deserialize<string[]>(row.Text("notificationsOffJson") ?? "[]")!,
        row.Flag("smartScheduling"), row.Number("reminderMinute"), row.Flag("soundEffects"), row.Flag("haptics"),
        row.Flag("motivationalMessages"), row.Flag("listeningExercises"), row.Flag("speakingExercises"),
        row.Flag("friendStreakInvites"), row.Number("revision"), now);
}
