using System.Globalization;
using System.Net;
using System.Net.Http.Json;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
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

public sealed class LearningNodeParityTests
{
    [Fact]
    public async Task EnrollmentLifecycleSessionAndAnswerSequenceMatchesNodeResponsesAndRows()
    {
        var scenarioText = Resource("Scenarios");
        var scenario = JsonNode.Parse(scenarioText)!;
        var baseline = JsonNode.Parse(Resource("Node"))!;
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());
        var steps = scenario["steps"]!.AsArray();
        var expected = baseline["results"]!.AsArray();
        Assert.Equal(steps.Count, expected.Count);

        using var factory = new LearningApiFixture
        {
            Now = DateTimeOffset.Parse(scenario["now"]!.GetValue<string>(), CultureInfo.InvariantCulture)
        };
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Request-ID", scenario["requestId"]!.GetValue<string>());
        var sessionId = CanonicalWire.RowId("session", "alice", scenario["sessionKey"]!.GetValue<string>());
        var reviewSessionId = CanonicalWire.RowId("session", "alice", scenario["reviewSessionKey"]!.GetValue<string>());
        var activeSessionId = CanonicalWire.RowId("session", "alice", scenario["activeSessionKey"]!.GetValue<string>());

        if (scenario["seedRows"] is JsonArray seedRows)
        {
            foreach (var seed in seedRows.OfType<JsonObject>())
                factory.Driver.Seed(seed.Text("table")!, seed.Text("id")!, seed["row"]!.DeepClone().AsObject());
        }

        for (var index = 0; index < steps.Count; index++)
        {
            var step = steps[index]!.AsObject();
            Assert.Equal(index, expected[index]!["index"]!.GetValue<int>());
            if (step["seedReview"] is JsonObject reviewSeed)
            {
                Assert.Equal("seed", expected[index]!["kind"]!.GetValue<string>());
                var completedLessonId = reviewSeed["completedLessonId"]!.GetValue<string>();
                var mistakeExerciseId = reviewSeed["mistakeExerciseId"]!.GetValue<string>();
                var enrollmentKey = ("l_enrollments", CanonicalWire.RowId("enrollment", "alice", "vi_en"));
                var enrollment = factory.Driver.Rows[enrollmentKey].Data.DeepClone().AsObject();
                enrollment["completedLessonsJson"] = JsonSerializer.Serialize(new[] { completedLessonId });
                factory.Driver.Seed(enrollmentKey.Item1, enrollmentKey.Item2, enrollment);
                var now = factory.Now;
                factory.Driver.Seed("l_mistakes", CanonicalWire.RowId("mistake", "alice", "vi_en", mistakeExerciseId), new JsonObject
                {
                    ["userId"] = "alice", ["courseId"] = "vi_en", ["exerciseId"] = mistakeExerciseId,
                    ["lessonVersion"] = "v2.u1n1l1", ["skillId"] = "u1.vocab", ["lastSessionId"] = sessionId,
                    ["mistakeCount"] = 1, ["lastMistakeAt"] = OwnerSchema.Iso(now.AddMinutes(-5)), ["resolvedAt"] = null,
                    ["revision"] = 0, ["createdAt"] = OwnerSchema.Iso(now.AddDays(-1)), ["updatedAt"] = OwnerSchema.Iso(now.AddMinutes(-5))
                });
                if (reviewSeed["additionalMistakes"] is JsonArray additionalMistakes)
                {
                    foreach (var item in additionalMistakes.OfType<JsonObject>())
                    {
                        var exerciseId = item["exerciseId"]!.GetValue<string>();
                        var lastMistakeAt = OwnerSchema.Iso(now.AddMinutes(-item["minutesAgo"]!.GetValue<int>()));
                        factory.Driver.Seed("l_mistakes", CanonicalWire.RowId("mistake", "alice", "vi_en", exerciseId), new JsonObject
                        {
                            ["userId"] = "alice", ["courseId"] = "vi_en", ["exerciseId"] = exerciseId,
                            ["lessonVersion"] = "v2.u1n1l1", ["skillId"] = "u1.vocab", ["lastSessionId"] = sessionId,
                            ["mistakeCount"] = 1, ["lastMistakeAt"] = lastMistakeAt, ["resolvedAt"] = null,
                            ["revision"] = 0, ["createdAt"] = OwnerSchema.Iso(now.AddDays(-1)), ["updatedAt"] = lastMistakeAt
                        });
                    }
                }
                foreach (var item in reviewSeed["reviewItems"]!.AsArray().OfType<JsonObject>())
                {
                    var vocabularyId = item["vocabularyId"]!.GetValue<string>();
                    var skillId = item["skillId"]!.GetValue<string>();
                    var lastReviewedAt = now.AddDays(-1);
                    var firstSeenAt = now.AddDays(-10);
                    factory.Driver.Seed("l_review_items", CanonicalWire.RowId("review", "alice", "vi_en", vocabularyId), new JsonObject
                    {
                        ["userId"] = "alice", ["courseId"] = "vi_en", ["vocabularyId"] = vocabularyId, ["skillId"] = skillId,
                        ["stage"] = 2, ["dueAt"] = OwnerSchema.Iso(now.AddMinutes(-item["dueMinutesAgo"]!.GetValue<int>())),
                        ["firstAttemptWindowJson"] = "[true,false,true,false,true]", ["lastReviewedAt"] = OwnerSchema.Iso(lastReviewedAt),
                        ["firstSeenAt"] = OwnerSchema.Iso(firstSeenAt), ["correctCount"] = 3, ["incorrectCount"] = 1,
                        ["halfLifeHours"] = 24, ["revision"] = 0, ["createdAt"] = OwnerSchema.Iso(firstSeenAt),
                        ["updatedAt"] = OwnerSchema.Iso(lastReviewedAt)
                    });
                }
                if (reviewSeed["activities"] is JsonArray activities)
                {
                    foreach (var item in activities.OfType<JsonObject>())
                    {
                        var activityId = item["activityId"]!.GetValue<string>();
                        factory.Driver.Seed("l_activity_progress", $"activity-{activityId}", new JsonObject
                        {
                            ["userId"] = "alice", ["courseId"] = "vi_en", ["kind"] = item["kind"]!.DeepClone(),
                            ["activityId"] = activityId, ["completions"] = item["completions"]!.DeepClone(),
                            ["bestScore"] = item["bestScore"]!.DeepClone(), ["stars"] = item["stars"]!.DeepClone(),
                            ["firstCompletedAt"] = OwnerSchema.Iso(now.AddDays(-1)), ["lastCompletedAt"] = null
                        });
                    }
                }
                continue;
            }
            if (step["inspect"] is JsonArray tables)
            {
                Assert.Equal("inspect", expected[index]!["kind"]!.GetValue<string>());
                var actual = new JsonObject();
                foreach (var name in tables.Select(item => item!.GetValue<string>()))
                    actual[name] = new JsonArray(factory.Driver.Rows
                        .Where(pair => pair.Key.Table == name)
                        .Where(pair => name != "l_receipts" || pair.Value.Data.Text("operation") != "publishContent")
                        .OrderBy(pair => pair.Key.Id, StringComparer.Ordinal)
                        .Select(pair => ProjectRow(pair.Key.Table, pair.Key.Id, pair.Value.Data)).ToArray());
                Match(expected[index]!["tables"], actual, $"step {index} persisted tables");
                continue;
            }

            var pathSessionId = step["sessionKey"] is JsonValue sessionPathKey
                ? CanonicalWire.RowId("session", step["user"]!.GetValue<string>(), sessionPathKey.GetValue<string>())
                : sessionId;
            var routePath = step["path"]!.GetValue<string>()
                .Replace("$sessionId", pathSessionId, StringComparison.Ordinal)
                .Replace("$reviewSessionId", reviewSessionId, StringComparison.Ordinal)
                .Replace("$activeSessionId", activeSessionId, StringComparison.Ordinal);
            var queryString = step["query"] is JsonValue query ? query.GetValue<string>() : "";
            var path = queryString.Length > 0 ? routePath + "?" + queryString : routePath;
            var method = step["method"]!.GetValue<string>();
            using var request = new HttpRequestMessage(new HttpMethod(method), path);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", step["user"]!.GetValue<string>());
            if (step["key"] is { } key)
            {
                var value = key.GetValue<string>() switch
                {
                    "$sessionKey" => scenario["sessionKey"]!.GetValue<string>(),
                    "$reportKey" => scenario["reportKey"]!.GetValue<string>(),
                    "$reviewSessionKey" => scenario["reviewSessionKey"]!.GetValue<string>(),
                    "$activeSessionKey" => scenario["activeSessionKey"]!.GetValue<string>(),
                    var literal => literal
                };
                request.Headers.Add("Idempotency-Key", value);
            }
            if (step["sender"] is JsonValue sender)
            {
                var senderName = sender.GetValue<string>();
                if (senderName != "progress") throw new InvalidOperationException("Unexpected Learning parity sender");
                var serviceKey = new ServiceKey("parity-progress", senderName, Enumerable.Repeat((byte)17, 32).ToArray());
                var allowedQueryKeys = queryString.Length > 0
                    ? new HashSet<string>(StringComparer.Ordinal) { "before" }
                    : new HashSet<string>(StringComparer.Ordinal);
                var signature = ServiceHmac.Sign(serviceKey, method, routePath, queryString, allowedQueryKeys, "", factory.Now.ToUnixTimeSeconds());
                request.Headers.Add("X-Service-Key-Id", signature.KeyId);
                request.Headers.Add("X-Service-Timestamp", signature.Timestamp);
                request.Headers.Add("X-Service-Signature", signature.Signature);
            }
            if (step["body"] is { } body)
                request.Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json");

            using var response = await client.SendAsync(request);
            var bodyText = await response.Content.ReadAsStringAsync();
            var actualBody = JsonNode.Parse(bodyText);
            Assert.Equal("call", expected[index]!["kind"]!.GetValue<string>());
            Assert.True((int)response.StatusCode == expected[index]!["status"]!.GetValue<int>(),
                $"step {index} {method} {path}: HTTP {(int)response.StatusCode}; expected {expected[index]!["status"]}; body={bodyText}");
            Match(expected[index]!["body"], actualBody, $"step {index} {method} {path}");
        }
    }

    [Fact]
    public async Task SignedEventConsumerSequenceMatchesNodeResponsesAndRows()
    {
        var scenario = JsonNode.Parse(Resource("Scenarios"))!["eventParity"]!.AsObject();
        var baseline = JsonNode.Parse(Resource("Node"))!;
        var expectedResults = Assert.IsType<JsonArray>(baseline["eventResults"]);
        var steps = scenario["steps"]!.AsArray();
        Assert.Equal(steps.Count, expectedResults.Count);
        var now = DateTimeOffset.Parse(scenario["now"]!.GetValue<string>(), CultureInfo.InvariantCulture);

        using var factory = new LearningApiFixture { Now = now };
        var seed = scenario["seed"]!.AsObject();
        for (var index = 0; index < seed["aliceReviewItems"]!.GetValue<int>(); index++)
            factory.Driver.Seed("l_review_items", $"alice-review-{index:D3}", new JsonObject
            {
                ["userId"] = "alice", ["courseId"] = "vi_en", ["vocabularyId"] = $"alice-v{index}"
            });
        for (var index = 0; index < seed["bobReviewItems"]!.GetValue<int>(); index++)
            factory.Driver.Seed("l_review_items", $"bob-review-{index:D3}", new JsonObject
            {
                ["userId"] = "bob", ["courseId"] = "vi_en", ["vocabularyId"] = $"bob-v{index}"
            });
        factory.Driver.Seed("l_energy", CanonicalWire.RowId("energy", "alice"), seed["energy"]!.DeepClone().AsObject());

        using var client = factory.CreateClient();
        var inspect = scenario["inspect"]!.AsArray().Select(node => node!.GetValue<string>()).ToArray();
        for (var index = 0; index < steps.Count; index++)
        {
            var step = steps[index]!.AsObject();
            var eventId = step["eventId"]!.GetValue<string>();
            var sender = step["sender"]?.GetValue<string>() ?? "progress";
            var payload = step["payload"]!.DeepClone().AsObject();
            var envelope = new JsonObject
            {
                ["eventId"] = eventId,
                ["type"] = step["type"]!.GetValue<string>(),
                ["schemaVersion"] = 1,
                ["producer"] = sender,
                ["aggregateId"] = payload["userId"]!.DeepClone(),
                ["occurredAt"] = scenario["now"]!.DeepClone(),
                ["requestId"] = eventId,
                ["payload"] = payload
            };
            var rawBody = envelope.ToJsonString();
            var key = new ServiceKey(sender == "progress" ? "parity-progress" : "parity-learning", sender,
                Enumerable.Repeat(sender == "progress" ? (byte)17 : (byte)51, 32).ToArray());
            var signature = ServiceHmac.Sign(key, "POST", "/internal/events", "", new HashSet<string>(StringComparer.Ordinal), rawBody, now.ToUnixTimeSeconds());
            using var request = new HttpRequestMessage(HttpMethod.Post, "/internal/events")
            {
                Content = new StringContent(rawBody, Encoding.UTF8, "application/json")
            };
            request.Headers.Add("X-Service-Key-Id", signature.KeyId);
            request.Headers.Add("X-Service-Timestamp", signature.Timestamp);
            request.Headers.Add("X-Service-Signature", signature.Signature);

            using var response = await client.SendAsync(request);
            var actualBody = JsonNode.Parse(await response.Content.ReadAsStringAsync())!.AsObject();
            if (actualBody.ContainsKey("requestId")) actualBody["requestId"] = "<request-id>";
            if (actualBody["error"] is JsonObject error && error.ContainsKey("requestId")) error["requestId"] = "<request-id>";
            var expected = expectedResults[index]!.AsObject();
            Assert.Equal(expected["status"]!.GetValue<int>(), (int)response.StatusCode);
            Match(expected["body"], actualBody, $"Learning event {index} ({step["type"]}) response");

            var actualTables = new JsonObject();
            foreach (var table in inspect)
            {
                var rows = factory.Driver.Rows
                    .Where(pair => pair.Key.Table == table)
                    .OrderBy(pair => pair.Key.Id, StringComparer.Ordinal)
                    .Select(pair => (JsonNode?)ProjectEventRow(table, pair.Key.Id, pair.Value.Data))
                    .ToArray();
                actualTables[table] = new JsonArray(rows);
            }
            Match(expected["tables"], actualTables, $"Learning event {index} ({step["type"]}) persisted rows");
        }
    }

    [Fact]
    public async Task SignedOutboxDispatchHttpMatchesNodeResponseAndRow()
    {
        var scenario = JsonNode.Parse(Resource("Scenarios"))!;
        var baseline = JsonNode.Parse(Resource("Node"))!;
        var spec = scenario["dispatchJob"]!.AsObject();
        var expected = baseline["dispatchJobResult"]!.AsObject();
        var now = DateTimeOffset.Parse(spec.Text("now")!, CultureInfo.InvariantCulture);
        var envelope = spec["event"]!.DeepClone().AsObject();
        var eventId = envelope.Text("eventId")!;

        using var factory = new LearningApiFixture { Now = now, UseParityRelay = true };
        factory.Driver.Seed("l_outbox", eventId, new JsonObject
        {
            ["eventId"] = eventId,
            ["type"] = envelope.Text("type"),
            ["schemaVersion"] = envelope["schemaVersion"]!.DeepClone(),
            ["aggregateId"] = envelope.Text("aggregateId"),
            ["occurredAt"] = envelope.Text("occurredAt"),
            ["payloadJson"] = CanonicalWire.Stringify(envelope),
            ["attempt"] = 0,
            ["nextAttemptAt"] = envelope.Text("occurredAt"),
            ["leaseOwner"] = null,
            ["leaseUntil"] = null,
            ["status"] = "PENDING",
            ["ackAt"] = null,
            ["revision"] = 0,
            ["createdAt"] = envelope.Text("occurredAt"),
            ["updatedAt"] = envelope.Text("occurredAt")
        });

        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Request-ID", spec.Text("requestId")!);
        const string route = "/internal/jobs/learning-outbox-dispatch";
        var body = spec["tick"]!.AsObject();
        var rawBody = body.ToJsonString();
        var serviceKey = new ServiceKey("parity-scheduler", "scheduler", Enumerable.Repeat((byte)34, 32).ToArray());
        var signature = ServiceHmac.Sign(serviceKey, "POST", route, "", new HashSet<string>(StringComparer.Ordinal), rawBody, now.ToUnixTimeSeconds());
        using var request = new HttpRequestMessage(HttpMethod.Post, route)
        {
            Content = new StringContent(rawBody, Encoding.UTF8, "application/json")
        };
        request.Headers.Add("X-Service-Key-Id", signature.KeyId);
        request.Headers.Add("X-Service-Timestamp", signature.Timestamp);
        request.Headers.Add("X-Service-Signature", signature.Signature);

        using var response = await client.SendAsync(request);
        var actualBody = JsonNode.Parse(await response.Content.ReadAsStringAsync());
        Assert.Equal(expected["status"]!.GetValue<int>(), (int)response.StatusCode);
        Assert.True(JsonNode.DeepEquals(expected["body"], actualBody),
            $"Learning dispatch response differs from Node: expected {expected["body"]?.ToJsonString()}, actual {actualBody?.ToJsonString()}");

        var actualRow = ProjectRow("l_outbox", eventId, factory.Driver.Rows[("l_outbox", eventId)].Data);
        Assert.True(JsonNode.DeepEquals(expected["row"], actualRow),
            $"Learning dispatch outbox row differs from Node: expected {expected["row"]?.ToJsonString()}, actual {actualRow.ToJsonString()}");
        var actualDeliveries = new JsonArray(factory.Relay.Deliveries.Select(delivery => delivery.DeepClone()).ToArray());
        Assert.True(JsonNode.DeepEquals(expected["deliveries"], actualDeliveries),
            $"Learning dispatch delivery differs from Node: expected {expected["deliveries"]?.ToJsonString()}, actual {actualDeliveries.ToJsonString()}");
    }

    [Fact]
    public async Task AuthoredModeCompletionsMatchNodeResponsesAndEffects()
    {
        var scenario = JsonNode.Parse(Resource("Scenarios"))!;
        var baseline = JsonNode.Parse(Resource("Node"))!;
        var completion = scenario["completionParity"]!.AsObject();
        var cases = completion["cases"]!.AsArray();
        var expected = baseline["completionResults"]!.AsArray();
        Assert.Equal(cases.Count, expected.Count);

        var overrides = CompletionContentOverrides();
        using var factory = new LearningApiFixture
        {
            Now = DateTimeOffset.Parse(completion.Text("now")!, CultureInfo.InvariantCulture),
            ContentOverrides = overrides
        };
        factory.ApplyContentOverrides();
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Request-ID", completion.Text("requestId")!);

        for (var index = 0; index < cases.Count; index++)
        {
            var testCase = cases[index]!.AsObject();
            var user = testCase.Text("user")!;
            var sessionId = testCase.Text("sessionId")!;
            var mode = testCase.Text("mode")!;
            var lessonId = testCase.Text("lessonId")!;
            var sourceLessonId = lessonId == "review_dynamic" ? "u1n1l1" : lessonId;
            var sourceBundle = BundleFrom(overrides, sourceLessonId);
            var exercises = (sourceBundle["exercises"] as JsonArray ?? [])
                .OfType<JsonObject>().Select(item => item.DeepClone().AsObject()).ToArray();
            if (lessonId == "review_dynamic") exercises = [exercises[0]];
            var sessionBundle = sourceBundle.DeepClone().AsObject();
            if (lessonId == "review_dynamic")
            {
                sessionBundle["lessonId"] = "review_dynamic";
                sessionBundle["lessonVersion"] = "review.dynamic.v1";
                sessionBundle["rewardIdentity"] = "review_dynamic";
                sessionBundle["exercises"] = new JsonArray(exercises[0].DeepClone());
            }
            var exerciseIds = exercises.Select(item => item.Text("id")!).ToArray();
            var answeredCorrectly = testCase["correct"]!.GetValue<bool>();
            var assisted = testCase["assisted"]!.GetValue<bool>();
            var retryWrong = testCase["retryWrong"]?.GetValue<bool>() ?? false;
            SeedCompletionCase(factory.Driver, completion, testCase, sourceBundle, sessionBundle, exercises,
                answeredCorrectly, assisted, retryWrong);

            using var request = new HttpRequestMessage(HttpMethod.Post, $"/v1/sessions/{sessionId}/complete");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", user);
            request.Headers.Add("Idempotency-Key", testCase.Text("key")!);
            request.Content = JsonContent.Create(new { expectedRevision = exerciseIds.Length + (retryWrong ? 1 : 0) });
            using var response = await client.SendAsync(request);
            var bodyText = await response.Content.ReadAsStringAsync();
            var actualBody = JsonNode.Parse(bodyText);
            Assert.Equal(expected[index]!["status"]!.GetValue<int>(), (int)response.StatusCode);
            Match(expected[index]!["body"], actualBody, $"{testCase.Text("name")} completion response");

            var actualTables = new JsonObject();
            foreach (var table in completion["tables"]!.AsArray().Select(item => item!.GetValue<string>()))
            {
                var rows = factory.Driver.Rows.Where(pair => pair.Key.Table == table)
                    .Where(pair => table switch
                    {
                        "l_outbox" => pair.Value.Data.Text("aggregateId") == sessionId,
                        "l_answers" => pair.Value.Data.Text("sessionId") == sessionId,
                        "l_receipts" => pair.Value.Data.Text("userId") == user && pair.Value.Data.Text("operation") == "completeSession",
                        _ => pair.Value.Data.Text("userId") == user
                    })
                    .OrderBy(pair => pair.Key.Id, StringComparer.Ordinal)
                    .Select(pair => ProjectCompletionRow(table, pair.Key.Id, pair.Value.Data)).ToArray();
                actualTables[table] = new JsonArray(rows);
            }
            Match(expected[index]!["tables"], actualTables, $"{testCase.Text("name")} persisted completion effects");
        }
    }

    private static void SeedCompletionCase(Driver driver, JsonObject completion, JsonObject testCase,
        JsonObject sourceBundle, JsonObject sessionBundle, JsonObject[] exercises, bool correct, bool assisted, bool retryWrong)
    {
        var user = testCase.Text("user")!;
        var sessionId = testCase.Text("sessionId")!;
        var now = DateTimeOffset.Parse(completion.Text("now")!, CultureInfo.InvariantCulture);
        var nowIso = OwnerSchema.Iso(now);
        var earlierIso = OwnerSchema.Iso(now.AddDays(-1));
        var exerciseCount = exercises.Length;
        var expectedRevision = exerciseCount + (retryWrong ? 1 : 0);
        if (testCase.Text("enrollment") != "none")
        {
            var completedLessons = testCase.Text("enrollment") is "mastery" or "checkpoint"
                ? new[] { "u1n1l1", "u1n1l2", "u1n1l3", "u1n1l4" }
                : [];
            driver.Seed("l_enrollments", CanonicalWire.RowId("enrollment", user, "vi_en"), new JsonObject
            {
                ["userId"] = user, ["courseId"] = "vi_en", ["courseVersion"] = "v2",
                ["frontierNodeOrder"] = completedLessons.Length > 0 ? 1 : 0,
                ["completedLessonsJson"] = JsonSerializer.Serialize(completedLessons),
                ["masteredNodesJson"] = "[]", ["legendaryNodesJson"] = "[]", ["placementUsed"] = false,
                ["active"] = true, ["proficiencyScore"] = 0, ["lastPracticedAt"] = null, ["removedAt"] = null,
                ["revision"] = 4, ["createdAt"] = earlierIso, ["updatedAt"] = earlierIso
            });
        }
        var bundleSnapshot = testCase.Text("lessonId") == "review_dynamic" ? CanonicalWire.Json(sessionBundle) : null;
        driver.Seed("l_sessions", sessionId, new JsonObject
        {
            ["userId"] = user, ["courseId"] = "vi_en", ["lessonId"] = testCase.Text("lessonId"),
            ["lessonVersion"] = sessionBundle.Text("lessonVersion"), ["rewardIdentity"] = sessionBundle.Text("rewardIdentity"),
            ["mode"] = testCase.Text("mode"), ["source"] = "ONLINE", ["status"] = "ACTIVE",
            ["activityId"] = null, ["opponentId"] = null, ["bundleHash"] = sourceBundle.Text("manifestHash"),
            ["bundleSnapshotJson"] = bundleSnapshot, ["nextOriginalOrdinal"] = exerciseCount, ["retryPass"] = retryWrong ? 1 : 0,
            ["assisted"] = assisted, ["energySpent"] = 0, ["energyEarned"] = 0, ["startedAt"] = earlierIso,
            ["expiresAt"] = OwnerSchema.Iso(now.AddDays(1)), ["completedAt"] = null, ["resultJson"] = "{}",
            ["revision"] = expectedRevision, ["createdAt"] = earlierIso, ["updatedAt"] = nowIso
        });
        driver.Seed("l_active_slots", CanonicalWire.RowId("slot", user, "vi_en"), new JsonObject
        {
            ["userId"] = user, ["courseId"] = "vi_en", ["sessionId"] = sessionId,
            ["expiresAt"] = OwnerSchema.Iso(now.AddDays(1)), ["createdAt"] = earlierIso, ["updatedAt"] = nowIso, ["revision"] = 0
        });

        var vocabularyIds = new HashSet<string>(StringComparer.Ordinal);
        foreach (var exercise in exercises)
        {
            var exerciseId = exercise.Text("id")!;
            var attemptResults = retryWrong && exerciseId == exercises[0].Text("id")
                ? new[] { false, true }
                : new[] { correct };
            for (var attemptOrdinal = 0; attemptOrdinal < attemptResults.Length; attemptOrdinal++)
            {
                var receivedAt = OwnerSchema.Iso(now.AddMilliseconds(attemptOrdinal));
                driver.Seed("l_answers", CanonicalWire.RowId("answer", sessionId, exerciseId, attemptOrdinal.ToString(CultureInfo.InvariantCulture)), new JsonObject
                {
                    ["sessionId"] = sessionId, ["userId"] = user, ["exerciseId"] = exerciseId, ["attemptOrdinal"] = attemptOrdinal,
                    ["answerJson"] = "{}", ["correct"] = attemptResults[attemptOrdinal], ["assisted"] = assisted, ["substituted"] = false,
                    ["receivedAt"] = receivedAt, ["resultJson"] = "{}", ["createdAt"] = receivedAt, ["updatedAt"] = receivedAt, ["revision"] = 0
                });
            }
            foreach (var value in exercise["vocabularyIds"] as JsonArray ?? [])
                if (value?.GetValue<string>() is { } vocabularyId) vocabularyIds.Add(vocabularyId);
            driver.Seed("l_mistakes", CanonicalWire.RowId("mistake", user, "vi_en", exerciseId), new JsonObject
            {
                ["userId"] = user, ["courseId"] = "vi_en", ["exerciseId"] = exerciseId,
                ["lessonVersion"] = sourceBundle.Text("lessonVersion"),
                ["skillId"] = (exercise["skillIds"] as JsonArray)?.FirstOrDefault()?.GetValue<string>() ?? "general",
                ["lastSessionId"] = "prior-session", ["mistakeCount"] = 1, ["lastMistakeAt"] = earlierIso,
                ["resolvedAt"] = null, ["revision"] = 0, ["createdAt"] = earlierIso, ["updatedAt"] = earlierIso
            });
        }
        foreach (var vocabularyId in vocabularyIds)
        {
            var firstSeenAt = OwnerSchema.Iso(now.AddDays(-10));
            driver.Seed("l_review_items", CanonicalWire.RowId("review", user, "vi_en", vocabularyId), new JsonObject
            {
                ["userId"] = user, ["courseId"] = "vi_en", ["vocabularyId"] = vocabularyId, ["skillId"] = "u1.vocab",
                ["stage"] = 2, ["dueAt"] = earlierIso, ["firstAttemptWindowJson"] = "[true,false,true,false,true]",
                ["lastReviewedAt"] = earlierIso, ["firstSeenAt"] = firstSeenAt, ["correctCount"] = 3,
                ["incorrectCount"] = 1, ["halfLifeHours"] = 72, ["revision"] = 0,
                ["createdAt"] = firstSeenAt, ["updatedAt"] = earlierIso
            });
        }
    }

    private static JsonObject ProjectCompletionRow(string table, string id, JsonObject data)
    {
        var projected = ProjectRow(table, id, data);
        var row = projected["row"]!.AsObject();
        if (table == "l_sessions" && row["resultJson"] is JsonObject result && result["eventId"] is not null)
            result["eventId"] = "<generated-event-id>";
        if (table == "l_outbox")
        {
            projected["id"] = "<generated-event-id>";
            row["eventId"] = "<generated-event-id>";
            if (row["payloadJson"] is JsonObject payload && payload["eventId"] is not null)
                payload["eventId"] = "<generated-event-id>";
        }
        return projected;
    }

    private static IReadOnlyDictionary<string, string> CompletionContentOverrides()
    {
        var files = ContentHandler.Files.ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.Ordinal);
        var manifest = JsonNode.Parse(ContentHandler.ManifestText)!.AsObject();
        foreach (var (lessonId, modeConfig) in new[]
        {
            ("u1n1l1", new JsonObject
            {
                ["modes"] = new JsonArray("STORIES", "ADVENTURE", "RADIO", "SIDE_QUEST", "CLASH", "UNIT_REVIEW", "TEST_OUT"),
                ["passThreshold"] = 0.8, ["opponents"] = new JsonArray("coach"), ["defaultOpponentId"] = "coach"
            }),
            ("u1n2l1", new JsonObject { ["modes"] = new JsonArray("CHECKPOINT"), ["passThreshold"] = 0.8 })
        })
        {
            var index = (manifest["bundles"] as JsonArray ?? []).OfType<JsonObject>().First(item => item.Text("lessonId") == lessonId);
            var fileId = index.Text("fileId")!;
            var bundle = JsonNode.Parse(files[fileId])!.AsObject();
            bundle["modeConfig"] = modeConfig.DeepClone();
            bundle["signatureKeyId"] = "dev-content-1";
            bundle["signature"] = SignContent(LearningIntegrity.SigningInput(bundle));
            var bundleText = CanonicalWire.Json(bundle);
            files[fileId] = bundleText;
            index["sha256"] = CanonicalWire.Sha256(bundleText);
        }
        manifest["manifestHash"] = LearningIntegrity.StructureHash(manifest);
        manifest["signatureKeyId"] = "dev-content-1";
        manifest["signature"] = SignContent(LearningIntegrity.SigningInput(manifest));
        files[ContentHandler.ManifestFileId] = CanonicalWire.Json(manifest);
        return files;
    }

    private static JsonObject BundleFrom(IReadOnlyDictionary<string, string> files, string lessonId)
    {
        var manifest = JsonNode.Parse(files[ContentHandler.ManifestFileId])!.AsObject();
        var index = (manifest["bundles"] as JsonArray ?? []).OfType<JsonObject>().FirstOrDefault(item => item.Text("lessonId") == lessonId)
            ?? (manifest["placementBundle"] is JsonObject placement && placement.Text("lessonId") == lessonId ? placement : null)
            ?? throw new InvalidOperationException($"Missing test bundle {lessonId}");
        return JsonNode.Parse(files[index.Text("fileId")!])!.AsObject();
    }

    private static string SignContent(string text)
    {
        var secret = new Ed25519PrivateKeyParameters(SHA256.HashData(Encoding.UTF8.GetBytes("cocenglish-dev-only:content-signing")), 0);
        var signer = new Ed25519Signer();
        signer.Init(true, secret);
        var bytes = Encoding.UTF8.GetBytes(text);
        signer.BlockUpdate(bytes, 0, bytes.Length);
        return Convert.ToBase64String(signer.GenerateSignature()).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    }

    private static string Resource(string name)
    {
        using var stream = typeof(LearningNodeParityTests).Assembly.GetManifestResourceStream($"CocEnglish.Learning.Parity.{name}.json")!;
        using var reader = new StreamReader(stream, Encoding.UTF8);
        return reader.ReadToEnd();
    }

    private static JsonObject ProjectRow(string table, string id, JsonObject data)
    {
        var row = data.DeepClone().AsObject();
        foreach (var key in row.Select(pair => pair.Key).ToArray())
            if (key.EndsWith("Json", StringComparison.Ordinal) && row.Text(key) is { } json)
                row[key] = JsonNode.Parse(json);
        if (table == "l_sessions" && row.Text("source") == "OFFLINE" && row["resultJson"] is JsonObject result && result["eventId"] is not null)
            result["eventId"] = "<generated-event-id>";
        // Node stores this absent optional value as undefined; ASP.NET's row contract stores null.
        row.Remove("opponentId");
        return new JsonObject { ["id"] = id, ["row"] = row };
    }

    private static JsonObject ProjectEventRow(string table, string id, JsonObject data)
    {
        var projected = ProjectRow(table, id, data);
        var row = projected["row"]!.AsObject();
        if (table == "l_outbox" && row.Text("type") == "account.purged.v1")
        {
            projected["id"] = "<generated-ack-id>";
            row["eventId"] = "<generated-ack-id>";
            if (row["payloadJson"] is JsonObject payload)
                payload["eventId"] = "<generated-ack-id>";
        }
        return projected;
    }

    private static void Match(JsonNode? expected, JsonNode? actual, string context)
    {
        var difference = Difference(expected, actual, "$");
        Assert.True(difference is null, context + ": " + difference);
    }

    private static string? Difference(JsonNode? expected, JsonNode? actual, string path)
    {
        if (expected is JsonObject obj && actual is JsonObject other)
        {
            foreach (var key in obj.Select(pair => pair.Key).Union(other.Select(pair => pair.Key)).Order(StringComparer.Ordinal))
            {
                if (!obj.ContainsKey(key) || !other.ContainsKey(key)) return path + "." + key + ": missing or unexpected field";
                if (Difference(obj[key], other[key], path + "." + key) is { } failure) return failure;
            }
            return null;
        }
        if (expected is JsonArray array && actual is JsonArray otherArray)
        {
            if (array.Count != otherArray.Count) return $"{path}: expected {array.Count} entries, actual {otherArray.Count}";
            for (var index = 0; index < array.Count; index++)
                if (Difference(array[index], otherArray[index], $"{path}[{index}]") is { } failure) return failure;
            return null;
        }
        return JsonNode.DeepEquals(expected, actual) ? null : $"{path}: expected {expected?.ToJsonString() ?? "null"}, actual {actual?.ToJsonString() ?? "null"}";
    }

    private sealed class LearningApiFixture : WebApplicationFactory<Learning.Program>
    {
        private static readonly string ContentPublicKey = Convert.ToHexString(new Ed25519PrivateKeyParameters(
            SHA256.HashData(Encoding.UTF8.GetBytes("cocenglish-dev-only:content-signing")), 0).GeneratePublicKey().GetEncoded());

        public Driver Driver { get; } = new();
        public DateTimeOffset Now { get; set; }
        public IReadOnlyDictionary<string, string>? ContentOverrides { get; set; }
        public bool UseParityRelay { get; init; }
        public ParityRelay Relay { get; } = new();

        public void ApplyContentOverrides()
        {
            if (ContentOverrides is null) return;
            var manifestText = ContentOverrides[ContentHandler.ManifestFileId];
            Driver.Seed("l_content_versions", CanonicalWire.RowId("content-version", "vi_en", "v2"), new JsonObject
            {
                ["courseId"] = "vi_en", ["versionId"] = "v2", ["manifestFileId"] = ContentHandler.ManifestFileId,
                ["manifestSha256"] = CanonicalWire.Sha256(manifestText), ["publishedAt"] = "2026-11-03T12:00:00.000Z", ["retiredAt"] = null
            });
        }

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.ConfigureAppConfiguration((_, configuration) => configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1",
                ["APPWRITE_PROJECT_ID"] = "learning-parity",
                ["COC_LEARNING_APPWRITE_KEY"] = "test-only-key",
                ["COC_LEARNING_PERSISTENCE"] = "appwrite",
                ["COC_LEARNING_ADMITTED"] = "reviewed-cloud-gate",
                ["COC_LEARNING_WORKER_ENABLED"] = "false",
                ["BUILD_ID"] = "local-scaffold",
                ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"parity-progress\",\"sender\":\"progress\",\"secretHex\":\"" + string.Concat(Enumerable.Repeat("11", 32)) + "\"},{\"keyId\":\"parity-scheduler\",\"sender\":\"scheduler\",\"secretHex\":\"" + string.Concat(Enumerable.Repeat("22", 32)) + "\"},{\"keyId\":\"parity-learning\",\"sender\":\"learning\",\"secretHex\":\"" + string.Concat(Enumerable.Repeat("33", 32)) + "\"}]",
                ["COC_ENERGY_MODE"] = "UNLIMITED",
                ["COC_CONTENT_PUBLIC_KEYS"] = $"[{{\"keyId\":\"dev-content-1\",\"publicKeyHex\":\"{ContentPublicKey}\"}}]"
            }));
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<IRowDriver>();
                services.AddSingleton<IRowDriver>(Driver);
                services.RemoveAll<IIdentityVerifier>();
                services.AddSingleton<IIdentityVerifier, Identity>();
                services.RemoveAll<LearningStorageFiles>();
                services.AddSingleton(new LearningStorageFiles(new HttpClient(new ContentHandler(ContentOverrides)),
                    new(new Uri("https://appwrite.test/v1"), "learning-parity", "test-only-key")));
                services.RemoveAll<TimeProvider>();
                services.AddSingleton<TimeProvider>(new Clock(() => Now));
                if (UseParityRelay)
                {
                    services.RemoveAll<ILearningRelayTransport>();
                    services.AddSingleton<ILearningRelayTransport>(Relay);
                }
            });
        }
    }

    private sealed class ParityRelay : ILearningRelayTransport
    {
        public bool Configured => true;
        public List<JsonObject> Deliveries { get; } = [];

        public Task<LearningRelayOutcome> DeliverAsync(JsonObject envelope, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            Deliveries.Add(envelope.DeepClone().AsObject());
            return Task.FromResult(LearningRelayOutcome.Ack);
        }
    }

    private sealed class Clock(Func<DateTimeOffset> now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now();
    }

    private sealed class Identity : IIdentityVerifier
    {
        public bool Configured => true;
        public Task<VerifiedSubject> VerifyAsync(string jwt, CancellationToken cancellationToken) => Task.FromResult(new VerifiedSubject(jwt));
    }

    private sealed class ContentHandler : HttpMessageHandler
    {
        private static readonly (string ManifestFileId, IReadOnlyDictionary<string, string> Files) Content = LoadContent();
        private readonly IReadOnlyDictionary<string, string> _files;
        public ContentHandler(IReadOnlyDictionary<string, string>? files = null) => _files = files ?? Content.Files;
        public static string ManifestFileId => Content.ManifestFileId;
        public static string ManifestText => Content.Files[Content.ManifestFileId];
        public static IReadOnlyDictionary<string, string> Files => Content.Files;

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var segments = request.RequestUri!.AbsolutePath.Split('/', StringSplitOptions.RemoveEmptyEntries);
            var fileIndex = Array.LastIndexOf(segments, "files");
            var fileId = fileIndex >= 0 && fileIndex + 1 < segments.Length ? Uri.UnescapeDataString(segments[fileIndex + 1]) : "";
            return Task.FromResult(_files.TryGetValue(fileId, out var content)
                ? new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(content, Encoding.UTF8, "application/octet-stream") }
                : new HttpResponseMessage(HttpStatusCode.NotFound));
        }

        private static (string ManifestFileId, IReadOnlyDictionary<string, string> Files) LoadContent()
        {
            var directory = new DirectoryInfo(AppContext.BaseDirectory);
            while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "content", "vi_en", "dist", "v2", "publish.json")))
                directory = directory.Parent;
            if (directory is null) throw new DirectoryNotFoundException("Could not locate committed Learning content from the test output directory.");
            var contentRoot = Path.Combine(directory.FullName, "content", "vi_en", "dist", "v2");
            var publication = JsonNode.Parse(File.ReadAllText(Path.Combine(contentRoot, "publish.json")))!.AsObject();
            var files = new Dictionary<string, string>(StringComparer.Ordinal);
            foreach (var file in publication["files"]!.AsArray().OfType<JsonObject>())
            {
                var fileId = file["fileId"]!.GetValue<string>();
                var relativePath = file["path"]!.GetValue<string>().Replace('/', Path.DirectorySeparatorChar);
                files[fileId] = File.ReadAllText(Path.Combine(contentRoot, relativePath));
            }
            return (publication["manifestFileId"]!.GetValue<string>(), files);
        }
    }

    private sealed class Driver : IRowDriver
    {
        public sealed record Stored(JsonObject Data, long Version);
        private readonly Dictionary<(string Table, string Id), Stored> _rows = [];
        private long _version;
        public string Owner => "learning";
        public bool Configured => true;
        public IReadOnlyDictionary<(string Table, string Id), Stored> Rows => _rows;

        public Driver()
        {
            _rows[("l_courses", CanonicalWire.RowId("course", "vi_en"))] = new(new JsonObject
            {
                ["courseId"] = "vi_en",
                ["title"] = "Tiếng Anh cho người Việt",
                ["sourceLocale"] = "vi-VN",
                ["targetLocale"] = "en-US",
                ["publishedVersion"] = "v2",
                ["status"] = "PUBLISHED"
            }, ++_version);
            _rows[("l_content_versions", CanonicalWire.RowId("content-version", "vi_en", "v2"))] = new(new JsonObject
            {
                ["courseId"] = "vi_en",
                ["versionId"] = "v2",
                ["manifestFileId"] = ContentHandler.ManifestFileId,
                ["manifestSha256"] = CanonicalWire.Sha256(ContentHandler.ManifestText),
                ["publishedAt"] = "2026-11-03T12:00:00.000Z",
                ["retiredAt"] = null
            }, ++_version);
        }

        public void Seed(string table, string id, JsonObject data) => _rows[(table, id)] = new(data.DeepClone().AsObject(), ++_version);

        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            return Task.FromResult(_rows.TryGetValue((table, id), out var stored)
                ? new RowDocument(id, stored.Data.DeepClone().AsObject(), stored.Version.ToString(CultureInfo.InvariantCulture))
                : null);
        }

        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            IEnumerable<KeyValuePair<(string Table, string Id), Stored>> selected = _rows.Where(pair => pair.Key.Table == table);
            foreach (var (key, value) in query.Where ?? new Dictionary<string, object?>())
                selected = selected.Where(pair => Equal(pair.Value.Data[key], value));
            foreach (var (key, values) in query.AnyOf ?? new Dictionary<string, string[]>())
                selected = selected.Where(pair => pair.Value.Data[key] is JsonValue scalar && scalar.TryGetValue<string>(out var value) && values.Contains(value, StringComparer.Ordinal));
            foreach (var (key, value) in query.GreaterThanEqual ?? new Dictionary<string, object?>())
                selected = selected.Where(pair => pair.Value.Data[key] is { } current && Compare(current, value) >= 0);
            foreach (var (key, value) in query.LessThan ?? new Dictionary<string, object?>())
                selected = selected.Where(pair => pair.Value.Data[key] is { } current && Compare(current, value) < 0);
            foreach (var (key, value) in query.LessThanEqual ?? new Dictionary<string, object?>())
                selected = selected.Where(pair => pair.Value.Data[key] is { } current && Compare(current, value) <= 0);
            foreach (var order in query.OrderBy ?? [])
                selected = order.Descending
                    ? selected.OrderByDescending(pair => pair.Value.Data[order.Column]?.ToString(), StringComparer.Ordinal)
                    : selected.OrderBy(pair => pair.Value.Data[order.Column]?.ToString(), StringComparer.Ordinal);
            var rows = selected.Skip(query.Offset).Take(query.Limit).Select(pair => new RowDocument(
                pair.Key.Id,
                pair.Value.Data.DeepClone().AsObject(),
                pair.Value.Version.ToString(CultureInfo.InvariantCulture))).ToArray();
            return Task.FromResult<IReadOnlyList<RowDocument>>(rows);
        }

        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            return Task.FromResult((long)_rows.Count(pair => pair.Key.Table == table && where.All(filter => Equal(pair.Value.Data[filter.Key], filter.Value))));
        }

        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            lock (_rows)
            {
                foreach (var read in reads)
                {
                    var actual = _rows.TryGetValue((read.Table, read.Id), out var stored)
                        ? stored.Version.ToString(CultureInfo.InvariantCulture)
                        : null;
                    if (actual != read.Document?.Version) throw new TransactionConflictException();
                }
                foreach (var write in writes)
                {
                    var key = (write.Table, write.Id);
                    if (write.Action == "delete") _rows.Remove(key);
                    else _rows[key] = new(write.Data!.DeepClone().AsObject(), ++_version);
                }
            }
            return Task.CompletedTask;
        }

        private static bool Equal(JsonNode? node, object? value) => JsonNode.DeepEquals(node, JsonSerializer.SerializeToNode(value));

        private static int Compare(JsonNode node, object? value)
        {
            var other = JsonSerializer.SerializeToNode(value);
            if (node.GetValueKind() == System.Text.Json.JsonValueKind.Number && other?.GetValueKind() == System.Text.Json.JsonValueKind.Number)
                return node.GetValue<double>().CompareTo(other.GetValue<double>());
            return StringComparer.Ordinal.Compare(node.GetValue<string>(), other?.GetValue<string>());
        }
    }
}
