namespace CocEnglish.Progress.Domain;

public sealed record LessonAward(string? Kind, int RawXp, int StudyXp, int ReplayXp, int LeagueXp, bool Capped, bool Perfect, string? Error = null);

public static class LessonPolicy
{
    private static readonly HashSet<string> Formula = ["LESSON", "STORIES", "ADVENTURE", "RADIO", "SIDE_QUEST", "CLASH"];
    private static readonly HashSet<string> Replay = ["REVIEW", "MASTERY", "UNIT_REVIEW"];
    private static readonly HashSet<string> Zero = ["PLACEMENT", "TEST_OUT", "CHECKPOINT"];
    public static LessonAward Award(string mode, string source, int count, int correct, bool assisted, bool first, int dayStudyXp, int dayReplayXp, int boost)
    {
        if (!Formula.Contains(mode) && !Replay.Contains(mode) && !Zero.Contains(mode)) return new(null, 0, 0, 0, 0, false, false, "MODE_NOT_IMPLEMENTED");
        if (source is not ("ONLINE" or "OFFLINE") || count is < 5 or > 20 || correct < 0 || correct > count)
            return new(null, 0, 0, 0, 0, false, false, "INVALID_GRADED_RESULT");
        if (Zero.Contains(mode)) return new(null, 0, 0, 0, 0, false, false);
        var isFirst = Formula.Contains(mode) && first;
        var perfect = isFirst && source == "ONLINE" && correct == count && !assisted;
        var baseXp = isFirst ? 10 + (int)Math.Floor(10d * correct / count + .5) + (perfect ? 5 : 0) : 5;
        var raw = baseXp * Math.Clamp(boost, 1, 3);
        var replay = isFirst ? 0 : Math.Min(raw, Math.Max(0, 30 - dayReplayXp));
        var beforeDailyCap = isFirst ? raw : replay;
        var study = Math.Min(beforeDailyCap, Math.Max(0, 1200 - dayStudyXp));
        return new(isFirst ? "FIRST" : "REPLAY", raw, study, isFirst ? 0 : study,
            Formula.Contains(mode) && source == "ONLINE" ? study : 0, beforeDailyCap < raw || study < beforeDailyCap, perfect);
    }
}
