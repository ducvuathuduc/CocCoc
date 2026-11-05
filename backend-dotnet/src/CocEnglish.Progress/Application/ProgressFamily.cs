using CocEnglish.Contracts;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using System.Text.Json.Nodes;

namespace CocEnglish.Progress.Application;

public sealed class ProgressFamily(ProgressCodes codes)
{
    public async Task<FamilyResponse> CreateAsync(OwnerSession tx, string user, string plan, string key, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var entitlement = await tx.GetAsync("p_entitlements", CanonicalWire.RowId("p_entitlements", user), ct) ?? new();
        if (!ProgressReads.EntitlementView(entitlement, tx.Now).UnlimitedEnergy || entitlement.Text("source") != "PURCHASE" || plan == "MAX" && entitlement.Text("plan") != "MAX") throw new ServiceException("ENTITLEMENT_REQUIRED");
        if (entitlement.Text("familyGroupId") is { Length: > 0 }) throw new ServiceException("REVISION_CONFLICT", new() { ["reason"] = "ALREADY_IN_FAMILY" });
        var group = CanonicalWire.RowId("operation", "family", user, key);
        var row = new JsonObject { ["groupId"] = group, ["ownerUserId"] = user, ["plan"] = plan,
            ["memberIdsJson"] = MemberJson([(user, tx.NowIso)]), ["inviteCodeHash"] = ProgressCodes.Hash(codes.Derive("family", group)), ["status"] = "ACTIVE" };
        tx.Put("p_family_groups", CanonicalWire.RowId("p_family_groups", group), row);
        await ProgressBilling.ChangeEntitlementAsync(tx, user, new() { ["familyGroupId"] = group }, ct);
        return await View(tx, row, user, 0, ct);
    }

    public async Task<FamilyResponse> JoinAsync(OwnerSession tx, string user, string groupId, string code, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var id = CanonicalWire.RowId("p_family_groups", groupId);
        var group = await tx.GetAsync("p_family_groups", id, ct);
        if (group is null || group.Text("status") != "ACTIVE" || group.Text("inviteCodeHash") != ProgressCodes.Hash(code)) throw new ServiceException("NOT_FOUND");
        var members = Members(group);
        var revision = group.Number("revision") + 1;
        if (!members.Any(m => m.User == user))
        {
            if (members.Count >= 6) throw new ServiceException("REVISION_CONFLICT", new() { ["reason"] = "FAMILY_FULL" });
            var entitlement = await tx.GetAsync("p_entitlements", CanonicalWire.RowId("p_entitlements", user), ct);
            if (entitlement?.Text("familyGroupId") is { Length: > 0 } other && other != groupId) throw new ServiceException("REVISION_CONFLICT", new() { ["reason"] = "ALREADY_IN_FAMILY" });
            members.Add((user, tx.NowIso)); group["memberIdsJson"] = MemberJson(members);
            tx.Put("p_family_groups", id, group);
            var owner = await tx.GetAsync("p_entitlements", CanonicalWire.RowId("p_entitlements", group.Text("ownerUserId")!), ct);
            await ProgressBilling.ChangeEntitlementAsync(tx, user, new() { ["plan"] = group.Text("plan"), ["source"] = "FAMILY", ["status"] = "ACTIVE",
                ["expiresAt"] = owner?.Text("expiresAt"), ["autoRenew"] = false, ["familyGroupId"] = groupId, ["purchaseId"] = null }, ct);
        }
        return await View(tx, group, user, revision, ct);
    }

    public async Task<FamilyResponse> RemoveAsync(OwnerSession tx, string user, string groupId, string member, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var id = CanonicalWire.RowId("p_family_groups", groupId);
        var group = await tx.GetAsync("p_family_groups", id, ct);
        if (group is null || group.Text("status") != "ACTIVE") throw new ServiceException("NOT_FOUND");
        var owner = group.Text("ownerUserId")!;
        if (user != owner && user != member) throw new ServiceException("FORBIDDEN");
        if (member == owner) throw new ServiceException("VALIDATION_ERROR", new() { ["reason"] = "MANAGER_CANNOT_LEAVE" });
        var members = Members(group); var revision = group.Number("revision");
        if (members.Any(m => m.User == member))
        {
            group["memberIdsJson"] = MemberJson(members.Where(m => m.User != member));
            tx.Put("p_family_groups", id, group); revision++;
            await ProgressBilling.ChangeEntitlementAsync(tx, member, new() { ["userId"] = member, ["plan"] = "FREE", ["source"] = "NONE", ["status"] = "REVOKED",
                ["expiresAt"] = null, ["autoRenew"] = false, ["familyGroupId"] = null, ["purchaseId"] = null, ["giftId"] = null }, ct);
        }
        return await View(tx, group, user, revision, ct);
    }
    private static List<(string User, string Joined)> Members(JsonObject row) => JsonNode.Parse(row.Text("memberIdsJson") ?? "[]")!.AsArray().Select(m => (m![0]!.GetValue<string>(), m[1]!.GetValue<string>())).ToList();
    private static string MemberJson(IEnumerable<(string User, string Joined)> members) => CanonicalWire.Stringify(new JsonArray(members.Select(m => (JsonNode)new JsonArray(JsonValue.Create(m.User), JsonValue.Create(m.Joined))).ToArray()));
    private async Task<FamilyResponse> View(OwnerSession tx, JsonObject row, string viewer, long revision, CancellationToken ct)
    {
        var members = new List<FamilyMemberResponse>(); var owner = row.Text("ownerUserId")!; var group = row.Text("groupId")!;
        foreach (var member in Members(row))
        {
            var profile = await tx.GetAsync("p_profiles", CanonicalWire.RowId("p_profiles", member.User), ct);
            var name = profile?.Text("nickname") ?? "Learner";
            members.Add(new(member.User, name[..Math.Min(40, name.Length)], member.User == owner ? "MANAGER" : "MEMBER", member.Joined));
        }
        return new(group, owner, row.Text("plan")!, row.Text("status")!, members,
            viewer == owner && row.Text("status") == "ACTIVE" ? codes.Derive("family", group) : null, revision);
    }
}
