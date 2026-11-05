using CocEnglish.Contracts;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using System.Text.Json.Nodes;
using static CocEnglish.Progress.Domain.ProgressCalendar;

namespace CocEnglish.Progress.Application;

public sealed class ProgressFriendStreaks
{
    public async Task<FriendStreakPageResponse> ListAsync(OwnerSession tx, string user, CancellationToken ct)
    {
        var profile = await ProgressReads.RequireProfile(tx, user, ct);
        var today = DayKey(ZonedDay(tx.Now, profile.Text("learningZone") ?? "UTC"));
        var rows = new List<RowDocument>();
        foreach (var column in new[] { "userAId", "userBId" }) rows.AddRange(await tx.ListAsync("p_friend_streaks", new(Where: new Dictionary<string, object?> { [column] = user }, Limit: 50), ct));
        var items = new List<FriendStreakResponse>();
        foreach (var row in rows.Where(r => r.Data.Text("status") is "PENDING" or "ACTIVE").Take(20)) items.Add(await View(tx, user, row.Data, today, ct));
        return new(items, null, tx.Now);
    }
    public async Task<FriendStreakResponse> InviteAsync(OwnerSession tx, string user, string target, CancellationToken ct)
    {
        var profile = await Writer(tx, user, ct);
        var today = DayKey(ZonedDay(tx.Now, profile.Text("learningZone") ?? "UTC"));
        if (user == target) throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "targetUserId" });
        if (await Blocked(tx, user, target, ct)) throw new ServiceException("USER_BLOCKED");
        var outgoing = await tx.ListAsync("p_follows", new(Where: new Dictionary<string, object?> { ["fromUserId"] = user, ["status"] = "ACTIVE" }, Limit: 500), ct);
        var incoming = await tx.ListAsync("p_follows", new(Where: new Dictionary<string, object?> { ["toUserId"] = user, ["status"] = "ACTIVE" }, Limit: 500), ct);
        if (!outgoing.Any(r => r.Data.Text("toUserId") == target) || !incoming.Any(r => r.Data.Text("fromUserId") == target)) throw new ServiceException("PROFILE_UNAVAILABLE");
        var other = await tx.GetAsync("p_profiles", CanonicalWire.RowId("p_profiles", target), ct);
        var prefs = await tx.GetAsync("p_preferences", CanonicalWire.RowId("p_preferences", target), ct);
        if (other is null || other.Text("ageBand") == "CHILD" || prefs?["friendStreakInvites"]?.GetValue<bool>() == false) throw new ServiceException("PROFILE_UNAVAILABLE");
        var sorted = new[] { user, target }.Order(StringComparer.Ordinal).ToArray();
        var pair = CanonicalWire.RowId("operation", "friend-streak", sorted[0], sorted[1]);
        var id = CanonicalWire.RowId("p_friend_streaks", pair);
        var row = await tx.GetAsync("p_friend_streaks", id, ct);
        if (row?.Text("status") is "PENDING" or "ACTIVE") return await View(tx, user, row, today, ct);
        if (await OpenCount(tx, user, ct) >= 5 || await OpenCount(tx, target, ct) >= 5) throw new ServiceException("FRIEND_STREAK_LIMIT");
        row ??= new();
        row["pairId"] = pair; row["userAId"] = sorted[0]; row["userBId"] = sorted[1]; row["inviterId"] = user;
        row["status"] = "PENDING"; row["startDay"] = null; row["length"] = 0; row["lastExtendedDay"] = null; row["endedAt"] = null;
        tx.Put("p_friend_streaks", id, row);
        return await View(tx, user, row, today, ct);
    }
    public async Task<FriendStreakResponse> RespondAsync(OwnerSession tx, string user, string pairId, bool accept, CancellationToken ct)
    {
        var profile = await Writer(tx, user, ct);
        var today = DayKey(ZonedDay(tx.Now, profile.Text("learningZone") ?? "UTC"));
        var id = CanonicalWire.RowId("p_friend_streaks", pairId);
        var row = await tx.GetAsync("p_friend_streaks", id, ct);
        if (row is null || row.Text("userAId") != user && row.Text("userBId") != user) throw new ServiceException("NOT_FOUND");
        if (row.Text("status") != "PENDING" || row.Text("inviterId") == user)
        {
            if (row.Text("status") == (accept ? "ACTIVE" : "DECLINED")) return await View(tx, user, row, today, ct);
            throw new ServiceException("REVISION_CONFLICT", new() { ["status"] = row.Text("status") });
        }
        var other = row.Text("userAId") == user ? row.Text("userBId")! : row.Text("userAId")!;
        if (await Blocked(tx, user, other, ct)) throw new ServiceException("USER_BLOCKED");
        if (accept && await OpenCount(tx, user, ct) > 5) throw new ServiceException("FRIEND_STREAK_LIMIT");
        row["status"] = accept ? "ACTIVE" : "DECLINED";
        row["startDay"] = accept ? today : null;
        tx.Put("p_friend_streaks", id, row);
        return await View(tx, user, row, today, ct);
    }
    private static async Task<JsonObject> Writer(OwnerSession tx, string user, CancellationToken ct)
    {
        var profile = await ProgressReads.RequireProfile(tx, user, ct);
        if (profile.Text("ageBand") == "CHILD") throw new ServiceException("FORBIDDEN");
        return profile;
    }
    private static async Task<long> OpenCount(OwnerSession tx, string user, CancellationToken ct)
    {
        long count = 0;
        foreach (var column in new[] { "userAId", "userBId" }) foreach (var status in new[] { "PENDING", "ACTIVE" })
            count += await tx.CountAsync("p_friend_streaks", new Dictionary<string, object?> { [column] = user, ["status"] = status }, ct);
        return count;
    }
    private static async Task<bool> Blocked(OwnerSession tx, string a, string b, CancellationToken ct) =>
        await tx.GetAsync("p_blocks", CanonicalWire.RowId("p_blocks", a, b), ct) is not null || await tx.GetAsync("p_blocks", CanonicalWire.RowId("p_blocks", b, a), ct) is not null;
    private static async Task<FriendStreakResponse> View(OwnerSession tx, string user, JsonObject row, string today, CancellationToken ct)
    {
        var other = row.Text("userAId") == user ? row.Text("userBId")! : row.Text("userAId")!;
        var friend = await tx.GetAsync("p_profiles", CanonicalWire.RowId("p_profiles", other), ct);
        var nickname = friend?.Text("nickname") ?? "Learner";
        return new(row.Text("pairId")!, other, nickname[..Math.Min(40, nickname.Length)], row.Text("inviterId")!, row.Text("status")!,
            row.Number("length"), row.Text("startDay"), row.Text("lastExtendedDay"), row.Text("lastExtendedDay") == today);
    }
}
