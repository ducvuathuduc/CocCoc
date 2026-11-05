using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CocEnglish.Learning;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed partial class LearningCompletionTests
{
    [Fact]
    public async Task Complete_CommitsEnrollmentReviewOutboxAndReceiptOnce()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var exercises = new[] { Exercise("ex1", "vocabulary.apple") };
        var driver = Driver.WithSession(now);
        var relay = new Relay();
        using var app = CreateApp(driver, now, relay, exercises);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "c4c2a130-71a0-4e93-9144-c1f27960d117");
        var body = new { expectedRevision = 1 };

        using var completed = await client.PostAsJsonAsync("/v1/sessions/session-1/complete", body);
        Assert.Equal(HttpStatusCode.OK, completed.StatusCode);
        var result = (await completed.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("session-1", result["completionId"]!.GetValue<string>());
        Assert.Equal(1, result["originalCount"]!.GetValue<int>());
        Assert.Equal(1, result["originalCorrect"]!.GetValue<int>());
        Assert.Equal("pending", result["rewardStatus"]!.GetValue<string>());
        Assert.Equal(1, result["enrollmentRevision"]!.GetValue<int>());

        var session = (await driver.ReadAsync("l_sessions", "session-1", CancellationToken.None))!.Data;
        Assert.Equal("COMPLETED", session.Text("status"));
        Assert.Null(await driver.ReadAsync("l_active_slots", CanonicalWire.RowId("slot", "alice", "course"), CancellationToken.None));
        var enrollment = (await driver.ReadAsync("l_enrollments", CanonicalWire.RowId("enrollment", "alice", "course"), CancellationToken.None))!.Data;
        Assert.Equal(2, enrollment.Number("frontierNodeOrder"));
        Assert.Equal("[\"lesson-1\"]", enrollment.Text("completedLessonsJson"));

        var reviewId = CanonicalWire.RowId("review", "alice", "course", "vocabulary.apple");
        var review = (await driver.ReadAsync("l_review_items", reviewId, CancellationToken.None))!.Data;
        Assert.Equal(1, review.Number("stage"));
        Assert.Equal(24, review.Number("halfLifeHours"));
        Assert.Equal(1, review.Number("correctCount"));
        Assert.Equal("2026-11-04T12:00:00.000Z", review.Text("dueAt"));
        var outbox = Assert.Single(driver.Rows, row => row.Key.Table == "l_outbox").Value;
        Assert.Equal("ACK", outbox.Text("status"));
        var envelope = JsonNode.Parse(outbox.Text("payloadJson")!)!.AsObject();
        Assert.Equal("lesson.completed.v1", envelope.Text("type"));
        Assert.Equal("alice", envelope["payload"]!["userId"]!.GetValue<string>());
        Assert.Single(relay.Delivered);

        var commits = driver.Commits;
        using var replay = await client.PostAsJsonAsync("/v1/sessions/session-1/complete", body);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.Equal(result.ToJsonString(), (await replay.Content.ReadFromJsonAsync<JsonObject>())!.ToJsonString());
        Assert.Equal(commits, driver.Commits);
        Assert.Single(relay.Delivered);
    }

    [Fact]
    public async Task Complete_RejectsIncompleteOriginalQueueWithoutWrites()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var exercises = new[] { Exercise("ex1"), Exercise("ex2") };
        var driver = Driver.WithSession(now);
        using var app = CreateApp(driver, now, new Relay(), exercises);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "d4c2a130-71a0-4e93-9144-c1f27960d117");

        using var incomplete = await client.PostAsJsonAsync("/v1/sessions/session-1/complete", new { expectedRevision = 1 });

        Assert.Equal(HttpStatusCode.Conflict, incomplete.StatusCode);
        Assert.Equal("SESSION_INCOMPLETE", (await incomplete.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
        Assert.Equal(0, driver.Commits);
        Assert.Equal("ACTIVE", (await driver.ReadAsync("l_sessions", "session-1", CancellationToken.None))!.Data.Text("status"));
    }

    [Fact]
    public async Task Complete_RecordsFirstAttemptMistakeAndResetsReviewSchedule()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var exercises = new[] { Exercise("ex1", "vocabulary.apple") };
        var driver = Driver.WithSession(now, correct: false);
        using var app = CreateApp(driver, now, new Relay(), exercises);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "e4c2a130-71a0-4e93-9144-c1f27960d117");

        using var completed = await client.PostAsJsonAsync("/v1/sessions/session-1/complete", new { expectedRevision = 1 });

        Assert.Equal(HttpStatusCode.OK, completed.StatusCode);
        var result = (await completed.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal(0, result["originalCorrect"]!.GetValue<int>());
        Assert.Equal("ex1", result["needsReviewIds"]![0]!.GetValue<string>());
        var review = (await driver.ReadAsync("l_review_items", CanonicalWire.RowId("review", "alice", "course", "vocabulary.apple"), CancellationToken.None))!.Data;
        Assert.Equal(0, review.Number("stage"));
        Assert.Equal(24, review.Number("halfLifeHours"));
        Assert.Equal(1, review.Number("incorrectCount"));
        Assert.Equal("2026-11-04T12:00:00.000Z", review.Text("dueAt"));
        var mistake = (await driver.ReadAsync("l_mistakes", CanonicalWire.RowId("mistake", "alice", "course", "ex1"), CancellationToken.None))!.Data;
        Assert.Equal(1, mistake.Number("mistakeCount"));
        Assert.Equal("session-1", mistake.Text("lastSessionId"));
        Assert.Null(mistake.Text("resolvedAt"));
    }

    private static WebApplicationFactory<Learning.Program> CreateApp(Driver driver, DateTimeOffset now, Relay relay, JsonObject[] exercises, ContentReader? content = null) =>
        new WebApplicationFactory<Learning.Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1",
                ["APPWRITE_PROJECT_ID"] = "test",
                ["COC_LEARNING_APPWRITE_KEY"] = "test-key",
                ["COC_LEARNING_PERSISTENCE"] = "appwrite",
                ["COC_LEARNING_ADMITTED"] = "reviewed-cloud-gate"
            }));
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<IRowDriver>();
                services.AddSingleton<IRowDriver>(driver);
                services.RemoveAll<ILearningContentReader>();
                services.AddSingleton<ILearningContentReader>(content ?? new ContentReader(exercises));
                services.RemoveAll<ILearningRelayTransport>();
                services.AddSingleton<ILearningRelayTransport>(relay);
                services.RemoveAll<IIdentityVerifier>();
                services.AddSingleton<IIdentityVerifier, Identity>();
                services.RemoveAll<TimeProvider>();
                services.AddSingleton<TimeProvider>(new Clock(now));
            });
        });

    private static JsonObject Exercise(string id, string? vocabularyId = null) => new()
    {
        ["id"] = id,
        ["skillIds"] = new JsonArray("general"),
        ["vocabularyIds"] = vocabularyId is null ? new JsonArray() : new JsonArray(vocabularyId)
    };

    private sealed class Clock(DateTimeOffset now) : TimeProvider { public override DateTimeOffset GetUtcNow() => now; }

    private sealed class Identity : IIdentityVerifier
    {
        public bool Configured => true;
        public Task<VerifiedSubject> VerifyAsync(string jwt, CancellationToken cancellationToken) => Task.FromResult(new VerifiedSubject(jwt));
    }

    private sealed class ContentReader : ILearningContentReader
    {
        private readonly JsonObject[] _exercises;
        private readonly string _courseId;
        private readonly string _lessonId;
        private readonly string _lessonVersion;
        private readonly string _rewardIdentity;
        private readonly JsonObject? _modeConfig;
        public ContentReader(JsonObject[] exercises, string courseId = "course", string lessonId = "lesson-1", string lessonVersion = "v1", string rewardIdentity = "lesson-1", JsonObject? modeConfig = null)
        {
            _exercises = exercises;
            _courseId = courseId;
            _lessonId = lessonId;
            _lessonVersion = lessonVersion;
            _rewardIdentity = rewardIdentity;
            _modeConfig = modeConfig;
        }

        public Task<JsonObject> PublishedAsync(string courseId, CancellationToken cancellationToken) => Task.FromResult(new JsonObject
        {
            ["courseId"] = courseId,
            ["courseVersion"] = "v1",
            ["manifestHash"] = new string('d', 64),
            ["bundles"] = new JsonArray(new JsonObject { ["lessonId"] = _lessonId, ["lessonVersion"] = _lessonVersion, ["rewardIdentity"] = _rewardIdentity, ["sha256"] = new string('a', 64) }),
            ["sections"] = new JsonArray(
                new JsonObject { ["sectionId"] = "section-1", ["unitIds"] = new JsonArray("unit-1", "unit-2") },
                new JsonObject { ["sectionId"] = "section-2", ["unitIds"] = new JsonArray("unit-3") }),
            ["nodes"] = new JsonArray(
                new JsonObject { ["nodeId"] = "node-1", ["order"] = 1, ["sectionId"] = "section-1", ["unitId"] = "unit-1", ["lessonIds"] = new JsonArray("lesson-1") },
                new JsonObject { ["nodeId"] = "node-2", ["order"] = 2, ["sectionId"] = "section-1", ["unitId"] = "unit-2", ["lessonIds"] = new JsonArray("lesson-2") },
                new JsonObject { ["nodeId"] = "node-3", ["order"] = 3, ["sectionId"] = "section-2", ["unitId"] = "unit-3", ["lessonIds"] = new JsonArray("lesson-3") })
        });

        public Task<JsonObject> BundleAsync(JsonObject manifest, string lessonId, CancellationToken cancellationToken) => Task.FromResult(Bundle());
        public Task<JsonObject> BundleByLessonVersionAsync(string courseId, string lessonId, string lessonVersion, CancellationToken cancellationToken) => Task.FromResult(Bundle());
        public JsonObject BundleSnapshot() => Bundle();
        private JsonObject Bundle() => new()
        {
            ["schemaVersion"] = 1,
            ["courseId"] = _courseId,
            ["courseVersion"] = "v1",
            ["sectionId"] = "section-1",
            ["unitId"] = "unit-1",
            ["nodeId"] = _lessonId == "lesson-2" ? "node-2" : "node-1",
            ["order"] = _lessonId == "lesson-2" ? 2 : 1,
            ["sectionId"] = "section-1",
            ["unitId"] = _lessonId == "lesson-2" ? "unit-2" : "unit-1",
            ["lessonId"] = _lessonId,
            ["lessonVersion"] = _lessonVersion,
            ["rewardIdentity"] = _rewardIdentity,
            ["title"] = "Lesson",
            ["skillIds"] = new JsonArray("general"),
            ["exercises"] = new JsonArray(_exercises.Select(item => (JsonNode)item.DeepClone()).ToArray()),
            ["assets"] = new JsonArray(),
            ["gradingRulesVersion"] = "v1",
            ["manifestHash"] = new string('b', 64),
            ["signatureKeyId"] = "test",
            ["signature"] = new string('c', 86),
            ["modeConfig"] = _modeConfig?.DeepClone()
        };
    }

    private sealed class Relay : ILearningRelayTransport
    {
        public bool Configured => true;
        public List<JsonObject> Delivered { get; } = [];
        public Task<LearningRelayOutcome> DeliverAsync(JsonObject envelope, CancellationToken cancellationToken)
        {
            Delivered.Add(envelope.DeepClone().AsObject());
            return Task.FromResult(LearningRelayOutcome.Ack);
        }
    }

    private sealed class Driver : IRowDriver
    {
        private readonly Dictionary<(string Table, string Id), JsonObject> _rows = [];
        public string Owner => "learning";
        public bool Configured => true;
        public int Commits { get; private set; }
        public IEnumerable<KeyValuePair<(string Table, string Id), JsonObject>> Rows => _rows;

        public static Driver WithSession(DateTimeOffset now, bool correct = true, string mode = "LESSON", string lessonId = "lesson-1",
            string completedLessonsJson = "[]", long frontierNodeOrder = 1, bool includeAnswer = true)
        {
            var driver = new Driver();
            var at = OwnerSchema.Iso(now);
            driver.Seed("l_sessions", "session-1", new JsonObject
            {
                ["userId"] = "alice", ["courseId"] = "course", ["lessonId"] = lessonId, ["lessonVersion"] = "v1", ["rewardIdentity"] = lessonId,
                ["mode"] = mode, ["source"] = "ONLINE", ["status"] = "ACTIVE", ["bundleHash"] = new string('a', 64), ["bundleSnapshotJson"] = null,
                ["nextOriginalOrdinal"] = includeAnswer ? 1 : 0, ["retryPass"] = 0, ["assisted"] = false, ["energySpent"] = 0, ["energyEarned"] = 0,
                ["startedAt"] = at, ["expiresAt"] = OwnerSchema.Iso(now.AddHours(24)), ["completedAt"] = null, ["resultJson"] = "{}",
                ["revision"] = includeAnswer ? 1 : 0, ["createdAt"] = at, ["updatedAt"] = at
            });
            driver.Seed("l_active_slots", CanonicalWire.RowId("slot", "alice", "course"), new JsonObject
            {
                ["userId"] = "alice", ["courseId"] = "course", ["sessionId"] = "session-1", ["expiresAt"] = OwnerSchema.Iso(now.AddHours(24)),
                ["revision"] = 0, ["createdAt"] = at, ["updatedAt"] = at
            });
            driver.Seed("l_enrollments", CanonicalWire.RowId("enrollment", "alice", "course"), new JsonObject
            {
                ["userId"] = "alice", ["courseId"] = "course", ["courseVersion"] = "v1", ["frontierNodeOrder"] = frontierNodeOrder,
                ["completedLessonsJson"] = completedLessonsJson, ["masteredNodesJson"] = "[]", ["legendaryNodesJson"] = "[]", ["placementUsed"] = false,
                ["active"] = true, ["proficiencyScore"] = 0, ["lastPracticedAt"] = null, ["removedAt"] = null,
                ["revision"] = 0, ["createdAt"] = at, ["updatedAt"] = at
            });
            if (includeAnswer)
                driver.Seed("l_answers", "answer-1", new JsonObject
                {
                    ["sessionId"] = "session-1", ["userId"] = "alice", ["exerciseId"] = "ex1", ["attemptOrdinal"] = 0,
                    ["answerJson"] = "{}", ["correct"] = correct, ["assisted"] = false, ["substituted"] = false, ["receivedAt"] = at,
                    ["resultJson"] = "{}", ["revision"] = 0, ["createdAt"] = at, ["updatedAt"] = at
                });
            return driver;
        }

        public static Driver WithEnrollment(DateTimeOffset now)
        {
            var driver = new Driver();
            var at = OwnerSchema.Iso(now);
            driver.Seed("l_enrollments", CanonicalWire.RowId("enrollment", "alice", "course"), new JsonObject
            {
                ["userId"] = "alice", ["courseId"] = "course", ["courseVersion"] = "v1", ["frontierNodeOrder"] = 1,
                ["completedLessonsJson"] = "[]", ["masteredNodesJson"] = "[]", ["legendaryNodesJson"] = "[]", ["placementUsed"] = false,
                ["active"] = true, ["proficiencyScore"] = 0, ["lastPracticedAt"] = null, ["removedAt"] = null,
                ["revision"] = 0, ["createdAt"] = at, ["updatedAt"] = at
            });
            return driver;
        }

        public void Seed(string table, string id, JsonObject data) => _rows[(table, id)] = data;
        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken cancellationToken) =>
            Task.FromResult(_rows.TryGetValue((table, id), out var row) ? new RowDocument(id, row.DeepClone().AsObject(), "v1") : null);

        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken cancellationToken)
        {
            IEnumerable<KeyValuePair<(string Table, string Id), JsonObject>> selected = _rows.Where(pair => pair.Key.Table == table);
            foreach (var (key, value) in query.Where ?? new Dictionary<string, object?>())
                selected = value is null
                    ? selected.Where(pair => pair.Value[key] is null)
                    : selected.Where(pair => pair.Value[key]?.ToString() == value.ToString());
            foreach (var (key, value) in query.LessThan ?? new Dictionary<string, object?>())
                selected = selected.Where(pair => pair.Value[key] is not null && StringComparer.Ordinal.Compare(pair.Value[key]!.GetValue<string>(), value?.ToString()) < 0);
            foreach (var (key, value) in query.LessThanEqual ?? new Dictionary<string, object?>())
                selected = selected.Where(pair => pair.Value[key] is not null && StringComparer.Ordinal.Compare(pair.Value[key]!.GetValue<string>(), value?.ToString()) <= 0);
            foreach (var order in query.OrderBy ?? [])
                selected = order.Descending
                    ? selected.OrderByDescending(pair => pair.Value[order.Column]?.ToString(), StringComparer.Ordinal)
                    : selected.OrderBy(pair => pair.Value[order.Column]?.ToString(), StringComparer.Ordinal);
            return Task.FromResult<IReadOnlyList<RowDocument>>(selected.Skip(query.Offset).Take(query.Limit)
                .Select(pair => new RowDocument(pair.Key.Id, pair.Value.DeepClone().AsObject(), "v1")).ToArray());
        }

        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken cancellationToken) =>
            Task.FromResult((long)_rows.Count(pair => pair.Key.Table == table && where.All(filter =>
                filter.Value is null ? pair.Value[filter.Key] is null : pair.Value[filter.Key]?.ToString() == filter.Value.ToString())));

        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken cancellationToken)
        {
            foreach (var write in writes)
            {
                if (write.Action == "delete") _rows.Remove((write.Table, write.Id));
                else _rows[(write.Table, write.Id)] = write.Data!.DeepClone().AsObject();
            }
            Commits++;
            return Task.CompletedTask;
        }
    }
}
