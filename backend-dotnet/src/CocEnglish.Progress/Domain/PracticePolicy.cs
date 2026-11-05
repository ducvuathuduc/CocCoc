namespace CocEnglish.Progress.Domain;

public sealed record PracticeAward(int RawXp, int StudyXp, int LeagueXp, bool Capped);

public static class PracticePolicy
{
    public static PracticeAward Award(int xp, int dayStudyXp, int dayPracticeXp, int boostMultiplier)
    {
        if (xp is < 0 or > 100) throw new ArgumentOutOfRangeException(nameof(xp));
        var raw = xp * Math.Clamp(boostMultiplier, 1, 3);
        var credited = Math.Min(raw, Math.Min(Math.Max(0, 100 - dayPracticeXp), Math.Max(0, 1200 - dayStudyXp)));
        return new(raw, credited, credited, credited < raw);
    }
}
