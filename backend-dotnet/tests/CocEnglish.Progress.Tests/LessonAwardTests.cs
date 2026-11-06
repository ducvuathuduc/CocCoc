using CocEnglish.Progress.Domain;
using Xunit;

namespace CocEnglish.Progress.Tests;

public sealed class LessonAwardTests
{
    [Theory]
    [InlineData("LESSON", "ONLINE", 10, 10, false, true, 0, 0, 1, "FIRST", 25, 25, false)]
    [InlineData("LESSON", "OFFLINE", 10, 10, false, true, 0, 0, 1, "FIRST", 20, 0, false)]
    [InlineData("LESSON", "ONLINE", 8, 1, true, true, 0, 0, 1, "FIRST", 11, 11, false)]
    [InlineData("REVIEW", "ONLINE", 10, 8, false, true, 0, 28, 1, "REPLAY", 2, 0, true)]
    [InlineData("LESSON", "ONLINE", 10, 10, false, false, 1198, 0, 2, "REPLAY", 2, 2, true)]
    [InlineData("CHECKPOINT", "ONLINE", 10, 10, false, true, 0, 0, 1, null, 0, 0, false)]
    public void Award_RespectsModeSourceAndCaps(string mode, string source, int count, int correct, bool assisted, bool first, int dayXp, int replayXp, int boost, string? kind, int study, int league, bool capped)
    {
        var result = LessonPolicy.Award(mode, source, count, correct, assisted, first, dayXp, replayXp, boost);
        Assert.Null(result.Error); Assert.Equal(kind, result.Kind); Assert.Equal(study, result.StudyXp); Assert.Equal(league, result.LeagueXp); Assert.Equal(capped, result.Capped);
    }

    [Theory]
    [InlineData("UNKNOWN", "ONLINE", 10, 5, "MODE_NOT_IMPLEMENTED")]
    [InlineData("LESSON", "ONLINE", 4, 4, "INVALID_GRADED_RESULT")]
    [InlineData("LESSON", "OFFLINE", 10, 11, "INVALID_GRADED_RESULT")]
    public void Award_RejectsInvalidGrading(string mode, string source, int count, int correct, string error) =>
        Assert.Equal(error, LessonPolicy.Award(mode, source, count, correct, false, true, 0, 0, 1).Error);
}
