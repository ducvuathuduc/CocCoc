using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed partial class LearningCompletionTests
{
    [Fact]
    public async Task OfflineCompletion_RegradesAndDeduplicatesByLocalCompletionId()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var exercises = new[] { ChoiceExercise() };
        var content = new ContentReader(exercises, rewardIdentity: "reward-1");
        var driver = Driver.WithEnrollment(now);
        var bundleHash = CanonicalWire.Sha256(CanonicalWire.Json(content.BundleSnapshot()));
        using var app = CreateApp(driver, now, new Relay(), exercises, content);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "a4c2a130-71a0-4e93-9144-c1f27960d117");
        var request = OfflineRequest(bundleHash, "yes");

        using var completed = await client.PostAsJsonAsync("/v1/offline-completions", request);

        Assert.Equal(HttpStatusCode.OK, completed.StatusCode);
        var result = (await completed.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("OFFLINE", result["source"]!.GetValue<string>());
        Assert.Equal("LESSON", result["mode"]!.GetValue<string>());
        Assert.Equal("pending", result["rewardStatus"]!.GetValue<string>());
        var sessionId = CanonicalWire.RowId("session", "alice", "offline|11111111-1111-4111-8111-111111111111");
        var session = (await driver.ReadAsync("l_sessions", sessionId, CancellationToken.None))!.Data;
        Assert.Equal("COMPLETED", session.Text("status"));
        Assert.Equal("OFFLINE", session.Text("source"));
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table == "l_answers");
        var enrollment = (await driver.ReadAsync("l_enrollments", CanonicalWire.RowId("enrollment", "alice", "course"), CancellationToken.None))!.Data;
        Assert.Equal("[\"lesson-1\"]", enrollment.Text("completedLessonsJson"));
        var outbox = Assert.Single(driver.Rows, row => row.Key.Table == "l_outbox").Value;
        var envelope = JsonNode.Parse(outbox.Text("payloadJson")!)!.AsObject();
        Assert.Equal("OFFLINE", envelope["payload"]!["source"]!.GetValue<string>());
        Assert.Equal("reward-1", envelope["payload"]!["rewardIdentity"]!.GetValue<string>());

        var original = request.DeepClone().AsObject();
        original["operationId"] = "22222222-2222-4222-8222-222222222222";
        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "b4c2a130-71a0-4e93-9144-c1f27960d117");
        using var replay = await client.PostAsJsonAsync("/v1/offline-completions", original);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.Equal(result.ToJsonString(), (await replay.Content.ReadFromJsonAsync<JsonObject>())!.ToJsonString());
        Assert.Single(driver.Rows, row => row.Key.Table == "l_outbox");

        var changed = original.DeepClone().AsObject();
        changed["operationId"] = "33333333-3333-4333-8333-333333333333";
        changed["answers"]![0]!["answer"]!["choiceId"] = "no";
        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "c4c2a130-71a0-4e93-9144-c1f27960d117");
        using var conflict = await client.PostAsJsonAsync("/v1/offline-completions", changed);
        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
        Assert.Equal("IDEMPOTENCY_CONFLICT", (await conflict.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
        Assert.Single(driver.Rows, row => row.Key.Table == "l_outbox");
    }

    [Fact]
    public async Task OfflineCompletion_RegradesClientClaimAndRequiresRetryForWrongAnswer()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var exercises = new[] { ChoiceExercise() };
        var content = new ContentReader(exercises);
        var driver = Driver.WithEnrollment(now);
        var bundleHash = CanonicalWire.Sha256(CanonicalWire.Json(content.BundleSnapshot()));
        using var app = CreateApp(driver, now, new Relay(), exercises, content);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "d4c2a130-71a0-4e93-9144-c1f27960d117");

        using var response = await client.PostAsJsonAsync("/v1/offline-completions", OfflineRequest(bundleHash, "no"));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("SESSION_INCOMPLETE", (await response.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table == "l_outbox");
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table == "l_sessions");
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table == "l_receipts");
        Assert.Equal(0, driver.Commits);
    }

    [Fact]
    public async Task OfflineCompletion_RejectsAlteredBundleHashWithoutWrites()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var exercises = new[] { ChoiceExercise() };
        var content = new ContentReader(exercises);
        var driver = Driver.WithEnrollment(now);
        var bundleHash = CanonicalWire.Sha256(CanonicalWire.Json(content.BundleSnapshot()));
        using var app = CreateApp(driver, now, new Relay(), exercises, content);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "e4c2a130-71a0-4e93-9144-c1f27960d117");
        var request = OfflineRequest(bundleHash, "yes");
        request["bundleHash"] = new string('a', 64);

        using var response = await client.PostAsJsonAsync("/v1/offline-completions", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var error = (await response.Content.ReadFromJsonAsync<JsonObject>())!["error"]!;
        Assert.Equal("BUNDLE_MISMATCH", error["details"]!["reason"]!.GetValue<string>());
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table == "l_outbox");
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table == "l_sessions");
        Assert.Equal(0, driver.Commits);
    }

    private static JsonObject OfflineRequest(string bundleHash, string choice) => new()
    {
        ["operationId"] = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        ["localCompletionId"] = "11111111-1111-4111-8111-111111111111",
        ["courseId"] = "course",
        ["lessonId"] = "lesson-1",
        ["lessonVersion"] = "v1",
        ["bundleHash"] = bundleHash,
        ["expectedEnrollmentRevision"] = 0,
        ["answers"] = new JsonArray(new JsonObject
        {
            ["exerciseId"] = "ex1",
            ["attemptOrdinal"] = 0,
            ["answer"] = new JsonObject { ["kind"] = "choice", ["choiceId"] = choice },
            ["assisted"] = false,
            ["substituted"] = false
        })
    };

    private static JsonObject ChoiceExercise() => new()
    {
        ["id"] = "ex1",
        ["type"] = "choice",
        ["skillIds"] = new JsonArray("general"),
        ["vocabularyIds"] = new JsonArray("vocabulary.apple"),
        ["content"] = new JsonObject { ["choices"] = new JsonArray(
            new JsonObject { ["id"] = "yes", ["text"] = "Yes" },
            new JsonObject { ["id"] = "no", ["text"] = "No" }) },
        ["gradingRule"] = new JsonObject { ["correctChoiceId"] = "yes" }
    };
}
