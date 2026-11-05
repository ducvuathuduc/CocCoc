using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class AiCapabilitiesTests
{
    [Fact]
    public async Task DisabledCapabilities_MatchNodeRouterResponse()
    {
        var scenarioText = Resource("Scenarios");
        var scenario = JsonNode.Parse(scenarioText)!;
        var baseline = JsonNode.Parse(Resource("Node"))!;
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());
        var step = scenario["steps"]![0]!;
        var expected = baseline["results"]![0]!;

        using var app = new WebApplicationFactory<CocEnglish.AI.Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1",
                ["APPWRITE_PROJECT_ID"] = "test",
                ["COC_AI_APPWRITE_KEY"] = "test-key",
                ["COC_AI_PERSISTENCE"] = "appwrite",
                ["COC_AI_ADMITTED"] = "reviewed-cloud-gate",
                ["COC_AI_PROVIDER"] = "disabled",
                ["COC_AI_SPEECH_ADMITTED"] = "not-reviewed"
            }));
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<IIdentityVerifier>();
                services.AddSingleton<IIdentityVerifier, Identity>();
            });
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", step["user"]!.GetValue<string>() + "-token");

        using var response = await client.GetAsync(step["path"]!.GetValue<string>());
        var actual = JsonNode.Parse(await response.Content.ReadAsStringAsync());
        Assert.Equal(expected["status"]!.GetValue<int>(), (int)response.StatusCode);
        Assert.True(JsonNode.DeepEquals(expected["body"], actual),
            $"AI capabilities differ from Node: expected {expected["body"]?.ToJsonString()}, actual {actual?.ToJsonString()}");
    }

    [Fact]
    public async Task Capabilities_RequiresVerifiedIdentityAndReportsOnlyFeaturesEnabledByThisHost()
    {
        using var app = new WebApplicationFactory<CocEnglish.AI.Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1",
                ["APPWRITE_PROJECT_ID"] = "test",
                ["COC_AI_APPWRITE_KEY"] = "test-key",
                ["COC_AI_PERSISTENCE"] = "appwrite",
                ["COC_AI_ADMITTED"] = "reviewed-cloud-gate"
            }));
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<IIdentityVerifier>();
                services.AddSingleton<IIdentityVerifier, Identity>();
            });
        });
        using var client = app.CreateClient();

        using var anonymous = await client.GetAsync("/v1/ai/capabilities");
        Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "alice-token");
        using var response = await client.GetAsync("/v1/ai/capabilities");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = (await response.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("disabled-v1", body["configVersion"]!.GetValue<string>());
        Assert.True(body["textTutor"]!.GetValue<bool>());
        Assert.False(body["nativeLive"]!.GetValue<bool>());
        Assert.False(body["turnSpeech"]!.GetValue<bool>());
        Assert.False(body["pronunciation"]!.GetValue<bool>());
        Assert.True(body["offlineShadowing"]!.GetValue<bool>());
        Assert.Equal("NATIVE_LIVE_DISABLED", body["nativeLiveReason"]!.GetValue<string>());
        Assert.Equal("AZURE_DISABLED", body["pronunciationReason"]!.GetValue<string>());
        Assert.Equal(180, body["liveUiMaxSeconds"]!.GetValue<int>());
        Assert.Equal(0, body["dailyLiveSessionLimit"]!.GetValue<int>());
    }

    [Fact]
    public async Task Capabilities_EnablesRecordedSpeechOnlyAfterExplicitAdmissionGate()
    {
        using var app = new WebApplicationFactory<CocEnglish.AI.Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1",
                ["APPWRITE_PROJECT_ID"] = "test",
                ["COC_AI_APPWRITE_KEY"] = "test-key",
                ["COC_AI_PERSISTENCE"] = "appwrite",
                ["COC_AI_ADMITTED"] = "reviewed-cloud-gate",
                ["COC_AI_PROVIDER"] = "speech",
                ["COC_AI_SPEECH_ADMITTED"] = "reviewed-device-quality-privacy-cost",
                ["COC_AZURE_SPEECH_KEY"] = "test-key",
                ["COC_AZURE_SPEECH_REGION"] = "westus2"
            }));
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<IIdentityVerifier>();
                services.AddSingleton<IIdentityVerifier, Identity>();
            });
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "alice-token");

        using var response = await client.GetAsync("/v1/ai/capabilities");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = (await response.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("speech-azure-v1", body["configVersion"]!.GetValue<string>());
        Assert.True(body["turnSpeech"]!.GetValue<bool>());
        Assert.True(body["pronunciation"]!.GetValue<bool>());
        Assert.Null(body["pronunciationReason"]);
        Assert.False(body["nativeLive"]!.GetValue<bool>());
        Assert.DoesNotContain("test-key", body.ToJsonString(), StringComparison.Ordinal);
    }

    [Fact]
    public async Task Capabilities_ProviderSecretsAloneDoNotEnableSpeechBeforeReviewGate()
    {
        using var app = new WebApplicationFactory<CocEnglish.AI.Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1",
                ["APPWRITE_PROJECT_ID"] = "test",
                ["COC_AI_APPWRITE_KEY"] = "test-key",
                ["COC_AI_PERSISTENCE"] = "appwrite",
                ["COC_AI_ADMITTED"] = "reviewed-cloud-gate",
                ["COC_AI_PROVIDER"] = "speech",
                ["COC_AZURE_SPEECH_KEY"] = "test-key",
                ["COC_AZURE_SPEECH_REGION"] = "westus2"
            }));
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<IIdentityVerifier>();
                services.AddSingleton<IIdentityVerifier, Identity>();
            });
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "alice-token");

        using var response = await client.GetAsync("/v1/ai/capabilities");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = (await response.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("disabled-v1", body["configVersion"]!.GetValue<string>());
        Assert.False(body["turnSpeech"]!.GetValue<bool>());
        Assert.False(body["pronunciation"]!.GetValue<bool>());
        Assert.Equal("AZURE_DISABLED", body["pronunciationReason"]!.GetValue<string>());
    }

    private sealed class Identity : IIdentityVerifier
    {
        public bool Configured => true;
        public Task<VerifiedSubject> VerifyAsync(string jwt, CancellationToken cancellationToken) => jwt == "alice-token"
            ? Task.FromResult(new VerifiedSubject("alice"))
            : throw new ServiceException("AUTH_EXPIRED");
    }

    private static string Resource(string name)
    {
        using var stream = typeof(AiCapabilitiesTests).Assembly.GetManifestResourceStream($"CocEnglish.AI.Parity.{name}.json")!;
        using var reader = new StreamReader(stream, Encoding.UTF8);
        return reader.ReadToEnd();
    }
}
