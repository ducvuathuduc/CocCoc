using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;
using Xunit;

namespace CocEnglish.Shared.Tests;

internal static class AppwriteOwnerProbeRows
{
    public static string ProgressUsername(string userId) => "probe-" + userId[^24..];

    public static JsonObject ProgressProfile(string userId, string nickname)
    {
        var now = OwnerSchema.Iso(DateTimeOffset.UtcNow);
        var row = new JsonObject
        {
            ["userId"] = userId,
            ["username"] = ProgressUsername(userId),
            ["nickname"] = nickname,
            ["publicOptIn"] = false,
            ["ageBand"] = "ADULT",
            ["emailVerifiedSnapshot"] = false,
            ["dailyGoal"] = 10,
            ["learningZone"] = "UTC",
            ["lastZoneChangedAt"] = now,
            ["revision"] = 0,
            ["createdAt"] = now,
            ["updatedAt"] = now
        };
        OwnerSchema.Validate("progress", "p_profiles", row);
        return row;
    }

    public static JsonObject AiActiveSlot(string userId, string sessionId)
    {
        var now = OwnerSchema.Iso(DateTimeOffset.UtcNow);
        var row = new JsonObject
        {
            ["userId"] = userId,
            ["sessionId"] = sessionId,
            ["expiresAt"] = OwnerSchema.Iso(DateTimeOffset.UtcNow.AddHours(1)),
            ["epoch"] = 7,
            ["revision"] = 0,
            ["createdAt"] = now,
            ["updatedAt"] = now
        };
        OwnerSchema.Validate("ai", "a_active_slots", row);
        return row;
    }

    public static JsonObject Change(string owner, string table, JsonObject source, string field, string value)
    {
        var row = source.DeepClone().AsObject();
        row[field] = value;
        row["revision"] = source["revision"]!.GetValue<int>() + 1;
        row["updatedAt"] = OwnerSchema.Iso(DateTimeOffset.UtcNow);
        OwnerSchema.Validate(owner, table, row);
        return row;
    }
}

public sealed class AppwriteOwnerProbeRowTests
{
    [Fact]
    public void ProgressProfileProbe_IsValidForTheDeclaredSchemaAndUpdatesRevision()
    {
        var userId = "dn_" + Guid.NewGuid().ToString("N");
        var original = AppwriteOwnerProbeRows.ProgressProfile(userId, "probe-original");

        var updated = AppwriteOwnerProbeRows.Change("progress", "p_profiles", original, "nickname", "probe-updated");

        Assert.Equal(userId, updated["userId"]!.GetValue<string>());
        Assert.Equal(AppwriteOwnerProbeRows.ProgressUsername(userId), updated["username"]!.GetValue<string>());
        Assert.Equal("probe-updated", updated["nickname"]!.GetValue<string>());
        Assert.Equal(1, updated["revision"]!.GetValue<int>());
    }

    [Fact]
    public void AiActiveSlotProbe_IsValidForTheDeclaredSchemaAndUpdatesRevision()
    {
        var userId = "dn_" + Guid.NewGuid().ToString("N");
        var original = AppwriteOwnerProbeRows.AiActiveSlot(userId, "probe-original");

        var updated = AppwriteOwnerProbeRows.Change("ai", "a_active_slots", original, "sessionId", "probe-updated");

        Assert.Equal(userId, updated["userId"]!.GetValue<string>());
        Assert.Equal(7, updated["epoch"]!.GetValue<int>());
        Assert.Equal("probe-updated", updated["sessionId"]!.GetValue<string>());
        Assert.Equal(1, updated["revision"]!.GetValue<int>());
    }
}
