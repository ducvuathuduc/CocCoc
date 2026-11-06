using System.Globalization;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;

namespace CocEnglish.Learning;

public static class LearningEnergy
{
    private sealed record Battery(long Balance, long Capacity, long Anchor, long Unit);
    private static Battery Calculate(JsonObject? row, DateTimeOffset now)
    {
        var capacity = Math.Clamp(row?.Number("capacity") ?? 25, 1, 100);
        var unit = 86_400_000L / capacity; var nowMs = now.ToUnixTimeMilliseconds();
        var parsed = DateTimeOffset.TryParse(row?.Text("anchorAt"), CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var anchorTime);
        var anchor = parsed ? anchorTime.ToUnixTimeMilliseconds() : nowMs;
        var stored = Math.Clamp(row?.Number("balance") ?? capacity, 0, capacity);
        var gained = parsed ? Math.Max(0, (nowMs - anchor) / unit) : 0;
        var balance = Math.Min(capacity, stored + gained);
        anchor = balance >= capacity || !parsed ? nowMs : anchor + gained * unit;
        return new(balance, capacity, anchor, unit);
    }

    public static async Task GrantAsync(OwnerSession tx, string user, long? amount, bool refill, CancellationToken ct)
    {
        var id = CocEnglish.Shared.Security.CanonicalWire.RowId("energy", user);
        var row = await tx.GetAsync("l_energy", id, ct); var battery = Calculate(row, tx.Now);
        var balance = refill ? battery.Capacity : battery.Balance + (amount ?? 0);
        Write(tx, id, user, row, battery, balance, balance >= battery.Capacity ? tx.Now.ToUnixTimeMilliseconds() : battery.Anchor, null, null);
    }

    public static async Task EntitlementAsync(OwnerSession tx, string user, string plan, string status, string? expiresAt, long revision, CancellationToken ct)
    {
        var id = CocEnglish.Shared.Security.CanonicalWire.RowId("energy", user);
        var row = await tx.GetAsync("l_energy", id, ct);
        if (row is not null && row.Number("entitlementRevision") > revision) return;
        var paid = plan is "SUPER" or "MAX" && status is "ACTIVE" or "GRACE" &&
            (expiresAt is null || DateTimeOffset.TryParse(expiresAt, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var expiry) && expiry > tx.Now);
        var battery = Calculate(row, tx.Now);
        Write(tx, id, user, row, battery, battery.Balance, battery.Anchor, paid ? "UNLIMITED" : "LIMITED", revision);
    }

    private static void Write(OwnerSession tx, string id, string user, JsonObject? row, Battery battery, long balance, long anchor, string? mode, long? entitlementRevision)
    {
        tx.Put("l_energy", id, new JsonObject { ["userId"] = user, ["mode"] = mode ?? (row?.Text("mode") == "UNLIMITED" ? "UNLIMITED" : "LIMITED"),
            ["balance"] = Math.Clamp(balance, 0, battery.Capacity), ["capacity"] = battery.Capacity,
            ["anchorAt"] = OwnerSchema.Iso(DateTimeOffset.FromUnixTimeMilliseconds(anchor)), ["entitlementRevision"] = entitlementRevision ?? row?.Number("entitlementRevision") ?? 0 });
    }

    public static JsonObject View(JsonObject? row, DateTimeOffset now, string config)
    {
        var battery = Calculate(row, now); var capacity = battery.Capacity; var balance = battery.Balance; var unitMs = battery.Unit; var anchor = battery.Anchor;
        var mode = config != "LIMITED" || row?.Text("mode") == "UNLIMITED" ? "UNLIMITED" : "LIMITED";
        var full = balance >= capacity;
        var next = anchor + unitMs;
        return new JsonObject { ["mode"] = mode, ["balance"] = mode == "UNLIMITED" ? capacity : balance, ["capacity"] = capacity,
            ["nextUnitAt"] = mode == "UNLIMITED" || full ? null : OwnerSchema.Iso(DateTimeOffset.FromUnixTimeMilliseconds(next)),
            ["fullAt"] = mode == "UNLIMITED" || full ? null : OwnerSchema.Iso(DateTimeOffset.FromUnixTimeMilliseconds(next + (capacity - balance - 1) * unitMs)),
            ["revision"] = row?.Number("revision") ?? 0, ["asOf"] = OwnerSchema.Iso(now) };
    }

    public static void AssertCanStart(JsonObject? row, DateTimeOffset now, string config, string mode)
    {
        if (config != "LIMITED" || mode is not ("LESSON" or "MASTERY") || row?.Text("mode") == "UNLIMITED") return;
        var view = View(row, now, config);
        if (view["balance"]!.GetValue<long>() >= 1) return;
        throw new ServiceException("ENERGY_DEPLETED", new() { ["balance"] = view["balance"]!.GetValue<long>(), ["nextUnitAt"] = view["nextUnitAt"]?.GetValue<string>() });
    }

    public static async Task<long> SpendAsync(OwnerSession tx, string user, string mode, string config, CancellationToken ct)
    {
        if (config != "LIMITED" || mode is not ("LESSON" or "MASTERY")) return 0;
        var id = CocEnglish.Shared.Security.CanonicalWire.RowId("energy", user);
        var row = await tx.GetAsync("l_energy", id, ct);
        if (row?.Text("mode") == "UNLIMITED") return 0;
        var battery = Calculate(row, tx.Now);
        if (battery.Balance < 1)
        {
            var view = View(row, tx.Now, config);
            throw new ServiceException("ENERGY_DEPLETED", new() { ["balance"] = view["balance"]!.GetValue<long>(), ["nextUnitAt"] = view["nextUnitAt"]?.GetValue<string>() });
        }
        Write(tx, id, user, row, battery, battery.Balance - 1, battery.Anchor, null, null);
        return 1;
    }
}
