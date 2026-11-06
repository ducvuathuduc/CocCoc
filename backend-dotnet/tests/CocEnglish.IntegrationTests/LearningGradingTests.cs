using System.Text.Json.Nodes;
using CocEnglish.Learning;
using CocEnglish.Shared.Errors;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LearningGradingTests
{
    [Fact]
    public void TextGrade_UsesAuthoredCasePunctuationAndAccentRules()
    {
        var exercise = new JsonObject { ["type"] = "textTranslation", ["content"] = new JsonObject(), ["gradingRule"] = new JsonObject {
            ["acceptedText"] = new JsonArray("Hello!"), ["caseSensitive"] = false, ["ignorePunctuation"] = true, ["ignoreDiacritics"] = false } };
        var answer = new JsonObject { ["kind"] = "text", ["text"] = "  HELLO  " };
        Assert.Equal(new LearningGrade(true, "Hello!"), LearningGrading.Grade(exercise, answer));

        exercise["gradingRule"]!["acceptedText"] = new JsonArray("café");
        exercise["gradingRule"]!["ignorePunctuation"] = false;
        exercise["gradingRule"]!["ignoreDiacritics"] = true;
        answer["text"] = "cafe";
        Assert.True(LearningGrading.Grade(exercise, answer).Correct);
    }

    [Fact]
    public void TokenGrade_TreatsRepeatedWordsAsOneIdentityClassAndRejectsDuplicates()
    {
        var exercise = new JsonObject { ["type"] = "wordBank", ["content"] = new JsonObject { ["tokens"] = new JsonArray(
            new JsonObject { ["id"] = "the1", ["text"] = "the" }, new JsonObject { ["id"] = "the2", ["text"] = "the" }, new JsonObject { ["id"] = "cat", ["text"] = "cat" }) },
            ["gradingRule"] = new JsonObject { ["correctTokenIds"] = new JsonArray("the1", "cat") } };
        Assert.True(LearningGrading.Grade(exercise, new JsonObject { ["kind"] = "tokens", ["tokenIds"] = new JsonArray("the2", "cat") }).Correct);
        var error = Assert.Throws<ServiceException>(() => LearningGrading.Grade(exercise,
            new JsonObject { ["kind"] = "tokens", ["tokenIds"] = new JsonArray("the1", "the1") }));
        Assert.Equal("DUPLICATE_TOKEN", error.Details["reason"]!.GetValue<string>());
    }

    [Fact]
    public void PairGrade_RequiresEachAuthoredEndpointOnce()
    {
        var exercise = new JsonObject { ["type"] = "matchPairs", ["content"] = new JsonObject { ["pairs"] = new JsonArray(
            new JsonObject { ["id"] = "p1", ["left"] = new JsonObject { ["id"] = "l1", ["text"] = "hi" }, ["right"] = new JsonObject { ["id"] = "r1", ["text"] = "xin chào" } },
            new JsonObject { ["id"] = "p2", ["left"] = new JsonObject { ["id"] = "l2", ["text"] = "bye" }, ["right"] = new JsonObject { ["id"] = "r2", ["text"] = "tạm biệt" } }) },
            ["gradingRule"] = new JsonObject { ["correctPairIds"] = new JsonArray("p1", "p2") } };
        var correct = LearningGrading.Grade(exercise, new JsonObject { ["kind"] = "pairs", ["matches"] = new JsonArray(
            new JsonObject { ["leftId"] = "l1", ["rightId"] = "r1" }, new JsonObject { ["leftId"] = "l2", ["rightId"] = "r2" }) });
        Assert.True(correct.Correct);
        var error = Assert.Throws<ServiceException>(() => LearningGrading.Grade(exercise,
            new JsonObject { ["kind"] = "pairs", ["matches"] = new JsonArray(new JsonObject { ["leftId"] = "l1", ["rightId"] = "r1" }, new JsonObject { ["leftId"] = "l1", ["rightId"] = "r2" }) }));
        Assert.Equal("REUSED_ENDPOINT", error.Details["reason"]!.GetValue<string>());
    }

    [Fact]
    public void SpeechAnswerFailsClosedAndSubstitutionUsesAuthoredAlternative()
    {
        var exercise = new JsonObject { ["type"] = "speakRepeat", ["content"] = new JsonObject { ["referenceText"] = "hello" },
            ["gradingRule"] = new JsonObject(), ["nonSpeechAlternative"] = new JsonObject { ["id"] = "choice1", ["type"] = "choice",
                ["content"] = new JsonObject { ["choices"] = new JsonArray(new JsonObject { ["id"] = "yes", ["text"] = "hello" }) },
                ["gradingRule"] = new JsonObject { ["correctChoiceId"] = "yes" } } };
        var error = Assert.Throws<ServiceException>(() => LearningGrading.Grade(exercise, new JsonObject { ["kind"] = "speech", ["assessmentJobId"] = "job1" }));
        Assert.Equal("VALIDATION_ERROR", error.Code);
        Assert.Equal("SPEECH_ASSESSMENT_UNAVAILABLE", error.Details["reason"]!.GetValue<string>());
        var alternative = LearningGrading.GradedExercise(exercise, true);
        Assert.True(LearningGrading.Grade(alternative, new JsonObject { ["kind"] = "choice", ["choiceId"] = "yes" }).Correct);
    }

    [Theory]
    [InlineData("textTranslation")]
    [InlineData("fillBlank")]
    [InlineData("dictation")]
    [InlineData("choice")]
    [InlineData("imageChoice")]
    [InlineData("listenChoice")]
    [InlineData("storyQuestion")]
    [InlineData("wordBank")]
    [InlineData("sentenceOrder")]
    [InlineData("matchPairs")]
    [InlineData("speakRepeat")]
    [InlineData("dialogueTurn")]
    public void Grade_AcceptsCorrectAnswerForEveryPublishedExerciseType(string type)
    {
        var exercise = ExerciseFor(type);
        var answer = type switch
        {
            "textTranslation" or "fillBlank" or "dictation" or "speakRepeat" or "dialogueTurn" =>
                new JsonObject { ["kind"] = "text", ["text"] = "  HELLO! " },
            "choice" or "imageChoice" or "listenChoice" or "storyQuestion" =>
                new JsonObject { ["kind"] = "choice", ["choiceId"] = "yes" },
            "wordBank" or "sentenceOrder" =>
                new JsonObject { ["kind"] = "tokens", ["tokenIds"] = new JsonArray("hello") },
            "matchPairs" =>
                new JsonObject { ["kind"] = "pairs", ["matches"] = new JsonArray(new JsonObject { ["leftId"] = "en", ["rightId"] = "vi" }) },
            _ => throw new ArgumentOutOfRangeException(nameof(type))
        };

        var result = LearningGrading.Grade(exercise, answer);

        Assert.True(result.Correct, $"Expected {type} to accept its authored correct answer.");
        Assert.False(string.IsNullOrWhiteSpace(result.AcceptedAnswer));
    }

    [Theory]
    [InlineData("speakRepeat")]
    [InlineData("dialogueTurn")]
    public void Grade_DoesNotTreatAnAssessmentJobIdAsAScore(string type)
    {
        var error = Assert.Throws<ServiceException>(() => LearningGrading.Grade(ExerciseFor(type),
            new JsonObject { ["kind"] = "speech", ["assessmentJobId"] = "job-1" }));

        Assert.Equal("VALIDATION_ERROR", error.Code);
        Assert.Equal("SPEECH_ASSESSMENT_UNAVAILABLE", error.Details["reason"]!.GetValue<string>());
    }

    private static JsonObject ExerciseFor(string type)
    {
        if (type is "textTranslation" or "fillBlank" or "dictation" or "speakRepeat" or "dialogueTurn")
            return new JsonObject
            {
                ["type"] = type,
                ["content"] = new JsonObject { ["referenceText"] = "Hello!" },
                ["gradingRule"] = new JsonObject { ["acceptedText"] = new JsonArray("Hello!"), ["caseSensitive"] = false, ["ignorePunctuation"] = true, ["ignoreDiacritics"] = false }
            };
        if (type is "choice" or "imageChoice" or "listenChoice" or "storyQuestion")
            return new JsonObject
            {
                ["type"] = type,
                ["content"] = new JsonObject { ["choices"] = new JsonArray(
                    new JsonObject { ["id"] = "yes", ["text"] = "Yes" }, new JsonObject { ["id"] = "no", ["text"] = "No" }) },
                ["gradingRule"] = new JsonObject { ["correctChoiceId"] = "yes" }
            };
        if (type is "wordBank" or "sentenceOrder")
            return new JsonObject
            {
                ["type"] = type,
                ["content"] = new JsonObject { ["tokens"] = new JsonArray(new JsonObject { ["id"] = "hello", ["text"] = "hello" }) },
                ["gradingRule"] = new JsonObject { ["correctTokenIds"] = new JsonArray("hello") }
            };
        if (type == "matchPairs")
            return new JsonObject
            {
                ["type"] = type,
                ["content"] = new JsonObject { ["pairs"] = new JsonArray(new JsonObject
                {
                    ["id"] = "greeting", ["left"] = new JsonObject { ["id"] = "en", ["text"] = "Hello" },
                    ["right"] = new JsonObject { ["id"] = "vi", ["text"] = "Xin chào" }
                }) },
                ["gradingRule"] = new JsonObject { ["correctPairIds"] = new JsonArray("greeting") }
            };
        throw new ArgumentOutOfRangeException(nameof(type));
    }
}
