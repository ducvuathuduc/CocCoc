using CocEnglish.Learning;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LearningCursorTests
{
    [Theory]
    [InlineData(null, 0)]
    [InlineData("", 0)]
    [InlineData("bzoxMg", 12)]
    [InlineData("bzowMDAwMDE", 1)]
    [InlineData("bm90LWN1cnNvcg", -1)]
    [InlineData("bzoxMjM0NTY3", -1)]
    public void Decode_MatchesNodeOffsetCursor(string? cursor, int expected) => Assert.Equal(expected, LearningCursor.Decode(cursor));

    [Theory]
    [InlineData(0, "bzow")]
    [InlineData(12, "bzoxMg")]
    [InlineData(999999, "bzo5OTk5OTk")]
    public void Encode_UsesBase64UrlWithoutPadding(int offset, string expected) => Assert.Equal(expected, LearningCursor.Encode(offset));
}
