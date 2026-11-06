using System.Globalization;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressEventController(OwnerStore store) : ControllerBase
{
    /// <summary>Apply authenticated owner events using the durable inbox.</summary>
    [HttpPost("/internal/events")]
    [ContractOperation("consumeEvent")]
    [ServiceSenders("learning", "ai")]
    [ProducesResponseType<OperationReceiptResponse>(200)]
    public async Task<OperationReceiptResponse> Consume(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["eventId", "type", "schemaVersion", "producer", "aggregateId", "occurredAt", "requestId", "payload"]);
        const string uuid = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$";
        const string identifier = "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$";
        try
        {
            ProgressInput.Text(body["eventId"], "event", 36, 36, uuid);
            ProgressInput.Text(body["type"], "event", 1, 128);
            ProgressInput.Integer(body["schemaVersion"], "event", 1, 1);
            ProgressInput.Text(body["producer"], "event", 1, 64);
            ProgressInput.Text(body["aggregateId"], "event", 1, 36, identifier);
            var occurred = ProgressInput.Text(body["occurredAt"], "event", 1, 128);
            if (!DateTimeOffset.TryParse(occurred, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out _)) throw RequestQuery.Bad("event");
            ProgressInput.Text(body["requestId"], "event", 0, 64);
            if (body["payload"] is not JsonObject) throw RequestQuery.Bad("event");
        }
        catch (ServiceException) { throw RequestQuery.Bad("event"); }
        var type = body["type"]!.GetValue<string>(); var producer = body["producer"]!.GetValue<string>();
        if (type is not ("account.purged.v1" or "lesson.completed.v1" or "ai.practice.completed.v1")) throw RequestQuery.Bad("type");
        if (producer != (string)HttpContext.Items["ServiceSender"]! || type == "lesson.completed.v1" && producer != "learning" || type == "ai.practice.completed.v1" && producer != "ai") throw new ServiceException("FORBIDDEN");
        var payload = body["payload"]!.AsObject();
        if (type == "lesson.completed.v1")
        {
            static ServiceException InvalidLesson(string reason) => new("VALIDATION_ERROR", new() { ["reason"] = reason });
            if (payload.Any(p => !new[] { "completionId", "userId", "courseId", "lessonVersion", "rewardIdentity", "source", "mode", "originalCount", "originalCorrect", "assisted" }.Contains(p.Key, StringComparer.Ordinal))) throw InvalidLesson("UNKNOWN_FIELD");
            foreach (var field in new[] { "completionId", "userId", "courseId", "lessonVersion", "rewardIdentity" })
                if (payload[field]?.GetValueKind() != System.Text.Json.JsonValueKind.String || !Regex.IsMatch(payload[field]!.GetValue<string>(), identifier)) throw InvalidLesson("INVALID_IDENTIFIER");
            var mode = payload["mode"]?.GetValueKind() == System.Text.Json.JsonValueKind.String ? payload["mode"]!.GetValue<string>() : "";
            if (mode is not ("LESSON" or "STORIES" or "ADVENTURE" or "RADIO" or "SIDE_QUEST" or "CLASH" or "REVIEW" or "MASTERY" or "UNIT_REVIEW" or "PLACEMENT" or "TEST_OUT" or "CHECKPOINT")) throw InvalidLesson("MODE_NOT_IMPLEMENTED");
            string source; long count; long correct; bool assisted;
            try
            {
                source = ProgressInput.Text(payload["source"], "source", 1, 64);
                count = ProgressInput.Integer(payload["originalCount"], "originalCount", 0, int.MaxValue);
                correct = ProgressInput.Integer(payload["originalCorrect"], "originalCorrect", 0, int.MaxValue); assisted = ProgressInput.Boolean(payload["assisted"], "assisted");
            }
            catch (ServiceException) { throw InvalidLesson("INVALID_GRADED_RESULT"); }
            var check = CocEnglish.Progress.Domain.LessonPolicy.Award(mode, source, (int)count, (int)correct, assisted, true, 0, 0, 1);
            if (check.Error is not null) throw InvalidLesson(check.Error);
            var lessonEvent = body["eventId"]!.GetValue<string>();
            var occurred = DateTimeOffset.Parse(body["occurredAt"]!.GetValue<string>(), CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal);
            var lessonStatus = await store.ApplyInboxAsync(lessonEvent, type, CanonicalWire.BodyHash(body), (tx, token) => ProgressLesson.ApplyAsync(tx, lessonEvent, occurred, payload, token), ct);
            return new(lessonEvent, lessonStatus, Response.Headers["X-Request-ID"].ToString());
        }
        if (type == "ai.practice.completed.v1")
        {
            static ServiceException Invalid(string reason) => new("VALIDATION_ERROR", new() { ["reason"] = reason });
            if (payload.Any(p => !new[] { "completionId", "userId", "kind", "courseId", "scenarioId", "xp", "wordsUsed", "stars" }.Contains(p.Key, StringComparer.Ordinal))) throw Invalid("UNKNOWN_FIELD");
            foreach (var field in new[] { "completionId", "userId", "courseId", "scenarioId" })
                if (payload[field]?.GetValueKind() != System.Text.Json.JsonValueKind.String || !Regex.IsMatch(payload[field]!.GetValue<string>(), identifier)) throw Invalid("INVALID_IDENTIFIER");
            if (payload["userId"]!.GetValue<string>() != body["aggregateId"]!.GetValue<string>()) throw Invalid("AGGREGATE_MISMATCH");
            try
            {
                var kind = ProgressInput.Text(payload["kind"], "kind", 1, 20);
                if (kind is not ("ROLEPLAY" or "VIDEO_CALL")) throw Invalid("INVALID_PRACTICE");
                ProgressInput.Integer(payload["xp"], "xp", 0, 100); ProgressInput.Integer(payload["wordsUsed"], "wordsUsed", 0, int.MaxValue); ProgressInput.Integer(payload["stars"], "stars", 0, 3);
            }
            catch (ServiceException) { throw Invalid("INVALID_PRACTICE"); }
            var practiceEvent = body["eventId"]!.GetValue<string>();
            var occurred = DateTimeOffset.Parse(body["occurredAt"]!.GetValue<string>(), CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal);
            var practiceStatus = await store.ApplyInboxAsync(practiceEvent, type, CanonicalWire.BodyHash(body), (tx, token) => ProgressPractice.ApplyAsync(tx, practiceEvent, occurred, payload, token), ct);
            return new(practiceEvent, practiceStatus, Response.Headers["X-Request-ID"].ToString());
        }
        var user = payload["userId"]?.GetValueKind() == System.Text.Json.JsonValueKind.String ? payload["userId"]!.GetValue<string>() : "";
        var request = payload["requestId"]?.GetValueKind() == System.Text.Json.JsonValueKind.String ? payload["requestId"]!.GetValue<string>() : "";
        var owner = payload["owner"]?.GetValueKind() == System.Text.Json.JsonValueKind.String ? payload["owner"]!.GetValue<string>() : "";
        if (!Regex.IsMatch(user, identifier) || !Regex.IsMatch(request, uuid) || owner != producer) throw new ServiceException("VALIDATION_ERROR", new() { ["reason"] = "INVALID_PURGE_ACK" });
        var eventId = body["eventId"]!.GetValue<string>(); var deletion = new ProgressDeletion(store);
        var status = await store.ApplyInboxAsync(eventId, type, CanonicalWire.BodyHash(body), (tx, token) => deletion.RecordAckAsync(tx, user, request, owner, token), ct);
        await deletion.PurgeAsync(user, 50, ct);
        return new(eventId, status, Response.Headers["X-Request-ID"].ToString());
    }
}
