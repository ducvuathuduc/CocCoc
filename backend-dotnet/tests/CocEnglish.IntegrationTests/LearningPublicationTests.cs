using System.Net;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Learning;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Org.BouncyCastle.Crypto.Parameters;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed partial class LearningManifestTests
{
    [Fact]
    public async Task Publish_MatchesNodeResponsesAndOwnerRows()
    {
        var scenarioText = PublicationParityResource("Scenarios");
        var scenario = JsonNode.Parse(scenarioText)!;
        var baseline = JsonNode.Parse(PublicationParityResource("Node"))!;
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());

        var publication = scenario["publication"]!.AsObject();
        var expected = baseline["publicationResults"]!.AsArray();
        var fixture = PublicationFixture.Load();
        var driver = new Driver(empty: true);
        var handler = new PublicationHandler(fixture.Files);
        using var app = CreatePublishingApp(driver, handler,
            DateTimeOffset.Parse(publication["now"]!.GetValue<string>(), System.Globalization.CultureInfo.InvariantCulture));
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "maintainer-1");
        client.DefaultRequestHeaders.Add("X-Request-ID", publication["requestId"]!.GetValue<string>());

        for (var index = 0; index < expected.Count; index++)
        {
            Assert.Equal(index, expected[index]!["index"]!.GetValue<int>());
            if (expected[index]!["kind"]!.GetValue<string>() == "inspect")
            {
                var actualTables = new JsonObject();
                foreach (var table in new[] { "l_courses", "l_content_versions", "l_receipts" })
                    actualTables[table] = new JsonArray(driver.Rows
                        .Where(pair => pair.Key.Item1 == table)
                        .OrderBy(pair => pair.Key.Item2, StringComparer.Ordinal)
                        .Select(pair => PublicationParityRow(pair.Key.Item1, pair.Key.Item2, pair.Value)).ToArray());
                Assert.True(JsonNode.DeepEquals(expected[index]!["tables"], actualTables),
                    $"publication persisted rows differ: expected {expected[index]!["tables"]}, actual {actualTables}");
                continue;
            }

            var key = index == 2
                ? publication["duplicateKey"]!.GetValue<string>()
                : publication["publishKey"]!.GetValue<string>();
            if (client.DefaultRequestHeaders.Contains("Idempotency-Key"))
                client.DefaultRequestHeaders.Remove("Idempotency-Key");
            client.DefaultRequestHeaders.Add("Idempotency-Key", key);
            using var response = await client.PostAsJsonAsync("/v1/admin/content-versions", fixture.Request(index == 2 ? "v2" : null));
            var actualBody = JsonNode.Parse(await response.Content.ReadAsStringAsync());
            Assert.Equal(expected[index]!["status"]!.GetValue<int>(), (int)response.StatusCode);
            Assert.True(JsonNode.DeepEquals(expected[index]!["body"], actualBody),
                $"publication step {index}: expected {expected[index]!["body"]}, actual {actualBody}");
        }
    }

    [Fact]
    public async Task Publish_VerifiesCommittedSignedCourseAndAtomicallyReplaysImmutableVersion()
    {
        var fixture = PublicationFixture.Load();
        var driver = new Driver();
        var handler = new PublicationHandler(fixture.Files);
        using var app = CreatePublishingApp(driver, handler);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");

        var body = fixture.Request("v1");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "d0cc93ad-f62f-45de-bdea-16cb6e060543");
        using var first = await client.PostAsJsonAsync("/v1/admin/content-versions", body);
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var response = (await first.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("accepted", response["status"]!.GetValue<string>());
        Assert.Equal("d0cc93ad-f62f-45de-bdea-16cb6e060543", response["operationId"]!.GetValue<string>());
        var versionId = CanonicalWire.RowId("content-version", "vi_en", "v2");
        var version = driver.Rows[("l_content_versions", versionId)];
        Assert.Equal("vi_en.v2.manifest", version["manifestFileId"]!.GetValue<string>());
        Assert.Equal("v2", driver.Rows[("l_courses", CanonicalWire.RowId("course", "vi_en"))]["publishedVersion"]!.GetValue<string>());
        Assert.True(handler.Requests > 1, "publication must read and verify every signed bundle");

        var commits = driver.Commits;
        using var replay = await client.PostAsJsonAsync("/v1/admin/content-versions", body);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.Equal(response.ToJsonString(), (await replay.Content.ReadFromJsonAsync<JsonObject>())!.ToJsonString());
        Assert.Equal(commits, driver.Commits);

        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "e0cc93ad-f62f-45de-bdea-16cb6e060543");
        using var duplicate = await client.PostAsJsonAsync("/v1/admin/content-versions", fixture.Request("v2"));
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);
        var duplicateError = (await duplicate.Content.ReadFromJsonAsync<JsonObject>())!["error"]!;
        Assert.Equal("REVISION_CONFLICT", duplicateError["code"]!.GetValue<string>());
        Assert.Equal("VERSION_EXISTS", duplicateError["details"]!["reason"]!.GetValue<string>());
        Assert.Equal(commits, driver.Commits);
    }

    [Fact]
    public async Task Publish_DeniesNonMaintainerAndRefusesTamperingOrMissingBundleWithoutPointerWrites()
    {
        var fixture = PublicationFixture.Load();
        var driver = new Driver();
        var handler = new PublicationHandler(fixture.Files);
        using var app = CreatePublishingApp(driver, handler);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "bob");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "a0cc93ad-f62f-45de-bdea-16cb6e060543");

        using var denied = await client.PostAsJsonAsync("/v1/admin/content-versions", fixture.Request("v1"));
        Assert.Equal(HttpStatusCode.Forbidden, denied.StatusCode);
        Assert.Equal("MAINTAINER_REQUIRED", (await denied.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
        Assert.Equal(0, handler.Requests);
        Assert.Equal(0, driver.Commits);

        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        var firstBundle = fixture.Files.Keys.First(fileId => fileId != fixture.ManifestFileId);
        handler.Files.Remove(firstBundle);
        using var missing = await client.PostAsJsonAsync("/v1/admin/content-versions", fixture.Request("v1"));
        Assert.Equal(HttpStatusCode.BadRequest, missing.StatusCode);
        var missingError = (await missing.Content.ReadFromJsonAsync<JsonObject>())!["error"]!;
        Assert.Equal("VALIDATION_ERROR", missingError["code"]!.GetValue<string>());
        Assert.True(missingError["details"]!["problemCount"]!.GetValue<int>() > 0);
        Assert.DoesNotContain(driver.Rows, row => row.Key.Item1 is "l_courses" or "l_content_versions");
        Assert.Equal(0, driver.Commits);
    }

    private static WebApplicationFactory<Learning.Program> CreatePublishingApp(Driver driver, PublicationHandler handler, DateTimeOffset? now = null)
    {
        var seed = SHA256.HashData(Encoding.UTF8.GetBytes("cocenglish-dev-only:content-signing"));
        var publicKeyHex = Convert.ToHexString(new Ed25519PrivateKeyParameters(seed, 0).GeneratePublicKey().GetEncoded());
        return new WebApplicationFactory<Learning.Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1",
                ["APPWRITE_PROJECT_ID"] = "test",
                ["COC_LEARNING_APPWRITE_KEY"] = "test-key",
                ["COC_LEARNING_PERSISTENCE"] = "appwrite",
                ["COC_LEARNING_ADMITTED"] = "reviewed-cloud-gate",
                ["COC_MAINTAINER_USER_IDS"] = "alice,maintainer-1",
                ["COC_CONTENT_PUBLIC_KEYS"] = "[{\"keyId\":\"dev-content-1\",\"publicKeyHex\":\"" + publicKeyHex + "\"}]"
            }));
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<IRowDriver>();
                services.AddSingleton<IRowDriver>(driver);
                services.RemoveAll<IIdentityVerifier>();
                services.AddSingleton<IIdentityVerifier, Identity>();
                services.RemoveAll<LearningStorageFiles>();
                services.AddSingleton(new LearningStorageFiles(new HttpClient(handler), new(new Uri("https://appwrite.test/v1"), "test", "test-key")));
                services.RemoveAll<TimeProvider>();
                services.AddSingleton<TimeProvider>(new Clock(now ?? DateTimeOffset.UtcNow));
            });
        });
    }

    private static string PublicationParityResource(string name)
    {
        using var stream = typeof(LearningManifestTests).Assembly.GetManifestResourceStream($"CocEnglish.Learning.Parity.{name}.json")!;
        using var reader = new StreamReader(stream, Encoding.UTF8);
        return reader.ReadToEnd();
    }

    private static JsonObject PublicationParityRow(string table, string id, JsonObject data)
    {
        var row = data.DeepClone().AsObject();
        foreach (var key in row.Select(pair => pair.Key).ToArray())
            if (key.EndsWith("Json", StringComparison.Ordinal) && row.Text(key) is { } json)
                row[key] = JsonNode.Parse(json);
        return new JsonObject { ["id"] = id, ["row"] = row };
    }

    private sealed class PublicationHandler(IReadOnlyDictionary<string, string> initial) : HttpMessageHandler
    {
        public Dictionary<string, string> Files { get; } = initial.ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.Ordinal);
        public int Requests { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Requests++;
            var segments = request.RequestUri!.AbsolutePath.Split('/', StringSplitOptions.RemoveEmptyEntries);
            var fileIndex = Array.LastIndexOf(segments, "files");
            var fileId = fileIndex >= 0 && fileIndex + 1 < segments.Length ? Uri.UnescapeDataString(segments[fileIndex + 1]) : "";
            if (!Files.TryGetValue(fileId, out var text)) return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(text, Encoding.UTF8, "application/json") });
        }
    }

    private sealed record PublicationFixture(string ManifestFileId, IReadOnlyDictionary<string, string> Files)
    {
        public static PublicationFixture Load()
        {
            var directory = new DirectoryInfo(AppContext.BaseDirectory);
            while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "content", "vi_en", "dist", "v2", "publish.json"))) directory = directory.Parent;
            if (directory is null) throw new DirectoryNotFoundException("Could not locate committed content fixture from test output directory.");
            var contentRoot = Path.Combine(directory.FullName, "content", "vi_en", "dist", "v2");
            var publish = JsonNode.Parse(File.ReadAllText(Path.Combine(contentRoot, "publish.json")))!.AsObject();
            var files = new Dictionary<string, string>(StringComparer.Ordinal);
            foreach (var file in publish["files"]!.AsArray().OfType<JsonObject>())
            {
                var fileId = file["fileId"]!.GetValue<string>();
                var relativePath = file["path"]!.GetValue<string>().Replace('/', Path.DirectorySeparatorChar);
                files[fileId] = File.ReadAllText(Path.Combine(contentRoot, relativePath));
            }
            return new(publish["manifestFileId"]!.GetValue<string>(), files);
        }

        public object Request(string? expectedPublishedVersion) => new
        {
            courseId = "vi_en",
            versionId = "v2",
            manifestFileId = ManifestFileId,
            manifestSha256 = CanonicalWire.Sha256(Files[ManifestFileId]),
            expectedPublishedVersion
        };
    }
}
