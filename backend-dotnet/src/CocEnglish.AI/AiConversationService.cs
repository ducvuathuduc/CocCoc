using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.Configuration;

namespace CocEnglish.AI;

internal sealed record AiScenario(string Id, string Title, string Level, string PartnerName, string[] TargetWords, AiScenarioStep[] Steps, string Closing);
internal sealed record AiScenarioStep(string Partner, string Expect, string[] Keywords, string HintVi);
internal sealed record TutorInput(string RequestId, string? ExerciseId, string? LessonVersion, string? ScenarioId, string LearnerText, string Level);
internal sealed record ConversationStart(string Kind, string CourseId, string ScenarioId, string? VoiceSessionId);

internal static class AiScenarioCatalog
{
    private static readonly IReadOnlyDictionary<string, AiScenario> Scenarios = Load();
    public static AiScenario? Find(string id) => Scenarios.GetValueOrDefault(id);

    private static IReadOnlyDictionary<string, AiScenario> Load()
    {
        using var stream = typeof(AiScenarioCatalog).Assembly.GetManifestResourceStream("CocEnglish.AI.Scenarios.json")
            ?? throw new InvalidOperationException("AI_SCENARIO_RESOURCE_MISSING");
        var scenarios = JsonSerializer.Deserialize<AiScenario[]>(stream, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? throw new InvalidOperationException("AI_SCENARIO_RESOURCE_INVALID");
        return scenarios.ToDictionary(scenario => scenario.Id, StringComparer.Ordinal);
    }
}

/// <summary>Deterministic authored tutor and conversation flows from services/ai/application/conversations.ts.</summary>
public sealed class AiConversationService(OwnerStore store, IRowDriver rows, TimeProvider clock, IConfiguration configuration)
{
    private const int DailyTextLimit = 100;
    private const int MaxTurns = 60;
    private const int ActiveTtlMinutes = 30;
    private const int HistoryTtlDays = 365;
    private static readonly string[] Plans = ["FREE", "SUPER", "MAX"];
    private static readonly string[] EntitlementStatuses = ["ACTIVE", "GRACE", "HOLD", "CANCELED", "EXPIRED", "REVOKED"];

    internal async Task<ReceiptResult> TutorAsync(string userId, TutorInput input, string bodyHash, CancellationToken ct)
    {
        return await store.CommitWithReceiptAsync(new(userId, "tutorFeedback", input.RequestId), bodyHash, async (tx, token) =>
        {
            var now = tx.Now;
            await CountTextUsageAsync(tx, userId, now, token);
            var scenario = input.ScenarioId is null ? null : AiScenarioCatalog.Find(input.ScenarioId);
            var conversation = scenario is null ? null : await ActiveConversationAsync(tx, userId, scenario.Id, null, token);
            if (conversation is not null)
            {
                var turn = ApplyTurn(tx, conversation.Value.Id, conversation.Value.Row, scenario!, input.LearnerText, now);
                return new OperationResponse(200, new JsonObject
                {
                    ["requestId"] = input.RequestId,
                    ["tutorText"] = turn.Reply,
                    ["correction"] = turn.OnTopic ? null : turn.Step.Expect,
                    ["explanation"] = turn.OnTopic ? "Tốt lắm! " + turn.Step.HintVi : turn.Step.HintVi,
                    ["source"] = "authored",
                    ["assessedPronunciation"] = false
                });
            }
            return new OperationResponse(200, new JsonObject
            {
                ["requestId"] = input.RequestId,
                ["tutorText"] = string.IsNullOrWhiteSpace(input.LearnerText)
                    ? "Write a short sentence in English and I will help you."
                    : "Good try! Keep your sentence short and clear, and check the example answer.",
                ["correction"] = null,
                ["explanation"] = "Hãy so sánh câu của bạn với đáp án mẫu trong bài học.",
                ["source"] = "fallback",
                ["assessedPronunciation"] = false
            });
        }, ct);
    }

    internal async Task<JsonObject> ListAsync(string userId, string? kind, string? scenarioId, string? cursor, int limit, CancellationToken ct)
    {
        var offset = 0;
        if (cursor is not null)
        {
            var match = Regex.Match(cursor, "^o([0-9]{1,6})$", RegexOptions.CultureInvariant);
            if (!match.Success) throw Invalid("cursor");
            offset = int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture);
        }
        var where = new Dictionary<string, object?> { ["userId"] = userId };
        if (kind is not null) where["kind"] = kind;
        if (scenarioId is not null) where["scenarioId"] = scenarioId;
        var page = await rows.ListAsync("a_conversations", new(Where: where, OrderBy: [new("startedAt", Descending: true)], Limit: limit + 1, Offset: offset), ct);
        var now = clock.GetUtcNow();
        var items = new JsonArray(page.Take(limit).Select(row => (JsonNode?)ToView(row.Data, now)).ToArray());
        return new JsonObject
        {
            ["items"] = items,
            ["nextCursor"] = page.Count > limit ? "o" + (offset + limit).ToString(CultureInfo.InvariantCulture) : null,
            ["asOf"] = OwnerSchema.Iso(now)
        };
    }

    /// <summary>Read the authored learner line before calling an external speech scorer.</summary>
    internal async Task<string?> ExpectedLineAsync(string userId, string voiceSessionId, CancellationToken ct)
    {
        var page = await rows.ListAsync("a_conversations", new(Where: new Dictionary<string, object?>
        {
            ["userId"] = userId,
            ["status"] = "ACTIVE",
            ["voiceSessionId"] = voiceSessionId
        }, OrderBy: [new("startedAt", Descending: true)], Limit: 1), ct);
        var row = page.FirstOrDefault()?.Data;
        if (row is null || IsExpired(row, clock.GetUtcNow())) return null;
        var scenario = AiScenarioCatalog.Find(row.Text("scenarioId") ?? "");
        if (scenario is null || scenario.Steps.Length == 0) return null;
        var draft = DraftOf(row);
        if (draft.StepIndex >= scenario.Steps.Length) return null;
        return scenario.Steps[Math.Min(draft.StepIndex, scenario.Steps.Length - 1)].Expect;
    }

    /// <summary>Apply one recognized voice turn inside its caller's receipt transaction.</summary>
    internal async Task<AiVoiceTurnApplication> ApplyVoiceTurnAsync(
        OwnerSession tx, string userId, string voiceSessionId, string turnId, string transcript, CancellationToken ct)
    {
        var conversation = await ActiveConversationAsync(tx, userId, null, voiceSessionId, ct);
        if (conversation is null)
        {
            return new AiVoiceTurnApplication(transcript, new JsonObject
            {
                ["requestId"] = turnId,
                ["tutorText"] = "I am listening. Start a roleplay to practice a conversation with me.",
                ["correction"] = null,
                ["explanation"] = "Hãy bắt đầu một bài hội thoại để luyện nói.",
                ["source"] = "fallback",
                ["assessedPronunciation"] = false
            });
        }

        var scenario = AiScenarioCatalog.Find(conversation.Value.Row.Text("scenarioId") ?? "")
            ?? throw new ServiceException("NOT_FOUND", new() { ["field"] = "scenarioId" });
        var turn = ApplyTurn(tx, conversation.Value.Id, conversation.Value.Row, scenario, transcript, tx.Now);
        return new AiVoiceTurnApplication(transcript, new JsonObject
        {
            ["requestId"] = turnId,
            ["tutorText"] = turn.Reply,
            ["correction"] = null,
            ["explanation"] = turn.Step.HintVi,
            ["source"] = "authored",
            ["assessedPronunciation"] = false
        });
    }

    internal async Task<ReceiptResult> StartAsync(string userId, ConversationStart input, string key, string bodyHash, CancellationToken ct)
    {
        var scenario = AiScenarioCatalog.Find(input.ScenarioId);
        if (scenario is null) throw new ServiceException("NOT_FOUND", new() { ["field"] = "scenarioId" });
        var requiredPlan = MinimumPlan(input.Kind);
        var projection = await ReadProjectionAsync(userId, ct);
        var effectivePlan = EffectivePlan(projection, clock.GetUtcNow());
        if (PlanRank(effectivePlan) < PlanRank(requiredPlan))
            throw new ServiceException("ENTITLEMENT_REQUIRED", new() { ["feature"] = input.Kind, ["required"] = requiredPlan });

        var previous = await rows.ListAsync("a_conversations", new(Where: new Dictionary<string, object?>
        {
            ["userId"] = userId, ["scenarioId"] = input.ScenarioId, ["status"] = "ACTIVE"
        }, Limit: 20), ct);
        var conversationId = CanonicalWire.RowId("conversation", userId, key);
        return await store.CommitWithReceiptAsync(new(userId, "startConversation", key), bodyHash, async (tx, token) =>
        {
            var now = tx.Now;
            if (input.VoiceSessionId is not null)
            {
                var voice = await tx.GetAsync("a_voice_sessions", CanonicalWire.RowId("voice", input.VoiceSessionId), token);
                if (voice is null || voice.Text("userId") != userId || voice.Text("mode") != "TURN")
                    throw new ServiceException("NOT_FOUND", new() { ["field"] = "voiceSessionId" });
                if (voice.Text("status") != "ACTIVE" || Date(voice, "expiresAt") <= now) throw new ServiceException("VOICE_SESSION_EXPIRED");
            }
            foreach (var prior in previous)
            {
                if (prior.Id == conversationId) continue;
                var old = await tx.GetAsync("a_conversations", prior.Id, token);
                if (old is not null && old.Text("status") == "ACTIVE")
                {
                    old["status"] = "ABANDONED";
                    tx.Put("a_conversations", prior.Id, old);
                }
            }
            var expiresAt = OwnerSchema.Iso(now.AddMinutes(ActiveTtlMinutes));
            var row = new JsonObject
            {
                ["conversationId"] = conversationId,
                ["userId"] = userId,
                ["kind"] = input.Kind,
                ["courseId"] = input.CourseId,
                ["scenarioId"] = input.ScenarioId,
                ["voiceSessionId"] = input.VoiceSessionId,
                ["status"] = "ACTIVE",
                ["startedAt"] = OwnerSchema.Iso(now),
                ["completedAt"] = null,
                ["turnCount"] = 0,
                ["wordsUsed"] = 0,
                ["stars"] = 0,
                ["xpAwarded"] = 0,
                ["feedbackJson"] = "{\"draft\":true,\"stepIndex\":0,\"onTopicTurns\":0,\"usedWords\":[]}",
                ["transcriptFileId"] = null,
                ["expiresAt"] = expiresAt
            };
            tx.Put("a_conversations", conversationId, row);
            return new OperationResponse(200, ToView(row, now));
        }, ct);
    }

    internal async Task<(ReceiptResult Receipt, IReadOnlyList<string> EventIds)> CompleteAsync(
        string userId, string conversationId, string endReason, string key, string bodyHash, CancellationToken ct)
    {
        var eventIds = new List<string>();
        var receipt = await store.CommitWithReceiptAsync(new(userId, "completeConversation", key), bodyHash, async (tx, token) =>
        {
            eventIds.Clear();
            var now = tx.Now;
            var row = await tx.GetAsync("a_conversations", conversationId, token);
            if (row is null || row.Text("userId") != userId) throw new ServiceException("NOT_FOUND");
            if (row.Text("status") != "ACTIVE") return new OperationResponse(200, ToView(row, now));
            var scenario = AiScenarioCatalog.Find(row.Text("scenarioId") ?? "");
            if (scenario is null) throw new ServiceException("NOT_FOUND", new() { ["field"] = "scenarioId" });
            var expired = IsExpired(row, now);
            if (expired || endReason == "USER_EXIT")
            {
                row["status"] = expired ? "EXPIRED" : "ABANDONED";
                row["completedAt"] = OwnerSchema.Iso(now);
                row["feedbackJson"] = null;
                row["expiresAt"] = OwnerSchema.Iso(now.AddDays(HistoryTtlDays));
                tx.Put("a_conversations", conversationId, row);
                await ReleaseVoiceAsync(tx, row, userId, now, token);
                return new OperationResponse(200, ToView(row, now));
            }

            var draft = DraftOf(row);
            if (draft.StepIndex < scenario.Steps.Length)
                throw new ServiceException("SESSION_INCOMPLETE", new() { ["completedSteps"] = draft.StepIndex, ["requiredSteps"] = scenario.Steps.Length });
            var words = draft.UsedWords.Distinct(StringComparer.Ordinal).Take(60).ToArray();
            var wordGoal = (int)Math.Ceiling(scenario.TargetWords.Length / 2d);
            var stars = 1 + (draft.OnTopicTurns >= scenario.Steps.Length ? 1 : 0) + (words.Length >= wordGoal ? 1 : 0);
            var strengths = new List<string>();
            var improvements = new List<string>();
            if (draft.OnTopicTurns >= scenario.Steps.Length) strengths.Add("You answered every question on topic.");
            else improvements.Add("Answer each question with the key words from the conversation.");
            if (words.Length >= wordGoal) strengths.Add($"You used {words.Length} useful words.");
            else improvements.Add("Try to use more of these words: " + string.Join(", ", scenario.TargetWords.Where(word => !words.Contains(word, StringComparer.Ordinal)).Take(4)) + ".");
            strengths.Add($"You finished \"{scenario.Title}\".");
            var feedback = new JsonObject
            {
                ["summary"] = stars == 3
                    ? $"Excellent! You completed \"{scenario.Title}\" with {scenario.PartnerName}."
                    : $"Good job! You completed \"{scenario.Title}\" with {scenario.PartnerName}. Keep practicing.",
                ["strengths"] = new JsonArray(strengths.Take(5).Select(value => (JsonNode?)JsonValue.Create(value)).ToArray()),
                ["improvements"] = new JsonArray(improvements.Take(5).Select(value => (JsonNode?)JsonValue.Create(value)).ToArray()),
                ["usedWords"] = new JsonArray(words.Select(value => (JsonNode?)JsonValue.Create(value)).ToArray())
            };
            row["status"] = "COMPLETED";
            row["completedAt"] = OwnerSchema.Iso(now);
            row["wordsUsed"] = words.Length;
            row["stars"] = stars;
            row["xpAwarded"] = 5 + 5 * stars;
            row["feedbackJson"] = feedback.ToJsonString();
            row["expiresAt"] = OwnerSchema.Iso(now.AddDays(HistoryTtlDays));
            tx.Put("a_conversations", conversationId, row);
            await ReleaseVoiceAsync(tx, row, userId, now, token);

            var eventId = DeterministicUuid("ai.practice.completed.v1|" + conversationId);
            var envelope = new JsonObject
            {
                ["eventId"] = eventId,
                ["type"] = "ai.practice.completed.v1",
                ["schemaVersion"] = 1,
                ["producer"] = "ai",
                ["aggregateId"] = userId,
                ["occurredAt"] = OwnerSchema.Iso(now),
                ["requestId"] = eventId,
                ["payload"] = new JsonObject
                {
                    ["completionId"] = conversationId,
                    ["userId"] = userId,
                    ["kind"] = row.Text("kind"),
                    ["courseId"] = row.Text("courseId"),
                    ["scenarioId"] = row.Text("scenarioId"),
                    ["xp"] = 5 + 5 * stars,
                    ["wordsUsed"] = words.Length,
                    ["stars"] = stars
                }
            };
            tx.Put("a_outbox", eventId, new JsonObject
            {
                ["eventId"] = eventId,
                ["type"] = "ai.practice.completed.v1",
                ["schemaVersion"] = 1,
                ["aggregateId"] = userId,
                ["occurredAt"] = OwnerSchema.Iso(now),
                ["payloadJson"] = envelope.ToJsonString(),
                ["attempt"] = 0,
                ["nextAttemptAt"] = OwnerSchema.Iso(now),
                ["leaseOwner"] = null,
                ["leaseUntil"] = null,
                ["status"] = "PENDING",
                ["ackAt"] = null
            });
            eventIds.Add(eventId);
            return new OperationResponse(200, ToView(row, now));
        }, ct);
        return (receipt, receipt.Status == "created" ? eventIds : []);
    }

    private async Task CountTextUsageAsync(OwnerSession tx, string userId, DateTimeOffset now, CancellationToken ct)
    {
        var day = OwnerSchema.Iso(now)[..10];
        var id = CanonicalWire.RowId("usage", userId, day);
        var row = await tx.GetAsync("a_usage", id, ct);
        var count = row?.Number("textRequests") ?? 0;
        if (count + 1 > DailyTextLimit) throw new ServiceException("QUOTA_EXHAUSTED", new() { ["utcDay"] = day });
        tx.Put("a_usage", id, new JsonObject
        {
            ["userId"] = userId,
            ["utcDay"] = day,
            ["liveReservedSeconds"] = row?.Number("liveReservedSeconds") ?? 0,
            ["liveUsedSeconds"] = row?.Number("liveUsedSeconds") ?? 0,
            ["liveGrants"] = row?.Number("liveGrants") ?? 0,
            ["textRequests"] = count + 1,
            ["recordedSpeechSeconds"] = row?.Number("recordedSpeechSeconds") ?? 0,
            ["recordedReservedSeconds"] = row?.Number("recordedReservedSeconds") ?? 0,
            ["reservationIdsJson"] = row?.Text("reservationIdsJson") ?? "[]"
        });
    }

    private async Task<(string Id, JsonObject Row)?> ActiveConversationAsync(OwnerSession tx, string userId, string? scenarioId, string? voiceSessionId, CancellationToken ct)
    {
        var where = new Dictionary<string, object?> { ["userId"] = userId, ["status"] = "ACTIVE" };
        if (scenarioId is not null) where["scenarioId"] = scenarioId;
        if (voiceSessionId is not null) where["voiceSessionId"] = voiceSessionId;
        var page = await tx.ListAsync("a_conversations", new(Where: where, OrderBy: [new("startedAt", Descending: true)], Limit: 1), ct);
        var first = page.FirstOrDefault();
        if (first is null) return null;
        var row = await tx.GetAsync("a_conversations", first.Id, ct);
        if (row is null || row.Text("status") != "ACTIVE" || IsExpired(row, tx.Now)) return null;
        return (first.Id, row);
    }

    private static (AiScenarioStep Step, bool OnTopic, string Reply) ApplyTurn(OwnerSession tx, string id, JsonObject row, AiScenario scenario, string learnerText, DateTimeOffset now)
    {
        var turnCount = row.Number("turnCount");
        if (turnCount >= MaxTurns) throw new ServiceException("SESSION_CONFLICT", new() { ["reason"] = "MAX_TURNS" });
        var draft = DraftOf(row);
        var finishedBefore = draft.StepIndex >= scenario.Steps.Length;
        var step = scenario.Steps[Math.Min(draft.StepIndex, scenario.Steps.Length - 1)];
        var hit = !finishedBefore && IsOnTopic(step, learnerText);
        var used = draft.UsedWords.Concat(UsedTargetWords(scenario, learnerText)).Distinct(StringComparer.Ordinal).ToArray();
        var nextIndex = hit ? draft.StepIndex + 1 : draft.StepIndex;
        var nextOnTopic = draft.OnTopicTurns + (hit ? 1 : 0);
        row["turnCount"] = turnCount + 1;
        row["wordsUsed"] = used.Length;
        row["feedbackJson"] = new JsonObject
        {
            ["draft"] = true,
            ["stepIndex"] = nextIndex,
            ["onTopicTurns"] = nextOnTopic,
            ["usedWords"] = new JsonArray(used.Select(value => (JsonNode?)JsonValue.Create(value)).ToArray())
        }.ToJsonString();
        tx.Put("a_conversations", id, row);
        var finished = nextIndex >= scenario.Steps.Length;
        var reply = finished ? scenario.Closing : hit ? scenario.Steps[nextIndex].Partner : "Let's try again. " + step.Partner;
        return (step, hit, reply);
    }

    private async Task<JsonObject?> ReadProjectionAsync(string userId, CancellationToken ct)
    {
        var row = await rows.ReadAsync("a_usage", CanonicalWire.RowId("entitlement", userId), ct);
        if (row is null || row.Data.Text("reservationIdsJson") is not { } json) return null;
        try
        {
            var projection = JsonNode.Parse(json) as JsonObject;
            if (projection is null || !Plans.Contains(projection.Text("plan"), StringComparer.Ordinal) ||
                !EntitlementStatuses.Contains(projection.Text("status"), StringComparer.Ordinal) ||
                projection["entitlementRevision"]?.GetValueKind() != JsonValueKind.Number ||
                !projection["entitlementRevision"]!.AsValue().TryGetValue<double>(out var revision) || !double.IsFinite(revision) || Math.Truncate(revision) != revision)
                return null;
            return projection;
        }
        catch (JsonException) { return null; }
    }

    private string MinimumPlan(string kind)
    {
        var setting = configuration[kind == "ROLEPLAY" ? "COC_AI_ROLEPLAY_MIN_PLAN" : "COC_AI_VIDEO_CALL_MIN_PLAN"];
        return Plans.Contains(setting, StringComparer.Ordinal) ? setting! : "MAX";
    }

    private static string EffectivePlan(JsonObject? projection, DateTimeOffset now)
    {
        if (projection is null || projection.Text("status") is not ("ACTIVE" or "GRACE")) return "FREE";
        if (projection.Text("expiresAt") is { Length: > 0 } expiry && DateTimeOffset.TryParse(expiry, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var end) && end <= now) return "FREE";
        return projection.Text("plan") ?? "FREE";
    }

    private static int PlanRank(string plan) => plan switch { "FREE" => 0, "SUPER" => 1, "MAX" => 2, _ => 0 };

    private async Task ReleaseVoiceAsync(OwnerSession tx, JsonObject conversation, string userId, DateTimeOffset now, CancellationToken ct)
    {
        if (conversation.Text("voiceSessionId") is not { } voiceId) return;
        var voiceRowId = CanonicalWire.RowId("voice", voiceId);
        var voice = await tx.GetAsync("a_voice_sessions", voiceRowId, ct);
        if (voice is not null && voice.Text("status") != "CLOSED" && voice.Text("userId") == userId)
        {
            voice["status"] = "CLOSED";
            tx.Put("a_voice_sessions", voiceRowId, voice);
            var slotId = CanonicalWire.RowId("slot", userId);
            var slot = await tx.GetAsync("a_active_slots", slotId, ct);
            if (slot?.Text("sessionId") == voiceId) tx.Delete("a_active_slots", slotId);
        }
    }

    private static JsonObject ToView(JsonObject row, DateTimeOffset now)
    {
        var status = IsExpired(row, now) ? "EXPIRED" : row.Text("status") ?? "";
        JsonNode? feedback = null;
        if (status == "COMPLETED" && row.Text("feedbackJson") is { Length: > 0 } json)
        {
            try { feedback = JsonNode.Parse(json); }
            catch (JsonException) { feedback = null; }
        }
        return new JsonObject
        {
            ["conversationId"] = row.Text("conversationId"),
            ["kind"] = row.Text("kind"),
            ["courseId"] = row.Text("courseId"),
            ["scenarioId"] = row.Text("scenarioId"),
            ["voiceSessionId"] = row.Text("voiceSessionId"),
            ["status"] = status,
            ["startedAt"] = row.Text("startedAt"),
            ["completedAt"] = row.Text("completedAt"),
            ["turnCount"] = row.Number("turnCount"),
            ["wordsUsed"] = row.Number("wordsUsed"),
            ["stars"] = row.Number("stars"),
            ["xpAwarded"] = row.Number("xpAwarded"),
            ["feedback"] = feedback,
            ["expiresAt"] = row.Text("expiresAt")
        };
    }

    private static (int StepIndex, int OnTopicTurns, string[] UsedWords) DraftOf(JsonObject row)
    {
        try
        {
            var draft = JsonNode.Parse(row.Text("feedbackJson") ?? "") as JsonObject;
            if (draft?.Flag("draft") == true)
                return ((int)draft.Number("stepIndex"), (int)draft.Number("onTopicTurns"), draft["usedWords"] is JsonArray words ? words.Select(Text).Where(value => value is not null).Select(value => value!).ToArray() : []);
        }
        catch (JsonException) { }
        return (0, 0, []);
    }

    private static bool IsExpired(JsonObject row, DateTimeOffset now) => row.Text("status") == "ACTIVE" && Date(row, "expiresAt") <= now;
    private static DateTimeOffset Date(JsonObject row, string key) => DateTimeOffset.Parse(row[key]!.GetValue<string>(), CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal);

    private static bool IsOnTopic(AiScenarioStep step, string text)
    {
        var normalized = Normalize(text);
        return step.Keywords.Any(keyword => normalized.Contains(" " + Normalize(keyword).Trim() + " ", StringComparison.Ordinal));
    }

    private static string[] UsedTargetWords(AiScenario scenario, string text)
    {
        var normalized = Normalize(text);
        return scenario.TargetWords.Where(word => normalized.Contains(" " + Normalize(word).Trim() + " ", StringComparison.Ordinal)).ToArray();
    }

    private static string Normalize(string text)
    {
        var lower = text.ToLowerInvariant().Replace('\'', '\u2019');
        lower = Regex.Replace(lower, "[^a-z0-9\u2019\\- ]+", " ", RegexOptions.CultureInvariant);
        return " " + Regex.Replace(lower, "\\s+", " ", RegexOptions.CultureInvariant).Trim() + " ";
    }

    private static string DeterministicUuid(string seed)
    {
        var hash = Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(seed)));
        var variant = ((Convert.ToInt32(hash[16].ToString(), 16) & 3) | 8).ToString("x", CultureInfo.InvariantCulture);
        return $"{hash[..8]}-{hash[8..12]}-5{hash[13..16]}-{variant}{hash[17..20]}-{hash[20..32]}";
    }

    private static string? Text(JsonNode? node) => node is JsonValue value && value.TryGetValue<string>(out var text) ? text : null;
    private static ServiceException Invalid(string field, string reason = "INVALID") => new("VALIDATION_ERROR", new() { ["field"] = field, ["reason"] = reason });
}

internal sealed record AiVoiceTurnApplication(string Transcript, JsonObject Tutor);
