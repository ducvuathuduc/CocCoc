using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;

namespace CocEnglish.Learning;

public static class LearningPath
{
    public const int PlacementPass = 8;

    public static void AssertLessonUnlocked(JsonObject manifest, JsonObject enrollment, string lessonId)
    {
        var completed = Strings(enrollment.Text("completedLessonsJson"));
        var frontier = enrollment.Number("frontierNodeOrder");
        var node = (manifest["nodes"] as JsonArray ?? []).OfType<JsonObject>()
            .FirstOrDefault(candidate => (candidate["lessonIds"] as JsonArray ?? []).Any(id => id?.GetValue<string>() == lessonId));
        if (node is null) throw new ServiceException("NOT_FOUND", new() { ["lessonId"] = lessonId });
        var order = node.Number("order");
        if (order < frontier) return;
        if (order > frontier) Locked(manifest, frontier);
        var lessons = (node["lessonIds"] as JsonArray ?? []).Select(value => value?.GetValue<string>() ?? "").ToArray();
        var index = Array.IndexOf(lessons, lessonId);
        if (index < 0 || lessons.Take(index).Any(id => !completed.Contains(id, StringComparer.Ordinal))) Locked(manifest, frontier);
    }

    public static void AssertMasteryUnlocked(JsonObject manifest, JsonObject enrollment, string lessonId)
    {
        var frontier = enrollment.Number("frontierNodeOrder");
        var node = (manifest["nodes"] as JsonArray ?? []).OfType<JsonObject>()
            .FirstOrDefault(candidate => (candidate["lessonIds"] as JsonArray ?? []).Any(id => id?.GetValue<string>() == lessonId));
        if (node is null) throw new ServiceException("NOT_FOUND", new() { ["lessonId"] = lessonId });
        if (node.Number("order") >= frontier) Locked(manifest, frontier);
    }

    public static void AssertCheckpointUnlocked(JsonObject manifest, JsonObject enrollment, string lessonId)
    {
        var node = (manifest["nodes"] as JsonArray ?? []).OfType<JsonObject>()
            .FirstOrDefault(candidate => (candidate["lessonIds"] as JsonArray ?? []).Any(id => id?.GetValue<string>() == lessonId));
        if (node is null) throw new ServiceException("ACTIVITY_NOT_FOUND", new() { ["lessonId"] = lessonId });
        var sectionId = node.Text("sectionId") ?? "";
        var completed = Strings(enrollment.Text("completedLessonsJson"));
        var unmet = SortedNodes(manifest).Where(candidate => candidate.Text("sectionId") == sectionId &&
            candidate.Number("order") < node.Number("order") &&
            (candidate["lessonIds"] as JsonArray ?? []).Any(id => id is null || !completed.Contains(id.GetValue<string>(), StringComparer.Ordinal)))
            .Take(20).Select(candidate => candidate.Text("nodeId") ?? "").ToArray();
        if (unmet.Length > 0)
            throw new ServiceException("CHECKPOINT_LOCKED", new()
            {
                ["sectionId"] = sectionId,
                ["unmetNodeIds"] = new JsonArray(unmet.Select(id => (JsonNode?)JsonValue.Create(id)).ToArray())
            });
    }

    public static JsonObject CompleteLesson(JsonObject manifest, JsonObject enrollment, string lessonId)
    {
        var completed = (JsonNode.Parse(enrollment.Text("completedLessonsJson") ?? "[]") as JsonArray ?? [])
            .Select(value => value?.GetValue<string>() ?? "").ToList();
        if (!completed.Contains(lessonId, StringComparer.Ordinal))
            completed.Add(lessonId);
        var completedSet = completed.ToHashSet(StringComparer.Ordinal);
        var nodes = SortedNodes(manifest);
        var frontier = enrollment.Number("frontierNodeOrder");
        foreach (var node in nodes)
        {
            var order = node.Number("order");
            if (order < frontier) continue;
            if (order == frontier && (node["lessonIds"] as JsonArray ?? []).All(id => id is not null && completedSet.Contains(id.GetValue<string>())))
            {
                var next = nodes.FirstOrDefault(candidate => candidate.Number("order") > order);
                frontier = next is null ? order + 1 : next.Number("order");
                continue;
            }
            break;
        }
        enrollment["frontierNodeOrder"] = Math.Max(frontier, enrollment.Number("frontierNodeOrder"));
        enrollment["completedLessonsJson"] = System.Text.Json.JsonSerializer.Serialize(completed);
        return enrollment;
    }

    public static JsonObject CompleteUnit(JsonObject manifest, JsonObject enrollment, string unitId) =>
        CompleteLessons(manifest, enrollment, SortedNodes(manifest)
            .Where(node => node.Text("unitId") == unitId)
            .SelectMany(node => (node["lessonIds"] as JsonArray ?? []).Select(id => id?.GetValue<string>() ?? "")));

    public static JsonObject CompleteSection(JsonObject manifest, JsonObject enrollment, string sectionId) =>
        CompleteLessons(manifest, enrollment, SortedNodes(manifest)
            .Where(node => node.Text("sectionId") == sectionId)
            .SelectMany(node => (node["lessonIds"] as JsonArray ?? []).Select(id => id?.GetValue<string>() ?? "")));

    public static string? NodeIdAtFrontier(JsonObject manifest, long frontierNodeOrder) =>
        SortedNodes(manifest).FirstOrDefault(node => node.Number("order") == frontierNodeOrder)?.Text("nodeId");

    public static string? NodeIdForLesson(JsonObject manifest, string lessonId) =>
        SortedNodes(manifest).FirstOrDefault(node => (node["lessonIds"] as JsonArray ?? []).Any(id => id?.GetValue<string>() == lessonId))?.Text("nodeId");

    public static string NodeState(JsonObject node, long frontier, IReadOnlyCollection<string> completed, IReadOnlyCollection<string> mastered)
    {
        if (mastered.Contains(node.Text("nodeId") ?? "")) return "mastered";
        var order = node.Number("order");
        if (order < frontier) return "completed";
        if (order > frontier) return "locked";
        return (node["lessonIds"] as JsonArray ?? []).Any(id => id is not null && completed.Contains(id.GetValue<string>())) ? "current" : "available";
    }

    public static int PlacementFrontier(JsonObject manifest, bool passed)
    {
        var nodes = (manifest["nodes"] as JsonArray ?? []).OfType<JsonObject>().OrderBy(node => node.Number("order")).ToArray();
        var first = nodes.Length == 0 ? 0 : (int)nodes[0].Number("order");
        if (!passed) return first;
        var unit = (manifest["sections"] as JsonArray ?? []).OfType<JsonObject>()
            .SelectMany(section => (section["unitIds"] as JsonArray ?? []).Select(value => value?.GetValue<string>()))
            .Skip(1).FirstOrDefault();
        var target = unit is null ? null : nodes.FirstOrDefault(node => node.Text("unitId") == unit);
        return target is null ? first : (int)target.Number("order");
    }

    private static HashSet<string> Strings(string? json) => string.IsNullOrEmpty(json)
        ? new(StringComparer.Ordinal)
        : (JsonNode.Parse(json) as JsonArray ?? []).Select(value => value?.GetValue<string>() ?? "").ToHashSet(StringComparer.Ordinal);

    private static JsonObject[] SortedNodes(JsonObject manifest) =>
        (manifest["nodes"] as JsonArray ?? []).OfType<JsonObject>().OrderBy(node => node.Number("order")).ToArray();

    private static JsonObject CompleteLessons(JsonObject manifest, JsonObject enrollment, IEnumerable<string> lessonIds)
    {
        foreach (var lessonId in lessonIds) CompleteLesson(manifest, enrollment, lessonId);
        return enrollment;
    }

    private static void Locked(JsonObject manifest, long frontier)
    {
        var current = (manifest["nodes"] as JsonArray ?? []).OfType<JsonObject>()
            .Where(node => node.Number("order") >= frontier).OrderBy(node => node.Number("order")).FirstOrDefault();
        throw new ServiceException("NODE_LOCKED", new() { ["currentNodeId"] = current?.Text("nodeId") }, "Complete the previous node first.");
    }
}
