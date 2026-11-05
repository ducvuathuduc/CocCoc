using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class PromoTests
{
    [Theory]
    [InlineData("GEMS")]
    [InlineData("ITEM")]
    [InlineData("SUPER_DAYS")]
    public async Task Redeem_AppliesRewardOnceAndDistinguishesOwnUsedCodeFromExhaustion(string kind)
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient();
        var (id, promo) = Seed(fixture, kind);
        if (kind == "SUPER_DAYS") fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "alice"))] = new() { ["userId"] = "alice", ["plan"] = "MAX", ["source"] = "PURCHASE", ["status"] = "ACTIVE", ["expiresAt"] = "2026-12-01T00:00:00.000Z", ["autoRenew"] = true, ["revision"] = 0 };
        var key = Guid.NewGuid().ToString(); string? original = null;
        for (var i = 0; i < 2; i++)
        {
            using var request = Request("alice", key); using var response = await client.SendAsync(request);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var text = await response.Content.ReadAsStringAsync();
            if (original is not null) Assert.Equal(original, text); original = text;
            var body = JsonNode.Parse(text)!;
            Assert.Equal(kind, body["rewardType"]!.GetValue<string>());
            if (kind == "SUPER_DAYS")
            {
                Assert.Equal("MAX", body["entitlement"]!["plan"]!.GetValue<string>());
                Assert.Equal("2026-12-08T00:00:00.000Z", body["entitlement"]!["expiresAt"]!.GetValue<string>());
                Assert.Equal("PURCHASE", body["entitlement"]!["source"]!.GetValue<string>());
            }
        }
        Assert.Equal(1, fixture.Driver.Rows[("p_promo_codes", id)].Number("redeemedCount"));
        Assert.Single(fixture.Driver.Rows, r => r.Key.Table == "p_promo_redemptions");
        if (kind == "GEMS") Assert.Equal(50, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("gems"));
        if (kind == "ITEM") Assert.Equal(2, fixture.Driver.Rows[("p_inventory", CanonicalWire.RowId("p_inventory", "alice", "xp_boost_15"))].Number("quantity"));
        using var again = Request("alice", Guid.NewGuid().ToString()); using var repeated = await client.SendAsync(again);
        Assert.Equal("PROMO_ALREADY_REDEEMED", JsonNode.Parse(await repeated.Content.ReadAsStringAsync())!["error"]!["code"]!.GetValue<string>());
        fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))] = new() { ["userId"] = "bob", ["learningZone"] = "UTC" };
        using var other = Request("bob", Guid.NewGuid().ToString()); using var exhausted = await client.SendAsync(other);
        Assert.Equal(HttpStatusCode.NotFound, exhausted.StatusCode);
        Assert.Equal(promo.Text("promoId"), fixture.Driver.Rows[("p_promo_codes", id)].Text("promoId"));
    }

    [Theory]
    [InlineData("future")]
    [InlineData("expired")]
    [InlineData("paused")]
    public async Task UnavailableCode_LeavesNoRedemptionOrReward(string condition)
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); var (_, promo) = Seed(fixture, "GEMS");
        if (condition == "future") promo["startsAt"] = "2026-11-03T10:00:00.001Z";
        if (condition == "expired") promo["endsAt"] = "2026-11-03T10:00:00.000Z";
        if (condition == "paused") promo["status"] = "PAUSED";
        using var request = Request("alice", Guid.NewGuid().ToString()); using var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal(0, fixture.Driver.Commits);
        Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table is "p_promo_redemptions" or "p_reward_ledger");
    }
    private static (string Id, JsonObject Row) Seed(ProgressApiFixture fixture, string kind)
    {
        var hash = ProgressCodes.Hash("PROMO1"); var promoId = CanonicalWire.RowId("operation", "promo", hash); var id = CanonicalWire.RowId("p_promo_codes", promoId);
        var row = new JsonObject { ["promoId"] = promoId, ["codeHash"] = hash, ["rewardType"] = kind, ["superDays"] = kind == "SUPER_DAYS" ? 7 : 0, ["gems"] = kind == "GEMS" ? 50 : 0,
            ["itemId"] = kind == "ITEM" ? "xp_boost_15" : null, ["itemQuantity"] = kind == "ITEM" ? 2 : 0, ["maxRedemptions"] = 1, ["redeemedCount"] = 0, ["startsAt"] = "2026-11-03T10:00:00.000Z", ["endsAt"] = null, ["status"] = "ACTIVE", ["revision"] = 0 };
        fixture.Driver.Rows[("p_promo_codes", id)] = row; return (id, row);
    }
    private static HttpRequestMessage Request(string user, string key)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "/v1/promo-codes/redeem") { Content = JsonContent.Create(new { code = "pro-mo1" }) };
        request.Headers.Add("Authorization", "Bearer " + user + "-jwt"); request.Headers.Add("Idempotency-Key", key); return request;
    }
}
