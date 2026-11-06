using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Learning;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Org.BouncyCastle.Crypto.Parameters;
using Org.BouncyCastle.Crypto.Signers;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LearningRetiredSessionTests
{
    [Fact]
    public async Task GetSession_RecoversBundleFromItsRetainedPublishedContentVersion()
    {
        var secret = new Ed25519PrivateKeyParameters(new byte[32], 0);
        var bundle = Sign(new JsonObject
        {
            ["schemaVersion"] = 1, ["courseId"] = "course", ["courseVersion"] = "v1", ["sectionId"] = "section",
            ["unitId"] = "unit", ["nodeId"] = "node", ["order"] = 1, ["lessonId"] = "legacy-lesson",
            ["lessonVersion"] = "lesson-v1", ["rewardIdentity"] = "legacy-lesson", ["title"] = "Retained lesson",
            ["skillIds"] = new JsonArray(), ["exercises"] = new JsonArray(), ["assets"] = new JsonArray(),
            ["gradingRulesVersion"] = "v1"
        }, secret);
        var bundleText = CanonicalWire.Json(bundle);
        var index = new JsonObject
        {
            ["lessonId"] = "legacy-lesson", ["lessonVersion"] = "lesson-v1", ["rewardIdentity"] = "legacy-lesson",
            ["fileId"] = "bundle-v1", ["sha256"] = CanonicalWire.Sha256(bundleText)
        };
        var v1 = Manifest("course", "v1", new JsonArray(index), secret);
        var v2 = Manifest("course", "v2", new JsonArray(), secret);
        var v1Text = CanonicalWire.Json(v1);
        var v2Text = CanonicalWire.Json(v2);
        var files = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["manifest-v1"] = v1Text,
            ["manifest-v2"] = v2Text,
            ["bundle-v1"] = bundleText
        };
        var downloadedFiles = new List<string>();
        var driver = new Driver();
        driver.Seed("l_courses", CanonicalWire.RowId("course", "course"), new() { ["courseId"] = "course", ["status"] = "PUBLISHED", ["publishedVersion"] = "v2" });
        driver.Seed("l_content_versions", CanonicalWire.RowId("content-version", "course", "v1"), new()
        { ["courseId"] = "course", ["versionId"] = "v1", ["manifestFileId"] = "manifest-v1", ["manifestSha256"] = CanonicalWire.Sha256(v1Text), ["publishedAt"] = "2026-10-01T00:00:00.000Z" });
        driver.Seed("l_content_versions", CanonicalWire.RowId("content-version", "course", "v2"), new()
        { ["courseId"] = "course", ["versionId"] = "v2", ["manifestFileId"] = "manifest-v2", ["manifestSha256"] = CanonicalWire.Sha256(v2Text), ["publishedAt"] = "2026-11-01T00:00:00.000Z" });
        driver.Seed("l_sessions", "session-1", new()
        {
            ["userId"] = "alice", ["courseId"] = "course", ["lessonId"] = "legacy-lesson", ["lessonVersion"] = "lesson-v1",
            ["mode"] = "LESSON", ["status"] = "ACTIVE", ["revision"] = 0, ["nextOriginalOrdinal"] = 0, ["retryPass"] = 0,
            ["expiresAt"] = "2026-11-04T00:00:00.000Z", ["bundleSnapshotJson"] = null, ["resultJson"] = "{}"
        });

        using var app = new WebApplicationFactory<Learning.Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1", ["APPWRITE_PROJECT_ID"] = "test",
                ["COC_LEARNING_APPWRITE_KEY"] = "test-key", ["COC_LEARNING_PERSISTENCE"] = "appwrite",
                ["COC_LEARNING_ADMITTED"] = "reviewed-cloud-gate",
                ["COC_CONTENT_PUBLIC_KEYS"] = "[{\"keyId\":\"test\",\"publicKeyHex\":\"" + Convert.ToHexString(secret.GeneratePublicKey().GetEncoded()) + "\"}]"
            }));
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<IRowDriver>(); services.AddSingleton<IRowDriver>(driver);
                services.RemoveAll<IIdentityVerifier>(); services.AddSingleton<IIdentityVerifier, Identity>();
                services.RemoveAll<TimeProvider>(); services.AddSingleton<TimeProvider>(new FixedClock(DateTimeOffset.Parse("2026-11-03T12:00:00Z")));
                services.AddHttpClient("appwrite").ConfigurePrimaryHttpMessageHandler(() => new StorageHandler(files, downloadedFiles));
            });
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");

        using var response = await client.GetAsync("/v1/sessions/session-1");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var view = (await response.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("legacy-lesson", view["lessonId"]!.GetValue<string>());
        Assert.Equal("ACTIVE", view["status"]!.GetValue<string>());
        Assert.Equal("Retained lesson", view["bundle"]!["title"]!.GetValue<string>());
        Assert.Equal("lesson-v1", view["bundle"]!["lessonVersion"]!.GetValue<string>());
        Assert.Equal(new[] { "manifest-v2", "manifest-v1", "bundle-v1" }, downloadedFiles);
    }

    private static JsonObject Manifest(string course, string version, JsonArray bundles, Ed25519PrivateKeyParameters secret)
    {
        var manifest = new JsonObject
        {
            ["courseId"] = course, ["courseVersion"] = version, ["title"] = version,
            ["bundles"] = bundles, ["nodes"] = new JsonArray(), ["sections"] = new JsonArray()
        };
        manifest["manifestHash"] = LearningIntegrity.StructureHash(manifest);
        return Sign(manifest, secret);
    }

    private static JsonObject Sign(JsonObject document, Ed25519PrivateKeyParameters secret)
    {
        document["signatureKeyId"] = "test";
        var signer = new Ed25519Signer(); signer.Init(true, secret);
        var input = Encoding.UTF8.GetBytes(LearningIntegrity.SigningInput(document));
        signer.BlockUpdate(input, 0, input.Length);
        document["signature"] = Convert.ToBase64String(signer.GenerateSignature()).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        return document;
    }

    private sealed class Identity : IIdentityVerifier
    {
        public bool Configured => true;
        public Task<VerifiedSubject> VerifyAsync(string jwt, CancellationToken ct) => Task.FromResult(new VerifiedSubject(jwt));
    }

    private sealed class FixedClock(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }

    private sealed class StorageHandler(IReadOnlyDictionary<string, string> files, List<string> downloadedFiles) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            var segments = request.RequestUri!.AbsolutePath.Split('/', StringSplitOptions.RemoveEmptyEntries);
            var fileId = Uri.UnescapeDataString(segments[^2]);
            downloadedFiles.Add(fileId);
            var response = files.TryGetValue(fileId, out var text)
                ? new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(text, Encoding.UTF8, "application/json") }
                : new HttpResponseMessage(HttpStatusCode.NotFound);
            return Task.FromResult(response);
        }
    }

    private sealed class Driver : IRowDriver
    {
        private readonly Dictionary<(string Table, string Id), JsonObject> rows = [];
        public string Owner => "learning";
        public bool Configured => true;
        public void Seed(string table, string id, JsonObject row) => rows[(table, id)] = row;
        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken ct) =>
            Task.FromResult(rows.TryGetValue((table, id), out var row) ? new RowDocument(id, row.DeepClone().AsObject(), "v1") : null);
        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken ct)
        {
            IEnumerable<KeyValuePair<(string Table, string Id), JsonObject>> selected = rows.Where(row => row.Key.Table == table);
            foreach (var filter in query.Where ?? new Dictionary<string, object?>())
                selected = selected.Where(row => row.Value[filter.Key]?.ToString() == filter.Value?.ToString());
            foreach (var order in query.OrderBy ?? [])
                selected = order.Descending
                    ? selected.OrderByDescending(row => row.Value[order.Column]?.ToString(), StringComparer.Ordinal)
                    : selected.OrderBy(row => row.Value[order.Column]?.ToString(), StringComparer.Ordinal);
            var result = selected.Skip(query.Offset).Take(query.Limit)
                .Select(row => new RowDocument(row.Key.Id, row.Value.DeepClone().AsObject(), "v1")).ToArray();
            return Task.FromResult<IReadOnlyList<RowDocument>>(result);
        }
        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken ct) => throw new NotSupportedException();
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken ct) => throw new NotSupportedException();
    }
}
