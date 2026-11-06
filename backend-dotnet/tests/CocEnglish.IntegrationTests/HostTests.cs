using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class HostTests
{
    [Fact]
    public async Task Health_IsPublicAndPreflightUsesAnExactCorsAllowlist()
    {
        await using var factory = new Factory();
        using var client = factory.CreateClient();
        using var health = await client.GetAsync("/health");
        Assert.Equal(HttpStatusCode.OK, health.StatusCode);
        var body = JsonNode.Parse(await health.Content.ReadAsStringAsync())!;
        Assert.Equal("progress", body["service"]!.GetValue<string>());
        Assert.Equal("degraded", body["status"]!.GetValue<string>());
        foreach (var origin in new[] { "https://learner.test", "https://learner.test.evil" })
        {
            using var request = new HttpRequestMessage(HttpMethod.Options, "/not-a-route");
            request.Headers.Add("Origin", origin);
            using var response = await client.SendAsync(request);
            Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
            Assert.Equal(origin == "https://learner.test", response.Headers.Contains("Access-Control-Allow-Origin"));
            if (origin == "https://learner.test") Assert.Equal(origin, Assert.Single(response.Headers.GetValues("Access-Control-Allow-Origin")));
        }
    }

    [Fact]
    public async Task ProtectedRoutes_RejectForgedAppwriteIdentityHeaders()
    {
        await using var factory = new Factory();
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, "/v1/me");
        request.Headers.Add("x-appwrite-user-id", "alice");
        request.Headers.Add("x-appwrite-user-jwt", "fake-jwt");
        using var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("AUTH_REQUIRED", (await Body(response))["error"]!["code"]!.GetValue<string>());
    }

    [Fact]
    public async Task ProtectedRoutes_RequireVerifiedSessionBeforeUnportedOperation()
    {
        await using var factory = new Factory();
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "revoked");
        using var rejected = await client.GetAsync("/v1/me");
        Assert.Equal(HttpStatusCode.Unauthorized, rejected.StatusCode);
        Assert.Equal("AUTH_EXPIRED", (await Body(rejected))["error"]!["code"]!.GetValue<string>());
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "alice-jwt");
        using var pending = await client.GetAsync("/v1/shop");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, pending.StatusCode);
        Assert.Equal("SERVICE_NOT_CONFIGURED", (await Body(pending))["error"]!["code"]!.GetValue<string>());
    }

    [Fact]
    public async Task RequestId_PropagatesValidIdAndRejectsInvalidHeaderValue()
    {
        await using var factory = new Factory();
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, "/v1/me");
        request.Headers.Add("X-Request-ID", "request-123");
        using var response = await client.SendAsync(request);
        Assert.Equal("request-123", Assert.Single(response.Headers.GetValues("X-Request-ID")));
        Assert.Equal("request-123", (await Body(response))["error"]!["requestId"]!.GetValue<string>());
        Assert.False((await Body(response))["error"]!["retryable"]!.GetValue<bool>());
        using var invalid = new HttpRequestMessage(HttpMethod.Get, "/v1/me");
        invalid.Headers.Add("X-Request-ID", "invalid request");
        using var invalidResponse = await client.SendAsync(invalid);
        var generated = Assert.Single(invalidResponse.Headers.GetValues("X-Request-ID"));
        Assert.True(Guid.TryParse(generated, out _));
        Assert.Equal(generated, (await Body(invalidResponse))["error"]!["requestId"]!.GetValue<string>());
    }

    [Fact]
    public async Task PayloadLimit_IsUtf8BytesAndGetRejectsBody()
    {
        await using var factory = new Factory();
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Post, "/v1/feedback")
        { Content = new StringContent(new string('é', 32001), Encoding.UTF8, "application/json") };
        using var tooLarge = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.RequestEntityTooLarge, tooLarge.StatusCode);
        using var get = new HttpRequestMessage(HttpMethod.Get, "/v1/me") { Content = new StringContent("{}") };
        using var invalid = await client.SendAsync(get);
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
        Assert.Equal("body", (await Body(invalid))["error"]!["details"]!["field"]!.GetValue<string>());
    }

    [Fact]
    public async Task Readiness_RequiresServiceHmacAndDoesNotClaimIncompleteMigrationReady()
    {
        await using var factory = new Factory();
        using var client = factory.CreateClient();
        using var unsigned = await client.GetAsync("/ready");
        Assert.Equal(HttpStatusCode.Unauthorized, unsigned.StatusCode);
        var key = new ServiceKey("maintainer-1", "maintainer", Enumerable.Repeat((byte)1, 32).ToArray());
        var signed = ServiceHmac.Sign(key, "GET", "/ready", "", new HashSet<string>(), "", DateTimeOffset.UtcNow.ToUnixTimeSeconds());
        using var request = new HttpRequestMessage(HttpMethod.Get, "/ready");
        request.Headers.Add("X-Service-Key-Id", signed.KeyId);
        request.Headers.Add("X-Service-Timestamp", signed.Timestamp);
        request.Headers.Add("X-Service-Signature", signed.Signature);
        using var pending = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, pending.StatusCode);
        Assert.Equal("SERVICE_NOT_CONFIGURED", (await Body(pending))["error"]!["code"]!.GetValue<string>());
    }

    private static async Task<JsonNode> Body(HttpResponseMessage response) => JsonNode.Parse(await response.Content.ReadAsStringAsync())!;

    private sealed class Factory : WebApplicationFactory<Progress.Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.ConfigureAppConfiguration((_, configuration) => configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["COC_CORS_ALLOWED_ORIGINS"] = "https://learner.test",
                ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"maintainer-1\",\"sender\":\"maintainer\",\"secretHex\":\"" + string.Concat(Enumerable.Repeat("01", 32)) + "\"}]"
            }));
            builder.ConfigureServices(services => { services.RemoveAll<IIdentityVerifier>(); services.AddSingleton<IIdentityVerifier, Identity>(); });
        }
    }

    private sealed class Identity : IIdentityVerifier
    {
        public bool Configured => true;
        public Task<VerifiedSubject> VerifyAsync(string jwt, CancellationToken cancellationToken) => jwt == "alice-jwt"
            ? Task.FromResult(new VerifiedSubject("alice")) : throw new ServiceException("AUTH_EXPIRED");
    }
}
