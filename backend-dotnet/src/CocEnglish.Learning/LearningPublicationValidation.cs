using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace CocEnglish.Learning;

internal sealed record ContentProblem(string Where, string Problem);

/// <summary>Ports publish-time course and exercise checks from services/learning/src/content/validate.ts.</summary>
internal static partial class LearningPublicationValidation
{
    private static readonly string[] ExerciseTypes =
    [
        "textTranslation", "choice", "wordBank", "sentenceOrder", "fillBlank", "matchPairs",
        "imageChoice", "listenChoice", "dictation", "speakRepeat", "dialogueTurn", "storyQuestion"
    ];
    private static readonly HashSet<string> AudioPromptTypes = ["listenChoice", "dictation"];
    private static readonly HashSet<string> SpeechTypes = ["speakRepeat", "dialogueTurn"];
    private static readonly HashSet<string> TextTypes = ["textTranslation", "fillBlank", "dictation", "speakRepeat", "dialogueTurn"];
    private static readonly HashSet<string> ChoiceTypes = ["choice", "imageChoice", "listenChoice", "storyQuestion"];
    private static readonly HashSet<string> TokenTypes = ["wordBank", "sentenceOrder"];
    private const int MaxSections = 20;
    private const int MaxUnits = 120;
    private const int MaxNodes = 600;
    private const int MaxBundles = 1200;
    private const int MaxUnitsPerSection = 30;
    private const int MaxNodesPerUnit = 30;

    [GeneratedRegex("^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$", RegexOptions.CultureInvariant)]
    private static partial Regex IdPattern();

    public static IReadOnlyList<ContentProblem> ValidateCourse(JsonObject manifest, IReadOnlyList<JsonObject> bundles)
    {
        var problems = ValidateManifestStructure(manifest).ToList();
        var seenTypes = new HashSet<string>(StringComparer.Ordinal);
        foreach (var bundle in bundles)
        {
            problems.AddRange(ValidateBundle(bundle));
            var lessonId = Text(bundle, "lessonId") ?? "?";
            if (Text(bundle, "courseId") != Text(manifest, "courseId") || Text(bundle, "courseVersion") != Text(manifest, "courseVersion"))
                problems.Add(new(lessonId, "COURSE_PIN_MISMATCH"));
            if (Text(bundle, "manifestHash") != Text(manifest, "manifestHash"))
                problems.Add(new(lessonId, "MANIFEST_HASH_MISMATCH"));
            foreach (var exercise in Objects(bundle["exercises"]))
                if (Text(exercise, "type") is { } type) seenTypes.Add(type);
        }
        foreach (var type in ExerciseTypes)
            if (!seenTypes.Contains(type)) problems.Add(new("course", "MISSING_TYPE_" + type));
        return problems;
    }

    public static IReadOnlyList<ContentProblem> ValidateBundle(JsonObject bundle, string? whereOverride = null)
    {
        var where = whereOverride ?? Text(bundle, "lessonId") ?? "?";
        var output = new List<ContentProblem>();
        if (Number(bundle["schemaVersion"]) != 1) output.Add(new(where, "SCHEMA_VERSION"));
        var exercises = Objects(bundle["exercises"]).ToArray();
        if (exercises.Length == 0 || exercises.Length > 20) output.Add(new(where, "EXERCISE_COUNT"));
        var assets = Objects(bundle["assets"]).ToArray();
        var assetIds = assets.Select(asset => Text(asset, "fileId") ?? "").ToHashSet(StringComparer.Ordinal);
        if (assetIds.Count != assets.Length) output.Add(new(where, "DUPLICATE_ASSET"));
        foreach (var asset in assets)
        {
            var fileId = Text(asset, "fileId") ?? "?";
            if (!Regex.IsMatch(Text(asset, "sha256") ?? "", "^[a-f0-9]{64}$", RegexOptions.CultureInvariant) || !Truthy(asset["altText"]))
                output.Add(new(where + "/" + fileId, "ASSET_METADATA"));
        }
        var ids = exercises.Select(exercise => Text(exercise, "id") ?? "").ToArray();
        if (ids.Distinct(StringComparer.Ordinal).Count() != ids.Length) output.Add(new(where, "DUPLICATE_EXERCISE_ID"));
        foreach (var exercise in exercises) CheckExercise(exercise, where, assetIds, output);
        return output;
    }

    public static IReadOnlyList<ContentProblem> ValidateManifestStructure(JsonObject manifest)
    {
        var output = new List<ContentProblem>();
        void Add(string location, string problem) => output.Add(new(location, problem));
        if (Number(manifest["schemaVersion"]) != 1) Add("manifest", "SCHEMA_VERSION");
        var sections = Objects(manifest["sections"]).ToArray();
        var units = Objects(manifest["units"]).ToArray();
        var nodes = Objects(manifest["nodes"]).ToArray();
        var bundles = Objects(manifest["bundles"]).ToArray();
        if (sections.Length > MaxSections || units.Length > MaxUnits || nodes.Length > MaxNodes || bundles.Length > MaxBundles)
            Add("manifest", "SIZE_LIMIT");

        var unitById = units.ToDictionaryLast(unit => Text(unit, "unitId") ?? "");
        var nodeById = nodes.ToDictionaryLast(node => Text(node, "nodeId") ?? "");
        var bundleByLesson = bundles.ToDictionaryLast(bundle => Text(bundle, "lessonId") ?? "");
        if (bundleByLesson.Count != bundles.Length) Add("manifest", "DUPLICATE_BUNDLE");
        if (nodes.Select(node => node["order"]?.ToJsonString() ?? "null").Distinct(StringComparer.Ordinal).Count() != nodes.Length)
            Add("manifest", "DUPLICATE_NODE_ORDER");
        foreach (var section in sections)
        {
            var sectionId = Text(section, "sectionId") ?? "?";
            var referencedUnits = Strings(section["unitIds"]).ToArray();
            if (referencedUnits.Length > MaxUnitsPerSection) Add(sectionId, "SIZE_LIMIT");
            foreach (var unitId in referencedUnits)
                if (!unitById.TryGetValue(unitId, out var unit) || Text(unit, "sectionId") != sectionId)
                    Add(sectionId, "UNIT_SECTION_MISMATCH");
        }
        foreach (var unit in units)
        {
            var unitId = Text(unit, "unitId") ?? "?";
            var sectionId = Text(unit, "sectionId");
            var referencedNodes = Strings(unit["nodeIds"]).ToArray();
            if (referencedNodes.Length > MaxNodesPerUnit) Add(unitId, "SIZE_LIMIT");
            foreach (var nodeId in referencedNodes)
                if (!nodeById.TryGetValue(nodeId, out var node) || Text(node, "unitId") != unitId || Text(node, "sectionId") != sectionId)
                    Add(unitId, "NODE_UNIT_MISMATCH");
        }
        var referencedLessons = new HashSet<string>(StringComparer.Ordinal);
        foreach (var node in nodes)
        {
            var nodeId = Text(node, "nodeId") ?? "?";
            var lessonIds = Strings(node["lessonIds"]).ToArray();
            if (lessonIds.Length == 0 || lessonIds.Length > 6) Add(nodeId, "LESSON_COUNT");
            foreach (var lessonId in lessonIds)
            {
                if (!bundleByLesson.ContainsKey(lessonId)) Add(nodeId, "BUNDLE_MISSING");
                referencedLessons.Add(lessonId);
            }
        }
        foreach (var bundle in bundles)
        {
            var lessonId = Text(bundle, "lessonId") ?? "?";
            if (!referencedLessons.Contains(lessonId)) Add(lessonId, "UNREFERENCED_BUNDLE");
        }
        if (bundleByLesson.ContainsKey(Text(manifest["placementBundle"] as JsonObject, "lessonId") ?? "")) Add("placement", "PLACEMENT_IS_PATH_LESSON");
        return output;
    }

    private static void CheckExercise(JsonObject exercise, string where, HashSet<string> assets, List<ContentProblem> output, bool nested = false)
    {
        var exerciseId = Text(exercise, "id") ?? "?";
        void Add(string problem) => output.Add(new(where + "/" + exerciseId, problem));
        if (!IdPattern().IsMatch(Text(exercise, "id") ?? "")) Add("INVALID_ID");
        var type = Text(exercise, "type") ?? "";
        if (!ExerciseTypes.Contains(type, StringComparer.Ordinal)) { Add("UNKNOWN_EXERCISE_TYPE"); return; }
        var rule = exercise["gradingRule"] as JsonObject;
        if (rule is null || !IsBoolean(rule["caseSensitive"]) || !IsBoolean(rule["ignorePunctuation"]) || !IsBoolean(rule["ignoreDiacritics"]))
        { Add("GRADING_RULE_FLAGS"); return; }

        var prompt = exercise["prompt"] as JsonObject;
        if (!Truthy(prompt?["text"]) || !Truthy(prompt?["locale"])) Add("PROMPT_TEXT_REQUIRED");
        if (!Strings(exercise["skillIds"]).Any()) Add("SKILL_REQUIRED");
        if (Strings(exercise["vocabularyIds"]).Count() > 20) Add("TOO_MANY_VOCABULARY");
        var content = exercise["content"] as JsonObject ?? new JsonObject();
        if (TextTypes.Contains(type))
        {
            var accepted = Strings(rule["acceptedText"]).ToArray();
            if (accepted.Length == 0 || accepted.Length > 20 || accepted.Any(text => string.IsNullOrWhiteSpace(text) || text.Length > 512)) Add("ACCEPTED_TEXT");
        }
        if (ChoiceTypes.Contains(type))
        {
            var choices = Objects(content["choices"]).ToArray();
            var choiceIds = choices.Select(choice => Text(choice, "id") ?? "").ToArray();
            if (choices.Length < 2 || choices.Length > 8) Add("CHOICE_COUNT");
            if (choiceIds.Distinct(StringComparer.Ordinal).Count() != choiceIds.Length) Add("DUPLICATE_CHOICE_ID");
            if (!choiceIds.Contains(Text(rule, "correctChoiceId") ?? "", StringComparer.Ordinal)) Add("CORRECT_CHOICE_MISSING");
            if (type == "imageChoice" && choices.Any(choice => !Truthy(choice["imageAssetId"]) || !assets.Contains(Text(choice, "imageAssetId") ?? ""))) Add("IMAGE_ASSET_MISSING");
            if (type == "storyQuestion" && !Truthy(content["passage"])) Add("PASSAGE_REQUIRED");
        }
        if (TokenTypes.Contains(type))
        {
            var tokens = Objects(content["tokens"]).ToArray();
            var tokenIds = tokens.Select(token => Text(token, "id") ?? "").ToHashSet(StringComparer.Ordinal);
            var correct = Strings(rule["correctTokenIds"]).ToArray();
            if (tokenIds.Count != tokens.Length) Add("DUPLICATE_TOKEN_ID");
            if (correct.Length == 0 || correct.Any(id => !tokenIds.Contains(id)) || correct.Distinct(StringComparer.Ordinal).Count() != correct.Length) Add("CORRECT_TOKENS");
            if (type == "sentenceOrder" && correct.Length != tokens.Length) Add("ORDER_USES_ALL_TOKENS");
        }
        if (type == "matchPairs")
        {
            var pairs = Objects(content["pairs"]).ToArray();
            var correct = Strings(rule["correctPairIds"]).ToHashSet(StringComparer.Ordinal);
            if (pairs.Length < 2) Add("PAIR_COUNT");
            if (pairs.Length != correct.Count || pairs.Any(pair => !correct.Contains(Text(pair, "id") ?? ""))) Add("CORRECT_PAIRS");
            var endpoints = pairs.SelectMany(pair => new[] { Text(pair["left"] as JsonObject, "id") ?? "", Text(pair["right"] as JsonObject, "id") ?? "" }).ToArray();
            if (endpoints.Distinct(StringComparer.Ordinal).Count() != endpoints.Length) Add("DUPLICATE_PAIR_ENDPOINT");
        }
        if (SpeechTypes.Contains(type))
        {
            if (!Truthy(content["referenceText"]) || !Truthy(content["locale"])) Add("SPEECH_CONTENT");
            if (exercise["nonSpeechAlternative"] is not JsonObject) Add("NON_SPEECH_ALTERNATIVE_REQUIRED");
        }
        var audio = prompt?["audioAssetId"];
        if (Truthy(audio) && !assets.Contains(Text(audio) ?? "")) Add("AUDIO_ASSET_MISSING");
        if (AudioPromptTypes.Contains(type) && !Truthy(audio)) Add("AUDIO_PROMPT_REQUIRED");
        if ((Truthy(audio) || AudioPromptTypes.Contains(type)) && exercise["nonAudioAlternative"] is not JsonObject && !SpeechTypes.Contains(type))
            Add("NON_AUDIO_ALTERNATIVE_REQUIRED");
        foreach (var alternative in new[] { exercise["nonAudioAlternative"], exercise["nonSpeechAlternative"] }.OfType<JsonObject>())
        {
            if (nested) Add("NESTED_ALTERNATIVE");
            var alternativeType = Text(alternative, "type") ?? "";
            if (Truthy((alternative["prompt"] as JsonObject)?["audioAssetId"]) || AudioPromptTypes.Contains(alternativeType) || SpeechTypes.Contains(alternativeType))
                Add("ALTERNATIVE_NEEDS_MEDIA");
            if (string.Join(',', Strings(alternative["skillIds"])) != string.Join(',', Strings(exercise["skillIds"]))) Add("ALTERNATIVE_SKILLS_DIFFER");
            CheckExercise(alternative, where + "/" + exerciseId, assets, output, true);
        }
    }

    private static IEnumerable<JsonObject> Objects(JsonNode? node) => node is JsonArray array ? array.OfType<JsonObject>() : [];
    private static IEnumerable<string> Strings(JsonNode? node) => node is JsonArray array ? array.Select(Text).Where(value => value is not null).Select(value => value!) : [];
    private static string? Text(JsonNode? node) => node is JsonValue value && value.TryGetValue<string>(out var text) ? text : null;
    private static string? Text(JsonObject? node, string field) => node is not null ? Text(node[field]) : null;
    private static bool Truthy(JsonNode? node) => node is JsonValue value && value.GetValueKind() switch
    {
        JsonValueKind.String => value.GetValue<string>().Length > 0,
        JsonValueKind.True => true,
        JsonValueKind.Number => value.GetValue<double>() != 0,
        _ => false
    };
    private static bool IsBoolean(JsonNode? node) => node?.GetValueKind() is JsonValueKind.True or JsonValueKind.False;
    private static double Number(JsonNode? node) => node is JsonValue value && value.GetValueKind() == JsonValueKind.Number ? value.GetValue<double>() : double.NaN;
    private static Dictionary<string, JsonObject> ToDictionaryLast(this IEnumerable<JsonObject> items, Func<JsonObject, string> key)
    {
        var result = new Dictionary<string, JsonObject>(StringComparer.Ordinal);
        foreach (var item in items) result[key(item)] = item;
        return result;
    }
}
