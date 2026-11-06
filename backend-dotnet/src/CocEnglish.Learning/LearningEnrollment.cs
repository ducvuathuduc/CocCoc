using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;

namespace CocEnglish.Learning;

public static class LearningEnrollment
{
    public static async Task<JsonObject> CommandAsync(OwnerSession tx, string user, string courseId, string command, long? expectedRevision, JsonObject? manifest, string key, string requestId, CancellationToken ct)
    {
        var id = CanonicalWire.RowId("enrollment", user, courseId);
        var row = await tx.GetAsync("l_enrollments", id, ct);
        if (row is null || !string.IsNullOrEmpty(row.Text("removedAt"))) throw new ServiceException("NOT_FOUND", new() { ["courseId"] = courseId, ["reason"] = "NOT_ENROLLED" });
        if (expectedRevision is not null && row.Number("revision") != expectedRevision) throw new ServiceException("REVISION_CONFLICT", new() { ["currentRevision"] = row.Number("revision") });
        if (command == "switchCourse")
        {
            var others = await tx.ListAsync("l_enrollments", new(Where: new Dictionary<string, object?> { ["userId"] = user, ["active"] = true }, Limit: 20), ct);
            foreach (var other in others)
            {
                if (other.Id == id) continue;
                var fresh = await tx.GetAsync("l_enrollments", other.Id, ct);
                if (fresh?.Flag("active") == true) { fresh["active"] = false; tx.Put("l_enrollments", other.Id, fresh); }
            }
            row["active"] = true;
        }
        else if (command is "resetCourse" or "removeCourse")
        {
            var slotId = CanonicalWire.RowId("slot", user, courseId);
            var slot = await tx.GetAsync("l_active_slots", slotId, ct);
            if (slot is not null)
            {
                var sessionId = slot.Text("sessionId") ?? "";
                var session = await tx.GetAsync("l_sessions", sessionId, ct);
                if (session is not null && session.Text("userId") == user && session.Text("courseId") == courseId && session.Text("status") == "ACTIVE")
                {
                    var expires = DateTimeOffset.Parse(session.Text("expiresAt")!, System.Globalization.CultureInfo.InvariantCulture);
                    session["status"] = expires <= tx.Now ? "EXPIRED" : "ABANDONED";
                    tx.Put("l_sessions", sessionId, session);
                }
                tx.Delete("l_active_slots", slotId);
            }
            if (command == "removeCourse") { row["active"] = false; row["removedAt"] = tx.NowIso; }
            else
            {
                if (manifest is null) throw new ServiceException("INTERNAL_ERROR");
                row["courseVersion"] = manifest.Text("courseVersion"); row["frontierNodeOrder"] = LearningPath.PlacementFrontier(manifest, false);
                row["completedLessonsJson"] = "[]"; row["masteredNodesJson"] = "[]"; row["legendaryNodesJson"] = "[]"; row["proficiencyScore"] = 0;
            }
        }
        else throw new ServiceException("INTERNAL_ERROR");
        tx.Put("l_enrollments", id, row);
        return command == "removeCourse" ? new JsonObject { ["operationId"] = key, ["status"] = "accepted", ["requestId"] = requestId } : Dto((await tx.GetAsync("l_enrollments", id, ct))!);
    }

    public static async Task<JsonObject> EnrollAsync(OwnerSession tx, string user, string courseId, string startPoint, string? sessionId, JsonObject manifest, CancellationToken ct)
    {
        var id = CanonicalWire.RowId("enrollment", user, courseId);
        var existing = await tx.GetAsync("l_enrollments", id, ct);
        if (existing is not null && string.IsNullOrEmpty(existing.Text("removedAt"))) return Dto(existing);
        var frontier = LearningPath.PlacementFrontier(manifest, false);
        if (startPoint == "placement")
        {
            if (string.IsNullOrEmpty(sessionId)) throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "placementSessionId" });
            var session = await tx.GetAsync("l_sessions", sessionId, ct);
            if (session is null || session.Text("userId") != user) throw new ServiceException("NOT_FOUND", new() { ["field"] = "placementSessionId" });
            if (session.Text("mode") != "PLACEMENT" || session.Text("courseId") != courseId || session.Text("status") != "COMPLETED")
                throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "placementSessionId", ["reason"] = "NOT_A_COMPLETED_PLACEMENT" });
            var result = string.IsNullOrEmpty(session.Text("resultJson")) ? null : JsonNode.Parse(session.Text("resultJson")!);
            var correct = (result?["completion"] as JsonObject)?.Number("originalCorrect") ?? 0;
            frontier = LearningPath.PlacementFrontier(manifest, correct >= LearningPath.PlacementPass);
        }
        var others = await tx.ListAsync("l_enrollments", new(Where: new Dictionary<string, object?> { ["userId"] = user, ["active"] = true }, Limit: 20), ct);
        foreach (var other in others)
        {
            if (other.Id == id) continue;
            var row = await tx.GetAsync("l_enrollments", other.Id, ct);
            if (row?.Flag("active") == true) { row["active"] = false; tx.Put("l_enrollments", other.Id, row); }
        }
        tx.Put("l_enrollments", id, new JsonObject {
            ["userId"] = user, ["courseId"] = courseId, ["courseVersion"] = manifest.Text("courseVersion"), ["frontierNodeOrder"] = frontier,
            ["completedLessonsJson"] = "[]", ["masteredNodesJson"] = "[]", ["legendaryNodesJson"] = "[]", ["placementUsed"] = startPoint == "placement",
            ["active"] = true, ["proficiencyScore"] = 0, ["lastPracticedAt"] = null, ["removedAt"] = null
        });
        return Dto((await tx.GetAsync("l_enrollments", id, ct))!);
    }

    public static JsonObject Dto(JsonObject row)
    {
        var completed = JsonNode.Parse(row.Text("completedLessonsJson") ?? "[]") as JsonArray ?? [];
        var mastered = JsonNode.Parse(row.Text("masteredNodesJson") ?? "[]") as JsonArray ?? [];
        return new JsonObject { ["courseId"] = row.Text("courseId"), ["courseVersion"] = row.Text("courseVersion"),
            ["frontierNodeOrder"] = row.Number("frontierNodeOrder"), ["completedLessonIds"] = new JsonArray(completed.TakeLast(1200).Select(x => x?.DeepClone()).ToArray()),
            ["masteredNodeIds"] = new JsonArray(mastered.Take(600).Select(x => x?.DeepClone()).ToArray()), ["revision"] = row.Number("revision") };
    }
}
