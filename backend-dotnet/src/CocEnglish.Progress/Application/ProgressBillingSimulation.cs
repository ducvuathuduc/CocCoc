using CocEnglish.Contracts;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using System.Text.Json.Nodes;
using System.Globalization;
using System.Text.RegularExpressions;

namespace CocEnglish.Progress.Application;

public sealed partial class ProgressBilling
{
    private static readonly Regex NotificationDatePattern = new(
        @"^(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})T(?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2})(?:\.(?<fraction>\d{1,6}))?(?<zone>Z|[+-]\d{2}:\d{2})$",
        RegexOptions.CultureInvariant);
    private const long MillisecondsPerDay = 86_400_000;

    private sealed record Product(string Id, string Kind, string? Plan = null, int Days = 0, int Gems = 0);
    private static readonly Product[] Products = [
        new("super_family", "SUBSCRIPTION", "SUPER", 365), new("max_family", "SUBSCRIPTION", "MAX", 365),
        new("super_monthly", "SUBSCRIPTION", "SUPER", 30), new("super_annual", "SUBSCRIPTION", "SUPER", 365),
        new("max_monthly", "SUBSCRIPTION", "MAX", 30), new("max_annual", "SUBSCRIPTION", "MAX", 365),
        new("gems_500", "GEMS", Gems: 500), new("gems_1200", "GEMS", Gems: 1200)
    ];
    public async Task<PurchaseResponse> VerifyAsync(OwnerSession tx, string user, string product, string kind, string state, string key, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var definition = Products.FirstOrDefault(p => p.Id == product && p.Kind == kind) ?? throw new ServiceException("NOT_FOUND", new() { ["productId"] = product });
        var purchase = CanonicalWire.RowId("operation", "purchase", user, key);
        var token = "sim:" + purchase;
        var row = new JsonObject {
            ["purchaseId"] = purchase, ["userId"] = user, ["platform"] = "SIMULATION", ["productId"] = definition.Id, ["kind"] = kind,
            ["purchaseToken"] = token, ["purchaseTokenHash"] = CanonicalWire.Sha256(token), ["state"] = state,
            ["vendorStateJson"] = CanonicalWire.Stringify(new JsonObject { ["simulation"] = true, ["lastOccurredAt"] = tx.NowIso }),
            ["verifiedAt"] = state == "PENDING" ? null : tx.NowIso, ["lastNotificationId"] = null
        };
        tx.Put("p_purchases", CanonicalWire.RowId("p_purchases", purchase), row);
        var gems = await ApplyStateAsync(tx, row, state, ct);
        var entitlement = await tx.GetAsync("p_entitlements", CanonicalWire.RowId("p_entitlements", user), ct) ?? new();
        return new(purchase, product, kind, "SIMULATION", state, state == "PENDING" ? null : tx.Now, gems, ProgressReads.EntitlementView(entitlement, tx.Now));
    }

    public Task<string> NotifyAsync(OwnerStore store, string notification, string purchase, string state, string occurredAt, string bodyHash, CancellationToken ct)
    {
        if (!TryParseNotificationDate(occurredAt, out var occurredAtMilliseconds)) throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "occurredAt" });
        return store.ApplyInboxAsync(CanonicalWire.RowId("operation", "billing-notification", notification), "billing.notification", bodyHash, async (tx, token) => {
            var id = CanonicalWire.RowId("p_purchases", purchase);
            var row = await tx.GetAsync("p_purchases", id, token) ?? throw new ServiceException("NOT_FOUND");
            if (row.Text("state") is "REFUNDED" or "REVOKED" or "EXPIRED") return;
            var vendor = JsonNode.Parse(row.Text("vendorStateJson") ?? "{}")!.AsObject();
            if (TryParseNotificationDate(vendor.Text("lastOccurredAt") ?? "", out var previousMilliseconds) && occurredAtMilliseconds <= previousMilliseconds) return;
            var changed = row.Text("state") != state;
            row["state"] = state;
            if (state != "PENDING" && changed) row["verifiedAt"] = tx.NowIso;
            row["lastNotificationId"] = notification;
            vendor["lastOccurredAt"] = FormatNotificationDate(occurredAtMilliseconds);
            row["vendorStateJson"] = CanonicalWire.Stringify(vendor);
            tx.Put("p_purchases", id, row);
            if (changed) await ApplyStateAsync(tx, row, state, token);
        }, ct);
    }

    private static bool TryParseNotificationDate(string value, out long milliseconds)
    {
        milliseconds = 0;
        var match = NotificationDatePattern.Match(value);
        if (!match.Success) return false;

        static int Number(Group group) => int.Parse(group.Value, CultureInfo.InvariantCulture);
        var year = Number(match.Groups["year"]);
        var month = Number(match.Groups["month"]);
        var day = Number(match.Groups["day"]);
        var hour = Number(match.Groups["hour"]);
        var minute = Number(match.Groups["minute"]);
        var second = Number(match.Groups["second"]);
        var fraction = match.Groups["fraction"].Value;
        var zone = match.Groups["zone"].Value;
        if (month is < 1 or > 12 || day is < 1 or > 31 || hour is < 0 or > 24 || minute is < 0 or > 59 || second is < 0 or > 59)
            return false;
        if (hour == 24 && (minute != 0 || second != 0 || fraction.Any(digit => digit != '0'))) return false;

        var offsetMinutes = 0;
        if (zone != "Z")
        {
            var offsetHours = int.Parse(zone.AsSpan(1, 2), CultureInfo.InvariantCulture);
            var offsetMinutePart = int.Parse(zone.AsSpan(4, 2), CultureInfo.InvariantCulture);
            if (offsetHours > 23 || offsetMinutePart > 59) return false;
            var sign = zone[0] == '+' ? 1 : -1;
            offsetMinutes = sign * (offsetHours * 60 + offsetMinutePart);
        }

        var fractionMilliseconds = int.Parse(fraction.PadRight(3, '0')[..3], CultureInfo.InvariantCulture);
        var localDays = DaysFromCivil(year, month, 1) + day - 1;
        var localMilliseconds = localDays * MillisecondsPerDay + hour * 3_600_000L + minute * 60_000L + second * 1_000L + fractionMilliseconds;
        milliseconds = localMilliseconds - offsetMinutes * 60_000L;
        return true;
    }

    private static string FormatNotificationDate(long milliseconds)
    {
        var days = FloorDivide(milliseconds, MillisecondsPerDay);
        var dayMilliseconds = milliseconds - days * MillisecondsPerDay;
        var (year, month, day) = CivilFromDays(days);
        var hour = dayMilliseconds / 3_600_000;
        var minute = dayMilliseconds / 60_000 % 60;
        var second = dayMilliseconds / 1_000 % 60;
        var fraction = dayMilliseconds % 1_000;
        var yearText = year is >= 0 and <= 9999
            ? year.ToString("D4", CultureInfo.InvariantCulture)
            : (year < 0 ? "-" : "+") + Math.Abs(year).ToString("D6", CultureInfo.InvariantCulture);
        return FormattableString.Invariant($"{yearText}-{month:D2}-{day:D2}T{hour:D2}:{minute:D2}:{second:D2}.{fraction:D3}Z");
    }

    private static long DaysFromCivil(long year, long month, long day)
    {
        var adjustedYear = year - (month <= 2 ? 1 : 0);
        var era = FloorDivide(adjustedYear, 400);
        var yearOfEra = adjustedYear - era * 400;
        var dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1;
        var dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear;
        return era * 146097 + dayOfEra - 719468;
    }

    private static (long Year, long Month, long Day) CivilFromDays(long days)
    {
        var era = FloorDivide(days + 719468, 146097);
        var dayOfEra = days + 719468 - era * 146097;
        var yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146096) / 365;
        var year = yearOfEra + era * 400;
        var dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100);
        var monthPrime = (5 * dayOfYear + 2) / 153;
        var day = dayOfYear - (153 * monthPrime + 2) / 5 + 1;
        var month = monthPrime + (monthPrime < 10 ? 3 : -9);
        year += month <= 2 ? 1 : 0;
        return (year, month, day);
    }

    private static long FloorDivide(long value, long divisor) => value >= 0 ? value / divisor : (value - divisor + 1) / divisor;

    private static async Task<long?> ApplyStateAsync(OwnerSession tx, JsonObject purchase, string state, CancellationToken ct)
    {
        var user = purchase.Text("userId")!; var purchaseId = purchase.Text("purchaseId")!;
        var product = Products.FirstOrDefault(p => p.Id == purchase.Text("productId"));
        if (product is null) return null;
        if (product.Kind == "GEMS")
        {
            var credited = await tx.GetAsync("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", user, purchaseId, "PURCHASE"), ct);
            var refunded = await tx.GetAsync("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", user, purchaseId, "REFUND"), ct);
            if (state is "ACTIVE" or "GRACE" && credited is null) return await ProgressShop.CreditGemsAsync(tx, user, product.Gems, "PURCHASE", purchaseId, product.Id, "UTC", ct);
            if (state is "REFUNDED" or "REVOKED" && credited is not null && refunded is null) return await ProgressShop.CreditGemsAsync(tx, user, -product.Gems, "REFUND", purchaseId, product.Id, "UTC", ct);
            return null;
        }
        if (state == "PENDING") return null;
        var status = state == "REFUNDED" ? "REVOKED" : state;
        var current = await tx.GetAsync("p_entitlements", CanonicalWire.RowId("p_entitlements", user), ct);
        if (current?.Text("purchaseId") is { Length: > 0 } currentPurchase && currentPurchase != purchaseId &&
            ProgressReads.EntitlementView(current, tx.Now).UnlimitedEnergy && status is not ("ACTIVE" or "GRACE")) return null;
        var same = current?.Text("purchaseId") == purchaseId;
        var expiry = (same ? current?.Text("expiresAt") : null) ?? (status is "ACTIVE" or "GRACE" ? OwnerSchema.Iso(tx.Now.AddDays(product.Days)) : tx.NowIso);
        await ChangeEntitlementAsync(tx, user, new() { ["plan"] = product.Plan, ["source"] = "PURCHASE", ["status"] = status,
            ["expiresAt"] = status == "CANCELED" ? current?.Text("expiresAt") ?? expiry : expiry,
            ["autoRenew"] = status is "ACTIVE" or "GRACE", ["purchaseId"] = purchaseId, ["giftId"] = null }, ct);
        return null;
    }

    internal static async Task<EntitlementResponse> ChangeEntitlementAsync(OwnerSession tx, string user, JsonObject patch, CancellationToken ct)
    {
        var id = CanonicalWire.RowId("p_entitlements", user);
        var current = await tx.GetAsync("p_entitlements", id, ct);
        var revision = current is null ? 0 : current.Number("revision") + 1;
        var next = current ?? new JsonObject { ["userId"] = user, ["plan"] = "FREE", ["source"] = "NONE", ["status"] = "ACTIVE", ["expiresAt"] = null,
            ["autoRenew"] = false, ["familyGroupId"] = null, ["purchaseId"] = null, ["giftId"] = null };
        foreach (var property in patch) next[property.Key] = property.Value?.DeepClone();
        next["userId"] = user;
        tx.Put("p_entitlements", id, next);
        ProgressWrites.EnqueueEvent(tx, "entitlement.changed.v1", user, new() { ["userId"] = user, ["plan"] = next.Text("plan"), ["status"] = next.Text("status"),
            ["expiresAt"] = next.Text("expiresAt"), ["entitlementRevision"] = revision });
        return ProgressReads.EntitlementView(next, tx.Now) with { Revision = revision };
    }
}
