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
    public async Task ReviewStart_RejectsAnInsufficientPoolWithoutCreatingASessionOrReceipt()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var driver = Driver.WithEnrollment(now);
        var enrollmentId = CanonicalWire.RowId("enrollment", "alice", "course");
        var enrollment = (await driver.ReadAsync("l_enrollments", enrollmentId, CancellationToken.None))!.Data;
        enrollment["frontierNodeOrder"] = 2;
        driver.Seed("l_enrollments", enrollmentId, enrollment);
        var exercises = Enumerable.Range(1, 4).Select(index => ReviewExercise($"exercise-{index}")).ToArray();
        using var app = CreateApp(driver, now, new Relay(), exercises);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "d4c2a130-71a0-4e93-9144-c1f27960d117");

        using var result = await client.PostAsJsonAsync("/v1/sessions", new
        {
            courseId = "course", lessonId = "review_dynamic", mode = "REVIEW", expectedEnrollmentRevision = 0
        });

        Assert.Equal(HttpStatusCode.NotFound, result.StatusCode);
        Assert.Equal("REVIEW_POOL_EMPTY", (await result.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["details"]!["reason"]!.GetValue<string>());
        Assert.Equal(0, driver.Commits);
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table is "l_sessions" or "l_active_slots" or "l_receipts");
    }

    [Fact]
    public async Task ReviewStart_PrioritizesMistakesAndDueWordsAndPinsPrivateSnapshot()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var exercises = new[]
        {
            ReviewExercise("exercise-1", "word-due"),
            ReviewExercise("exercise-2"),
            ReviewExercise("exercise-3"),
            ReviewExercise("exercise-4"),
            ReviewExercise("exercise-5"),
            ReviewExercise("exercise-6")
        };
        var driver = Driver.WithEnrollment(now);
        var enrollmentId = CanonicalWire.RowId("enrollment", "alice", "course");
        var enrollment = (await driver.ReadAsync("l_enrollments", enrollmentId, CancellationToken.None))!.Data;
        enrollment["frontierNodeOrder"] = 2;
        enrollment["completedLessonsJson"] = "[\"lesson-1\"]";
        driver.Seed("l_enrollments", enrollmentId, enrollment);
        driver.Seed("l_mistakes", CanonicalWire.RowId("mistake", "alice", "course", "exercise-2"), new JsonObject
        {
            ["userId"] = "alice", ["courseId"] = "course", ["exerciseId"] = "exercise-2", ["lessonVersion"] = "v1",
            ["skillId"] = "skill_reading", ["lastSessionId"] = "old-session", ["mistakeCount"] = 1,
            ["lastMistakeAt"] = OwnerSchema.Iso(now.AddMinutes(-5)), ["resolvedAt"] = null,
            ["revision"] = 0, ["createdAt"] = OwnerSchema.Iso(now.AddDays(-1)), ["updatedAt"] = OwnerSchema.Iso(now.AddMinutes(-5))
        });
        driver.Seed("l_review_items", CanonicalWire.RowId("review", "alice", "course", "word-due"), new JsonObject
        {
            ["userId"] = "alice", ["courseId"] = "course", ["vocabularyId"] = "word-due", ["skillId"] = "skill_words",
            ["stage"] = 2, ["dueAt"] = OwnerSchema.Iso(now.AddMinutes(-1)), ["firstAttemptWindowJson"] = "[true,false,true,false,true]",
            ["lastReviewedAt"] = OwnerSchema.Iso(now.AddDays(-1)), ["firstSeenAt"] = OwnerSchema.Iso(now.AddDays(-10)),
            ["correctCount"] = 3, ["incorrectCount"] = 1, ["halfLifeHours"] = 24
        });

        using var app = CreateApp(driver, now, new Relay(), exercises);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "f4c2a130-71a0-4e93-9144-c1f27960d117");
        var request = new { courseId = "course", lessonId = "review_dynamic", mode = "REVIEW", expectedEnrollmentRevision = 0 };

        using var started = await client.PostAsJsonAsync("/v1/sessions", request);

        Assert.True(started.StatusCode == HttpStatusCode.OK, await started.Content.ReadAsStringAsync());
        var view = (await started.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("review_dynamic", view["lessonId"]!.GetValue<string>());
        var bundle = view["bundle"]!.AsObject();
        var exerciseIds = bundle["exercises"]!.AsArray().Select(item => item!["id"]!.GetValue<string>()).ToArray();
        Assert.Equal(["exercise-2", "exercise-1", "exercise-3", "exercise-4", "exercise-5"], exerciseIds);
        Assert.Equal("server-snapshot-sha512", bundle["signatureKeyId"]!.GetValue<string>());
        Assert.Equal(86, bundle["signature"]!.GetValue<string>().Length);

        var sessionId = view["sessionId"]!.GetValue<string>();
        var session = (await driver.ReadAsync("l_sessions", sessionId, CancellationToken.None))!.Data;
        var snapshot = session.Text("bundleSnapshotJson")!;
        Assert.InRange(snapshot.Length, 1, 65536);
        Assert.Equal(CanonicalWire.Sha256(snapshot), session.Text("bundleHash"));
        var commits = driver.Commits;

        exercises[1]["id"] = "changed-after-start";
        var resumed = await client.GetFromJsonAsync<JsonObject>($"/v1/sessions/{sessionId}");
        Assert.Equal("exercise-2", resumed!["bundle"]!["exercises"]![0]!["id"]!.GetValue<string>());

        using var replay = await client.PostAsJsonAsync("/v1/sessions", request);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.Equal(exerciseIds, (await replay.Content.ReadFromJsonAsync<JsonObject>())!["bundle"]!["exercises"]!.AsArray()
            .Select(item => item!["id"]!.GetValue<string>()).ToArray());
        Assert.Equal(commits, driver.Commits);

        for (var index = 0; index < exerciseIds.Length; index++)
        {
            client.DefaultRequestHeaders.Remove("Idempotency-Key");
            client.DefaultRequestHeaders.Add("Idempotency-Key", $"a{index + 1:x7}-1111-4111-8111-111111111111");
            using var answer = await client.PostAsJsonAsync($"/v1/sessions/{sessionId}/answers", new
            {
                exerciseId = exerciseIds[index], attemptOrdinal = 0, answer = new { kind = "text", text = "Hello" },
                assisted = false, substituted = false, expectedRevision = index
            });
            Assert.Equal(HttpStatusCode.OK, answer.StatusCode);
            Assert.True((await answer.Content.ReadFromJsonAsync<JsonObject>())!["correct"]!.GetValue<bool>());
        }

        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "c1111111-1111-4111-8111-111111111111");
        using var completed = await client.PostAsJsonAsync($"/v1/sessions/{sessionId}/complete", new { expectedRevision = exerciseIds.Length });
        Assert.True(completed.StatusCode == HttpStatusCode.OK, await completed.Content.ReadAsStringAsync());
        var completion = (await completed.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("REVIEW", completion["mode"]!.GetValue<string>());
        Assert.Equal(5, completion["originalCorrect"]!.GetValue<int>());
        var resolvedMistake = (await driver.ReadAsync("l_mistakes", CanonicalWire.RowId("mistake", "alice", "course", "exercise-2"), CancellationToken.None))!.Data;
        Assert.Equal(OwnerSchema.Iso(now), resolvedMistake.Text("resolvedAt"));
    }

    private static JsonObject ReviewExercise(string id, string? vocabularyId = null) => new()
    {
        ["id"] = id,
        ["type"] = "textTranslation",
        ["skillIds"] = new JsonArray("skill_reading"),
        ["vocabularyIds"] = vocabularyId is null ? new JsonArray() : new JsonArray(vocabularyId),
        ["prompt"] = new JsonObject { ["text"] = "Translate the sentence", ["locale"] = "en-US", ["audioAssetId"] = null },
        ["content"] = new JsonObject(),
        ["gradingRule"] = new JsonObject { ["acceptedText"] = new JsonArray("Hello"), ["caseSensitive"] = false, ["ignorePunctuation"] = false, ["ignoreDiacritics"] = false },
        ["explanation"] = "Use the authored translation."
    };
}
