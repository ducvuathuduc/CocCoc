using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Learning;

public sealed record LearningOfflineAnswer(string ExerciseId, int AttemptOrdinal, JsonObject Answer, bool Assisted, bool Substituted);
public sealed record LearningOfflineCompletion(string OperationId, string LocalCompletionId, string CourseId, string LessonId,
    string LessonVersion, string BundleHash, long ExpectedEnrollmentRevision, IReadOnlyList<LearningOfflineAnswer> Answers);
public sealed record LearningOfflineSyncResult(ReceiptResult Receipt, string? EventId);

public sealed class LearningOfflineCompletionService(OwnerStore store, IRowDriver rows, ILearningContentReader content,
    TimeProvider clock, ILearningRelayTransport relay)
{
    public async Task<LearningOfflineSyncResult> SyncAsync(string userId, LearningOfflineCompletion body, string key,
        string bodyHash, string requestId, CancellationToken cancellationToken)
    {
        var sessionId = CanonicalWire.RowId("session", userId, "offline|" + body.LocalCompletionId);
        var existing = (await rows.ReadAsync("l_sessions", sessionId, cancellationToken))?.Data;
        if (existing is not null && existing.Text("userId") == userId && existing.Text("status") == "COMPLETED")
        {
            var replay = await store.CommitWithReceiptAsync(new(userId, "syncOfflineCompletion", key), bodyHash, async (tx, token) =>
            {
                var current = await tx.GetAsync("l_sessions", sessionId, token);
                if (current is null || current.Text("userId") != userId || current.Text("status") != "COMPLETED")
                    throw new ServiceException("NOT_FOUND");
                return new OperationResponse(200, ReplayCompletion(current, body));
            }, cancellationToken);
            return new(replay, null);
        }

        var manifest = await content.PublishedAsync(body.CourseId, cancellationToken);
        var bundle = await content.BundleByLessonVersionAsync(body.CourseId, body.LessonId, body.LessonVersion, cancellationToken);
        if (manifest["placementBundle"] is JsonObject placement && placement.Text("lessonId") == body.LessonId)
            throw RequestQuery.Bad("lessonId");
        if (CanonicalWire.Sha256(CanonicalWire.Json(bundle)) != body.BundleHash)
            throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "bundleHash", ["reason"] = "BUNDLE_MISMATCH" });

        var exercises = (bundle["exercises"] as JsonArray ?? []).OfType<JsonObject>().ToArray();
        var order = exercises.Select(exercise => exercise.Text("id") ?? "").ToArray();
        var byId = exercises.ToDictionary(exercise => exercise.Text("id") ?? "", StringComparer.Ordinal);
        var attempts = new List<LearningAttempt>(body.Answers.Count);
        for (var i = 0; i < body.Answers.Count; i++)
        {
            var answer = body.Answers[i];
            var expected = LearningSessionQueue.State(order, attempts);
            if (expected.NextExerciseId != answer.ExerciseId || expected.AttemptOrdinal != answer.AttemptOrdinal)
            {
                JsonNode? next = expected.NextExerciseId is null ? null : new JsonObject
                {
                    ["exerciseId"] = expected.NextExerciseId,
                    ["attemptOrdinal"] = expected.AttemptOrdinal
                };
                throw new ServiceException("VALIDATION_ERROR", new()
                {
                    ["field"] = $"answers[{i}]",
                    ["reason"] = "OUT_OF_ORDER",
                    ["expected"] = next
                });
            }
            var exercise = byId[answer.ExerciseId];
            var verdict = LearningGrading.Grade(LearningGrading.GradedExercise(exercise, answer.Substituted), answer.Answer);
            attempts.Add(new(answer.ExerciseId, answer.AttemptOrdinal, verdict.Correct, answer.Assisted));
        }

        var finalState = LearningSessionQueue.State(order, attempts);
        if (finalState.NextOriginalOrdinal < order.Length || finalState.NextExerciseId is not null)
            throw new ServiceException("SESSION_INCOMPLETE", new() { ["attempted"] = finalState.NextOriginalOrdinal, ["required"] = order.Length });
        var summary = LearningCompletionEffects.Tally(exercises, attempts);
        var index = (manifest["bundles"] as JsonArray ?? []).OfType<JsonObject>()
            .FirstOrDefault(item => item.Text("lessonId") == body.LessonId && item.Text("lessonVersion") == body.LessonVersion);
        var rewardIdentity = index?.Text("rewardIdentity") ?? bundle.Text("rewardIdentity") ?? body.LessonId;
        var logHash = LogHash(body);
        var eventId = (string?)null;

        var receipt = await store.CommitWithReceiptAsync(new(userId, "syncOfflineCompletion", key), bodyHash, async (tx, token) =>
        {
            eventId = null;
            var now = tx.Now;
            var completedAt = OwnerSchema.Iso(now);
            var prior = await tx.GetAsync("l_sessions", sessionId, token);
            if (prior?.Text("status") == "COMPLETED") return new OperationResponse(200, ReplayCompletion(prior, body));

            var enrollmentId = CanonicalWire.RowId("enrollment", userId, body.CourseId);
            var enrollment = await tx.GetAsync("l_enrollments", enrollmentId, token);
            if (enrollment is null || !string.IsNullOrEmpty(enrollment.Text("removedAt")))
                throw new ServiceException("NOT_FOUND", new() { ["courseId"] = body.CourseId, ["reason"] = "NOT_ENROLLED" });
            var currentRevision = enrollment.Number("revision");
            if (currentRevision != body.ExpectedEnrollmentRevision)
                throw new ServiceException("REVISION_CONFLICT", new() { ["currentRevision"] = currentRevision });

            LearningPath.AssertLessonUnlocked(manifest, enrollment, body.LessonId);
            enrollment = LearningPath.CompleteLesson(manifest, enrollment, body.LessonId);
            enrollment["lastPracticedAt"] = completedAt;
            var enrollmentRevision = enrollment.Number("revision") + 1;
            tx.Put("l_enrollments", enrollmentId, enrollment);

            await LearningCompletionEffects.StageReviewUpdatesAsync(tx, userId, body.CourseId, exercises, attempts, advance: false, token);
            await LearningCompletionEffects.StageMistakesAsync(tx, userId, body.CourseId, sessionId, body.LessonVersion, "LESSON", exercises, attempts, token);

            eventId = Guid.NewGuid().ToString();
            var completion = new JsonObject
            {
                ["completionId"] = sessionId,
                ["sessionId"] = sessionId,
                ["originalCount"] = summary.OriginalCount,
                ["originalCorrect"] = summary.OriginalCorrect,
                ["assisted"] = summary.Assisted,
                ["source"] = "OFFLINE",
                ["mode"] = "LESSON",
                ["completedAt"] = completedAt,
                ["enrollmentRevision"] = enrollmentRevision,
                ["rewardStatus"] = "pending",
                ["needsReviewIds"] = new JsonArray(summary.NeedsReviewIds.Select(id => (JsonNode?)JsonValue.Create(id)).ToArray())
            };
            var envelope = new JsonObject
            {
                ["eventId"] = eventId,
                ["type"] = "lesson.completed.v1",
                ["schemaVersion"] = 1,
                ["producer"] = "learning",
                ["aggregateId"] = sessionId,
                ["occurredAt"] = completedAt,
                ["requestId"] = requestId[..Math.Min(requestId.Length, 64)],
                ["payload"] = new JsonObject
                {
                    ["completionId"] = sessionId,
                    ["userId"] = userId,
                    ["courseId"] = body.CourseId,
                    ["lessonVersion"] = body.LessonVersion,
                    ["rewardIdentity"] = rewardIdentity,
                    ["source"] = "OFFLINE",
                    ["mode"] = "LESSON",
                    ["originalCount"] = summary.OriginalCount,
                    ["originalCorrect"] = summary.OriginalCorrect,
                    ["assisted"] = summary.Assisted
                }
            };
            tx.Put("l_outbox", eventId, new JsonObject
            {
                ["eventId"] = eventId,
                ["type"] = "lesson.completed.v1",
                ["schemaVersion"] = 1,
                ["aggregateId"] = sessionId,
                ["occurredAt"] = completedAt,
                ["payloadJson"] = CanonicalWire.Stringify(envelope),
                ["attempt"] = 0,
                ["nextAttemptAt"] = completedAt,
                ["leaseOwner"] = null,
                ["leaseUntil"] = null,
                ["status"] = "PENDING",
                ["ackAt"] = null
            });
            tx.Put("l_sessions", sessionId, new JsonObject
            {
                ["userId"] = userId,
                ["courseId"] = body.CourseId,
                ["lessonId"] = body.LessonId,
                ["lessonVersion"] = body.LessonVersion,
                ["rewardIdentity"] = rewardIdentity,
                ["mode"] = "LESSON",
                ["source"] = "OFFLINE",
                ["status"] = "COMPLETED",
                ["bundleHash"] = body.BundleHash,
                ["bundleSnapshotJson"] = null,
                ["nextOriginalOrdinal"] = order.Length,
                ["retryPass"] = finalState.RetryPass,
                ["assisted"] = summary.Assisted,
                ["energySpent"] = 0,
                ["energyEarned"] = 0,
                ["startedAt"] = completedAt,
                ["expiresAt"] = completedAt,
                ["completedAt"] = completedAt,
                ["resultJson"] = CanonicalWire.Stringify(new JsonObject
                {
                    ["completion"] = completion.DeepClone(),
                    ["eventId"] = eventId,
                    ["logHash"] = logHash
                })
            });
            return new OperationResponse(200, completion);
        }, cancellationToken);

        if (receipt.Status == "created" && eventId is not null)
        {
            try
            {
                await LearningImmediateRelay.DispatchAsync(store, relay, clock, [eventId], "offline-" + eventId[..8], cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { throw; }
            catch { /* The durable dispatcher retries the staged event. */ }
        }
        return new(receipt, eventId);
    }

    private static JsonNode? ReplayCompletion(JsonObject session, LearningOfflineCompletion body)
    {
        JsonObject? stored;
        try { stored = JsonNode.Parse(session.Text("resultJson") ?? "null") as JsonObject; }
        catch (JsonException) { stored = null; }
        if (stored?.Text("logHash") is { } logHash && logHash != LogHash(body))
            throw new ServiceException("IDEMPOTENCY_CONFLICT", new() { ["localCompletionId"] = body.LocalCompletionId });
        return stored?["completion"]?.DeepClone();
    }

    private static string LogHash(LearningOfflineCompletion body) => CanonicalWire.BodyHash(new JsonObject
    {
        ["courseId"] = body.CourseId,
        ["lessonId"] = body.LessonId,
        ["lessonVersion"] = body.LessonVersion,
        ["bundleHash"] = body.BundleHash,
        ["answers"] = new JsonArray(body.Answers.Select(answer => (JsonNode)new JsonObject
        {
            ["exerciseId"] = answer.ExerciseId,
            ["attemptOrdinal"] = answer.AttemptOrdinal,
            ["answer"] = answer.Answer.DeepClone(),
            ["assisted"] = answer.Assisted,
            ["substituted"] = answer.Substituted
        }).ToArray())
    });
}

[ApiController]
public sealed class LearningOfflineCompletionController(OwnerStore store, IRowDriver rows, ILearningContentReader content,
    ILearningRelayTransport relay, TimeProvider clock) : ControllerBase
{
    private const string UuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$";
    private const string ShaPattern = "^[a-f0-9]{64}$";
    private static readonly string[] Fields = ["operationId", "localCompletionId", "courseId", "lessonId", "lessonVersion", "bundleHash", "expectedEnrollmentRevision", "answers"];
    private static readonly string[] AnswerFields = ["exerciseId", "attemptOrdinal", "answer", "assisted", "substituted"];

    /// <summary>Regrade an offline answer log against its signed lesson and commit its completion once.</summary>
    [HttpPost("/v1/offline-completions")]
    [ContractOperation("syncOfflineCompletion")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<IActionResult> Sync(CancellationToken cancellationToken)
    {
        var input = (HttpContext.Items[typeof(ParsedRequestBody)] as ParsedRequestBody)?.Value as JsonObject ?? throw Invalid("body");
        LearningSessionController.Exact(input, Fields, "body");
        var operationId = Uuid(input["operationId"], "body.operationId");
        var localCompletionId = Uuid(input["localCompletionId"], "body.localCompletionId");
        var courseId = LearningSessionController.Id(input["courseId"], "body.courseId");
        var lessonId = LearningSessionController.Id(input["lessonId"], "body.lessonId");
        var lessonVersion = LearningSessionController.Id(input["lessonVersion"], "body.lessonVersion");
        var bundleHash = Sha(input["bundleHash"], "body.bundleHash");
        var enrollmentRevision = LearningSessionController.Integer(input["expectedEnrollmentRevision"], "body.expectedEnrollmentRevision", 0, int.MaxValue);
        if (input["answers"] is not JsonArray rawAnswers || rawAnswers.Count > 60) throw Invalid("body.answers");
        var answers = new List<LearningOfflineAnswer>(rawAnswers.Count);
        for (var i = 0; i < rawAnswers.Count; i++)
        {
            var field = $"body.answers[{i}]";
            if (rawAnswers[i] is not JsonObject answer) throw Invalid(field);
            LearningSessionController.Exact(answer, AnswerFields, field);
            answers.Add(new(
                LearningSessionController.Id(answer["exerciseId"], field + ".exerciseId"),
                checked((int)LearningSessionController.Integer(answer["attemptOrdinal"], field + ".attemptOrdinal", 0, 2)),
                LearningSessionController.ParseAnswer(answer["answer"], field + ".answer"),
                LearningSessionController.Boolean(answer["assisted"], field + ".assisted"),
                LearningSessionController.Boolean(answer["substituted"], field + ".substituted")));
        }

        var body = new LearningOfflineCompletion(operationId, localCompletionId, courseId, lessonId, lessonVersion,
            bundleHash, enrollmentRevision, answers);
        var normalized = new JsonObject
        {
            ["operationId"] = operationId,
            ["localCompletionId"] = localCompletionId,
            ["courseId"] = courseId,
            ["lessonId"] = lessonId,
            ["lessonVersion"] = lessonVersion,
            ["bundleHash"] = bundleHash,
            ["expectedEnrollmentRevision"] = enrollmentRevision,
            ["answers"] = new JsonArray(answers.Select(answer => (JsonNode)new JsonObject
            {
                ["exerciseId"] = answer.ExerciseId,
                ["attemptOrdinal"] = answer.AttemptOrdinal,
                ["answer"] = answer.Answer.DeepClone(),
                ["assisted"] = answer.Assisted,
                ["substituted"] = answer.Substituted
            }).ToArray())
        };
        var bodyHash = CanonicalWire.BodyHash(new JsonObject
        {
            ["operation"] = "syncOfflineCompletion",
            ["params"] = new JsonObject(),
            ["body"] = normalized
        });
        var key = Request.Headers["Idempotency-Key"].ToString();
        if (!Regex.IsMatch(key, UuidPattern, RegexOptions.CultureInvariant | RegexOptions.IgnoreCase)) throw Invalid("Idempotency-Key");
        key = key.ToLowerInvariant();
        var userId = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        var result = await new LearningOfflineCompletionService(store, rows, content, clock, relay).SyncAsync(
            userId, body, key, bodyHash, Response.Headers["X-Request-ID"].ToString(), cancellationToken);
        return new ObjectResult(result.Receipt.Body) { StatusCode = result.Receipt.StatusCode };
    }

    private static string Uuid(JsonNode? node, string field)
    {
        if (node?.GetValueKind() != System.Text.Json.JsonValueKind.String) throw Invalid(field);
        var value = node.GetValue<string>();
        return Regex.IsMatch(value, UuidPattern, RegexOptions.CultureInvariant) ? value.ToLowerInvariant() : throw Invalid(field);
    }

    private static string Sha(JsonNode? node, string field)
    {
        if (node?.GetValueKind() != System.Text.Json.JsonValueKind.String) throw Invalid(field);
        var value = node.GetValue<string>();
        return Regex.IsMatch(value, ShaPattern, RegexOptions.CultureInvariant) ? value : throw Invalid(field);
    }

    private static ServiceException Invalid(string field, string reason = "INVALID") => new("VALIDATION_ERROR", new() { ["field"] = field, ["reason"] = reason });
}
