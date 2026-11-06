using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;

namespace CocEnglish.Learning;

public sealed record LearningCompletionResult(ReceiptResult Receipt, string? EventId);

public sealed class LearningSessions(OwnerStore store, IRowDriver rows, ILearningContentReader content, TimeProvider clock, IConfiguration config)
{
    private static readonly HashSet<string> Modes = ["LESSON", "REVIEW", "MASTERY", "PLACEMENT", "STORIES", "ADVENTURE", "RADIO", "SIDE_QUEST", "CLASH", "UNIT_REVIEW", "TEST_OUT", "CHECKPOINT"];
    private static readonly HashSet<string> AuthoredModes = ["STORIES", "ADVENTURE", "RADIO", "SIDE_QUEST", "CLASH", "UNIT_REVIEW", "TEST_OUT", "CHECKPOINT"];
    private static readonly HashSet<string> GateModes = ["TEST_OUT", "CHECKPOINT"];

    public async Task<ReceiptResult> StartAsync(string user, string courseId, string lessonId, string mode, long expectedEnrollmentRevision,
        string key, string bodyHash, string? activityId, string? requestedOpponentId, CancellationToken ct)
    {
        if (!Modes.Contains(mode)) throw Invalid("mode");
        var manifest = await content.PublishedAsync(courseId, ct);
        JsonObject index;
        JsonObject bundle;
        string? bundleSnapshot = null;
        if (mode == "PLACEMENT")
        {
            index = manifest["placementBundle"] as JsonObject ?? throw new ServiceException("NOT_FOUND", new() { ["lessonId"] = lessonId });
            if (index.Text("lessonId") != lessonId) throw new ServiceException("NOT_FOUND", new() { ["lessonId"] = lessonId });
            bundle = await content.BundleAsync(manifest, lessonId, ct);
        }
        else if (mode == "REVIEW")
        {
            if (lessonId != LearningReviewBundleBuilder.ReviewLessonId)
                throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "lessonId", ["expected"] = LearningReviewBundleBuilder.ReviewLessonId });
            var enrollmentPreview = (await rows.ReadAsync("l_enrollments", CanonicalWire.RowId("enrollment", user, courseId), ct))?.Data;
            if (enrollmentPreview is null || !string.IsNullOrEmpty(enrollmentPreview.Text("removedAt")))
                throw new ServiceException("NOT_FOUND", new() { ["courseId"] = courseId, ["reason"] = "NOT_ENROLLED" });
            var review = await LearningReviewBundleBuilder.BuildAsync(rows, content, manifest, enrollmentPreview, user, courseId,
                user + "|" + key, clock.GetUtcNow(), ct);
            bundle = review.Bundle;
            bundleSnapshot = review.Snapshot;
            index = new JsonObject
            {
                ["lessonId"] = LearningReviewBundleBuilder.ReviewLessonId,
                ["lessonVersion"] = review.Bundle.Text("lessonVersion"),
                ["rewardIdentity"] = LearningReviewBundleBuilder.ReviewLessonId,
                ["sha256"] = review.Hash
            };
        }
        else
        {
            index = (manifest["bundles"] as JsonArray ?? []).OfType<JsonObject>().FirstOrDefault(item => item.Text("lessonId") == lessonId)
                ?? throw new ServiceException(AuthoredModes.Contains(mode) ? "ACTIVITY_NOT_FOUND" : "NOT_FOUND", new() { ["lessonId"] = lessonId });
            bundle = await content.BundleAsync(manifest, lessonId, ct);
            AssertAuthoredMode(bundle, mode);
            if (mode == "CLASH") requestedOpponentId = ResolveOpponent(bundle, requestedOpponentId);
        }
        var sessionId = CanonicalWire.RowId("session", user, key);
        var enrollmentId = CanonicalWire.RowId("enrollment", user, courseId);
        return await store.CommitWithReceiptAsync(new(user, "startSession", key), bodyHash, async (tx, token) => {
            var enrollment = await tx.GetAsync("l_enrollments", enrollmentId, token);
            if (enrollment is not null && !string.IsNullOrEmpty(enrollment.Text("removedAt"))) enrollment = null;
            var currentRevision = enrollment?.Number("revision") ?? 0;
            if (mode == "PLACEMENT")
            {
                if (enrollment is not null && (enrollment.Flag("placementUsed") || ReadStrings(enrollment.Text("completedLessonsJson")).Count > 0))
                    throw new ServiceException("NODE_LOCKED", new() { ["reason"] = "PLACEMENT_UNAVAILABLE" });
            }
            else if (enrollment is null)
                throw new ServiceException("NOT_FOUND", new() { ["courseId"] = courseId, ["reason"] = "NOT_ENROLLED" });
            if (currentRevision != expectedEnrollmentRevision) throw new ServiceException("REVISION_CONFLICT", new() { ["currentRevision"] = currentRevision });
            if (enrollment is not null && mode == "LESSON") LearningPath.AssertLessonUnlocked(manifest, enrollment, lessonId);
            if (enrollment is not null && mode == "MASTERY") LearningPath.AssertMasteryUnlocked(manifest, enrollment, lessonId);
            if (enrollment is not null && mode == "CHECKPOINT") LearningPath.AssertCheckpointUnlocked(manifest, enrollment, lessonId);
            if (mode is "LESSON" or "MASTERY")
            {
                var energyId = CanonicalWire.RowId("energy", user);
                LearningEnergy.AssertCanStart(await tx.GetAsync("l_energy", energyId, token), tx.Now, config["COC_ENERGY_MODE"] ?? "UNLIMITED", mode);
            }

            var slotId = CanonicalWire.RowId("slot", user, courseId);
            var slot = await tx.GetAsync("l_active_slots", slotId, token);
            if (slot is not null)
            {
                var activeId = slot.Text("sessionId") ?? "";
                var holder = await tx.GetAsync("l_sessions", activeId, token);
                if (holder?.Text("status") == "ACTIVE")
                {
                    var expiry = ParseDate(holder.Text("expiresAt"));
                    if (expiry > tx.Now) throw new ServiceException("SESSION_CONFLICT", new() { ["activeSessionId"] = activeId, ["expiresAt"] = holder.Text("expiresAt") });
                    holder["status"] = "EXPIRED";
                    tx.Put("l_sessions", activeId, holder);
                }
            }
            var expiresAt = OwnerSchema.Iso(tx.Now.AddHours(24));
            tx.Put("l_active_slots", slotId, new JsonObject { ["userId"] = user, ["courseId"] = courseId, ["sessionId"] = sessionId, ["expiresAt"] = expiresAt });
            tx.Put("l_sessions", sessionId, new JsonObject {
                ["userId"] = user, ["courseId"] = courseId, ["lessonId"] = lessonId,
                ["lessonVersion"] = index.Text("lessonVersion"), ["rewardIdentity"] = index.Text("rewardIdentity"), ["mode"] = mode,
                ["activityId"] = activityId, ["opponentId"] = requestedOpponentId,
                ["source"] = "ONLINE", ["status"] = "ACTIVE", ["bundleHash"] = index.Text("sha256"), ["bundleSnapshotJson"] = bundleSnapshot,
                ["nextOriginalOrdinal"] = 0, ["retryPass"] = 0, ["assisted"] = false, ["energySpent"] = 0, ["energyEarned"] = 0,
                ["startedAt"] = tx.NowIso, ["expiresAt"] = expiresAt, ["completedAt"] = null, ["resultJson"] = "{}"
            });
            return new OperationResponse(200, new JsonObject { ["sessionRef"] = sessionId });
        }, ct);
    }

    private static void AssertAuthoredMode(JsonObject bundle, string mode)
    {
        if (!AuthoredModes.Contains(mode)) return;
        var config = bundle["modeConfig"] as JsonObject;
        if (config?["modes"] is JsonArray modes && !modes.Any(value => value?.GetValueKind() == System.Text.Json.JsonValueKind.String && value.GetValue<string>() == mode))
            throw new ServiceException("MODE_UNAVAILABLE", new() { ["mode"] = mode, ["lessonId"] = bundle.Text("lessonId"), ["reason"] = "MODE_NOT_AUTHORED" });
        if (GateModes.Contains(mode) && !ValidThreshold(config?["passThreshold"]))
            throw new ServiceException("MODE_UNAVAILABLE", new() { ["mode"] = mode, ["lessonId"] = bundle.Text("lessonId"), ["reason"] = "PASS_THRESHOLD_MISSING" });
    }

    private static bool ValidThreshold(JsonNode? value) => value is JsonValue scalar && scalar.GetValueKind() == System.Text.Json.JsonValueKind.Number &&
        scalar.TryGetValue<double>(out var threshold) && double.IsFinite(threshold) && threshold is >= 0 and <= 1;

    private static string? ResolveOpponent(JsonObject bundle, string? requested)
    {
        var config = bundle["modeConfig"] as JsonObject;
        if (requested is null) return config?.Text("defaultOpponentId");
        var known = (config?["opponents"] as JsonArray ?? []).Any(value => value?.GetValueKind() == System.Text.Json.JsonValueKind.String && value.GetValue<string>() == requested);
        if (!known) throw new ServiceException("OPPONENT_UNAVAILABLE", new() { ["opponentId"] = requested });
        return requested;
    }

    public async Task<ReceiptResult> SubmitAnswerAsync(string user, string sessionId, string exerciseId, int attemptOrdinal, JsonObject answer,
        bool assisted, bool substituted, long expectedRevision, string key, string bodyHash, CancellationToken ct)
    {
        var preview = (await rows.ReadAsync("l_sessions", sessionId, ct))?.Data;
        if (preview is null || preview.Text("userId") != user) throw new ServiceException("NOT_FOUND", new() { ["sessionId"] = sessionId });
        var bundle = !string.IsNullOrEmpty(preview.Text("bundleSnapshotJson"))
            ? JsonNode.Parse(preview.Text("bundleSnapshotJson")!) as JsonObject ?? throw new ServiceException("INTERNAL_ERROR", new() { ["reason"] = "REVIEW_SNAPSHOT_MISSING" })
            : await content.BundleByLessonVersionAsync(preview.Text("courseId")!, preview.Text("lessonId")!, preview.Text("lessonVersion")!, ct);
        return await store.CommitWithReceiptAsync(new(user, "submitAnswer", key), bodyHash, async (tx, token) => {
            var now = tx.Now;
            var session = await tx.GetAsync("l_sessions", sessionId, token);
            if (session is null || session.Text("userId") != user) throw new ServiceException("NOT_FOUND", new() { ["sessionId"] = sessionId });
            var expiry = ParseDate(session.Text("expiresAt"));
            if (session.Text("status") == "EXPIRED" || session.Text("status") == "ACTIVE" && expiry <= now) throw new ServiceException("SESSION_EXPIRED");
            if (session.Text("status") != "ACTIVE") throw new ServiceException("SESSION_CONFLICT", new() { ["status"] = session.Text("status") });
            var revision = session.Number("revision");
            if (revision != expectedRevision) throw new ServiceException("REVISION_CONFLICT", new() { ["currentRevision"] = revision });
            var slotId = CanonicalWire.RowId("slot", user, session.Text("courseId")!);
            var slot = await tx.GetAsync("l_active_slots", slotId, token);
            if (slot is null || slot.Text("sessionId") != sessionId) throw new ServiceException("SESSION_CONFLICT", new() { ["reason"] = "ACTIVE_SLOT_MISSING" });

            var answers = await rows.ListAsync("l_answers", new(Where: new Dictionary<string, object?> { ["sessionId"] = sessionId }, Limit: 60), token);
            var attempts = answers.Select(row => new LearningAttempt(row.Data.Text("exerciseId") ?? "", (int)row.Data.Number("attemptOrdinal"), row.Data.Flag("correct"), row.Data.Flag("assisted"))).ToList();
            var exercises = (bundle["exercises"] as JsonArray ?? []).OfType<JsonObject>().ToArray();
            var order = exercises.Select(item => item.Text("id") ?? "").ToArray();
            var state = LearningSessionQueue.State(order, attempts);
            if (state.NextExerciseId != exerciseId || state.AttemptOrdinal != attemptOrdinal)
            {
                JsonNode? expected = state.NextExerciseId is null ? null : new JsonObject { ["exerciseId"] = state.NextExerciseId, ["attemptOrdinal"] = state.AttemptOrdinal };
                throw new ServiceException("SESSION_CONFLICT", new() { ["expected"] = expected });
            }
            var exercise = exercises.FirstOrDefault(item => item.Text("id") == exerciseId) ?? throw new ServiceException("INTERNAL_ERROR");
            var graded = LearningGrading.GradedExercise(exercise, substituted);
            var verdict = LearningGrading.Grade(graded, answer);
            var after = LearningSessionQueue.State(order, [.. attempts, new(exerciseId, attemptOrdinal, verdict.Correct, assisted)]);
            var nextRevision = revision + 1;
            var result = new JsonObject { ["exerciseId"] = exerciseId, ["correct"] = verdict.Correct,
                ["explanation"] = Truncate(graded.Text("explanation") ?? "", 1024), ["acceptedAnswer"] = Truncate(verdict.AcceptedAnswer, 512),
                ["nextOriginalOrdinal"] = after.NextOriginalOrdinal, ["retryPass"] = after.RetryPass, ["sessionRevision"] = nextRevision, ["provisional"] = false };
            var answerId = CanonicalWire.RowId("answer", sessionId, exerciseId, attemptOrdinal.ToString(CultureInfo.InvariantCulture));
            if (await tx.GetAsync("l_answers", answerId, token) is not null) throw new ServiceException("SESSION_CONFLICT", new() { ["reason"] = "ALREADY_ANSWERED" });
            var spent = await LearningEnergy.SpendAsync(tx, user, session.Text("mode") ?? "", config["COC_ENERGY_MODE"] ?? "UNLIMITED", token);
            tx.Put("l_answers", answerId, new JsonObject { ["sessionId"] = sessionId, ["userId"] = user, ["exerciseId"] = exerciseId,
                ["attemptOrdinal"] = attemptOrdinal, ["answerJson"] = CanonicalWire.Stringify(answer), ["correct"] = verdict.Correct,
                ["assisted"] = assisted, ["substituted"] = substituted, ["receivedAt"] = OwnerSchema.Iso(now), ["resultJson"] = CanonicalWire.Stringify(result) });
            session["nextOriginalOrdinal"] = after.NextOriginalOrdinal; session["retryPass"] = after.RetryPass;
            session["assisted"] = session.Flag("assisted") || assisted; session["energySpent"] = session.Number("energySpent") + spent;
            tx.Put("l_sessions", sessionId, session);
            return new OperationResponse(200, result);
        }, ct);
    }

    public Task<ReceiptResult> AbandonAsync(string user, string sessionId, long expectedRevision, string key, string bodyHash, string requestId, CancellationToken ct) =>
        store.CommitWithReceiptAsync(new(user, "abandonSession", key), bodyHash, async (tx, token) =>
        {
            var session = await tx.GetAsync("l_sessions", sessionId, token);
            if (session is null || session.Text("userId") != user)
                throw new ServiceException("NOT_FOUND", new() { ["sessionId"] = sessionId });
            if (session.Text("status") == "ABANDONED")
                return new OperationResponse(200, new JsonObject { ["operationId"] = key, ["status"] = "replayed", ["requestId"] = requestId });
            if (session.Text("status") == "COMPLETED")
                throw new ServiceException("SESSION_CONFLICT", new() { ["status"] = "COMPLETED" });
            if (session.Number("revision") != expectedRevision)
                throw new ServiceException("REVISION_CONFLICT", new() { ["currentRevision"] = session.Number("revision") });

            var expired = session.Text("status") == "ACTIVE" && ParseDate(session.Text("expiresAt")) <= tx.Now;
            session["status"] = expired ? "EXPIRED" : "ABANDONED";
            tx.Put("l_sessions", sessionId, session);
            var slotId = CanonicalWire.RowId("slot", user, session.Text("courseId")!);
            var slot = await tx.GetAsync("l_active_slots", slotId, token);
            if (slot?.Text("sessionId") == sessionId) tx.Delete("l_active_slots", slotId);
            return new OperationResponse(200, new JsonObject { ["operationId"] = key, ["status"] = "accepted", ["requestId"] = requestId });
        }, ct);

    public async Task<LearningCompletionResult> CompleteAsync(string user, string sessionId, long expectedRevision,
        string key, string bodyHash, string requestId, ILearningRelayTransport relay, CancellationToken ct)
    {
        var preview = (await rows.ReadAsync("l_sessions", sessionId, ct))?.Data;
        if (preview is null || preview.Text("userId") != user) throw new ServiceException("NOT_FOUND", new() { ["sessionId"] = sessionId });
        var bundle = !string.IsNullOrEmpty(preview.Text("bundleSnapshotJson"))
            ? JsonNode.Parse(preview.Text("bundleSnapshotJson")!) as JsonObject ?? throw new ServiceException("INTERNAL_ERROR", new() { ["reason"] = "REVIEW_SNAPSHOT_MISSING" })
            : await content.BundleByLessonVersionAsync(preview.Text("courseId")!, preview.Text("lessonId")!, preview.Text("lessonVersion")!, ct);
        var courseId = preview.Text("courseId")!;
        var mode = preview.Text("mode")!;
        var manifest = mode is "LESSON" or "MASTERY" or "TEST_OUT" or "CHECKPOINT" ? await content.PublishedAsync(courseId, ct) : null;
        var exercises = (bundle["exercises"] as JsonArray ?? []).OfType<JsonObject>().ToArray();
        var order = exercises.Select(exercise => exercise.Text("id") ?? "").ToArray();
        var sourceVersions = new Dictionary<string, string>(StringComparer.Ordinal);
        if (preview.Text("lessonId") == LearningReviewBundleBuilder.ReviewLessonId)
        {
            var published = await content.PublishedAsync(courseId, ct);
            foreach (var exercise in exercises)
            {
                var exerciseId = exercise.Text("id") ?? "";
                var source = (published["bundles"] as JsonArray ?? []).OfType<JsonObject>()
                    .FirstOrDefault(index => exerciseId.StartsWith((index.Text("lessonId") ?? "") + "-", StringComparison.Ordinal));
                if (source?.Text("lessonVersion") is { } lessonVersion) sourceVersions[exerciseId] = lessonVersion;
            }
        }
        var eventId = (string?)null;

        var receipt = await store.CommitWithReceiptAsync(new(user, "completeSession", key), bodyHash, async (tx, token) =>
        {
            eventId = null;
            var session = await tx.GetAsync("l_sessions", sessionId, token);
            if (session is null || session.Text("userId") != user) throw new ServiceException("NOT_FOUND", new() { ["sessionId"] = sessionId });
            if (session.Text("status") == "COMPLETED")
            {
                JsonObject? stored = null;
                try { stored = JsonNode.Parse(session.Text("resultJson") ?? "null") as JsonObject; }
                catch (JsonException) { }
                return new OperationResponse(200, stored?["completion"]?.DeepClone());
            }
            var now = tx.Now;
            if (session.Text("status") == "EXPIRED" || session.Text("status") == "ACTIVE" && ParseDate(session.Text("expiresAt")) <= now)
                throw new ServiceException("SESSION_EXPIRED");
            if (session.Text("status") != "ACTIVE") throw new ServiceException("SESSION_CONFLICT", new() { ["status"] = session.Text("status") });
            var currentRevision = session.Number("revision");
            if (currentRevision != expectedRevision) throw new ServiceException("REVISION_CONFLICT", new() { ["currentRevision"] = currentRevision });
            var slotId = CanonicalWire.RowId("slot", user, courseId);
            var slot = await tx.GetAsync("l_active_slots", slotId, token);
            if (slot?.Text("sessionId") != sessionId) throw new ServiceException("SESSION_CONFLICT", new() { ["reason"] = "ACTIVE_SLOT_MISSING" });

            var answerRows = await rows.ListAsync("l_answers", new(Where: new Dictionary<string, object?> { ["sessionId"] = sessionId }, Limit: 60), token);
            var attempts = answerRows.Select(row => new LearningAttempt(row.Data.Text("exerciseId") ?? "",
                (int)row.Data.Number("attemptOrdinal"), row.Data.Flag("correct"), row.Data.Flag("assisted"))).ToArray();
            var state = LearningSessionQueue.State(order, attempts);
            if (state.NextOriginalOrdinal < order.Length)
                throw new ServiceException("SESSION_INCOMPLETE", new() { ["attempted"] = state.NextOriginalOrdinal, ["required"] = order.Length });

            var summary = LearningCompletionEffects.Tally(exercises, attempts);
            var completedAt = OwnerSchema.Iso(now);
            var enrollmentRevision = 0L;
            var gate = GateModes.Contains(mode);
            var threshold = gate ? AuthoredThreshold(bundle) : null;
            if (gate && threshold is null)
                throw new ServiceException("MODE_UNAVAILABLE", new() { ["mode"] = mode, ["lessonId"] = session.Text("lessonId"), ["reason"] = "PASS_THRESHOLD_MISSING" });
            var passed = gate && threshold is { } required && summary.OriginalCount > 0 && summary.OriginalCorrect / (double)summary.OriginalCount >= required;
            string? unlockedNodeId = null;
            var enrollmentId = CanonicalWire.RowId("enrollment", user, courseId);
            var enrollment = await tx.GetAsync("l_enrollments", enrollmentId, token);
            if (enrollment is not null && !string.IsNullOrEmpty(enrollment.Text("removedAt"))) enrollment = null;
            if (enrollment is not null)
            {
                var oldFrontier = enrollment.Number("frontierNodeOrder");
                if (mode == "LESSON" && manifest is not null)
                    enrollment = LearningPath.CompleteLesson(manifest, enrollment, session.Text("lessonId")!);
                else if (mode == "MASTERY" && manifest is not null && LearningCompletionEffects.MasteryPassed(summary))
                {
                    var nodeId = LearningPath.NodeIdForLesson(manifest, session.Text("lessonId")!);
                    var mastered = JsonNode.Parse(enrollment.Text("masteredNodesJson") ?? "[]") as JsonArray ?? [];
                    if (nodeId is not null && !mastered.Any(value => value?.GetValue<string>() == nodeId)) mastered.Add(nodeId);
                    enrollment["masteredNodesJson"] = mastered.ToJsonString();
                }
                else if (gate && passed && manifest is not null)
                {
                    enrollment = mode == "TEST_OUT"
                        ? LearningPath.CompleteUnit(manifest, enrollment, bundle.Text("unitId") ?? "")
                        : LearningPath.CompleteSection(manifest, enrollment, bundle.Text("sectionId") ?? "");
                    if (enrollment.Number("frontierNodeOrder") > oldFrontier)
                        unlockedNodeId = LearningPath.NodeIdAtFrontier(manifest, enrollment.Number("frontierNodeOrder"));
                }
                if (gate && !passed)
                    enrollmentRevision = enrollment.Number("revision");
                else
                {
                    if (mode != "PLACEMENT") enrollment["lastPracticedAt"] = completedAt;
                    enrollmentRevision = enrollment.Number("revision") + 1;
                    tx.Put("l_enrollments", enrollmentId, enrollment);
                }
            }

            var rewards = mode is not ("PLACEMENT" or "TEST_OUT" or "CHECKPOINT");
            if (rewards)
            {
                await LearningCompletionEffects.StageReviewUpdatesAsync(tx, user, courseId, exercises, attempts,
                    mode is "REVIEW" or "MASTERY" or "UNIT_REVIEW", token);
                await LearningCompletionEffects.StageMistakesAsync(tx, user, courseId, sessionId,
                    session.Text("lessonVersion")!, mode, exercises, attempts, token, sourceVersions);
            }
            tx.Delete("l_active_slots", slotId);

            eventId = rewards ? Guid.NewGuid().ToString() : null;
            var completion = new JsonObject
            {
                ["completionId"] = sessionId,
                ["sessionId"] = sessionId,
                ["originalCount"] = summary.OriginalCount,
                ["originalCorrect"] = summary.OriginalCorrect,
                ["assisted"] = summary.Assisted,
                ["source"] = "ONLINE",
                ["mode"] = mode,
                ["completedAt"] = completedAt,
                ["enrollmentRevision"] = enrollmentRevision,
                ["rewardStatus"] = rewards ? "pending" : "notEligible",
                ["needsReviewIds"] = new JsonArray(summary.NeedsReviewIds.Select(id => (JsonNode?)JsonValue.Create(id)).ToArray())
            };
            if (gate)
            {
                completion["passed"] = passed;
                if (unlockedNodeId is not null) completion["unlockedNodeId"] = unlockedNodeId;
            }

            if (eventId is not null)
            {
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
                        ["userId"] = user,
                        ["courseId"] = courseId,
                        ["lessonVersion"] = session.Text("lessonVersion"),
                        ["rewardIdentity"] = session.Text("rewardIdentity"),
                        ["source"] = "ONLINE",
                        ["mode"] = mode,
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
            }

            session["status"] = "COMPLETED";
            session["completedAt"] = completedAt;
            session["assisted"] = summary.Assisted;
            session["resultJson"] = CanonicalWire.Stringify(new JsonObject { ["completion"] = completion.DeepClone(), ["eventId"] = eventId });
            tx.Put("l_sessions", sessionId, session);
            return new OperationResponse(200, completion);
        }, ct);

        if (receipt.Status == "created" && eventId is not null)
        {
            try
            {
                await LearningImmediateRelay.DispatchAsync(store, relay, clock, [eventId], "completion-" + eventId[..8], ct);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
            catch { /* The durable outbox runner retries after the completion transaction. */ }
        }
        return new(receipt, eventId);
    }

    public async Task<JsonObject> GetViewAsync(string user, string sessionId, CancellationToken ct)
    {
        var session = (await rows.ReadAsync("l_sessions", sessionId, ct))?.Data;
        if (session is null || session.Text("userId") != user) throw new ServiceException("NOT_FOUND", new() { ["sessionId"] = sessionId });
        JsonObject bundle;
        if (!string.IsNullOrEmpty(session.Text("bundleSnapshotJson")))
            bundle = JsonNode.Parse(session.Text("bundleSnapshotJson")!) as JsonObject ?? throw new ServiceException("INTERNAL_ERROR", new() { ["reason"] = "REVIEW_SNAPSHOT_MISSING" });
        else bundle = await content.BundleByLessonVersionAsync(session.Text("courseId")!, session.Text("lessonId")!, session.Text("lessonVersion")!, ct);
        var answerRows = await rows.ListAsync("l_answers", new(Where: new Dictionary<string, object?> { ["sessionId"] = sessionId }, OrderBy: [new("receivedAt")], Limit: 60), ct);
        var ordered = answerRows.OrderBy(row => FeedbackRevision(row.Data.Text("resultJson"))).ToArray();
        var history = new JsonArray();
        foreach (var row in ordered)
        {
            var answer = JsonNode.Parse(row.Data.Text("answerJson") ?? "null");
            history.Add(new JsonObject { ["exerciseId"] = row.Data.Text("exerciseId"), ["attemptOrdinal"] = row.Data.Number("attemptOrdinal"),
                ["answer"] = answer, ["assisted"] = row.Data.Flag("assisted"), ["substituted"] = row.Data.Flag("substituted") });
        }
        var modeConfig = bundle["modeConfig"] as JsonObject;
        bundle = bundle.DeepClone().AsObject(); bundle.Remove("modeConfig");
        var expired = session.Text("status") == "ACTIVE" && ParseDate(session.Text("expiresAt")) <= clock.GetUtcNow();
        var view = new JsonObject {
            ["sessionId"] = sessionId, ["courseId"] = session.Text("courseId"), ["lessonId"] = session.Text("lessonId"),
            ["lessonVersion"] = session.Text("lessonVersion"), ["status"] = expired ? "EXPIRED" : session.Text("status"), ["mode"] = session.Text("mode"),
            ["revision"] = session.Number("revision"), ["nextOriginalOrdinal"] = session.Number("nextOriginalOrdinal"),
            ["retryPass"] = session.Number("retryPass"), ["expiresAt"] = session.Text("expiresAt"), ["bundle"] = bundle,
            ["answerHistory"] = history, ["lastFeedback"] = ordered.Length > 0 ? JsonNode.Parse(ordered[^1].Data.Text("resultJson") ?? "null") : null
        };
        if (!string.IsNullOrEmpty(session.Text("activityId"))) view["activityId"] = session.Text("activityId");
        if (!string.IsNullOrEmpty(session.Text("opponentId"))) view["opponentId"] = session.Text("opponentId");
        if (modeConfig?["passThreshold"] is JsonValue threshold) view["passThreshold"] = threshold.DeepClone();
        return view;
    }

    private static long FeedbackRevision(string? json)
    {
        try { return (JsonNode.Parse(json ?? "null") as JsonObject)?["sessionRevision"]?.GetValue<long>() ?? long.MaxValue; }
        catch (Exception e) when (e is JsonException or InvalidOperationException) { return long.MaxValue; }
    }

    private static HashSet<string> ReadStrings(string? json) => string.IsNullOrEmpty(json) ? new(StringComparer.Ordinal) :
        (JsonNode.Parse(json) as JsonArray ?? []).Select(value => value?.GetValue<string>() ?? "").ToHashSet(StringComparer.Ordinal);

    private static double? AuthoredThreshold(JsonObject bundle)
    {
        var value = (bundle["modeConfig"] as JsonObject)?["passThreshold"];
        return ValidThreshold(value) && value is JsonValue scalar && scalar.TryGetValue<double>(out var threshold) ? threshold : null;
    }

    private static DateTimeOffset ParseDate(string? value) => DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var date) ? date : DateTimeOffset.MinValue;
    private static string Truncate(string value, int limit) => value[..Math.Min(value.Length, limit)];
    private static ServiceException Invalid(string field) => new("VALIDATION_ERROR", new() { ["field"] = field });
}
