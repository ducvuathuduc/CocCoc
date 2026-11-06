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

public sealed partial class LearningManifestTests
{
    [Fact]
    public async Task EnergyEvent_RequiresProgressSignatureAndDeduplicates()
    {
        var driver = new Driver(); var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        using var app = new WebApplicationFactory<Learning.Program>().WithWebHostBuilder(builder => {
            builder.ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(new Dictionary<string, string?> { ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"key\",\"sender\":\"progress\",\"secretHex\":\"" + new string('9', 64) + "\"}]" }));
            builder.ConfigureServices(s => { s.RemoveAll<IRowDriver>(); s.AddSingleton<IRowDriver>(driver); s.RemoveAll<TimeProvider>(); s.AddSingleton<TimeProvider>(new Clock(now)); });
        });
        using var client = app.CreateClient();
        var envelope = new JsonObject { ["eventId"] = "11111111-1111-4111-8111-111111111111", ["type"] = "energy.granted.v1", ["schemaVersion"] = 1,
            ["producer"] = "progress", ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(now), ["requestId"] = "trace",
            ["payload"] = new JsonObject { ["operationId"] = "operation", ["userId"] = "alice", ["amount"] = 1, ["refillToCapacity"] = false, ["reason"] = "SHOP" } };
        async Task<HttpResponseMessage> Send(JsonObject data)
        {
            var raw = data.ToJsonString(); var signature = ServiceHmac.Sign(new("key", "progress", Convert.FromHexString(new string('9', 64))), "POST", "/internal/events", "", new HashSet<string>(), raw, now.ToUnixTimeSeconds());
            using var request = new HttpRequestMessage(HttpMethod.Post, "/internal/events") { Content = new StringContent(raw, Encoding.UTF8, "application/json") };
            request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
            return await client.SendAsync(request);
        }
        using var first = await Send(envelope); Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        using var replay = await Send(envelope); Assert.Equal("replayed", (await replay.Content.ReadFromJsonAsync<JsonObject>())!["status"]!.GetValue<string>()); Assert.Equal(1, driver.Commits);
        envelope["payload"]!["amount"] = 2;
        using var conflict = await Send(envelope); Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
    }

    [Fact]
    public async Task AccountDeletionEvent_PurgesOwnedRowsAndStagesOneAcknowledgement()
    {
        var driver = new Driver(); var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var relay = new Relay();
        driver.Seed("l_answers", "answer-alice", new() { ["userId"] = "alice" });
        driver.Seed("l_answers", "answer-bob", new() { ["userId"] = "bob" });
        driver.Seed("l_energy", CanonicalWire.RowId("energy", "alice"), new() { ["userId"] = "alice" });
        using var app = new WebApplicationFactory<Learning.Program>().WithWebHostBuilder(builder => {
            builder.ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(new Dictionary<string, string?> { ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"key\",\"sender\":\"progress\",\"secretHex\":\"" + new string('9', 64) + "\"}]" }));
            builder.ConfigureServices(s => { s.RemoveAll<IRowDriver>(); s.AddSingleton<IRowDriver>(driver); s.RemoveAll<TimeProvider>(); s.AddSingleton<TimeProvider>(new Clock(now)); s.RemoveAll<ILearningRelayTransport>(); s.AddSingleton<ILearningRelayTransport>(relay); });
        });
        using var client = app.CreateClient();
        var envelope = new JsonObject { ["eventId"] = "22222222-2222-4222-8222-222222222222", ["type"] = "account.deleted.v1", ["schemaVersion"] = 1,
            ["producer"] = "progress", ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(now), ["requestId"] = "trace",
            ["payload"] = new JsonObject { ["userId"] = "alice", ["requestId"] = "33333333-3333-4333-8333-333333333333" } };
        async Task<HttpResponseMessage> Send(JsonObject data)
        {
            var raw = data.ToJsonString(); var signature = ServiceHmac.Sign(new("key", "progress", Convert.FromHexString(new string('9', 64))), "POST", "/internal/events", "", new HashSet<string>(), raw, now.ToUnixTimeSeconds());
            using var request = new HttpRequestMessage(HttpMethod.Post, "/internal/events") { Content = new StringContent(raw, Encoding.UTF8, "application/json") };
            request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
            return await client.SendAsync(request);
        }

        using var accepted = await Send(envelope);
        Assert.Equal(HttpStatusCode.OK, accepted.StatusCode);
        Assert.Equal("accepted", (await accepted.Content.ReadFromJsonAsync<JsonObject>())!["status"]!.GetValue<string>());
        Assert.Null(await driver.ReadAsync("l_answers", "answer-alice", CancellationToken.None));
        Assert.NotNull(await driver.ReadAsync("l_answers", "answer-bob", CancellationToken.None));
        Assert.Null(await driver.ReadAsync("l_energy", CanonicalWire.RowId("energy", "alice"), CancellationToken.None));
        var ack = Assert.Single(driver.Rows, r => r.Key.Item1 == "l_outbox").Value;
        Assert.Equal("account.purged.v1", ack["type"]!.GetValue<string>());
        var ackEvent = JsonNode.Parse(ack["payloadJson"]!.GetValue<string>())!.AsObject();
        Assert.Equal("learning", ackEvent["producer"]!.GetValue<string>());
        Assert.Equal("alice", ackEvent["payload"]!["userId"]!.GetValue<string>());
        Assert.Equal("account.purged.v1", relay.Delivered.Single()["type"]!.GetValue<string>());
        var ackEventId = relay.Delivered.Single()["eventId"]!.GetValue<string>();
        Assert.Equal("ACK", (await driver.ReadAsync("l_outbox", ackEventId, CancellationToken.None))!.Data["status"]!.GetValue<string>());

        var commits = driver.Commits;
        using var replay = await Send(envelope);
        Assert.Equal("replayed", (await replay.Content.ReadFromJsonAsync<JsonObject>())!["status"]!.GetValue<string>());
        Assert.Equal(commits, driver.Commits);
        Assert.Single(relay.Delivered);
        Assert.Single(driver.Rows, r => r.Key.Item1 == "l_outbox");

        envelope["payload"]!["requestId"] = "44444444-4444-4444-8444-444444444444";
        using var conflict = await Send(envelope);
        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
        Assert.NotNull(await driver.ReadAsync("l_answers", "answer-bob", CancellationToken.None));
    }

    private sealed class Clock(DateTimeOffset now) : TimeProvider { public override DateTimeOffset GetUtcNow() => now; }
    private sealed class Relay : ILearningRelayTransport
    {
        public bool Configured => true;
        public List<JsonObject> Delivered { get; } = [];
        public Task<LearningRelayOutcome> DeliverAsync(JsonObject envelope, CancellationToken ct)
        { Delivered.Add(envelope.DeepClone().AsObject()); return Task.FromResult(LearningRelayOutcome.Ack); }
    }
    [Fact]
    public async Task Manifest_UsesPublishedVersionAndRejectsAlteredFiles()
    {
        var secret = new Ed25519PrivateKeyParameters(new byte[32], 0);
        var bundle = new JsonObject { ["schemaVersion"] = 1, ["courseId"] = "vi_en", ["courseVersion"] = "v1", ["sectionId"] = "s1", ["unitId"] = "u1", ["nodeId"] = "n1", ["order"] = 1,
            ["lessonId"] = "lesson1", ["lessonVersion"] = "l1", ["rewardIdentity"] = "lesson1", ["title"] = "Hello", ["skillIds"] = new JsonArray(),
            ["exercises"] = new JsonArray(new JsonObject { ["id"] = "ex1", ["type"] = "choice", ["prompt"] = new JsonObject { ["text"] = "Hello?", ["locale"] = "en-US" },
                ["content"] = new JsonObject { ["choices"] = new JsonArray(new JsonObject { ["id"] = "yes", ["text"] = "hello" }, new JsonObject { ["id"] = "no", ["text"] = "goodbye" }) },
                ["gradingRule"] = new JsonObject { ["caseSensitive"] = false, ["ignorePunctuation"] = false, ["ignoreDiacritics"] = false, ["correctChoiceId"] = "yes" },
                ["hint"] = "", ["explanation"] = "Correct", ["skillIds"] = new JsonArray(), ["vocabularyIds"] = new JsonArray() }), ["assets"] = new JsonArray(), ["gradingRulesVersion"] = "v1" };
        var bundleSigner = new Ed25519Signer(); bundleSigner.Init(true, secret);
        var bundleInput = Encoding.UTF8.GetBytes(LearningIntegrity.SigningInput(bundle)); bundleSigner.BlockUpdate(bundleInput, 0, bundleInput.Length);
        bundle["signature"] = Convert.ToBase64String(bundleSigner.GenerateSignature()).TrimEnd('=').Replace('+', '-').Replace('/', '_'); bundle["signatureKeyId"] = "key";
        var bundleText = CanonicalWire.Json(bundle);
        var index = new JsonObject { ["lessonId"] = "lesson1", ["lessonVersion"] = "l1", ["rewardIdentity"] = "lesson1", ["fileId"] = "bundle", ["sha256"] = CanonicalWire.Sha256(bundleText) };
        var manifest = new JsonObject { ["courseId"] = "vi_en", ["courseVersion"] = "v1", ["title"] = "Tiếng Việt", ["bundles"] = new JsonArray(index), ["nodes"] = new JsonArray(new JsonObject { ["nodeId"] = "n2", ["unitId"] = "u1", ["order"] = 3, ["lessonIds"] = new JsonArray("l2") }, new JsonObject { ["nodeId"] = "n1", ["unitId"] = "u1", ["order"] = 2, ["lessonIds"] = new JsonArray("lesson1") }), ["sections"] = new JsonArray() };
        manifest["manifestHash"] = LearningIntegrity.StructureHash(manifest);
        var signer = new Ed25519Signer(); signer.Init(true, secret);
        var input = Encoding.UTF8.GetBytes(LearningIntegrity.SigningInput(manifest)); signer.BlockUpdate(input, 0, input.Length);
        manifest["signature"] = Convert.ToBase64String(signer.GenerateSignature()).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        manifest["signatureKeyId"] = "key";
        var content = CanonicalWire.Json(manifest);
        var driver = new Driver { Hash = CanonicalWire.Sha256(content) };
        var handler = new Handler { Content = content, Bundle = bundleText };
        using var app = new WebApplicationFactory<Learning.Program>().WithWebHostBuilder(builder => {
            builder.ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(new Dictionary<string, string?> {
                ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1", ["APPWRITE_PROJECT_ID"] = "test", ["COC_LEARNING_APPWRITE_KEY"] = "test",
                ["COC_LEARNING_PERSISTENCE"] = "appwrite", ["COC_LEARNING_ADMITTED"] = "reviewed-cloud-gate",
                ["COC_CONTENT_PUBLIC_KEYS"] = "[{\"keyId\":\"key\",\"publicKeyHex\":\"" + Convert.ToHexString(secret.GeneratePublicKey().GetEncoded()) + "\"}]" }));
            builder.ConfigureServices(s => {
                s.RemoveAll<IRowDriver>(); s.AddSingleton<IRowDriver>(driver);
                s.RemoveAll<IIdentityVerifier>(); s.AddSingleton<IIdentityVerifier, Identity>();
                s.RemoveAll<LearningStorageFiles>(); s.AddSingleton(new LearningStorageFiles(new HttpClient(handler), new(new("https://appwrite.test/v1"), "test", "test")));
            });
        });
        using var client = app.CreateClient(); client.DefaultRequestHeaders.Add("Authorization", "Bearer token");
        var result = await client.GetFromJsonAsync<JsonObject>("/v1/courses/vi_en/manifest");
        Assert.Equal("Tiếng Việt", result!["title"]!.GetValue<string>());
        client.DefaultRequestHeaders.Add("Idempotency-Key", "D0CC93AD-F62F-45DE-BDEA-16CB6E060543");
        var enrolled = await client.PostAsJsonAsync("/v1/enrollments", new { courseId = "vi_en", startPoint = "beginner" });
        Assert.Equal(HttpStatusCode.OK, enrolled.StatusCode);
        Assert.Equal(2, (await enrolled.Content.ReadFromJsonAsync<JsonObject>())!["frontierNodeOrder"]!.GetValue<int>());
        var replay = await client.PostAsJsonAsync("/v1/enrollments", new { courseId = "vi_en", startPoint = "beginner", placementSessionId = (string?)null });
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode); Assert.Equal(1, driver.Commits);
        var conflict = await client.PostAsJsonAsync("/v1/enrollments", new { courseId = "vi_en", startPoint = "placement" });
        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode); Assert.Equal(1, driver.Commits);
        client.DefaultRequestHeaders.Remove("Idempotency-Key"); client.DefaultRequestHeaders.Add("Idempotency-Key", "e0cc93ad-f62f-45de-bdea-16cb6e060543");
        var started = await client.PostAsJsonAsync("/v1/sessions", new { courseId = "vi_en", lessonId = "lesson1", mode = "LESSON", expectedEnrollmentRevision = 0 });
        var startBody = await started.Content.ReadAsStringAsync();
        Assert.True(started.StatusCode == HttpStatusCode.OK, startBody);
        var session = (await started.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("lesson1", session["lessonId"]!.GetValue<string>());
        Assert.Equal("ACTIVE", session["status"]!.GetValue<string>());
        Assert.Equal("ex1", session["bundle"]!["exercises"]![0]!["id"]!.GetValue<string>());
        var sessionId = session["sessionId"]!.GetValue<string>();
        client.DefaultRequestHeaders.Remove("Idempotency-Key"); client.DefaultRequestHeaders.Add("Idempotency-Key", "a1cc93ad-f62f-45de-bdea-16cb6e060543");
        var answerBody = new { exerciseId = "ex1", attemptOrdinal = 0, answer = new { kind = "choice", choiceId = "no" }, assisted = false, substituted = false, expectedRevision = 0 };
        var answer = await client.PostAsJsonAsync($"/v1/sessions/{sessionId}/answers", answerBody);
        Assert.Equal(HttpStatusCode.OK, answer.StatusCode);
        var feedback = (await answer.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.False(feedback["correct"]!.GetValue<bool>());
        Assert.Equal(1, feedback["nextOriginalOrdinal"]!.GetValue<int>());
        Assert.Equal(1, feedback["retryPass"]!.GetValue<int>());
        Assert.Equal(1, feedback["sessionRevision"]!.GetValue<int>());
        var answerReplay = await client.PostAsJsonAsync($"/v1/sessions/{sessionId}/answers", answerBody);
        Assert.Equal(HttpStatusCode.OK, answerReplay.StatusCode);
        var changedAnswer = await client.PostAsJsonAsync($"/v1/sessions/{sessionId}/answers", new { exerciseId = "ex1", attemptOrdinal = 0, answer = new { kind = "choice", choiceId = "yes" }, assisted = false, substituted = false, expectedRevision = 0 });
        Assert.Equal(HttpStatusCode.Conflict, changedAnswer.StatusCode);
        client.DefaultRequestHeaders.Remove("Idempotency-Key"); client.DefaultRequestHeaders.Add("Idempotency-Key", "b1cc93ad-f62f-45de-bdea-16cb6e060543");
        var retryAnswerBody = new { exerciseId = "ex1", attemptOrdinal = 1, answer = new { kind = "choice", choiceId = "yes" }, assisted = false, substituted = false, expectedRevision = 1 };
        var retryAnswer = await client.PostAsJsonAsync($"/v1/sessions/{sessionId}/answers", retryAnswerBody);
        Assert.Equal(HttpStatusCode.OK, retryAnswer.StatusCode);
        var retriedFeedback = (await retryAnswer.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.True(retriedFeedback["correct"]!.GetValue<bool>());
        Assert.Equal(2, retriedFeedback["sessionRevision"]!.GetValue<int>());
        var commitsAfterAnswer = driver.Commits;
        var retryReplay = await client.PostAsJsonAsync($"/v1/sessions/{sessionId}/answers", retryAnswerBody);
        Assert.Equal(HttpStatusCode.OK, retryReplay.StatusCode);
        Assert.Equal(commitsAfterAnswer, driver.Commits);
        client.DefaultRequestHeaders.Remove("Idempotency-Key"); client.DefaultRequestHeaders.Add("Idempotency-Key", "b1cc93ad-f62f-45de-bdea-16cb6e060543");
        var resumed = await client.GetFromJsonAsync<JsonObject>($"/v1/sessions/{sessionId}");
        Assert.Equal(sessionId, resumed!["sessionId"]!.GetValue<string>());
        Assert.Collection(resumed["answerHistory"]!.AsArray(), first => Assert.Equal("no", first!["answer"]!["choiceId"]!.GetValue<string>()),
            second => Assert.Equal("yes", second!["answer"]!["choiceId"]!.GetValue<string>()));
        Assert.True(resumed["lastFeedback"]!["correct"]!.GetValue<bool>());
        client.DefaultRequestHeaders.Remove("Idempotency-Key"); client.DefaultRequestHeaders.Add("Idempotency-Key", "f0cc93ad-f62f-45de-bdea-16cb6e060543");
        var competing = await client.PostAsJsonAsync("/v1/sessions", new { courseId = "vi_en", lessonId = "lesson1", mode = "LESSON", expectedEnrollmentRevision = 0 });
        Assert.Equal(HttpStatusCode.Conflict, competing.StatusCode);
        Assert.Equal("SESSION_CONFLICT", (await competing.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
        Assert.Equal(commitsAfterAnswer, driver.Commits);
        client.DefaultRequestHeaders.Remove("Authorization"); client.DefaultRequestHeaders.Add("Authorization", "Bearer bob");
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/v1/sessions/{sessionId}")).StatusCode);
        client.DefaultRequestHeaders.Remove("Authorization"); client.DefaultRequestHeaders.Add("Authorization", "Bearer token");
        client.DefaultRequestHeaders.Remove("Idempotency-Key"); client.DefaultRequestHeaders.Add("Idempotency-Key", "e0cc93ad-f62f-45de-bdea-16cb6e060543");
        var startReplay = await client.PostAsJsonAsync("/v1/sessions", new { courseId = "vi_en", lessonId = "lesson1", mode = "LESSON", expectedEnrollmentRevision = 0 });
        Assert.Equal(HttpStatusCode.OK, startReplay.StatusCode);
        Assert.Equal(sessionId, (await startReplay.Content.ReadFromJsonAsync<JsonObject>())!["sessionId"]!.GetValue<string>());
        Assert.Equal(commitsAfterAnswer, driver.Commits);
        client.DefaultRequestHeaders.Remove("Authorization"); client.DefaultRequestHeaders.Add("Authorization", "Bearer bob");
        using var foreignAbandon = await client.PostAsJsonAsync($"/v1/sessions/{sessionId}/abandon", new { expectedRevision = 2 });
        Assert.Equal(HttpStatusCode.NotFound, foreignAbandon.StatusCode);
        client.DefaultRequestHeaders.Remove("Authorization"); client.DefaultRequestHeaders.Add("Authorization", "Bearer token");
        client.DefaultRequestHeaders.Remove("Idempotency-Key"); client.DefaultRequestHeaders.Add("Idempotency-Key", "c1cc93ad-f62f-45de-bdea-16cb6e060543");
        using var staleAbandon = await client.PostAsJsonAsync($"/v1/sessions/{sessionId}/abandon", new { expectedRevision = 1 });
        Assert.Equal(HttpStatusCode.Conflict, staleAbandon.StatusCode);
        Assert.Equal("REVISION_CONFLICT", (await staleAbandon.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
        var abandonBody = new { expectedRevision = 2 };
        using var abandoned = await client.PostAsJsonAsync($"/v1/sessions/{sessionId}/abandon", abandonBody);
        Assert.Equal(HttpStatusCode.OK, abandoned.StatusCode);
        Assert.Equal("accepted", (await abandoned.Content.ReadFromJsonAsync<JsonObject>())!["status"]!.GetValue<string>());
        var abandonedRow = (await driver.ReadAsync("l_sessions", sessionId, CancellationToken.None))!.Data;
        Assert.Equal("ABANDONED", abandonedRow["status"]!.GetValue<string>());
        Assert.Equal(3L, abandonedRow["revision"]!.GetValue<long>());
        var activeSlotId = CanonicalWire.RowId("slot", "alice", "vi_en");
        Assert.Null(await driver.ReadAsync("l_active_slots", activeSlotId, CancellationToken.None));
        var commitsAfterAbandon = driver.Commits;
        using var sameKeyReplay = await client.PostAsJsonAsync($"/v1/sessions/{sessionId}/abandon", abandonBody);
        Assert.Equal(HttpStatusCode.OK, sameKeyReplay.StatusCode);
        Assert.Equal("accepted", (await sameKeyReplay.Content.ReadFromJsonAsync<JsonObject>())!["status"]!.GetValue<string>());
        Assert.Equal(commitsAfterAbandon, driver.Commits);
        client.DefaultRequestHeaders.Remove("Idempotency-Key"); client.DefaultRequestHeaders.Add("Idempotency-Key", "d1cc93ad-f62f-45de-bdea-16cb6e060543");
        using var newKeyReplay = await client.PostAsJsonAsync($"/v1/sessions/{sessionId}/abandon", abandonBody);
        Assert.Equal("replayed", (await newKeyReplay.Content.ReadFromJsonAsync<JsonObject>())!["status"]!.GetValue<string>());
        Assert.Equal("ABANDONED", (await driver.ReadAsync("l_sessions", sessionId, CancellationToken.None))!.Data["status"]!.GetValue<string>());
        var path = await client.GetFromJsonAsync<JsonObject>("/v1/courses/vi_en/path?limit=1");
        Assert.Equal("n1", path!["nodes"]![0]!["nodeId"]!.GetValue<string>()); Assert.Equal("available", path["nodes"]![0]!["state"]!.GetValue<string>());
        Assert.Equal("bzox", path["nextCursor"]!.GetValue<string>());
        var nextPath = await client.GetFromJsonAsync<JsonObject>("/v1/courses/vi_en/path?limit=1&cursor=bzox");
        Assert.Equal("locked", nextPath!["nodes"]![0]!["state"]!.GetValue<string>()); Assert.Null(nextPath["nextCursor"]);
        client.DefaultRequestHeaders.Remove("Idempotency-Key"); client.DefaultRequestHeaders.Add("Idempotency-Key", "a0cc93ad-f62f-45de-bdea-16cb6e060543");
        var reset = await client.PostAsJsonAsync("/v1/enrollments/vi_en/reset", new { expectedRevision = 0 });
        Assert.Equal(HttpStatusCode.OK, reset.StatusCode); Assert.Equal(1, (await reset.Content.ReadFromJsonAsync<JsonObject>())!["revision"]!.GetValue<int>());
        var resetReplay = await client.PostAsJsonAsync("/v1/enrollments/vi_en/reset", new { expectedRevision = 0 });
        Assert.Equal(HttpStatusCode.OK, resetReplay.StatusCode); Assert.Equal(7, driver.Commits);
        client.DefaultRequestHeaders.Remove("Idempotency-Key"); client.DefaultRequestHeaders.Add("Idempotency-Key", "b0cc93ad-f62f-45de-bdea-16cb6e060543");
        using var switched = await client.PostAsJsonAsync("/v1/enrollments/vi_en/activate", new { expectedRevision = 1 });
        Assert.Equal(HttpStatusCode.OK, switched.StatusCode);
        var switchedBody = (await switched.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal(2, switchedBody["revision"]!.GetValue<int>());
        var afterSwitch = driver.Commits;
        using var switchReplay = await client.PostAsJsonAsync("/v1/enrollments/vi_en/activate", new { expectedRevision = 1 });
        Assert.Equal(HttpStatusCode.OK, switchReplay.StatusCode);
        Assert.Equal(switchedBody.ToJsonString(), (await switchReplay.Content.ReadFromJsonAsync<JsonObject>())!.ToJsonString());
        Assert.Equal(afterSwitch, driver.Commits);
        client.DefaultRequestHeaders.Remove("Idempotency-Key"); client.DefaultRequestHeaders.Add("Idempotency-Key", "b1cc93ad-f62f-45de-bdea-16cb6e060543");
        Assert.Equal(HttpStatusCode.Conflict, (await client.PostAsJsonAsync("/v1/enrollments/vi_en/activate", new { expectedRevision = 1 })).StatusCode);
        client.DefaultRequestHeaders.Remove("Idempotency-Key"); client.DefaultRequestHeaders.Add("Idempotency-Key", "c0cc93ad-f62f-45de-bdea-16cb6e060543");
        using var removed = await client.DeleteAsync("/v1/enrollments/vi_en");
        Assert.Equal(HttpStatusCode.OK, removed.StatusCode);
        var removedBody = (await removed.Content.ReadFromJsonAsync<JsonObject>())!;
        var afterRemove = driver.Commits;
        using var removeReplay = await client.DeleteAsync("/v1/enrollments/vi_en");
        Assert.Equal(HttpStatusCode.OK, removeReplay.StatusCode);
        Assert.Equal(removedBody.ToJsonString(), (await removeReplay.Content.ReadFromJsonAsync<JsonObject>())!.ToJsonString());
        Assert.Equal(afterRemove, driver.Commits);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/v1/courses/vi_en/path")).StatusCode);
        var lesson = await client.GetFromJsonAsync<JsonObject>("/v1/lessons/lesson1/bundle");
        Assert.Equal("Hello", lesson!["title"]!.GetValue<string>());
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/v1/lessons/unknown/bundle")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/v1/lessons/lesson1/bundle?version=v2")).StatusCode);
        handler.Bundle = bundleText.Replace("Hello", "Altered");
        var badBundle = await client.GetAsync("/v1/lessons/lesson1/bundle");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, badBundle.StatusCode);
        Assert.Equal("BUNDLE_HASH_MISMATCH", (await badBundle.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["details"]!["reason"]!.GetValue<string>());
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/v1/courses/vi_en/manifest?version=v2")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/v1/courses/vi_en/manifest?version=invalid%20version")).StatusCode);
        handler.Content = content.Replace("Tiếng Việt", "changed");
        var badHash = await client.GetAsync("/v1/courses/vi_en/manifest");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, badHash.StatusCode);
        Assert.Equal("MANIFEST_HASH_MISMATCH", (await badHash.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["details"]!["reason"]!.GetValue<string>());
        driver.Hash = CanonicalWire.Sha256(handler.Content);
        var badSignature = await client.GetAsync("/v1/courses/vi_en/manifest");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, badSignature.StatusCode);
        Assert.Equal("MANIFEST_SIGNATURE_INVALID", (await badSignature.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["details"]!["reason"]!.GetValue<string>());
    }

    private sealed class Handler : HttpMessageHandler
    {
        public required string Content { get; set; }
        public required string Bundle { get; set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) =>
            Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(request.RequestUri!.AbsolutePath.Contains("/bundle/", StringComparison.Ordinal) ? Bundle : Content, Encoding.UTF8, "application/json") });
    }
    private sealed class Identity : IIdentityVerifier
    {
        public bool Configured => true;
        public Task<VerifiedSubject> VerifyAsync(string jwt, CancellationToken ct) => Task.FromResult(new VerifiedSubject(jwt switch
        {
            "bob" => "bob",
            "maintainer-1" => "maintainer-1",
            _ => "alice"
        }));
    }
    private sealed class Driver : IRowDriver
    {
        public string Hash { get; set; } = ""; public string Owner => "learning"; public bool Configured => true;
        public int Commits { get; private set; }
        private readonly Dictionary<(string, string), JsonObject> _rows = [];
        private readonly bool _empty;
        public IReadOnlyDictionary<(string, string), JsonObject> Rows => _rows;
        public Driver(bool empty = false) => _empty = empty;
        public void Seed(string table, string id, JsonObject row) => _rows[(table, id)] = row;
        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken ct)
        {
            JsonObject? row = _rows.GetValueOrDefault((table, id));
            if (row is null && !_empty)
                row = table == "l_courses" && id == CanonicalWire.RowId("course", "vi_en") ? new() { ["status"] = "PUBLISHED", ["publishedVersion"] = "v1" } :
                    table == "l_content_versions" && id == CanonicalWire.RowId("content-version", "vi_en", "v1") ? new() { ["manifestFileId"] = "file", ["manifestSha256"] = Hash } : null;
            return Task.FromResult(row is null ? null : new RowDocument(id, row, null));
        }
        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken ct) => table == "l_courses" && !_empty ? Task.FromResult<IReadOnlyList<RowDocument>>([new("course", new JsonObject { ["courseId"] = "vi_en", ["status"] = "PUBLISHED" }, null)]) : Task.FromResult<IReadOnlyList<RowDocument>>(_rows.Where(p => p.Key.Item1 == table && (query.Where is null || query.Where.All(q => p.Value[q.Key]?.ToString() == q.Value?.ToString()))).Select(p => new RowDocument(p.Key.Item2, p.Value.DeepClone().AsObject(), null)).ToArray());
        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken ct) => throw new NotSupportedException();
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken ct)
        { Commits++; foreach (var write in writes) if (write.Action == "delete") _rows.Remove((write.Table, write.Id)); else _rows[(write.Table, write.Id)] = write.Data!.DeepClone().AsObject(); return Task.CompletedTask; }
    }
}
