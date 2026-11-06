using System.Text.Json;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;

namespace CocEnglish.Learning;

public sealed record LearningCompletionSummary(int OriginalCount, int OriginalCorrect, bool Assisted, IReadOnlyList<string> NeedsReviewIds);

public static class LearningCompletionEffects
{
    private static readonly int[] ReviewIntervals = [1, 3, 7, 14, 30];

    public static LearningCompletionSummary Tally(IReadOnlyList<JsonObject> exercises, IReadOnlyList<LearningAttempt> attempts)
    {
        var originalCorrect = 0;
        var needsReview = new List<string>();
        foreach (var exercise in exercises)
        {
            var id = exercise.Text("id") ?? "";
            if (attempts.FirstOrDefault(attempt => attempt.ExerciseId == id && attempt.AttemptOrdinal == 0)?.Correct == true)
                originalCorrect++;
            if (!attempts.Any(attempt => attempt.ExerciseId == id && attempt.Correct)) needsReview.Add(id);
        }
        return new(exercises.Count, originalCorrect, attempts.Any(attempt => attempt.Assisted), needsReview.Take(20).ToArray());
    }

    public static bool MasteryPassed(LearningCompletionSummary summary) =>
        summary.OriginalCount > 0 && !summary.Assisted && summary.OriginalCorrect * 5 >= summary.OriginalCount * 4;

    public static async Task StageReviewUpdatesAsync(OwnerSession tx, string userId, string courseId,
        IReadOnlyList<JsonObject> exercises, IReadOnlyList<LearningAttempt> attempts, bool advance, CancellationToken cancellationToken)
    {
        var evidence = new Dictionary<string, (bool Correct, bool Assisted, string SkillId)>(StringComparer.Ordinal);
        foreach (var exercise in exercises)
        {
            var id = exercise.Text("id") ?? "";
            var first = attempts.FirstOrDefault(attempt => attempt.ExerciseId == id && attempt.AttemptOrdinal == 0);
            if (first is null) continue;
            var skill = (exercise["skillIds"] as JsonArray)?.FirstOrDefault()?.GetValue<string>() ?? "general";
            foreach (var value in exercise["vocabularyIds"] as JsonArray ?? [])
            {
                var vocabularyId = value?.GetValue<string>();
                if (vocabularyId is null) continue;
                if (evidence.TryGetValue(vocabularyId, out var previous))
                    evidence[vocabularyId] = (previous.Correct && first.Correct, previous.Assisted || first.Assisted, previous.SkillId);
                else evidence[vocabularyId] = (first.Correct, first.Assisted, skill);
            }
        }

        var now = tx.Now;
        foreach (var (vocabularyId, item) in evidence.Take(30))
        {
            var rowId = CanonicalWire.RowId("review", userId, courseId, vocabularyId);
            var previous = await tx.GetAsync("l_review_items", rowId, cancellationToken);
            var window = ReadWindow(previous?.Text("firstAttemptWindowJson"));
            window.Add(item.Correct);
            if (window.Count > 20) window.RemoveRange(0, window.Count - 20);

            var previousStage = (int)(previous?.Number("stage") ?? 0);
            var good = item.Correct && !item.Assisted;
            var stage = previousStage;
            var dueAt = previous?.Text("dueAt");
            var halfLifeHours = previous?.Number("halfLifeHours") ?? 0;
            if (!good)
            {
                stage = 0;
                dueAt = OwnerSchema.Iso(now.AddDays(1));
                halfLifeHours = 24;
            }
            else if (previous is null || advance)
            {
                var days = ReviewIntervals[Math.Clamp(previousStage, 0, ReviewIntervals.Length - 1)];
                stage = Math.Min(previousStage + 1, 4);
                dueAt = OwnerSchema.Iso(now.AddDays(days));
                halfLifeHours = days * 24;
            }

            tx.Put("l_review_items", rowId, new JsonObject
            {
                ["userId"] = userId,
                ["courseId"] = courseId,
                ["vocabularyId"] = vocabularyId,
                ["skillId"] = previous?.Text("skillId") ?? item.SkillId,
                ["stage"] = stage,
                ["dueAt"] = dueAt,
                ["firstAttemptWindowJson"] = JsonSerializer.Serialize(window),
                ["lastReviewedAt"] = OwnerSchema.Iso(now),
                ["firstSeenAt"] = previous?.Text("firstSeenAt") ?? OwnerSchema.Iso(now),
                ["correctCount"] = (previous?.Number("correctCount") ?? 0) + (item.Correct ? 1 : 0),
                ["incorrectCount"] = (previous?.Number("incorrectCount") ?? 0) + (item.Correct ? 0 : 1),
                ["halfLifeHours"] = halfLifeHours
            });
        }
    }

    public static async Task StageMistakesAsync(OwnerSession tx, string userId, string courseId, string sessionId,
        string lessonVersion, string mode, IReadOnlyList<JsonObject> exercises, IReadOnlyList<LearningAttempt> attempts,
        CancellationToken cancellationToken, IReadOnlyDictionary<string, string>? sourceVersions = null)
    {
        var at = tx.NowIso;
        var created = 0;
        var captured = 0;
        foreach (var exercise in exercises)
        {
            var exerciseId = exercise.Text("id") ?? "";
            var first = attempts.FirstOrDefault(attempt => attempt.ExerciseId == exerciseId && attempt.AttemptOrdinal == 0);
            if (first is null) continue;
            var rowId = CanonicalWire.RowId("mistake", userId, courseId, exerciseId);
            if (!first.Correct)
            {
                if (captured >= 10) continue;
                captured++;
                var previous = await tx.GetAsync("l_mistakes", rowId, cancellationToken);
                if (previous is null || !string.IsNullOrEmpty(previous.Text("resolvedAt"))) created++;
                tx.Put("l_mistakes", rowId, new JsonObject
                {
                    ["userId"] = userId,
                    ["courseId"] = courseId,
                    ["exerciseId"] = exerciseId,
                    ["lessonVersion"] = sourceVersions?.GetValueOrDefault(exerciseId) ?? lessonVersion,
                    ["skillId"] = (exercise["skillIds"] as JsonArray)?.FirstOrDefault()?.GetValue<string>() ?? "general",
                    ["lastSessionId"] = sessionId,
                    ["mistakeCount"] = (previous?.Number("mistakeCount") ?? 0) + 1,
                    ["lastMistakeAt"] = at,
                    ["resolvedAt"] = null
                });
            }
            else if ((mode is "REVIEW" or "MASTERY" or "UNIT_REVIEW") && !first.Assisted)
            {
                var previous = await tx.GetAsync("l_mistakes", rowId, cancellationToken);
                if (previous is not null && string.IsNullOrEmpty(previous.Text("resolvedAt")))
                {
                    previous["resolvedAt"] = at;
                    tx.Put("l_mistakes", rowId, previous);
                }
            }
        }

        if (created == 0) return;
        var unresolved = await tx.ListAsync("l_mistakes", new RowQuery(
            Where: new Dictionary<string, object?> { ["userId"] = userId, ["courseId"] = courseId, ["resolvedAt"] = null },
            OrderBy: [new("lastMistakeAt")],
            Limit: 110), cancellationToken);
        var excess = unresolved.Count - 100;
        foreach (var item in unresolved.Take(Math.Max(0, excess))) tx.Delete("l_mistakes", item.Id);
    }

    private static List<bool> ReadWindow(string? json) =>
        (JsonNode.Parse(string.IsNullOrEmpty(json) ? "[]" : json) as JsonArray ?? []).Select(value => value?.GetValue<bool>() ?? false).ToList();
}
