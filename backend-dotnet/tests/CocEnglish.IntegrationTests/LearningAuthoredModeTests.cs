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
    public async Task Start_AuthoredActivityReturnsResolvedMetadataAndHidesPrivateConfig()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var modeConfig = new JsonObject
        {
            ["modes"] = new JsonArray("STORIES", "CLASH"),
            ["passThreshold"] = 0.8,
            ["opponents"] = new JsonArray("coach"),
            ["defaultOpponentId"] = "coach"
        };
        var driver = Driver.WithEnrollment(now);
        var content = new ContentReader([Exercise("ex1")], modeConfig: modeConfig);
        using var app = CreateApp(driver, now, new Relay(), [Exercise("ex1")], content);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        const string key = "104f7c23-664d-4214-9b8a-e00ea420c731";
        client.DefaultRequestHeaders.Add("Idempotency-Key", key);

        using var started = await client.PostAsJsonAsync("/v1/sessions", new
        {
            courseId = "course",
            lessonId = "lesson-1",
            mode = "CLASH",
            expectedEnrollmentRevision = 0,
            activityId = "story-episode-1",
            opponentId = "coach"
        });

        Assert.True(started.IsSuccessStatusCode, await started.Content.ReadAsStringAsync());
        var view = (await started.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("CLASH", view["mode"]!.GetValue<string>());
        Assert.Equal("story-episode-1", view["activityId"]!.GetValue<string>());
        Assert.Equal("coach", view["opponentId"]!.GetValue<string>());
        Assert.Equal(0.8, view["passThreshold"]!.GetValue<double>());
        Assert.Null(view["bundle"]!["modeConfig"]);

        var sessionId = CocEnglish.Shared.Security.CanonicalWire.RowId("session", "alice", key);
        var session = (await driver.ReadAsync("l_sessions", sessionId, CancellationToken.None))!.Data;
        Assert.Equal("CLASH", session.Text("mode"));
    }

    [Theory]
    [InlineData("STORIES")]
    [InlineData("ADVENTURE")]
    [InlineData("RADIO")]
    [InlineData("SIDE_QUEST")]
    [InlineData("CLASH")]
    [InlineData("UNIT_REVIEW")]
    public async Task Start_AuthoredActivityModesAreAvailableWhenBundleDoesNotRestrictThem(string mode)
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var driver = Driver.WithEnrollment(now);
        using var app = CreateApp(driver, now, new Relay(), [Exercise("ex1")]);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", Guid.NewGuid().ToString());

        using var started = await client.PostAsJsonAsync("/v1/sessions", new
        {
            courseId = "course", lessonId = "lesson-1", mode, expectedEnrollmentRevision = 0, activityId = "activity-1"
        });

        Assert.True(started.IsSuccessStatusCode, await started.Content.ReadAsStringAsync());
        var view = (await started.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal(mode, view["mode"]!.GetValue<string>());
        Assert.Equal("activity-1", view["activityId"]!.GetValue<string>());
    }

    [Fact]
    public async Task Start_ClashRejectsAnOpponentOutsideTheServerAuthoredSet()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var driver = Driver.WithEnrollment(now);
        var content = new ContentReader([Exercise("ex1")], modeConfig: new JsonObject
        {
            ["modes"] = new JsonArray("CLASH"), ["opponents"] = new JsonArray("coach")
        });
        using var app = CreateApp(driver, now, new Relay(), [Exercise("ex1")], content);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "804f7c23-664d-4214-9b8a-e00ea420c731");

        using var started = await client.PostAsJsonAsync("/v1/sessions", new
        {
            courseId = "course", lessonId = "lesson-1", mode = "CLASH", expectedEnrollmentRevision = 0, opponentId = "ghost"
        });

        Assert.Equal(HttpStatusCode.ServiceUnavailable, started.StatusCode);
        var error = (await started.Content.ReadFromJsonAsync<JsonObject>())!["error"]!;
        Assert.Equal("OPPONENT_UNAVAILABLE", error["code"]!.GetValue<string>());
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table == "l_sessions");
    }

    [Fact]
    public async Task Answer_AuthoredActivityUsesTheNormalGradingAndRevisionRulesWithoutEnergyCost()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var driver = Driver.WithSession(now, mode: "STORIES", includeAnswer: false);
        var exercise = ChoiceExercise();
        using var app = CreateApp(driver, now, new Relay(), [exercise], new ContentReader([exercise]));
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "b04f7c23-664d-4214-9b8a-e00ea420c731");

        using var answer = await client.PostAsJsonAsync("/v1/sessions/session-1/answers", new
        {
            exerciseId = "ex1", attemptOrdinal = 0, answer = new { kind = "choice", choiceId = "yes" },
            assisted = false, substituted = false, expectedRevision = 0
        });

        Assert.Equal(HttpStatusCode.OK, answer.StatusCode);
        var result = (await answer.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.True(result["correct"]!.GetValue<bool>());
        Assert.Equal(1, result["sessionRevision"]!.GetValue<int>());
        var session = (await driver.ReadAsync("l_sessions", "session-1", CancellationToken.None))!.Data;
        Assert.Equal(1, session.Number("nextOriginalOrdinal"));
        Assert.Equal(0, session.Number("energySpent"));
    }

    [Fact]
    public async Task Answer_SpeechSubstitutionStoresAssistanceFlagsAndUsesOnlyAuthoredAlternative()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var exercise = new JsonObject
        {
            ["id"] = "ex1", ["type"] = "speakRepeat", ["skillIds"] = new JsonArray("speaking"), ["vocabularyIds"] = new JsonArray(),
            ["content"] = new JsonObject { ["referenceText"] = "hello" },
            ["gradingRule"] = new JsonObject { ["acceptedText"] = new JsonArray("hello") },
            ["nonSpeechAlternative"] = new JsonObject
            {
                ["type"] = "choice",
                ["content"] = new JsonObject { ["choices"] = new JsonArray(new JsonObject { ["id"] = "yes", ["text"] = "hello" }) },
                ["gradingRule"] = new JsonObject { ["correctChoiceId"] = "yes" }
            }
        };
        var driver = Driver.WithSession(now, mode: "STORIES", includeAnswer: false);
        using var app = CreateApp(driver, now, new Relay(), [exercise], new ContentReader([exercise]));
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "114f7c23-664d-4214-9b8a-e00ea420c731");

        using var response = await client.PostAsJsonAsync("/v1/sessions/session-1/answers", new
        {
            exerciseId = "ex1", attemptOrdinal = 0, answer = new { kind = "choice", choiceId = "yes" },
            assisted = true, substituted = true, expectedRevision = 0
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var result = (await response.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.True(result["correct"]!.GetValue<bool>());
        Assert.Equal(1, result["sessionRevision"]!.GetValue<int>());
        var answer = Assert.Single(driver.Rows, row => row.Key.Table == "l_answers").Value;
        Assert.True(answer.Flag("assisted")); Assert.True(answer.Flag("substituted"));
        Assert.Equal("{\"kind\":\"choice\",\"choiceId\":\"yes\"}", answer.Text("answerJson"));
        var session = (await driver.ReadAsync("l_sessions", "session-1", CancellationToken.None))!.Data;
        Assert.True(session.Flag("assisted"));
        Assert.Equal(0, session.Number("energySpent"));
    }

    [Fact]
    public async Task Answer_SpeechAssessmentJobWithoutAdmittedProviderFailsBeforeWrites()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var exercise = new JsonObject
        {
            ["id"] = "ex1", ["type"] = "speakRepeat", ["skillIds"] = new JsonArray("speaking"), ["vocabularyIds"] = new JsonArray(),
            ["content"] = new JsonObject { ["referenceText"] = "hello" }, ["gradingRule"] = new JsonObject()
        };
        var driver = Driver.WithSession(now, mode: "STORIES", includeAnswer: false);
        using var app = CreateApp(driver, now, new Relay(), [exercise], new ContentReader([exercise]));
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "214f7c23-664d-4214-9b8a-e00ea420c731");

        using var response = await client.PostAsJsonAsync("/v1/sessions/session-1/answers", new
        {
            exerciseId = "ex1", attemptOrdinal = 0, answer = new { kind = "speech", assessmentJobId = "job-1" },
            assisted = false, substituted = false, expectedRevision = 0
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var error = (await response.Content.ReadFromJsonAsync<JsonObject>())!["error"]!;
        Assert.Equal("VALIDATION_ERROR", error["code"]!.GetValue<string>());
        Assert.Equal("SPEECH_ASSESSMENT_UNAVAILABLE", error["details"]!["reason"]!.GetValue<string>());
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table is "l_answers" or "l_receipts");
        Assert.Equal(0, driver.Commits);
        Assert.Equal("ACTIVE", (await driver.ReadAsync("l_sessions", "session-1", CancellationToken.None))!.Data.Text("status"));
    }

    [Fact]
    public async Task Start_AuthoredModesFailClosedWhenTheBundleDoesNotDeclareThem()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var driver = Driver.WithEnrollment(now);
        var content = new ContentReader([Exercise("ex1")], modeConfig: new JsonObject
        {
            ["modes"] = new JsonArray("RADIO")
        });
        using var app = CreateApp(driver, now, new Relay(), [Exercise("ex1")], content);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "204f7c23-664d-4214-9b8a-e00ea420c731");

        using var started = await client.PostAsJsonAsync("/v1/sessions", new
        {
            courseId = "course", lessonId = "lesson-1", mode = "STORIES", expectedEnrollmentRevision = 0
        });

        Assert.Equal(HttpStatusCode.BadRequest, started.StatusCode);
        var error = (await started.Content.ReadFromJsonAsync<JsonObject>())!["error"]!;
        Assert.Equal("MODE_UNAVAILABLE", error["code"]!.GetValue<string>());
        Assert.Equal("MODE_NOT_AUTHORED", error["details"]!["reason"]!.GetValue<string>());
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table == "l_sessions");
    }

    [Fact]
    public async Task Start_UnknownAuthoredLessonUsesActivityNotFound()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var driver = Driver.WithEnrollment(now);
        using var app = CreateApp(driver, now, new Relay(), [Exercise("ex1")]);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "304f7c23-664d-4214-9b8a-e00ea420c731");

        using var started = await client.PostAsJsonAsync("/v1/sessions", new
        {
            courseId = "course", lessonId = "missing", mode = "STORIES", expectedEnrollmentRevision = 0
        });

        Assert.Equal(HttpStatusCode.NotFound, started.StatusCode);
        var error = (await started.Content.ReadFromJsonAsync<JsonObject>())!["error"]!;
        Assert.Equal("ACTIVITY_NOT_FOUND", error["code"]!.GetValue<string>());
    }

    [Fact]
    public async Task Start_GatesRequireAnAuthoredThresholdAndCheckpointPrerequisites()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var noThresholdDriver = Driver.WithEnrollment(now);
        var noThresholdContent = new ContentReader([Exercise("ex1")], modeConfig: new JsonObject
        {
            ["modes"] = new JsonArray("TEST_OUT", "CHECKPOINT")
        });
        using var noThresholdApp = CreateApp(noThresholdDriver, now, new Relay(), [Exercise("ex1")], noThresholdContent);
        using var noThresholdClient = noThresholdApp.CreateClient();
        noThresholdClient.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        noThresholdClient.DefaultRequestHeaders.Add("Idempotency-Key", "404f7c23-664d-4214-9b8a-e00ea420c731");
        using var missingThreshold = await noThresholdClient.PostAsJsonAsync("/v1/sessions", new
        {
            courseId = "course", lessonId = "lesson-1", mode = "TEST_OUT", expectedEnrollmentRevision = 0
        });
        Assert.Equal(HttpStatusCode.BadRequest, missingThreshold.StatusCode);
        var thresholdError = (await missingThreshold.Content.ReadFromJsonAsync<JsonObject>())!["error"]!;
        Assert.Equal("MODE_UNAVAILABLE", thresholdError["code"]!.GetValue<string>());
        Assert.Equal("PASS_THRESHOLD_MISSING", thresholdError["details"]!["reason"]!.GetValue<string>());

        var checkpointDriver = Driver.WithEnrollment(now);
        var checkpointContent = new ContentReader([Exercise("ex1")], lessonId: "lesson-2", rewardIdentity: "lesson-2",
            modeConfig: new JsonObject { ["modes"] = new JsonArray("CHECKPOINT"), ["passThreshold"] = 0.8 });
        using var checkpointApp = CreateApp(checkpointDriver, now, new Relay(), [Exercise("ex1")], checkpointContent);
        using var checkpointClient = checkpointApp.CreateClient();
        checkpointClient.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        checkpointClient.DefaultRequestHeaders.Add("Idempotency-Key", "504f7c23-664d-4214-9b8a-e00ea420c731");
        using var blocked = await checkpointClient.PostAsJsonAsync("/v1/sessions", new
        {
            courseId = "course", lessonId = "lesson-2", mode = "CHECKPOINT", expectedEnrollmentRevision = 0
        });
        Assert.Equal(HttpStatusCode.Conflict, blocked.StatusCode);
        var checkpointError = (await blocked.Content.ReadFromJsonAsync<JsonObject>())!["error"]!;
        Assert.Equal("CHECKPOINT_LOCKED", checkpointError["code"]!.GetValue<string>());
    }

    [Fact]
    public async Task Complete_TestOutPassAdvancesUnitWithoutRewardOrReviewEffects()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var driver = Driver.WithSession(now, mode: "TEST_OUT");
        var content = new ContentReader([Exercise("ex1", "vocabulary.apple")], modeConfig: new JsonObject
        {
            ["modes"] = new JsonArray("TEST_OUT"), ["passThreshold"] = 0.8
        });
        using var app = CreateApp(driver, now, new Relay(), [Exercise("ex1", "vocabulary.apple")], content);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "604f7c23-664d-4214-9b8a-e00ea420c731");

        using var completed = await client.PostAsJsonAsync("/v1/sessions/session-1/complete", new { expectedRevision = 1 });

        Assert.Equal(HttpStatusCode.OK, completed.StatusCode);
        var result = (await completed.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.True(result["passed"]!.GetValue<bool>());
        Assert.Equal("notEligible", result["rewardStatus"]!.GetValue<string>());
        Assert.Equal("node-2", result["unlockedNodeId"]!.GetValue<string>());
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table is "l_outbox" or "l_review_items" or "l_mistakes");
        var enrollment = (await driver.ReadAsync("l_enrollments", CocEnglish.Shared.Security.CanonicalWire.RowId("enrollment", "alice", "course"), CancellationToken.None))!.Data;
        Assert.Equal(2, enrollment.Number("frontierNodeOrder"));
        Assert.Equal("[\"lesson-1\"]", enrollment.Text("completedLessonsJson"));
    }

    [Fact]
    public async Task Complete_TestOutFailureLeavesEnrollmentUnchanged()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var driver = Driver.WithSession(now, correct: false, mode: "TEST_OUT");
        var content = new ContentReader([Exercise("ex1")], modeConfig: new JsonObject
        {
            ["modes"] = new JsonArray("TEST_OUT"), ["passThreshold"] = 0.8
        });
        using var app = CreateApp(driver, now, new Relay(), [Exercise("ex1")], content);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "704f7c23-664d-4214-9b8a-e00ea420c731");

        using var completed = await client.PostAsJsonAsync("/v1/sessions/session-1/complete", new { expectedRevision = 1 });

        Assert.Equal(HttpStatusCode.OK, completed.StatusCode);
        var result = (await completed.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.False(result["passed"]!.GetValue<bool>());
        Assert.Equal("notEligible", result["rewardStatus"]!.GetValue<string>());
        Assert.Null(result["unlockedNodeId"]);
        var enrollment = (await driver.ReadAsync("l_enrollments", CocEnglish.Shared.Security.CanonicalWire.RowId("enrollment", "alice", "course"), CancellationToken.None))!.Data;
        Assert.Equal(1, enrollment.Number("frontierNodeOrder"));
        Assert.Equal("[]", enrollment.Text("completedLessonsJson"));
        Assert.Equal(0, enrollment.Number("revision"));
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table is "l_outbox" or "l_review_items" or "l_mistakes");
    }

    [Fact]
    public async Task Complete_CheckpointPassMarksSectionCompleteWithoutReward()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var driver = Driver.WithSession(now, mode: "CHECKPOINT", lessonId: "lesson-2",
            completedLessonsJson: "[\"lesson-1\"]", frontierNodeOrder: 2);
        var content = new ContentReader([Exercise("ex1")], lessonId: "lesson-2", rewardIdentity: "lesson-2",
            modeConfig: new JsonObject { ["modes"] = new JsonArray("CHECKPOINT"), ["passThreshold"] = 0.8 });
        using var app = CreateApp(driver, now, new Relay(), [Exercise("ex1")], content);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "904f7c23-664d-4214-9b8a-e00ea420c731");

        using var completed = await client.PostAsJsonAsync("/v1/sessions/session-1/complete", new { expectedRevision = 1 });

        Assert.Equal(HttpStatusCode.OK, completed.StatusCode);
        var result = (await completed.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.True(result["passed"]!.GetValue<bool>());
        Assert.Equal("notEligible", result["rewardStatus"]!.GetValue<string>());
        Assert.Equal("node-3", result["unlockedNodeId"]!.GetValue<string>());
        var enrollment = (await driver.ReadAsync("l_enrollments", CanonicalWire.RowId("enrollment", "alice", "course"), CancellationToken.None))!.Data;
        Assert.Equal(3, enrollment.Number("frontierNodeOrder"));
        Assert.Equal("[\"lesson-1\",\"lesson-2\"]", enrollment.Text("completedLessonsJson"));
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table is "l_outbox" or "l_review_items" or "l_mistakes");
    }

    [Fact]
    public async Task Complete_AuthoredActivityCreatesCompletionEventWithoutChangingCourseFrontier()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var driver = Driver.WithSession(now, mode: "STORIES");
        var relay = new Relay();
        using var app = CreateApp(driver, now, relay, [Exercise("ex1", "vocabulary.apple")]);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "a04f7c23-664d-4214-9b8a-e00ea420c731");

        using var completed = await client.PostAsJsonAsync("/v1/sessions/session-1/complete", new { expectedRevision = 1 });

        Assert.Equal(HttpStatusCode.OK, completed.StatusCode);
        var result = (await completed.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("STORIES", result["mode"]!.GetValue<string>());
        Assert.Equal("pending", result["rewardStatus"]!.GetValue<string>());
        Assert.Single(relay.Delivered);
        Assert.Equal("STORIES", relay.Delivered[0]["payload"]!["mode"]!.GetValue<string>());
        var enrollment = (await driver.ReadAsync("l_enrollments", CanonicalWire.RowId("enrollment", "alice", "course"), CancellationToken.None))!.Data;
        Assert.Equal(1, enrollment.Number("frontierNodeOrder"));
        Assert.Equal("[]", enrollment.Text("completedLessonsJson"));
    }

}
