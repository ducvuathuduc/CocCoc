using System.Diagnostics;
using System.Globalization;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.Configuration;

namespace CocEnglish.AI;

public sealed record AiSpeechPhonemeScore(string Phoneme, double? Accuracy);
public sealed record AiSpeechWordScore(string Word, double? Accuracy, string? ErrorType, IReadOnlyList<AiSpeechPhonemeScore> Phonemes);
public sealed record AiSpeechAssessment(string ScoreState, double? Accuracy, double? Fluency, double? Completeness, double? Prosody, IReadOnlyList<AiSpeechWordScore> Words, string? Reason);
public sealed record AiSpeechResult(string Transcript, double? Confidence, string? Provider, AiSpeechAssessment? Assessment);

/// <summary>Server-side speech recognition/scoring, requiring speech mode and the reviewed device/privacy/cost admission gate.</summary>
public interface IAiSpeechEngine
{
    bool Enabled { get; }
    bool AzureEnabled { get; }
    string ConfigVersion { get; }
    IReadOnlyList<string> Fallbacks { get; }
    Task<AiSpeechResult> RecognizeAsync(ReadOnlyMemory<byte> wav, string? referenceText, string locale, int seconds, CancellationToken ct);
}

/// <summary>
/// Provider adapter for the existing Node speech contract. It stays disabled until
/// COC_AI_SPEECH_ADMITTED is explicitly reviewed. The engine stores only hashes and
/// bounded result metadata; audio is sent in request bodies and never written to persistence.
/// </summary>
public sealed class AiSpeechEngine : IAiSpeechEngine
{
    public const string GlobalQuotaUser = "system-speech-azure";
    public const int DefaultAzureDailySeconds = 540;
    private const int MaxWords = 100;
    private const int MaxPhonemes = 100;
    private const int CacheLimit = 200;
    private static readonly Regex SafeAssemblyId = new("^[A-Za-z0-9-]+$", RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private readonly HttpClient _http;
    private readonly OwnerStore _store;
    private readonly TimeProvider _clock;
    private readonly string? _azureKey;
    private readonly string? _azureRegion;
    private readonly string? _assemblyKey;
    private readonly string? _deepgramKey;
    private readonly int _azureDailySeconds;
    private static readonly SpeechResultCache Cache = new(CacheLimit);

    public AiSpeechEngine(HttpClient http, OwnerStore store, TimeProvider clock, IConfiguration configuration)
    {
        _http = http;
        _store = store;
        _clock = clock;

        var enabled = string.Equals(configuration["COC_AI_PROVIDER"], "speech", StringComparison.Ordinal) &&
            string.Equals(configuration["COC_AI_SPEECH_ADMITTED"], "reviewed-device-quality-privacy-cost", StringComparison.Ordinal);
        var candidateRegion = configuration["COC_AZURE_SPEECH_REGION"];
        _azureRegion = !string.IsNullOrWhiteSpace(candidateRegion) && Regex.IsMatch(candidateRegion, "^[a-z0-9]+$", RegexOptions.CultureInvariant)
            ? candidateRegion
            : null;
        _azureKey = enabled ? NonEmpty(configuration["COC_AZURE_SPEECH_KEY"]) : null;
        if (_azureKey is null) _azureRegion = null;
        _assemblyKey = enabled ? NonEmpty(configuration["COC_ASSEMBLYAI_API_KEY"]) : null;
        _deepgramKey = enabled ? NonEmpty(configuration["COC_DEEPGRAM_API_KEY"]) : null;
        var configuredCap = configuration["COC_SPEECH_DAILY_SECONDS"];
        _azureDailySeconds = int.TryParse(configuredCap, NumberStyles.None, CultureInfo.InvariantCulture, out var cap) && cap > 0
            ? cap
            : DefaultAzureDailySeconds;
        AzureEnabled = _azureKey is not null && _azureRegion is not null;
        Enabled = AzureEnabled || _assemblyKey is not null || _deepgramKey is not null;
        Fallbacks = Array.AsReadOnly(new[]
        {
            _assemblyKey is null ? null : "assemblyai",
            _deepgramKey is null ? null : "deepgram"
        }.Where(value => value is not null).Select(value => value!).ToArray());
        ConfigVersion = !Enabled ? "disabled-v1" : AzureEnabled ? "speech-azure-v1" : "speech-stt-v1";
    }

    public bool Enabled { get; }
    public bool AzureEnabled { get; }
    public string ConfigVersion { get; }
    public IReadOnlyList<string> Fallbacks { get; }

    public async Task<AiSpeechResult> RecognizeAsync(ReadOnlyMemory<byte> wav, string? referenceText, string locale, int seconds, CancellationToken ct)
    {
        if (!Enabled) return Unavailable("AZURE_DISABLED", referenceText is not null);
        var reference = string.IsNullOrWhiteSpace(referenceText) ? null : referenceText.Trim();
        var audioHash = Convert.ToHexStringLower(SHA256.HashData(wav.Span));
        var cacheKey = Hash($"{audioHash}|{reference ?? ""}|{locale}|{ConfigVersion}|{_azureRegion}|{_azureKey}|{_assemblyKey}|{_deepgramKey}");
        if (Cache.TryGet(cacheKey, out var cached)) return cached;

        string? unavailable = AzureEnabled ? null : "AZURE_DISABLED";
        if (AzureEnabled)
        {
            var reserved = await ReserveAzureAsync(seconds, ct);
            if (reserved)
            {
                var azure = await SafeAsync(() => CallAzureAsync(wav, reference, ct), ct);
                if (azure is not null)
                {
                    Cache.Set(cacheKey, azure);
                    return azure;
                }
                unavailable = "AZURE_FAILED";
            }
            else unavailable = "DAILY_CAP";
        }

        foreach (var provider in Fallbacks)
        {
            var fallback = await SafeAsync(
                () => provider == "assemblyai" ? CallAssemblyAsync(wav, ct) : CallDeepgramAsync(wav, ct), ct);
            if (fallback is null) continue;
            var withNullAssessment = fallback with
            {
                Assessment = reference is null ? null : NullScore("NULL_UNAVAILABLE", unavailable)
            };
            Cache.Set(cacheKey, withNullAssessment);
            return withNullAssessment;
        }

        var state = unavailable == "AZURE_FAILED" ? "FAILED" : "NULL_UNAVAILABLE";
        var result = new AiSpeechResult("", null, null, reference is null ? null : NullScore(state, unavailable ?? "STT_UNAVAILABLE"));
        Cache.Set(cacheKey, result);
        return result;
    }

    private async Task<bool> ReserveAzureAsync(int seconds, CancellationToken ct)
    {
        var now = _clock.GetUtcNow();
        var utcDay = now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var id = CanonicalWire.RowId("usage", GlobalQuotaUser, utcDay);
        try
        {
            return await _store.TransactAsync(async (tx, token) =>
            {
                var row = await tx.GetAsync("a_usage", id, token);
                var recorded = row?.Number("recordedSpeechSeconds") ?? 0;
                if (recorded + seconds > _azureDailySeconds) return false;
                tx.Put("a_usage", id, new JsonObject
                {
                    ["userId"] = GlobalQuotaUser,
                    ["utcDay"] = utcDay,
                    ["liveReservedSeconds"] = row?.Number("liveReservedSeconds") ?? 0,
                    ["liveUsedSeconds"] = row?.Number("liveUsedSeconds") ?? 0,
                    ["liveGrants"] = row?.Number("liveGrants") ?? 0,
                    ["textRequests"] = (row?.Number("textRequests") ?? 0) + 1,
                    ["recordedSpeechSeconds"] = recorded + seconds,
                    ["recordedReservedSeconds"] = row?.Number("recordedReservedSeconds") ?? 0,
                    ["reservationIdsJson"] = row?.Text("reservationIdsJson") ?? "[]"
                });
                return true;
            }, ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception) { return false; }
    }

    private async Task<AiSpeechResult?> CallAzureAsync(ReadOnlyMemory<byte> wav, string? reference, CancellationToken ct)
    {
        var url = $"https://{_azureRegion}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=en-US&format=detailed";
        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        request.Headers.TryAddWithoutValidation("Ocp-Apim-Subscription-Key", _azureKey);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        if (reference is not null)
        {
            var assessment = new JsonObject
            {
                ["ReferenceText"] = reference,
                ["GradingSystem"] = "HundredMark",
                ["Granularity"] = "Phoneme",
                ["Dimension"] = "Comprehensive",
                ["EnableMiscue"] = true,
                ["EnableProsodyAssessment"] = true
            };
            request.Headers.TryAddWithoutValidation("Pronunciation-Assessment", Convert.ToBase64String(Encoding.UTF8.GetBytes(assessment.ToJsonString())));
        }
        request.Content = AudioContent(wav, "audio/wav; codecs=\"audio/pcm\"; samplerate=16000");
        using var response = await SendAsync(request, TimeSpan.FromSeconds(20), ct);
        if (!response.IsSuccessStatusCode) return null;
        using var body = await ReadJsonAsync(response, ct);
        return ParseAzure(body.RootElement, reference is not null);
    }

    private async Task<AiSpeechResult?> CallAssemblyAsync(ReadOnlyMemory<byte> wav, CancellationToken ct)
    {
        using var upload = new HttpRequestMessage(HttpMethod.Post, "https://api.assemblyai.com/v2/upload");
        upload.Headers.TryAddWithoutValidation("authorization", _assemblyKey);
        upload.Content = AudioContent(wav, "application/octet-stream");
        using var uploaded = await SendAsync(upload, TimeSpan.FromSeconds(15), ct);
        if (!uploaded.IsSuccessStatusCode) return null;
        using var uploadJson = await ReadJsonAsync(uploaded, ct);
        var uploadUrl = String(uploadJson.RootElement, "upload_url");
        if (string.IsNullOrWhiteSpace(uploadUrl)) return null;

        using var create = new HttpRequestMessage(HttpMethod.Post, "https://api.assemblyai.com/v2/transcript");
        create.Headers.TryAddWithoutValidation("authorization", _assemblyKey);
        var createBody = new JsonObject { ["audio_url"] = uploadUrl, ["language_code"] = "en_us", ["punctuate"] = true };
        create.Content = new StringContent(createBody.ToJsonString(), Encoding.UTF8, "application/json");
        using var created = await SendAsync(create, TimeSpan.FromSeconds(15), ct);
        if (!created.IsSuccessStatusCode) return null;
        using var createdJson = await ReadJsonAsync(created, ct);
        var id = String(createdJson.RootElement, "id");
        if (id is null || !SafeAssemblyId.IsMatch(id)) return null;

        var timer = Stopwatch.StartNew();
        while (timer.Elapsed < TimeSpan.FromSeconds(25))
        {
            using var poll = new HttpRequestMessage(HttpMethod.Get, $"https://api.assemblyai.com/v2/transcript/{id}");
            poll.Headers.TryAddWithoutValidation("authorization", _assemblyKey);
            using var polled = await SendAsync(poll, TimeSpan.FromSeconds(10), ct);
            if (!polled.IsSuccessStatusCode) return null;
            using var pollJson = await ReadJsonAsync(polled, ct);
            var root = pollJson.RootElement;
            var status = String(root, "status");
            if (status == "completed")
            {
                return new AiSpeechResult(Truncate(String(root, "text"), 2048), Number(root, "confidence"), "assemblyai", null);
            }
            if (status == "error") return null;
            await Task.Delay(TimeSpan.FromMilliseconds(700), _clock, ct);
        }
        return null;
    }

    private async Task<AiSpeechResult?> CallDeepgramAsync(ReadOnlyMemory<byte> wav, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.deepgram.com/v1/listen?model=nova-3&language=en&smart_format=true");
        request.Headers.TryAddWithoutValidation("authorization", "Token " + _deepgramKey);
        request.Content = AudioContent(wav, "audio/wav");
        using var response = await SendAsync(request, TimeSpan.FromSeconds(20), ct);
        if (!response.IsSuccessStatusCode) return null;
        using var body = await ReadJsonAsync(response, ct);
        if (!TryGet(body.RootElement, "results", out var results) || !TryGet(results, "channels", out var channels) || channels.ValueKind != JsonValueKind.Array || channels.GetArrayLength() == 0)
            return null;
        var channel = channels[0];
        if (!TryGet(channel, "alternatives", out var alternatives) || alternatives.ValueKind != JsonValueKind.Array || alternatives.GetArrayLength() == 0)
            return null;
        var alternative = alternatives[0];
        return new AiSpeechResult(Truncate(String(alternative, "transcript"), 2048), Number(alternative, "confidence"), "deepgram", null);
    }

    private async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, TimeSpan timeout, CancellationToken ct)
    {
        using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeoutSource.CancelAfter(timeout);
        return await _http.SendAsync(request, HttpCompletionOption.ResponseContentRead, timeoutSource.Token);
    }

    private static ByteArrayContent AudioContent(ReadOnlyMemory<byte> wav, string contentType)
    {
        var content = new ByteArrayContent(wav.ToArray());
        content.Headers.ContentType = MediaTypeHeaderValue.Parse(contentType);
        return content;
    }

    private static async Task<JsonDocument> ReadJsonAsync(HttpResponseMessage response, CancellationToken ct)
    {
        var json = await response.Content.ReadAsStringAsync(ct);
        return JsonDocument.Parse(json);
    }

    private static async Task<AiSpeechResult?> SafeAsync(Func<Task<AiSpeechResult?>> operation, CancellationToken ct)
    {
        try { return await operation(); }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception) { return null; }
    }

    private static AiSpeechResult ParseAzure(JsonElement body, bool withReference)
    {
        var status = String(body, "RecognitionStatus") ?? "";
        if (status != "Success" || !TryGet(body, "NBest", out var candidates) || candidates.ValueKind != JsonValueKind.Array || candidates.GetArrayLength() == 0)
            return new AiSpeechResult("", null, "azure", withReference ? NullScore("NULL_LOW_CONFIDENCE", "AZURE_" + (status.Length == 0 ? "EMPTY" : status)) : null);

        var best = candidates[0];
        var transcript = Truncate(String(best, "Display") ?? String(body, "DisplayText"), 2048);
        var confidence = Number(best, "Confidence");
        if (!withReference) return new AiSpeechResult(transcript, confidence, "azure", null);

        var assessment = TryGet(best, "PronunciationAssessment", out var nested) ? nested : best;
        var words = new List<AiSpeechWordScore>();
        if (TryGet(best, "Words", out var wordNodes) && wordNodes.ValueKind == JsonValueKind.Array)
        {
            foreach (var word in wordNodes.EnumerateArray().Take(MaxWords))
            {
                var wordAssessment = TryGet(word, "PronunciationAssessment", out var wordNested) ? wordNested : word;
                var phonemes = new List<AiSpeechPhonemeScore>();
                if (TryGet(word, "Phonemes", out var phonemeNodes) && phonemeNodes.ValueKind == JsonValueKind.Array)
                {
                    foreach (var phoneme in phonemeNodes.EnumerateArray().Take(MaxPhonemes))
                    {
                        var phonemeAssessment = TryGet(phoneme, "PronunciationAssessment", out var phonemeNested) ? phonemeNested : phoneme;
                        phonemes.Add(new AiSpeechPhonemeScore(Truncate(String(phoneme, "Phoneme"), 32), Score(phonemeAssessment, "AccuracyScore")));
                    }
                }
                words.Add(new AiSpeechWordScore(
                    Truncate(String(word, "Word"), 128),
                    Score(wordAssessment, "AccuracyScore"),
                    TruncateNullable(String(wordAssessment, "ErrorType"), 64),
                    phonemes.AsReadOnly()));
            }
        }

        var accuracy = Score(assessment, "AccuracyScore");
        var fluency = Score(assessment, "FluencyScore");
        var completeness = Score(assessment, "CompletenessScore");
        var prosody = Score(assessment, "ProsodyScore");
        var lowConfidence = confidence is not null && confidence < 0.5;
        if (string.IsNullOrWhiteSpace(transcript) || accuracy is null || completeness is null || lowConfidence)
        {
            var reason = lowConfidence ? "LOW_CONFIDENCE" : "NO_SCORE";
            return new AiSpeechResult(transcript, confidence, "azure", NullScore("NULL_LOW_CONFIDENCE", reason));
        }
        return new AiSpeechResult(transcript, confidence, "azure", new AiSpeechAssessment("VALID", accuracy, fluency, completeness, prosody, words.AsReadOnly(), null));
    }

    private static AiSpeechResult Unavailable(string reason, bool withReference) =>
        new("", null, null, withReference ? NullScore("NULL_UNAVAILABLE", reason) : null);

    private static AiSpeechAssessment NullScore(string state, string? reason) =>
        new(state, null, null, null, null, Array.Empty<AiSpeechWordScore>(), reason);

    private static double? Score(JsonElement element, string key)
    {
        var value = Number(element, key);
        return value is null ? null : Math.Clamp(value.Value, 0, 100);
    }

    private static double? Number(JsonElement element, string key) =>
        TryGet(element, key, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetDouble(out var number) && double.IsFinite(number)
            ? number
            : null;

    private static string? String(JsonElement element, string key) =>
        TryGet(element, key, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;

    private static bool TryGet(JsonElement element, string key, out JsonElement value)
    {
        if (element.ValueKind == JsonValueKind.Object) return element.TryGetProperty(key, out value);
        value = default;
        return false;
    }

    private static string? NonEmpty(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static string Truncate(string? value, int limit) => value is null ? "" : value.Length <= limit ? value : value[..limit];
    private static string? TruncateNullable(string? value, int limit) => value is null ? null : value.Length <= limit ? value : value[..limit];
    private static string Hash(string value) => Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(value)));

    private sealed class SpeechResultCache(int capacity)
    {
        private readonly object _gate = new();
        private readonly Dictionary<string, LinkedListNode<(string Key, AiSpeechResult Value)>> _entries = new(StringComparer.Ordinal);
        private readonly LinkedList<(string Key, AiSpeechResult Value)> _order = [];

        public bool TryGet(string key, out AiSpeechResult result)
        {
            lock (_gate)
            {
                if (!_entries.TryGetValue(key, out var node)) { result = null!; return false; }
                _order.Remove(node);
                _order.AddLast(node);
                result = node.Value.Value;
                return true;
            }
        }

        public void Set(string key, AiSpeechResult value)
        {
            lock (_gate)
            {
                if (_entries.TryGetValue(key, out var existing)) _order.Remove(existing);
                var node = _order.AddLast((key, value));
                _entries[key] = node;
                while (_entries.Count > capacity)
                {
                    var first = _order.First!;
                    _entries.Remove(first.Value.Key);
                    _order.RemoveFirst();
                }
            }
        }
    }
}
