using CocEnglish.Contracts;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using System.Text.Json.Nodes;

namespace CocEnglish.Progress.Application;

public sealed partial class ProgressSocial
{
    public async Task<string> BlockAsync(OwnerSession tx, string user, string target, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        if (user == target) throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "targetUserId" });
        var id = CanonicalWire.RowId("p_blocks", user, target);
        if (await tx.GetAsync("p_blocks", id, ct) is not null) return "replayed";
        tx.Put("p_blocks", id, new() { ["blockerId"] = user, ["blockedId"] = target });
        foreach (var (from, to) in new[] { (user, target), (target, user) })
        {
            var followId = CanonicalWire.RowId("p_follows", from, to);
            var row = await tx.GetAsync("p_follows", followId, ct);
            if (row?.Text("status") == "ACTIVE") { row["status"] = "REMOVED"; tx.Put("p_follows", followId, row); }
        }
        var pair = new[] { user, target }.Order(StringComparer.Ordinal).ToArray();
        var pairId = CanonicalWire.RowId("operation", "friend-streak", pair[0], pair[1]);
        var streakId = CanonicalWire.RowId("p_friend_streaks", pairId);
        var streak = await tx.GetAsync("p_friend_streaks", streakId, ct);
        if (streak?.Text("status") is "ACTIVE" or "PENDING")
        { streak["status"] = "ENDED"; streak["endedAt"] = tx.NowIso; tx.Put("p_friend_streaks", streakId, streak); }
        return "completed";
    }
    public async Task<string> UnblockAsync(OwnerSession tx, string user, string target, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var id = CanonicalWire.RowId("p_blocks", user, target);
        if (await tx.GetAsync("p_blocks", id, ct) is null) return "replayed";
        tx.Delete("p_blocks", id);
        return "completed";
    }
    public async Task<string> ReportAsync(OwnerSession tx, string user, string target, string reason, string? note, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        if (user == target) throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "targetUserId" });
        var id = CanonicalWire.RowId("p_user_reports", user, target, reason);
        if (await tx.GetAsync("p_user_reports", id, ct) is not null) return "replayed";
        tx.Put("p_user_reports", id, new() { ["reporterId"] = user, ["targetUserId"] = target, ["reason"] = reason, ["note"] = note, ["status"] = "OPEN" });
        return "completed";
    }
    public async Task<FriendsPageResponse> FriendsAsync(OwnerSession tx, string user, int offset, int limit, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var outgoing = await tx.ListAsync("p_follows", new(Where: new Dictionary<string, object?> { ["fromUserId"] = user, ["status"] = "ACTIVE" }, Limit: 500), ct);
        var incoming = await tx.ListAsync("p_follows", new(Where: new Dictionary<string, object?> { ["toUserId"] = user, ["status"] = "ACTIVE" }, Limit: 500), ct);
        var back = incoming.Select(r => r.Data.Text("fromUserId")!).ToHashSet(StringComparer.Ordinal);
        var friends = outgoing.Select(r => r.Data.Text("toUserId")!).Where(back.Contains).Order(StringComparer.Ordinal).ToArray();
        var items = new List<PublicProfileResponse>();
        var index = offset;
        for (; index < friends.Length && items.Count < limit; index++)
            if (await VisibleAsync(tx, user, friends[index], ct) is not null) items.Add(await GetProfileAsync(tx, user, friends[index], ct));
        return new(items, index < friends.Length ? Cursor(index) : null, tx.Now);
    }
    public async Task<ActivityPageResponse> ActivityAsync(OwnerSession tx, string user, int offset, int limit, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var following = await tx.ListAsync("p_follows", new(Where: new Dictionary<string, object?> { ["fromUserId"] = user, ["status"] = "ACTIVE" }, Limit: 99), ct);
        var authors = new List<string> { user };
        foreach (var follow in following)
        {
            var target = follow.Data.Text("toUserId")!;
            if (await VisibleAsync(tx, user, target, ct) is not null) authors.Add(target);
        }
        var rows = await tx.ListAsync("p_activity", new(AnyOf: new Dictionary<string, string[]> { ["userId"] = authors.ToArray() },
            OrderBy: [new("createdAt", true)], Limit: Math.Min(500, offset + limit + 1)), ct);
        var visible = rows.Where(r => (r.Data.Text("userId") == user || r.Data.Flag("visible")) && r.Data.Text("kind") is "MILESTONE" or "QUEST" or "STREAK").ToArray();
        var items = visible.Skip(offset).Take(limit).Select(r => new ActivityResponse(r.Data.Text("eventId")!, r.Data.Text("userId")!, r.Data.Text("kind")!,
            r.Data.Text("publicSummary")!, DateTimeOffset.Parse(r.Data.Text("createdAt")!, System.Globalization.CultureInfo.InvariantCulture))).ToArray();
        return new(items, visible.Length > offset + limit ? Cursor(offset + limit) : null, tx.Now);
    }
    private static string Cursor(int offset) => Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes($"{{\"o\":{offset}}}")).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    public async Task<PublicProfileResponse> GetProfileAsync(OwnerSession tx, string viewer, string target, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, viewer, ct);
        var profile = await VisibleAsync(tx, viewer, target, ct) ?? throw new ServiceException("PROFILE_UNAVAILABLE");
        var rewards = await tx.GetAsync("p_rewards", CanonicalWire.RowId("p_rewards", target), ct) ?? new JsonObject();
        var achievements = await tx.ListAsync("p_achievements", new(Where: new Dictionary<string, object?> { ["userId"] = target }, OrderBy: [new("earnedAt")], Limit: 200), ct);
        var status = "none";
        if (viewer != target && await Active(tx, viewer, target, ct)) status = await Active(tx, target, viewer, ct) ? "friend" : "following";
        return new(target, profile.Text("nickname")!, profile.Text("avatarId"), rewards.Number("studyXp"),
            Math.Min(365, ProgressReads.RewardsView(tx.Now, profile.Text("learningZone") ?? "UTC", rewards).CurrentStreak),
            achievements.Select(a => a.Data.Text("achievementId")!).Distinct(StringComparer.Ordinal).Take(30).ToArray(), status);
    }
    public async Task<string> FollowAsync(OwnerSession tx, string user, string target, CancellationToken ct)
    {
        var profile = await ProgressReads.RequireProfile(tx, user, ct);
        if (profile.Text("ageBand") == "CHILD") throw new ServiceException("FORBIDDEN");
        if (user == target) throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "targetUserId" });
        if (await Blocked(tx, user, target, ct)) throw new ServiceException("USER_BLOCKED");
        if (await VisibleAsync(tx, user, target, ct) is null) throw new ServiceException("PROFILE_UNAVAILABLE");
        var id = CanonicalWire.RowId("p_follows", user, target);
        var row = await tx.GetAsync("p_follows", id, ct);
        if (row?.Text("status") == "ACTIVE") return "replayed";
        if (await tx.CountAsync("p_follows", new Dictionary<string, object?> { ["fromUserId"] = user, ["status"] = "ACTIVE" }, ct) >= 1000)
            throw new ServiceException("VALIDATION_ERROR", new() { ["reason"] = "FOLLOW_LIMIT" });
        row ??= new();
        row["fromUserId"] = user; row["toUserId"] = target; row["status"] = "ACTIVE";
        tx.Put("p_follows", id, row);
        return "completed";
    }
    public async Task<string> UnfollowAsync(OwnerSession tx, string user, string target, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var id = CanonicalWire.RowId("p_follows", user, target);
        var row = await tx.GetAsync("p_follows", id, ct);
        if (row?.Text("status") != "ACTIVE") return "replayed";
        row["status"] = "REMOVED";
        tx.Put("p_follows", id, row);
        return "completed";
    }
    private static async Task<bool> Active(OwnerSession tx, string from, string to, CancellationToken ct) =>
        (await tx.GetAsync("p_follows", CanonicalWire.RowId("p_follows", from, to), ct))?.Text("status") == "ACTIVE";
    private static async Task<bool> Blocked(OwnerSession tx, string a, string b, CancellationToken ct) =>
        await tx.GetAsync("p_blocks", CanonicalWire.RowId("p_blocks", a, b), ct) is not null || await tx.GetAsync("p_blocks", CanonicalWire.RowId("p_blocks", b, a), ct) is not null;
    private static async Task<JsonObject?> VisibleAsync(OwnerSession tx, string viewer, string target, CancellationToken ct)
    {
        var profile = await tx.GetAsync("p_profiles", CanonicalWire.RowId("p_profiles", target), ct);
        if (profile is null || profile.Text("deletedAt") is not null || await tx.GetAsync("p_deletions", CanonicalWire.RowId("p_deletions", target), ct) is not null) return null;
        if (viewer == target) return profile;
        return !profile.Flag("publicOptIn") || profile.Text("ageBand") == "CHILD" || await Blocked(tx, viewer, target, ct) ? null : profile;
    }
}
