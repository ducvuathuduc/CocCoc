using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class AdTests
{
    [Theory]
    [InlineData("premium", "AD_NOT_ELIGIBLE")]
    [InlineData("no-reward", "AD_NOT_ELIGIBLE")]
    [InlineData("substitute", "IDEMPOTENCY_CONFLICT")]
    public async Task IneligibleOrSubstitutedEvent_DoesNotApplyEffects(string condition, string error)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(b => b.ConfigureServices(s => s.AddSingleton(new ProgressCommercePolicy(true))));
        using var client = app.CreateClient(); var ad = Guid.NewGuid().ToString();
        if (condition == "premium") fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "alice"))] = new() { ["plan"] = "SUPER", ["status"] = "ACTIVE", ["expiresAt"] = "2026-12-01T00:00:00.000Z" };
        if (condition == "substitute")
        {
            using var first = Request(ad, "REWARDED_GEMS", "REWARDED_COMPLETION"); using var result = await client.SendAsync(first);
            Assert.Equal(HttpStatusCode.OK, result.StatusCode);
        }
        var commits = fixture.Driver.Commits;
        using var request = Request(ad, condition == "no-reward" ? "LESSON_END_INTERSTITIAL" : "REWARDED_GEMS", condition == "substitute" ? "IMPRESSION" : "REWARDED_COMPLETION");
        using var response = await client.SendAsync(request);
        Assert.Equal(error, JsonNode.Parse(await response.Content.ReadAsStringAsync())!["error"]!["code"]!.GetValue<string>());
        Assert.Equal(commits, fixture.Driver.Commits);
        Assert.Equal(condition == "substitute" ? 1 : 0, fixture.Driver.Rows.Count(r => r.Key.Table == "p_ad_events"));
    }

    [Theory]
    [InlineData("LESSON_END_INTERSTITIAL", "IMPRESSION", 0, 0)]
    [InlineData("REWARDED_GEMS", "IMPRESSION", 0, 0)]
    [InlineData("REWARDED_ENERGY_REFILL", "IMPRESSION", 0, 0)]
    [InlineData("REWARDED_GEMS", "REWARDED_COMPLETION", 5, 0)]
    [InlineData("REWARDED_ENERGY_REFILL", "REWARDED_COMPLETION", 0, 25)]
    public async Task Event_DeduplicatesAcrossRequestKeysAndProjectsReward(string placement, string kind, int gems, int energy)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(b => b.ConfigureServices(s => s.AddSingleton(new ProgressCommercePolicy(true))));
        using var client = app.CreateClient(); var ad = Guid.NewGuid().ToString();
        for (var i = 0; i < 2; i++)
        {
            using var request = Request(ad, placement, kind); using var response = await client.SendAsync(request);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode); var body = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
            Assert.Equal(gems, body["rewardGems"]!.GetValue<int>()); Assert.Equal(energy, body["rewardEnergy"]!.GetValue<int>());
            Assert.Equal(1, body["dailyIndex"]!.GetValue<int>());
            Assert.Equal(kind == "IMPRESSION" ? 19 : 4, body["remainingToday"]!.GetValue<int>());
            Assert.Equal(i == 0 && energy > 0, body["energyGrantPending"]!.GetValue<bool>());
        }
        Assert.Single(fixture.Driver.Rows, r => r.Key.Table == "p_ad_events");
        Assert.Equal(gems, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("gems"));
        Assert.Equal(energy > 0 ? 1 : 0, fixture.Driver.Rows.Count(r => r.Key.Table == "p_outbox"));
        if (energy > 0)
        {
            var payload = JsonNode.Parse(fixture.Driver.Rows.Single(r => r.Key.Table == "p_outbox").Value.Text("payloadJson")!)!;
            Assert.Equal(25, payload["amount"]!.GetValue<int>()); Assert.False(payload["refillToCapacity"]!.GetValue<bool>()); Assert.Equal("AD", payload["reason"]!.GetValue<string>());
        }
    }

    [Fact]
    public async Task RewardCap_RejectsSixthThenResetsNextDay()
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(b => b.ConfigureServices(s => s.AddSingleton(new ProgressCommercePolicy(true))));
        using var client = app.CreateClient();
        for (var i = 0; i < 6; i++)
        {
            using var request = Request(Guid.NewGuid().ToString(), "REWARDED_GEMS", "REWARDED_COMPLETION"); using var response = await client.SendAsync(request);
            if (i < 5) Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            else Assert.Equal("AD_DAILY_CAP", JsonNode.Parse(await response.Content.ReadAsStringAsync())!["error"]!["code"]!.GetValue<string>());
        }
        Assert.Equal(25, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("gems"));
        fixture.Now = fixture.Now.AddDays(1);
        using var next = Request(Guid.NewGuid().ToString(), "REWARDED_GEMS", "REWARDED_COMPLETION"); using var result = await client.SendAsync(next);
        Assert.Equal(HttpStatusCode.OK, result.StatusCode);
        Assert.Equal(1, JsonNode.Parse(await result.Content.ReadAsStringAsync())!["dailyIndex"]!.GetValue<int>());
        Assert.Equal(30, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("gems"));
    }

    [Fact]
    public async Task DefaultHost_RejectsSimulationWithoutWrites()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient();
        using var request = Request(Guid.NewGuid().ToString(), "REWARDED_GEMS", "REWARDED_COMPLETION"); using var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode); Assert.Equal(0, fixture.Driver.Commits);
    }

    private static HttpRequestMessage Request(string ad, string placement, string kind)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "/v1/ad-events") { Content = JsonContent.Create(new { adEventId = ad, placement, kind }) };
        request.Headers.Add("Authorization", "Bearer alice-jwt"); request.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString()); return request;
    }
}
