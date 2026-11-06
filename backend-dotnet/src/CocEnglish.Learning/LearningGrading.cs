using System.Text.Json.Nodes;
using System.Text;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;

namespace CocEnglish.Learning;

public sealed record LearningGrade(bool Correct, string AcceptedAnswer);

/// <summary>Pure deterministic grading rules shared by online and offline lesson submissions.</summary>
public static class LearningGrading
{
    private static readonly HashSet<string> TextExercises = ["textTranslation", "fillBlank", "dictation"];
    private static readonly HashSet<string> ChoiceExercises = ["choice", "imageChoice", "listenChoice", "storyQuestion"];
    private static readonly HashSet<string> TokenExercises = ["wordBank", "sentenceOrder"];
    private static readonly HashSet<string> SpeechExercises = ["speakRepeat", "dialogueTurn"];

    public static JsonObject GradedExercise(JsonObject exercise, bool substituted)
    {
        if (!substituted) return exercise;
        return exercise["nonSpeechAlternative"] as JsonObject ?? exercise["nonAudioAlternative"] as JsonObject ??
            throw Invalid("NO_SUBSTITUTE");
    }

    public static LearningGrade Grade(JsonObject exercise, JsonObject answer)
    {
        var type = exercise.Text("type") ?? ""; var kind = answer.Text("kind") ?? "";
        var validKind = TextExercises.Contains(type) && kind == "text" || ChoiceExercises.Contains(type) && kind == "choice" ||
                        TokenExercises.Contains(type) && kind == "tokens" || type == "matchPairs" && kind == "pairs" ||
                        SpeechExercises.Contains(type) && kind is "text" or "speech";
        if (!validKind) throw Invalid("ANSWER_KIND_MISMATCH");
        var rule = exercise["gradingRule"] as JsonObject ?? throw Invalid("NO_ANSWER_KEY");
        switch (kind)
        {
            case "text":
            {
                var accepted = rule["acceptedText"] as JsonArray ?? [];
                if (accepted.Count == 0) throw Invalid("NO_ANSWER_KEY");
                var value = answer.Text("text") ?? "";
                if (value.Length > 512) throw Invalid("TOO_LONG");
                var given = Normalize(value, rule);
                if (given.Length == 0) throw Invalid("EMPTY");
                var correct = accepted.OfType<JsonValue>().Select(item => item.GetValue<string>()).Any(item => Normalize(item, rule) == given);
                return new(correct, accepted[0]!.GetValue<string>());
            }
            case "choice":
            {
                var choices = (exercise["content"]?["choices"] as JsonArray ?? []).OfType<JsonObject>().ToArray();
                var id = answer.Text("choiceId") ?? "";
                if (!choices.Any(choice => choice.Text("id") == id)) throw Invalid("UNKNOWN_CHOICE");
                var correctId = rule.Text("correctChoiceId"); var right = choices.FirstOrDefault(choice => choice.Text("id") == correctId);
                return new(id == correctId, right?.Text("text") ?? "");
            }
            case "tokens":
            {
                var bank = (exercise["content"]?["tokens"] as JsonArray ?? []).OfType<JsonObject>().ToArray();
                var byId = bank.ToDictionary(token => token.Text("id") ?? "", StringComparer.Ordinal);
                var selected = (answer["tokenIds"] as JsonArray ?? []).Select(node => node?.GetValue<string>() ?? "").ToArray();
                var seen = new HashSet<string>(StringComparer.Ordinal);
                foreach (var id in selected)
                {
                    if (!byId.ContainsKey(id)) throw Invalid("UNKNOWN_TOKEN");
                    if (!seen.Add(id)) throw Invalid("DUPLICATE_TOKEN");
                }
                if (selected.Length == 0) throw Invalid("EMPTY");
                var classByText = new Dictionary<string, string>(StringComparer.Ordinal);
                var classById = new Dictionary<string, string>(StringComparer.Ordinal);
                foreach (var token in bank)
                {
                    var id = token.Text("id") ?? ""; var text = token.Text("text") ?? "";
                    if (!classByText.TryGetValue(text, out var first)) classByText[text] = first = id;
                    classById[id] = first;
                }
                var expected = (rule["correctTokenIds"] as JsonArray ?? []).Select(node => node?.GetValue<string>() ?? "").ToArray();
                var correct = expected.Length == selected.Length && expected.Select((id, index) => classById.GetValueOrDefault(id) == classById.GetValueOrDefault(selected[index])).All(value => value);
                var sentence = string.Join(' ', expected.Select(id => byId.GetValueOrDefault(id)?.Text("text") ?? ""));
                sentence = Regex.Replace(sentence, @"\s+([.,!?])", "$1", RegexOptions.CultureInvariant);
                return new(correct, Truncate(sentence, 512));
            }
            case "pairs":
            {
                var pairs = (exercise["content"]?["pairs"] as JsonArray ?? []).OfType<JsonObject>().ToArray();
                var lefts = pairs.ToDictionary(pair => pair["left"]?.AsObject().Text("id") ?? "", StringComparer.Ordinal);
                var rights = pairs.Select(pair => pair["right"]?.AsObject().Text("id") ?? "").ToHashSet(StringComparer.Ordinal);
                var matches = (answer["matches"] as JsonArray ?? []).OfType<JsonObject>().ToArray();
                var usedLeft = new HashSet<string>(StringComparer.Ordinal); var usedRight = new HashSet<string>(StringComparer.Ordinal);
                foreach (var match in matches)
                {
                    var leftId = match.Text("leftId") ?? ""; var rightId = match.Text("rightId") ?? "";
                    if (!lefts.ContainsKey(leftId) || !rights.Contains(rightId)) throw Invalid("UNKNOWN_ENDPOINT");
                    if (!usedLeft.Add(leftId) || !usedRight.Add(rightId)) throw Invalid("REUSED_ENDPOINT");
                }
                if (matches.Length != pairs.Length) throw Invalid("INCOMPLETE_PAIRS");
                var required = (rule["correctPairIds"] as JsonArray ?? []).Select(node => node?.GetValue<string>() ?? "").ToHashSet(StringComparer.Ordinal);
                var correct = matches.All(match => lefts.TryGetValue(match.Text("leftId") ?? "", out var pair) &&
                    pair["right"]?.AsObject().Text("id") == match.Text("rightId") && required.Contains(pair.Text("id") ?? ""));
                var display = string.Join("; ", pairs.Select(pair => $"{pair["left"]?.AsObject().Text("text")} = {pair["right"]?.AsObject().Text("text")}"));
                return new(correct, Truncate(display, 512));
            }
            // The Node grader treats this as a validation reason within the standard error envelope.
            case "speech": throw Invalid("SPEECH_ASSESSMENT_UNAVAILABLE");
            default: throw Invalid("ANSWER_KIND_MISMATCH");
        }
    }

    private static string Normalize(string value, JsonObject rule)
    {
        var text = value.Normalize(NormalizationForm.FormC).Replace('\u2018', '\'').Replace('\u2019', '\'').Replace('\u02BC', '\'').Replace('\u201C', '"').Replace('\u201D', '"');
        if (rule["ignorePunctuation"]?.GetValue<bool>() == true) text = Regex.Replace(text, @"[\p{P}\p{S}]", " ", RegexOptions.CultureInvariant);
        text = Regex.Replace(text, @"\s+", " ", RegexOptions.CultureInvariant).Trim();
        if (rule["caseSensitive"]?.GetValue<bool>() != true) text = text.ToLowerInvariant();
        if (rule["ignoreDiacritics"]?.GetValue<bool>() == true)
            text = Regex.Replace(text.Normalize(NormalizationForm.FormD), @"\p{M}", "", RegexOptions.CultureInvariant).Replace('đ', 'd').Replace('Đ', 'D').Normalize(NormalizationForm.FormC);
        return text;
    }

    private static string Truncate(string text, int length) => text[..Math.Min(text.Length, length)];
    private static ServiceException Invalid(string reason) => new("VALIDATION_ERROR", new() { ["field"] = "answer", ["reason"] = reason });
}
