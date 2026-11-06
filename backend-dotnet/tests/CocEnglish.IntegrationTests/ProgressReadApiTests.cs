using System.Net;
using System.Net.Http.Headers;
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

public sealed class ProgressReadApiTests
{
    [Fact]
    public async Task Entitlement_HttpReturnsOnlyServerCapabilitiesAndMillisecondDates()
    {
        await using var factory = new ProgressApiFixture();
        factory.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "alice"))] = new()
        { ["userId"] = "alice", ["plan"] = "MAX", ["status"] = "CANCELED", ["source"] = "PURCHASE", ["expiresAt"] = "2026-11-03T10:00:00.001Z", ["autoRenew"] = false, ["revision"] = 2 };
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice-jwt");
        client.DefaultRequestHeaders.Add("X-Appwrite-User-ID", "bob");
        using var response = await client.GetAsync("/v1/me/entitlement");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = (await Body(response)).AsObject();
        Assert.Equal(new[] { "adFree", "asOf", "autoRenew", "conversations", "expiresAt", "familyGroupId", "plan", "revision", "source", "status", "unlimitedEnergy" }, body.Select(p => p.Key).Order(StringComparer.Ordinal));
        Assert.True(body["conversations"]!.GetValue<bool>());
        Assert.True(body["unlimitedEnergy"]!.GetValue<bool>());
        Assert.Equal("2026-11-03T10:00:00.001Z", body["expiresAt"]!.GetValue<string>());
        factory.Now = factory.Now.AddMilliseconds(1);
        using var expired = await client.GetAsync("/v1/me/entitlement");
        Assert.Equal(HttpStatusCode.OK, expired.StatusCode);
        var lapsed = await Body(expired);
        Assert.Equal("FREE", lapsed["plan"]!.GetValue<string>());
        Assert.False(lapsed["conversations"]!.GetValue<bool>());
        Assert.Equal(0, factory.Driver.Commits);
    }
    [Theory]
    [InlineData("/v1/ME")]
    [InlineData("/v1/me/")]
    public async Task Routing_PreservesNodeExactPathRatherThanAspNetCaseOrSlashAliases(string path)
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var response = await client.GetAsync(path);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("NOT_FOUND", (await Body(response))["error"]!["code"]!.GetValue<string>());
        Assert.Empty(factory.Calls);
    }
    [Fact]
    public async Task Preferences_HttpReturnsDefaultWireProjectionWithoutPrivateIdentity()
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var response = await client.GetAsync("/v1/me/preferences");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = (await Body(response)).AsObject();
        Assert.Equal(new[] { "asOf", "friendStreakInvites", "haptics", "listeningExercises", "motivationalMessages", "notificationsOff", "reminderMinute", "revision", "smartScheduling", "soundEffects", "speakingExercises" }, body.Select(p => p.Key).Order(StringComparer.Ordinal));
        Assert.Empty(body["notificationsOff"]!.AsArray());
        Assert.Equal(1200, body["reminderMinute"]!.GetValue<int>());
        Assert.Equal(0, body["revision"]!.GetValue<int>());
        Assert.Equal("2026-11-03T10:00:00.000Z", body["asOf"]!.GetValue<string>());
        Assert.All(factory.Calls, call => Assert.StartsWith("GET ", call));
    }

    [Fact]
    public async Task Quests_HttpPaginatesWithExistingCursorContract()
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var first = await client.GetAsync("/v1/quests?limit=2");
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var page = await Body(first);
        Assert.Equal("eyJvIjoyfQ", page["nextCursor"]!.GetValue<string>());
        Assert.Equal("daily_lessons", page["items"]![0]!["questId"]!.GetValue<string>());
        Assert.Equal("2026-11-03", page["items"]![0]!["periodKey"]!.GetValue<string>());
        Assert.Equal("2026-11-03T10:00:00.000Z", page["asOf"]!.GetValue<string>());
        using var second = await client.GetAsync("/v1/quests?limit=2&cursor=eyJvIjoyfQ");
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);
        var final = await Body(second);
        Assert.Equal("daily_review", final["items"]![0]!["questId"]!.GetValue<string>());
        Assert.Equal(2, final["items"]!.AsArray().Count);
        Assert.Null(final["nextCursor"]);
    }

    [Fact]
    public async Task Me_ReturnsExactProfileWireKeysAndIgnoresForgedUserId()
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        client.DefaultRequestHeaders.Add("X-Appwrite-User-ID", "bob");
        using var response = await client.GetAsync("/v1/me");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = (await Body(response)).AsObject();
        Assert.Equal("alice", body["userId"]!.GetValue<string>());
        Assert.Equal("Alice", body["nickname"]!.GetValue<string>());
        Assert.Equal(new[] { "achievementIds", "avatarId", "dailyGoal", "learningZone", "nickname", "pendingZone", "publicOptIn", "revision", "userId", "zoneEffectiveAt" }, body.Select(p => p.Key).Order(StringComparer.Ordinal).ToArray());
        Assert.Null(body["avatarId"]);
        Assert.Empty(body["achievementIds"]!.AsArray());
        Assert.All(factory.Calls, call => Assert.StartsWith("GET ", call));
    }

    [Fact]
    public async Task Rewards_ReadsAuthoritativeTotalsWithMillisecondUtcTimestamp()
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var response = await client.GetAsync("/v1/me/rewards?completionId=missing-completion");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await Body(response);
        Assert.Equal(18, body["studyXp"]!.GetValue<int>());
        Assert.Equal("pending", body["status"]!.GetValue<string>());
        Assert.Null(body["awardXp"]);
        Assert.Equal("2026-11-03T10:00:00.000Z", body["asOf"]!.GetValue<string>());
    }

    [Fact]
    public async Task Statistics_HttpUsesServerCountsAndFillsMissingDays()
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var response = await client.GetAsync("/v1/me/learning-stats");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await Body(response);
        var days = body["days"]!.AsArray();
        Assert.Equal(28, days.Count);
        Assert.Equal("2026-11-03", days[^1]!["day"]!.GetValue<string>());
        Assert.Equal(8, days[^1]!["trackedOriginalCorrect"]!.GetValue<int>());
        Assert.Equal(13, days[^1]!["trackedOriginalCount"]!.GetValue<int>());
        Assert.Equal(0, days[0]!["studyXp"]!.GetValue<int>());
        Assert.All(factory.Calls, call => Assert.DoesNotContain("POST ", call));
    }

    [Theory]
    [InlineData("/v1/me/learning-stats?userId=bob", "userId")]
    [InlineData("/v1/me/rewards?completionId=a&completionId=b", "completionId")]
    [InlineData("/v1/me/rewards?completionId=bad%2Fid", "completionId")]
    [InlineData("/v1/quests?limit=0", "limit")]
    [InlineData("/v1/quests?limit=101", "limit")]
    [InlineData("/v1/quests?limit=1.0", "limit")]
    [InlineData("/v1/quests?limit=1&limit=2", "limit")]
    [InlineData("/v1/quests?cursor=eyJvIjotMX0", "cursor")]
    [InlineData("/v1/quests?cursor=eyJvIjoxMDAwMDB9", "cursor")]
    [InlineData("/v1/quests?cursor=eyJvIjoiMiJ9", "cursor")]
    [InlineData("/v1/quests?cursor=invalid", "cursor")]
    [InlineData("/v1/quests?cursor=bnVsbA", "cursor")]
    [InlineData("/v1/quests?cursor=eyJvIjoyLjV9", "cursor")]
    public async Task QueryValidation_RejectsBeforeReadingStorage(string path, string field)
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var response = await client.GetAsync(path);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(field, (await Body(response))["error"]!["details"]!["field"]!.GetValue<string>());
        Assert.Empty(factory.Calls);
    }

    private static HttpClient Client(Factory factory)
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "alice-jwt");
        return client;
    }
    private static async Task<JsonNode> Body(HttpResponseMessage response) => JsonNode.Parse(await response.Content.ReadAsStringAsync())!;

    private sealed class Factory : WebApplicationFactory<Progress.Program>
    {
        public List<string> Calls { get; } = [];
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.ConfigureAppConfiguration((_, configuration) => configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1", ["APPWRITE_PROJECT_ID"] = "isolated-test", ["COC_PROGRESS_APPWRITE_KEY"] = "not-a-real-key",
                ["COC_PROGRESS_PERSISTENCE"] = "appwrite", ["COC_PROGRESS_ADMITTED"] = "reviewed-cloud-gate"
            }));
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<IIdentityVerifier>(); services.AddSingleton<IIdentityVerifier, Identity>();
                services.RemoveAll<TimeProvider>(); services.AddSingleton<TimeProvider>(new Clock());
                services.AddHttpClient("appwrite").ConfigurePrimaryHttpMessageHandler(() => new AppwriteHandler(Calls));
            });
        }
    }

    private sealed class Clock : TimeProvider
    { public override DateTimeOffset GetUtcNow() => DateTimeOffset.Parse("2026-11-03T10:00:00Z", global::System.Globalization.CultureInfo.InvariantCulture); }
    private sealed class Identity : IIdentityVerifier
    {
        public bool Configured => true;
        public Task<VerifiedSubject> VerifyAsync(string jwt, CancellationToken cancellationToken) => jwt == "alice-jwt"
            ? Task.FromResult(new VerifiedSubject("alice")) : throw new ServiceException("AUTH_EXPIRED");
    }
    private sealed class AppwriteHandler(List<string> calls) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            calls.Add(request.Method + " " + request.RequestUri!.AbsolutePath);
            Assert.Equal(HttpMethod.Get, request.Method);
            var path = request.RequestUri!.AbsolutePath;
            var status = 200;
            string body;
            if (path.Contains("/p_profiles/rows/", StringComparison.Ordinal))
                body = """{"$id":"profile","userId":"alice","nickname":"Alice","avatarId":null,"dailyGoal":10,"learningZone":"UTC","pendingZone":null,"zoneEffectiveAt":null,"revision":1,"publicOptIn":false,"deletedAt":null}""";
            else if (path.Contains("/p_rewards/rows/", StringComparison.Ordinal))
                body = """{"$id":"rewards","studyXp":18,"gems":20,"currentStreak":0,"revision":1}""";
            else if (path.EndsWith("/rows", StringComparison.Ordinal))
            {
                Assert.Contains("alice", Uri.UnescapeDataString(request.RequestUri.Query));
                body = path.Contains("/p_day_activity/", StringComparison.Ordinal)
                    ? """{"rows":[{"$id":"day","userId":"alice","day":"2026-11-03","studyXp":18,"completedLessons":1,"originalCorrect":8,"trackedOriginalCorrect":8,"trackedOriginalCount":13,"active":true}]}"""
                    : "{\"rows\":[]}";
            }
            else { status = 404; body = "{}"; }
            return Task.FromResult(new HttpResponseMessage((HttpStatusCode)status) { Content = new StringContent(body) });
        }
    }
}
