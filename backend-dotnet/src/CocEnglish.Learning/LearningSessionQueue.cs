namespace CocEnglish.Learning;

public sealed record LearningAttempt(string ExerciseId, int AttemptOrdinal, bool Correct, bool Assisted);
public sealed record LearningQueueState(string? NextExerciseId, int AttemptOrdinal, int NextOriginalOrdinal, int RetryPass);

/// <summary>Original queue followed by two deterministic retry passes over missed items.</summary>
public static class LearningSessionQueue
{
    public static LearningQueueState State(IReadOnlyList<string> order, IReadOnlyList<LearningAttempt> attempts)
    {
        LearningAttempt? Latest(string id, int ordinal) => attempts.FirstOrDefault(item => item.ExerciseId == id && item.AttemptOrdinal == ordinal);
        var originalsDone = order.Count(id => Latest(id, 0) is not null);
        var firstMissing = order.FirstOrDefault(id => Latest(id, 0) is null);
        if (firstMissing is not null) return new(firstMissing, 0, originalsDone, 0);
        foreach (var pass in new[] { 1, 2 })
        {
            var pending = order.Where(id => Latest(id, pass - 1)?.Correct == false).FirstOrDefault(id => Latest(id, pass) is null);
            if (pending is not null) return new(pending, pass, order.Count, pass);
        }
        var passesUsed = order.Any(id => Latest(id, 2) is not null) ? 2 : order.Any(id => Latest(id, 1) is not null) ? 1 : 0;
        return new(null, 0, order.Count, passesUsed);
    }
}
