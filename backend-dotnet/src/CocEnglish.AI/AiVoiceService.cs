using System.Buffers.Binary;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;

namespace CocEnglish.AI;

/// <summary>Validated assessment request fields passed from the HTTP boundary to the voice service.</summary>
public sealed record AssessmentInput(string JobId, string ReferenceExerciseId, string LessonVersion, string Locale, string WavBase64, string AudioSha256, string? ReferenceText);

/// <summary>Application operations for voice sessions and recorded speech assessments.</summary>
public interface IAiVoiceService
{
    Task<ReceiptResult> CreateVoiceAsync(string userId, string sessionId, string scenarioId, string mode, string level, string key, string bodyHash, CancellationToken ct);
    Task<JsonObject> HeartbeatAsync(string userId, string sessionId, int epoch, int elapsedSeconds, CancellationToken ct);
    Task<JsonObject> CloseAsync(string userId, string sessionId, CancellationToken ct);
    Task<ReceiptResult> CreateAssessmentAsync(string userId, AssessmentInput input, string key, string bodyHash, CancellationToken ct);
    Task<JsonObject> GetAssessmentAsync(string userId, string jobId, CancellationToken ct);
    Task<ReceiptResult> SubmitVoiceTurnAsync(string userId, string sessionId, string turnId, int epoch, string wavBase64, string audioSha256, string key, string bodyHash, CancellationToken ct);
}

/// <summary>Admission-gated recorded speech, durable voice turns, receipt-safe assessments and owner-only reads.</summary>
internal sealed class AiVoiceService(
    OwnerStore store,
    IRowDriver rows,
    TimeProvider clock,
    IAiSpeechEngine speech,
    AiConversationService conversations) : IAiVoiceService
{
    private const int DailyRecordedSeconds = 600;
    private const int AssessmentTtlHours = 24;
    private const int TurnSessionTtlMinutes = 15;
    private const string ScriptedModel = "scripted-roleplay-v1";

    public Task<ReceiptResult> CreateVoiceAsync(string userId, string sessionId, string scenarioId, string mode, string level, string key, string bodyHash, CancellationToken ct)
    {
        if (mode == "LIVE") throw new ServiceException("NATIVE_LIVE_DISABLED");
        if (!speech.Enabled) throw new ServiceException("AI_PROVIDER_UNAVAILABLE");
        return store.CommitWithReceiptAsync(new(userId, "createVoiceSession", key), bodyHash, async (tx, token) =>
        {
            var now = tx.Now;
            var id = CanonicalWire.RowId("voice", sessionId);
            if (await tx.GetAsync("a_voice_sessions", id, token) is not null)
                throw new ServiceException("VOICE_RESERVATION_CONFLICT", new() { ["field"] = "sessionId" });

            var slotId = CanonicalWire.RowId("slot", userId);
            var slot = await tx.GetAsync("a_active_slots", slotId, token);
            if (slot is not null && Date(slot, "expiresAt") > now)
            {
                var holder = await tx.GetAsync("a_voice_sessions", CanonicalWire.RowId("voice", slot.Text("sessionId") ?? ""), token);
                if (holder is not null && holder.Text("status") == "ACTIVE")
                    throw new ServiceException("ACTIVE_VOICE_SESSION");
            }

            var expiresAt = OwnerSchema.Iso(now.AddMinutes(TurnSessionTtlMinutes));
            tx.Put("a_voice_sessions", id, new JsonObject
            {
                ["userId"] = userId,
                ["sessionId"] = sessionId,
                ["providerAlias"] = "speech",
                ["mode"] = "TURN",
                ["status"] = "ACTIVE",
                ["expiresAt"] = expiresAt,
                ["lastHeartbeatAt"] = OwnerSchema.Iso(now),
                ["epoch"] = 0,
                ["consumedSeconds"] = 0,
                ["configVersion"] = speech.ConfigVersion
            });
            tx.Put("a_active_slots", slotId, new JsonObject
            {
                ["userId"] = userId,
                ["sessionId"] = sessionId,
                ["expiresAt"] = expiresAt,
                ["epoch"] = 0
            });
            return new OperationResponse(200, new JsonObject
            {
                ["sessionId"] = sessionId,
                ["mode"] = "TURN",
                ["providerAlias"] = "speech",
                ["model"] = ScriptedModel,
                ["ephemeralToken"] = null,
                ["connectExpiresAt"] = null,
                ["sessionExpiresAt"] = expiresAt,
                ["epoch"] = 0,
                ["inputSampleRate"] = 16000,
                ["outputSampleRate"] = 24000,
                ["configVersion"] = speech.ConfigVersion
            });
        }, ct);
    }

    public async Task<JsonObject> HeartbeatAsync(string userId, string sessionId, int epoch, int elapsedSeconds, CancellationToken ct)
    {
        _ = await OwnedSessionAsync(userId, sessionId, ct);
        return await store.TransactAsync(async (tx, token) =>
        {
            var now = tx.Now;
            var id = CanonicalWire.RowId("voice", sessionId);
            var row = await tx.GetAsync("a_voice_sessions", id, token);
            if (row is null || row.Text("userId") != userId) throw new ServiceException("NOT_FOUND");
            if (row.Number("epoch") != epoch) throw new ServiceException("VOICE_EPOCH_CONFLICT");
            if (row.Text("status") != "ACTIVE" || Date(row, "expiresAt") <= now) return VoiceState(row, now);
            row["lastHeartbeatAt"] = OwnerSchema.Iso(now);
            row["consumedSeconds"] = Math.Min(180, Math.Max(row.Number("consumedSeconds"), elapsedSeconds));
            tx.Put("a_voice_sessions", id, row);
            return VoiceState(row, now);
        }, ct);
    }

    public async Task<JsonObject> CloseAsync(string userId, string sessionId, CancellationToken ct)
    {
        _ = await OwnedSessionAsync(userId, sessionId, ct);
        return await store.TransactAsync(async (tx, token) =>
        {
            var now = tx.Now;
            var id = CanonicalWire.RowId("voice", sessionId);
            var row = await tx.GetAsync("a_voice_sessions", id, token);
            if (row is null || row.Text("userId") != userId) throw new ServiceException("NOT_FOUND");
            if (row.Text("status") == "CLOSED") return VoiceState(row, now);
            row["status"] = "CLOSED";
            tx.Put("a_voice_sessions", id, row);
            var slotId = CanonicalWire.RowId("slot", userId);
            var slot = await tx.GetAsync("a_active_slots", slotId, token);
            if (slot?.Text("sessionId") == sessionId) tx.Delete("a_active_slots", slotId);
            return VoiceState(row, now);
        }, ct);
    }

    public async Task<ReceiptResult> CreateAssessmentAsync(string userId, AssessmentInput input, string key, string bodyHash, CancellationToken ct)
    {
        var seconds = AiAudioValidation.ValidateWav(input.WavBase64, input.AudioSha256);
        var reference = string.IsNullOrWhiteSpace(input.ReferenceText) ? null : input.ReferenceText.Trim();
        var score = NullScore("NULL_UNAVAILABLE", speech.AzureEnabled ? "NO_REFERENCE_TEXT" : "AZURE_DISABLED");
        string? transcript = null;
        string? provider = null;
        var receiptId = CanonicalWire.RowId("receipt", userId, "createAssessment", key);
        var jobId = CanonicalWire.RowId("job", userId, input.JobId);
        var existingReceipt = await rows.ReadAsync("a_receipts", receiptId, ct);
        var existingJob = await rows.ReadAsync("a_jobs", jobId, ct);
        if (existingReceipt is null && existingJob is null && speech.Enabled && reference is not null &&
            await UnderDailyQuotaAsync(userId, seconds, ct))
        {
            var recognized = await speech.RecognizeAsync(Convert.FromBase64String(input.WavBase64), reference, input.Locale, seconds, ct);
            transcript = string.IsNullOrEmpty(recognized.Transcript) ? null : recognized.Transcript;
            provider = recognized.Provider;
            score = recognized.Assessment ?? NullScore("NULL_UNAVAILABLE", "NO_SCORE");
        }

        return await store.CommitWithReceiptAsync(new(userId, "createAssessment", key), bodyHash, async (tx, token) =>
        {
            var now = tx.Now;
            if (await tx.GetAsync("a_jobs", jobId, token) is not null)
                throw new ServiceException("IDEMPOTENCY_CONFLICT", new() { ["field"] = "jobId" });
            await CountRecordedSecondsAsync(tx, userId, now, seconds, token);

            var expiresAt = OwnerSchema.Iso(now.AddHours(AssessmentTtlHours));
            var referenceHashInput = input.ReferenceExerciseId + "|" + input.LessonVersion + (reference is null ? "" : "|" + reference);
            var valid = score.ScoreState == "VALID";
            var words = valid ? WordsJson(score.Words) : new JsonArray();
            var miscues = valid
                ? new JsonArray(score.Words
                    .Where(word => word.ErrorType is not null && new[] { "omission", "insertion", "mispronunciation" }.Contains(word.ErrorType.ToLowerInvariant(), StringComparer.Ordinal))
                    .Take(100)
                    .Select(word => (JsonNode?)new JsonObject
                    {
                        ["word"] = word.Word,
                        ["kind"] = word.ErrorType!.ToLowerInvariant()
                    }).ToArray())
                : new JsonArray();
            var result = new JsonObject
            {
                ["jobId"] = input.JobId,
                ["status"] = "SUCCEEDED",
                ["transcript"] = transcript,
                ["accuracy"] = valid ? JsonValue.Create(score.Accuracy) : null,
                ["fluency"] = valid ? JsonValue.Create(score.Fluency) : null,
                ["completeness"] = valid ? JsonValue.Create(score.Completeness) : null,
                ["prosody"] = valid ? JsonValue.Create(score.Prosody) : null,
                ["words"] = words,
                ["scorer"] = valid ? "azure-pronunciation-assessment" : null,
                ["scoreVersion"] = valid ? "azure-rest-v1-hundredmark" : null,
                ["unavailableReason"] = valid ? null : score.Reason,
                ["expiresAt"] = expiresAt,
                ["scoreState"] = score.ScoreState,
                ["locale"] = input.Locale,
                ["referenceHash"] = CanonicalWire.Sha256(referenceHashInput),
                ["provider"] = provider,
                ["modelVersion"] = valid ? "azure-rest-v1-hundredmark" : null,
                ["miscues"] = miscues
            };
            tx.Put("a_jobs", jobId, new JsonObject
            {
                ["userId"] = userId,
                ["jobId"] = input.JobId,
                ["kind"] = "ASSESSMENT",
                ["status"] = "SUCCEEDED",
                ["referenceId"] = input.ReferenceExerciseId,
                ["locale"] = input.Locale,
                ["inputHash"] = input.AudioSha256,
                ["audioFileId"] = null,
                ["leaseUntil"] = null,
                ["attempt"] = 1,
                ["dispatchState"] = "NOT_SENT",
                ["reservedSeconds"] = 0,
                ["chargedSeconds"] = 0,
                ["resultJson"] = result.ToJsonString(),
                ["expiresAt"] = expiresAt
            });
            return new OperationResponse(202, result);
        }, ct);
    }

    public async Task<JsonObject> GetAssessmentAsync(string userId, string jobId, CancellationToken ct)
    {
        var row = (await rows.ReadAsync("a_jobs", CanonicalWire.RowId("job", userId, jobId), ct))?.Data;
        if (row is null || row.Text("userId") != userId || row.Text("kind") != "ASSESSMENT") throw new ServiceException("NOT_FOUND");
        var result = JsonNode.Parse(row.Text("resultJson") ?? "null") as JsonObject ?? throw new ServiceException("INTERNAL_ERROR");
        if (Date(row, "expiresAt") <= clock.GetUtcNow()) result["status"] = "EXPIRED";
        return result;
    }

    public async Task<ReceiptResult> SubmitVoiceTurnAsync(string userId, string sessionId, string turnId, int epoch, string wavBase64, string audioSha256, string key, string bodyHash, CancellationToken ct)
    {
        if (!speech.Enabled) throw new ServiceException("AI_PROVIDER_UNAVAILABLE");
        var seconds = AiAudioValidation.ValidateWav(wavBase64, audioSha256);
        var session = await OwnedSessionAsync(userId, sessionId, ct);
        AiSpeechResult? heard = null;
        string? reference = null;
        if (session.Text("status") == "ACTIVE" && Date(session, "expiresAt") > clock.GetUtcNow() &&
            session.Number("epoch") == epoch)
        {
            var receiptId = CanonicalWire.RowId("receipt", userId, "submitVoiceTurn", key);
            var receipt = await rows.ReadAsync("a_receipts", receiptId, ct);
            if (receipt is null && await UnderDailyQuotaAsync(userId, seconds, ct))
            {
                reference = await conversations.ExpectedLineAsync(userId, sessionId, ct);
                heard = await speech.RecognizeAsync(Convert.FromBase64String(wavBase64), reference, "en-US", seconds, ct);
            }
        }

        return await store.CommitWithReceiptAsync(new(userId, "submitVoiceTurn", key), bodyHash, async (tx, token) =>
        {
            var now = tx.Now;
            var id = CanonicalWire.RowId("voice", sessionId);
            var row = await tx.GetAsync("a_voice_sessions", id, token);
            if (row is null || row.Text("userId") != userId) throw new ServiceException("NOT_FOUND");
            if (row.Text("status") != "ACTIVE" || Date(row, "expiresAt") <= now)
                throw new ServiceException("VOICE_SESSION_EXPIRED");
            if (row.Number("epoch") != epoch) throw new ServiceException("VOICE_EPOCH_CONFLICT");
            await CountRecordedSecondsAsync(tx, userId, now, seconds, token);
            row["lastHeartbeatAt"] = OwnerSchema.Iso(now);
            row["consumedSeconds"] = Math.Min(180, row.Number("consumedSeconds") + seconds);
            tx.Put("a_voice_sessions", id, row);

            var applied = await conversations.ApplyVoiceTurnAsync(tx, userId, sessionId, turnId, heard?.Transcript ?? "", token);
            var validScore = heard?.Assessment?.ScoreState == "VALID";
            applied.Tutor["assessedPronunciation"] = validScore;
            var score = BuildTurnScore(heard, reference);
            return new OperationResponse(200, new JsonObject
            {
                ["turnId"] = turnId,
                ["epoch"] = epoch,
                ["transcript"] = applied.Transcript,
                ["tutor"] = applied.Tutor,
                ["audioAssetId"] = null,
                ["score"] = score,
                ["mode"] = "TURN"
            });
        }, ct);
    }

    private async Task<JsonObject> OwnedSessionAsync(string userId, string sessionId, CancellationToken ct)
    {
        var row = (await rows.ReadAsync("a_voice_sessions", CanonicalWire.RowId("voice", sessionId), ct))?.Data;
        if (row is null || row.Text("userId") != userId) throw new ServiceException("NOT_FOUND");
        return row;
    }

    private async Task<bool> UnderDailyQuotaAsync(string userId, int seconds, CancellationToken ct)
    {
        var day = OwnerSchema.Iso(clock.GetUtcNow())[..10];
        var id = CanonicalWire.RowId("usage", userId, day);
        var row = (await rows.ReadAsync("a_usage", id, ct))?.Data;
        return (row?.Number("recordedSpeechSeconds") ?? 0) + seconds <= DailyRecordedSeconds;
    }

    private static AiSpeechAssessment NullScore(string state, string? reason) =>
        new(state, null, null, null, null, Array.Empty<AiSpeechWordScore>(), reason);

    private static JsonArray WordsJson(IReadOnlyList<AiSpeechWordScore> words) =>
        new(words.Select(word => (JsonNode?)new JsonObject
        {
            ["word"] = word.Word,
            ["accuracy"] = word.Accuracy is null ? null : JsonValue.Create(word.Accuracy.Value),
            ["errorType"] = word.ErrorType,
            ["phonemes"] = new JsonArray(word.Phonemes.Select(phoneme => (JsonNode?)new JsonObject
            {
                ["phoneme"] = phoneme.Phoneme,
                ["accuracy"] = phoneme.Accuracy is null ? null : JsonValue.Create(phoneme.Accuracy.Value)
            }).ToArray())
        }).ToArray());

    private static JsonObject? BuildTurnScore(AiSpeechResult? heard, string? reference)
    {
        if (heard is null || reference is null || heard.Assessment is null) return null;
        var assessment = heard.Assessment;
        var valid = assessment.ScoreState == "VALID";
        return new JsonObject
        {
            ["scoreState"] = assessment.ScoreState,
            ["referenceText"] = reference.Length <= 300 ? reference : reference[..300],
            ["accuracy"] = valid ? JsonValue.Create(assessment.Accuracy) : null,
            ["fluency"] = valid ? JsonValue.Create(assessment.Fluency) : null,
            ["completeness"] = valid ? JsonValue.Create(assessment.Completeness) : null,
            ["prosody"] = valid ? JsonValue.Create(assessment.Prosody) : null,
            ["words"] = valid ? WordsJson(assessment.Words) : new JsonArray(),
            ["scorer"] = valid ? "azure-pronunciation-assessment" : null,
            ["transcriptProvider"] = heard.Provider,
            ["unavailableReason"] = valid ? null : assessment.Reason
        };
    }

    private static JsonObject VoiceState(JsonObject row, DateTimeOffset now) => new()
    {
        ["sessionId"] = row.Text("sessionId"),
        ["status"] = row.Text("status") != "CLOSED" && Date(row, "expiresAt") <= now ? "EXPIRED" : row.Text("status"),
        ["epoch"] = row.Number("epoch"),
        ["accountedSeconds"] = row.Number("consumedSeconds")
    };

    private static async Task CountRecordedSecondsAsync(OwnerSession tx, string userId, DateTimeOffset now, int seconds, CancellationToken ct)
    {
        var day = OwnerSchema.Iso(now)[..10];
        var id = CanonicalWire.RowId("usage", userId, day);
        var current = await tx.GetAsync("a_usage", id, ct);
        var textRequests = current?.Number("textRequests") ?? 0;
        var recorded = current?.Number("recordedSpeechSeconds") ?? 0;
        if (recorded + seconds > DailyRecordedSeconds) throw new ServiceException("QUOTA_EXHAUSTED", new() { ["utcDay"] = day });
        tx.Put("a_usage", id, new JsonObject
        {
            ["userId"] = userId,
            ["utcDay"] = day,
            ["liveReservedSeconds"] = current?.Number("liveReservedSeconds") ?? 0,
            ["liveUsedSeconds"] = current?.Number("liveUsedSeconds") ?? 0,
            ["liveGrants"] = current?.Number("liveGrants") ?? 0,
            ["textRequests"] = textRequests,
            ["recordedSpeechSeconds"] = recorded + seconds,
            ["recordedReservedSeconds"] = current?.Number("recordedReservedSeconds") ?? 0,
            ["reservationIdsJson"] = current?.Text("reservationIdsJson") ?? "[]"
        });
    }

    private static DateTimeOffset Date(JsonObject row, string key) => DateTimeOffset.Parse(row[key]!.GetValue<string>(), CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal);
}

internal static class AiAudioValidation
{
    private const int MaxBytes = 480044;
    private static readonly Regex Base64Pattern = new("^[A-Za-z0-9+/]+={0,2}$", RegexOptions.CultureInvariant | RegexOptions.Compiled);

    public static int ValidateWav(string base64, string expectedSha)
    {
        if (base64.Length % 4 != 0 || !Base64Pattern.IsMatch(base64)) throw InvalidAudio("BASE64");
        byte[] bytes;
        try { bytes = Convert.FromBase64String(base64); }
        catch (FormatException) { throw InvalidAudio("BASE64"); }
        if (bytes.Length > MaxBytes) throw InvalidAudio("TOO_LARGE");
        var actual = Convert.ToHexStringLower(SHA256.HashData(bytes));
        if (actual != expectedSha) throw InvalidAudio("SHA256_MISMATCH");
        if (bytes.Length < 44 || Encoding.ASCII.GetString(bytes, 0, 4) != "RIFF" || Encoding.ASCII.GetString(bytes, 8, 4) != "WAVE")
            throw InvalidAudio("NOT_WAV");
        var offset = 12;
        int? channels = null, sampleRate = null, bits = null, audioFormat = null, dataBytes = null;
        while (offset + 8 <= bytes.Length)
        {
            var chunkId = Encoding.ASCII.GetString(bytes, offset, 4);
            var size = BinaryPrimitives.ReadUInt32LittleEndian(bytes.AsSpan(offset + 4, 4));
            var body = offset + 8;
            if (chunkId == "fmt " && body + 16 <= bytes.Length)
            {
                audioFormat = BinaryPrimitives.ReadUInt16LittleEndian(bytes.AsSpan(body, 2));
                channels = BinaryPrimitives.ReadUInt16LittleEndian(bytes.AsSpan(body + 2, 2));
                var rate = BinaryPrimitives.ReadUInt32LittleEndian(bytes.AsSpan(body + 4, 4));
                sampleRate = rate <= int.MaxValue ? (int)rate : -1;
                bits = BinaryPrimitives.ReadUInt16LittleEndian(bytes.AsSpan(body + 14, 2));
            }
            else if (chunkId == "data")
            {
                dataBytes = (int)Math.Min(size, (uint)(bytes.Length - body));
                break;
            }
            var nextOffset = (long)body + size + (size % 2 == 0 ? 0 : 1);
            if (nextOffset > bytes.Length) break;
            offset = (int)nextOffset;
        }
        if (audioFormat != 1 || channels != 1 || sampleRate != 16000 || bits != 16) throw InvalidAudio("FORMAT");
        if (dataBytes is null or <= 0) throw InvalidAudio("NO_DATA");
        var seconds = dataBytes.Value / 32000d;
        if (seconds > 15) throw InvalidAudio("TOO_LONG");
        return Math.Max(1, (int)Math.Ceiling(seconds));
    }

    private static ServiceException InvalidAudio(string reason) => new("INVALID_AUDIO", new() { ["reason"] = reason });
}
