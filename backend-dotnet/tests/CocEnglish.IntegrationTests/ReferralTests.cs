using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class ReferralTests
{
    [Fact]
    public async Task Issue_WithoutServerSecretFailsBeforeWriting()
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient(); client.DefaultRequestHeaders.Add("Authorization", "Bearer alice-jwt");
        using var response = await client.GetAsync("/v1/me/referral");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal(0, fixture.Driver.Commits);
        Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table == "p_referrals");
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task IssueRedeem_GrantsTrialOnceAndPreservesExistingPaidPlan(bool paid)
    {
        await using var fixture = new ProgressApiFixture { CodeSecret = "local-test-code-secret" };
        using var client = fixture.CreateClient();
        fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))] = new() { ["userId"] = "bob", ["learningZone"] = "UTC" };
        if (paid) fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "alice"))] = new() {
            ["userId"] = "alice", ["plan"] = "MAX", ["source"] = "PURCHASE", ["status"] = "ACTIVE", ["expiresAt"] = "2027-01-01T00:00:00.000Z", ["autoRenew"] = true, ["revision"] = 0 };
        client.DefaultRequestHeaders.Add("Authorization", "Bearer alice-jwt");
        var issued = await client.GetFromJsonAsync<JsonObject>("/v1/me/referral");
        var code = issued!["code"]!.GetValue<string>();
        Assert.Equal(8, code.Length); Assert.Equal(0, issued["accepted"]!.GetValue<int>());
        var commits = fixture.Driver.Commits;
        await client.GetFromJsonAsync<JsonObject>("/v1/me/referral");
        Assert.Equal(commits, fixture.Driver.Commits);
        for (var i = 0; i < 2; i++)
        {
            using var request = Redeem("bob", i == 0 ? code.ToLowerInvariant() : "INVALID");
            using var response = await client.SendAsync(request);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }
        var bob = fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "bob"))];
        Assert.Equal("SUPER", bob.Text("plan")); Assert.Equal("REFERRAL", bob.Text("source"));
        Assert.Equal("2026-11-10T10:00:00.000Z", bob.Text("expiresAt"));
        Assert.False(bob.Flag("autoRenew"));
        var alice = fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "alice"))];
        Assert.Equal(paid ? "MAX" : "SUPER", alice.Text("plan"));
        Assert.Equal(paid ? "2027-01-01T00:00:00.000Z" : "2026-11-10T10:00:00.000Z", alice.Text("expiresAt"));
        Assert.Equal(paid ? 1 : 2, fixture.Driver.Rows.Count(r => r.Key.Table == "p_outbox"));
        var summary = await client.GetFromJsonAsync<JsonObject>("/v1/me/referral");
        foreach (var field in new[] { "accepted", "qualified", "rewarded" }) Assert.Equal(1, summary![field]!.GetValue<int>());
        Assert.Equal(2, fixture.Driver.Rows.Count(r => r.Key.Table == "p_referrals"));
    }

    [Fact]
    public async Task SelfOrUnknownCode_DoesNotGrantEntitlement()
    {
        await using var fixture = new ProgressApiFixture { CodeSecret = "local-test-code-secret" };
        using var client = fixture.CreateClient(); client.DefaultRequestHeaders.Add("Authorization", "Bearer alice-jwt");
        var issued = await client.GetFromJsonAsync<JsonObject>("/v1/me/referral");
        foreach (var code in new[] { issued!["code"]!.GetValue<string>(), "UNKNOWN" })
        {
            using var request = Redeem("alice", code); using var response = await client.SendAsync(request);
            Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        }
        Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table is "p_entitlements" or "p_outbox");
    }
    private static HttpRequestMessage Redeem(string user, string code)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "/v1/referrals/redeem") { Content = JsonContent.Create(new { code }) };
        request.Headers.Add("Authorization", "Bearer " + user + "-jwt"); request.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
        return request;
    }
}
