using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CocEnglish.Learning;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LearningHostTests
{
    private static readonly ServiceKey MaintainerKey = new("maintainer-test", "maintainer", Enumerable.Repeat((byte)51, 32).ToArray());
    private const string AllAcceptanceGates = "durable-owner-storage,mixed-node-dotnet-event-boundaries,all-dotnet-docker,flutter-native-end-to-end,one-writer-cutover-and-rollback";

    [Fact]
    public async Task Health_IsPublicAndReadinessRemainsClosedUntilMigrationGatesPass()
    {
        using var factory = new WebApplicationFactory<Learning.Program>().WithWebHostBuilder(builder =>
        {
            var secret = Convert.ToHexStringLower(MaintainerKey.Secret);
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"maintainer-test\",\"sender\":\"maintainer\",\"secretHex\":\"" + secret + "\"}]"
            }));
        });
        using var client = factory.CreateClient();

        using var health = await client.GetAsync("/health");
        Assert.Equal(HttpStatusCode.OK, health.StatusCode);
        var healthBody = (await health.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("learning", healthBody["service"]!.GetValue<string>());
        Assert.Equal("degraded", healthBody["status"]!.GetValue<string>());

        using var unsigned = await client.GetAsync("/ready");
        Assert.Equal(HttpStatusCode.Unauthorized, unsigned.StatusCode);
        using var request = SignedReadinessRequest();
        using var readiness = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, readiness.StatusCode);
        Assert.Equal("SERVICE_NOT_CONFIGURED", (await readiness.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
    }

    [Fact]
    public async Task Readiness_OpensWhenAppwriteAndEverySystemAcceptanceGateAreAdmitted()
    {
        using var factory = AdmissionFactory(AllAcceptanceGates, storageConfigured: true, businessAdmitted: true);
        using var client = factory.CreateClient();
        using var response = await client.SendAsync(SignedReadinessRequest());

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = (await response.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("learning", body["service"]!.GetValue<string>());
        Assert.Equal("ok", body["status"]!.GetValue<string>());
    }

    [Theory]
    [MemberData(nameof(ReadinessGateSetsMissingOneGate))]
    public async Task Readiness_RemainsClosedWhenAnySystemAcceptanceGateIsMissing(string gates)
    {
        using var factory = AdmissionFactory(gates, storageConfigured: true, businessAdmitted: true);
        using var client = factory.CreateClient();
        using var response = await client.SendAsync(SignedReadinessRequest());

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal("SERVICE_NOT_CONFIGURED", (await response.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
    }

    [Theory]
    [InlineData(AllAcceptanceGates + ",durable-owner-storage")]
    [InlineData(AllAcceptanceGates + ",unknown-gate")]
    public async Task Readiness_RemainsClosedWhenAcceptanceGateListHasDuplicatesOrUnknownEntries(string gates)
    {
        using var factory = AdmissionFactory(gates, storageConfigured: true, businessAdmitted: true);
        using var client = factory.CreateClient();
        using var response = await client.SendAsync(SignedReadinessRequest());

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }

    public static IEnumerable<object[]> ReadinessGateSetsMissingOneGate => AllAcceptanceGates.Split(',')
        .Select(missing => new object[] { string.Join(',', AllAcceptanceGates.Split(',').Where(gate => gate != missing)) });

    [Theory]
    [InlineData(false, true)]
    [InlineData(true, false)]
    [InlineData(false, false)]
    public async Task Readiness_RemainsClosedWithoutAppwriteOrBusinessAdmission(bool storageConfigured, bool businessAdmitted)
    {
        using var factory = AdmissionFactory(AllAcceptanceGates, storageConfigured, businessAdmitted);
        using var client = factory.CreateClient();
        using var response = await client.SendAsync(SignedReadinessRequest());

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal("SERVICE_NOT_CONFIGURED", (await response.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
    }

    private static WebApplicationFactory<Learning.Program> AdmissionFactory(string gates, bool storageConfigured, bool businessAdmitted) =>
        new WebApplicationFactory<Learning.Program>().WithWebHostBuilder(builder =>
        {
            var key = Convert.ToHexStringLower(MaintainerKey.Secret);
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"maintainer-test\",\"sender\":\"maintainer\",\"secretHex\":\"" + key + "\"}]",
                ["APPWRITE_ENDPOINT"] = storageConfigured ? "https://appwrite.test/v1" : null,
                ["APPWRITE_PROJECT_ID"] = storageConfigured ? "test-project" : null,
                ["COC_LEARNING_APPWRITE_KEY"] = storageConfigured ? "test-server-key" : null,
                ["COC_LEARNING_PERSISTENCE"] = storageConfigured ? "appwrite" : null,
                ["COC_LEARNING_ADMITTED"] = businessAdmitted ? "reviewed-cloud-gate" : null,
                ["COC_LEARNING_READINESS_GATES"] = gates
            }));
        });

    private static HttpRequestMessage SignedReadinessRequest()
    {
        var signed = ServiceHmac.Sign(MaintainerKey, "GET", "/ready", "", new HashSet<string>(), "", DateTimeOffset.UtcNow.ToUnixTimeSeconds());
        var request = new HttpRequestMessage(HttpMethod.Get, "/ready");
        request.Headers.Add("X-Service-Key-Id", signed.KeyId);
        request.Headers.Add("X-Service-Timestamp", signed.Timestamp);
        request.Headers.Add("X-Service-Signature", signed.Signature);
        return request;
    }
}
