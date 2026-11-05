using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.AI;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed partial class AiConversationTests
{
    [Fact]
    public async Task Assessment_AzureScoresAreBoundedAndReceiptReplayDoesNotCallProviderAgain()
    {
        var driver = new Driver();
        using var handler = new SpeechHandler(_ => JsonResponse("""
            {"RecognitionStatus":"Success","NBest":[{"Display":"I like learning English.","Confidence":0.94,"PronunciationAssessment":{"AccuracyScore":101,"FluencyScore":82,"CompletenessScore":96,"ProsodyScore":74},"Words":[{"Word":"learning","PronunciationAssessment":{"AccuracyScore":91,"ErrorType":"None"},"Phonemes":[{"Phoneme":"l","PronunciationAssessment":{"AccuracyScore":88}}]}]}]}
            """));
        using var app = CreateSpeechApp(driver, handler, new Dictionary<string, string?>
        {
            ["COC_AI_PROVIDER"] = "speech",
            ["COC_AZURE_SPEECH_KEY"] = "test-azure-key",
            ["COC_AZURE_SPEECH_REGION"] = "westus2"
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "12121212-1212-4212-8212-121212121212");
        var bytes = OneSecondWav();
        var encoded = Convert.ToBase64String(bytes);
        var body = new
        {
            jobId = "23232323-2323-4232-8232-232323232323",
            referenceExerciseId = "exercise1",
            lessonVersion = "v1",
            locale = "en-US",
            wavBase64 = encoded,
            audioSha256 = Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(bytes)),
            referenceText = "I like learning English."
        };

        using var first = await client.PostAsJsonAsync("/v1/assessment-jobs", body);
        Assert.True(first.StatusCode == HttpStatusCode.Accepted, await first.Content.ReadAsStringAsync());
        var result = (await first.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("VALID", result["scoreState"]!.GetValue<string>());
        Assert.Equal("azure", result["provider"]!.GetValue<string>());
        Assert.Equal(100, result["accuracy"]!.GetValue<double>());
        Assert.Equal(82, result["fluency"]!.GetValue<double>());
        Assert.Single(result["words"]!.AsArray());
        Assert.Equal(88, result["words"]![0]!["phonemes"]![0]!["accuracy"]!.GetValue<double>());
        Assert.Single(handler.Requests);
        Assert.Contains("Pronunciation-Assessment", handler.Headers.Single().Keys);

        using var replay = await client.PostAsJsonAsync("/v1/assessment-jobs", body);
        Assert.Equal(HttpStatusCode.Accepted, replay.StatusCode);
        Assert.Equal(result.ToJsonString(), (await replay.Content.ReadFromJsonAsync<JsonObject>())!.ToJsonString());
        Assert.Single(handler.Requests);
        var globalUsage = driver.Rows[("a_usage", CanonicalWire.RowId("usage", "system-speech-azure", "2026-11-03"))];
        Assert.Equal(1, globalUsage.Number("recordedSpeechSeconds"));
        Assert.DoesNotContain(driver.Rows.Values, row => row.ToJsonString().Contains(encoded, StringComparison.Ordinal));
    }

    [Fact]
    public async Task Assessment_AzureProviderOnSequenceMatchesNodeResponsesProviderRequestAndRows()
    {
        var scenarioText = ReadAiParityResource("SpeechScenarios");
        var scenario = JsonNode.Parse(scenarioText)!.AsObject();
        var baseline = JsonNode.Parse(ReadAiParityResource("SpeechNode"))!.AsObject();
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());

        var driver = new Driver();
        var clock = new AdvancingClock(DateTimeOffset.Parse(scenario["now"]!.GetValue<string>()));
        using var handler = new SpeechHandler(_ => JsonResponse(scenario["azureResponse"]!.ToJsonString()));
        using var app = CreateSpeechApp(driver, handler, new Dictionary<string, string?>
        {
            ["COC_AI_PROVIDER"] = "speech",
            ["COC_AZURE_SPEECH_KEY"] = "synthetic-parity-key",
            ["COC_AZURE_SPEECH_REGION"] = scenario["azureRegion"]!.GetValue<string>()
        }, clock);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", scenario["user"]!.GetValue<string>());
        client.DefaultRequestHeaders.Add("Idempotency-Key", scenario["idempotencyKey"]!.GetValue<string>());

        var bytes = OneSecondWav();
        var body = new
        {
            jobId = scenario["jobId"]!.GetValue<string>(),
            referenceExerciseId = scenario["referenceExerciseId"]!.GetValue<string>(),
            lessonVersion = scenario["lessonVersion"]!.GetValue<string>(),
            locale = scenario["locale"]!.GetValue<string>(),
            wavBase64 = Convert.ToBase64String(bytes),
            audioSha256 = Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(bytes)),
            referenceText = scenario["referenceText"]!.GetValue<string>()
        };

        using var first = await client.PostAsJsonAsync("/v1/assessment-jobs", body);
        using var replay = await client.PostAsJsonAsync("/v1/assessment-jobs", body);
        clock.Advance(TimeSpan.FromHours(24));
        using var read = await client.GetAsync($"/v1/assessment-jobs/{body.jobId}");
        var actualResults = new JsonObject
        {
            ["first"] = new JsonObject
            {
                ["status"] = (int)first.StatusCode,
                ["body"] = JsonNode.Parse(await first.Content.ReadAsStringAsync())
            },
            ["replay"] = new JsonObject
            {
                ["status"] = (int)replay.StatusCode,
                ["body"] = JsonNode.Parse(await replay.Content.ReadAsStringAsync())
            },
            ["read"] = new JsonObject
            {
                ["status"] = (int)read.StatusCode,
                ["body"] = JsonNode.Parse(await read.Content.ReadAsStringAsync())
            }
        };
        Assert.True(JsonNode.DeepEquals(baseline["results"], actualResults),
            $"Azure provider-on response sequence differs from Node: expected {baseline["results"]?.ToJsonString()}, actual {actualResults.ToJsonString()}");
        Assert.Equal("EXPIRED", actualResults["read"]!["body"]!["status"]!.GetValue<string>());

        var requestHeaders = handler.Headers.Single();
        var pronunciationHeader = Convert.FromBase64String(requestHeaders["Pronunciation-Assessment"]);
        var actualProviderRequest = new JsonObject
        {
            ["method"] = handler.Methods.Single(),
            ["url"] = handler.Requests.Single()!.ToString(),
            // .NET quotes the audio/pcm MIME parameter while Node emits the equivalent token unquoted.
            ["contentType"] = NormalizeProviderContentType(handler.ContentTypes.Single()),
            ["bodyLength"] = checked((int)handler.ContentLengths.Single()!.Value),
            ["pronunciationAssessment"] = JsonNode.Parse(Encoding.UTF8.GetString(pronunciationHeader))
        };
        Assert.True(JsonNode.DeepEquals(baseline["providerRequest"], actualProviderRequest),
            $"Azure provider request differs from Node: expected {baseline["providerRequest"]?.ToJsonString()}, actual {actualProviderRequest.ToJsonString()}");
        Assert.Single(handler.Requests); // Receipt replay and read never call the provider again.

        var user = scenario["user"]!.GetValue<string>();
        var tables = new JsonObject();
        foreach (var tableNode in scenario["inspect"]!.AsArray())
        {
            var table = tableNode!.GetValue<string>();
            var rows = driver.Rows
                .Where(pair => pair.Key.Table == table &&
                    (pair.Value["userId"]?.GetValue<string>() == user ||
                     pair.Value["userId"]?.GetValue<string>() == "system-speech-azure"))
                .OrderBy(pair => pair.Key.Id, StringComparer.Ordinal)
                .Select(pair => (JsonNode?)ProjectSpeechRow(pair.Key.Id, pair.Value))
                .ToArray();
            tables[table] = new JsonArray(rows);
        }
        Assert.True(JsonNode.DeepEquals(baseline["tables"], tables),
            $"Azure provider-on persisted rows differ from Node: expected {baseline["tables"]?.ToJsonString()}, actual {tables.ToJsonString()}");
    }

    [Fact]
    public async Task VoiceTurn_AzureProviderOnSequenceMatchesNodeResponsesProviderRequestAndRows()
    {
        var scenarioText = ReadAiParityResource("VoiceTurnScenarios");
        var scenario = JsonNode.Parse(scenarioText)!.AsObject();
        var baseline = JsonNode.Parse(ReadAiParityResource("VoiceTurnNode"))!.AsObject();
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());

        var driver = new Driver();
        driver.SeedEntitlement(scenario["user"]!.GetValue<string>(), "MAX");
        using var handler = new SpeechHandler(_ => JsonResponse(scenario["azureResponse"]!.ToJsonString()));
        using var app = CreateSpeechApp(driver, handler, new Dictionary<string, string?>
        {
            ["COC_AI_PROVIDER"] = "speech",
            ["COC_AZURE_SPEECH_KEY"] = "synthetic-voice-parity-key",
            ["COC_AZURE_SPEECH_REGION"] = scenario["azureRegion"]!.GetValue<string>()
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", scenario["user"]!.GetValue<string>());

        var sessionKey = scenario["sessionKey"]!.GetValue<string>();
        client.DefaultRequestHeaders.Add("Idempotency-Key", sessionKey);
        using var session = await client.PostAsJsonAsync("/v1/voice-sessions", new
        {
            sessionId = scenario["sessionId"]!.GetValue<string>(),
            scenarioId = scenario["scenarioId"]!.GetValue<string>(),
            mode = "TURN",
            level = scenario["level"]!.GetValue<string>()
        });

        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", scenario["conversationKey"]!.GetValue<string>());
        using var conversation = await client.PostAsJsonAsync("/v1/conversations", new
        {
            kind = scenario["kind"]!.GetValue<string>(),
            courseId = scenario["courseId"]!.GetValue<string>(),
            scenarioId = scenario["scenarioId"]!.GetValue<string>(),
            voiceSessionId = scenario["voiceSessionId"]!.GetValue<string>()
        });

        var bytes = OneSecondWav();
        var turnBody = new
        {
            turnId = scenario["turnId"]!.GetValue<string>(),
            epoch = scenario["epoch"]!.GetValue<int>(),
            wavBase64 = Convert.ToBase64String(bytes),
            audioSha256 = Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(bytes))
        };
        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", scenario["turnKey"]!.GetValue<string>());
        var turnPath = $"/v1/voice-sessions/{scenario["sessionId"]!.GetValue<string>()}/turns";
        using var firstTurn = await client.PostAsJsonAsync(turnPath, turnBody);
        using var replayTurn = await client.PostAsJsonAsync(turnPath, turnBody);
        var actualResults = new JsonObject
        {
            ["session"] = new JsonObject
            {
                ["status"] = (int)session.StatusCode,
                ["body"] = JsonNode.Parse(await session.Content.ReadAsStringAsync())
            },
            ["conversation"] = new JsonObject
            {
                ["status"] = (int)conversation.StatusCode,
                ["body"] = JsonNode.Parse(await conversation.Content.ReadAsStringAsync())
            },
            ["firstTurn"] = new JsonObject
            {
                ["status"] = (int)firstTurn.StatusCode,
                ["body"] = JsonNode.Parse(await firstTurn.Content.ReadAsStringAsync())
            },
            ["replayTurn"] = new JsonObject
            {
                ["status"] = (int)replayTurn.StatusCode,
                ["body"] = JsonNode.Parse(await replayTurn.Content.ReadAsStringAsync())
            }
        };
        Assert.True(JsonNode.DeepEquals(baseline["results"], actualResults),
            $"Azure voice-turn response sequence differs from Node: expected {baseline["results"]?.ToJsonString()}, actual {actualResults.ToJsonString()}");

        var requestHeaders = handler.Headers.Single();
        var pronunciationHeader = Convert.FromBase64String(requestHeaders["Pronunciation-Assessment"]);
        var actualProviderRequest = new JsonObject
        {
            ["method"] = handler.Methods.Single(),
            ["url"] = handler.Requests.Single()!.ToString(),
            ["contentType"] = NormalizeProviderContentType(handler.ContentTypes.Single()),
            ["bodyLength"] = checked((int)handler.ContentLengths.Single()!.Value),
            ["pronunciationAssessment"] = JsonNode.Parse(Encoding.UTF8.GetString(pronunciationHeader))
        };
        Assert.True(JsonNode.DeepEquals(baseline["providerRequest"], actualProviderRequest),
            $"Azure voice-turn provider request differs from Node: expected {baseline["providerRequest"]?.ToJsonString()}, actual {actualProviderRequest.ToJsonString()}");
        Assert.Single(handler.Requests); // Receipt replay never calls the provider again.

        var user = scenario["user"]!.GetValue<string>();
        var tables = new JsonObject();
        foreach (var tableNode in scenario["inspect"]!.AsArray())
        {
            var table = tableNode!.GetValue<string>();
            var rows = driver.Rows
                .Where(pair => pair.Key.Table == table &&
                    (pair.Value["userId"]?.GetValue<string>() == user ||
                     pair.Value["aggregateId"]?.GetValue<string>() == user ||
                     pair.Value["userId"]?.GetValue<string>() == "system-speech-azure"))
                .OrderBy(pair => pair.Key.Id, StringComparer.Ordinal)
                .Select(pair => (JsonNode?)ProjectSpeechRow(pair.Key.Id, pair.Value))
                .ToArray();
            tables[table] = new JsonArray(rows);
        }
        Assert.True(JsonNode.DeepEquals(baseline["tables"], tables),
            $"Azure voice-turn persisted rows differ from Node: expected {baseline["tables"]?.ToJsonString()}, actual {tables.ToJsonString()}");
    }

    [Fact]
    public async Task Assessment_DeepgramFallbackSequenceMatchesNodeResponsesProviderRequestsAndRows()
    {
        var scenarioText = ReadAiParityResource("FallbackScenarios");
        var scenario = JsonNode.Parse(scenarioText)!.AsObject();
        var baseline = JsonNode.Parse(ReadAiParityResource("FallbackNode"))!.AsObject();
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());

        var driver = new Driver();
        using var handler = new SpeechHandler(request =>
            request.RequestUri!.Host == $"{scenario["azureRegion"]!.GetValue<string>()}.stt.speech.microsoft.com"
                ? new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
                : JsonResponse(scenario["deepgramResponse"]!.ToJsonString()));
        using var app = CreateSpeechApp(driver, handler, new Dictionary<string, string?>
        {
            ["COC_AI_PROVIDER"] = "speech",
            ["COC_AZURE_SPEECH_KEY"] = "synthetic-fallback-azure-key",
            ["COC_AZURE_SPEECH_REGION"] = scenario["azureRegion"]!.GetValue<string>(),
            ["COC_DEEPGRAM_API_KEY"] = "synthetic-fallback-deepgram-key"
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", scenario["user"]!.GetValue<string>());
        client.DefaultRequestHeaders.Add("Idempotency-Key", scenario["idempotencyKey"]!.GetValue<string>());

        var bytes = OneSecondWav();
        var body = new
        {
            jobId = scenario["jobId"]!.GetValue<string>(),
            referenceExerciseId = scenario["referenceExerciseId"]!.GetValue<string>(),
            lessonVersion = scenario["lessonVersion"]!.GetValue<string>(),
            locale = scenario["locale"]!.GetValue<string>(),
            wavBase64 = Convert.ToBase64String(bytes),
            audioSha256 = Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(bytes)),
            referenceText = scenario["referenceText"]!.GetValue<string>()
        };
        using var first = await client.PostAsJsonAsync("/v1/assessment-jobs", body);
        using var replay = await client.PostAsJsonAsync("/v1/assessment-jobs", body);
        using var read = await client.GetAsync($"/v1/assessment-jobs/{body.jobId}");
        var actualResults = new JsonObject
        {
            ["first"] = new JsonObject
            {
                ["status"] = (int)first.StatusCode,
                ["body"] = JsonNode.Parse(await first.Content.ReadAsStringAsync())
            },
            ["replay"] = new JsonObject
            {
                ["status"] = (int)replay.StatusCode,
                ["body"] = JsonNode.Parse(await replay.Content.ReadAsStringAsync())
            },
            ["read"] = new JsonObject
            {
                ["status"] = (int)read.StatusCode,
                ["body"] = JsonNode.Parse(await read.Content.ReadAsStringAsync())
            }
        };
        Assert.True(JsonNode.DeepEquals(baseline["results"], actualResults),
            $"Deepgram fallback response sequence differs from Node: expected {baseline["results"]?.ToJsonString()}, actual {actualResults.ToJsonString()}");

        var actualProviderRequests = new JsonArray();
        for (var index = 0; index < handler.Requests.Count; index++)
        {
            var uri = handler.Requests[index]!;
            var requestHeaders = handler.Headers[index];
            var request = new JsonObject
            {
                ["method"] = handler.Methods[index],
                ["url"] = uri.ToString(),
                ["contentType"] = handler.ContentTypes[index]!.Replace("\"", "", StringComparison.Ordinal),
                ["bodyLength"] = checked((int)handler.ContentLengths[index]!.Value)
            };
            if (uri.Host.EndsWith(".stt.speech.microsoft.com", StringComparison.Ordinal))
            {
                var encoded = Convert.FromBase64String(requestHeaders["Pronunciation-Assessment"]);
                request["pronunciationAssessment"] = JsonNode.Parse(Encoding.UTF8.GetString(encoded));
            }
            else
            {
                request["authorizationScheme"] = requestHeaders["Authorization"].Split(' ')[0];
            }
            actualProviderRequests.Add(request);
        }
        Assert.True(JsonNode.DeepEquals(baseline["providerRequests"], actualProviderRequests),
            $"Deepgram fallback provider requests differ from Node: expected {baseline["providerRequests"]?.ToJsonString()}, actual {actualProviderRequests.ToJsonString()}");
        Assert.Equal(2, handler.Requests.Count); // Receipt replay and read do not re-run either provider.

        var user = scenario["user"]!.GetValue<string>();
        var tables = new JsonObject();
        foreach (var tableNode in scenario["inspect"]!.AsArray())
        {
            var table = tableNode!.GetValue<string>();
            var rows = driver.Rows
                .Where(pair => pair.Key.Table == table &&
                    (pair.Value["userId"]?.GetValue<string>() == user ||
                     pair.Value["aggregateId"]?.GetValue<string>() == user ||
                     pair.Value["userId"]?.GetValue<string>() == "system-speech-azure"))
                .OrderBy(pair => pair.Key.Id, StringComparer.Ordinal)
                .Select(pair => (JsonNode?)ProjectSpeechRow(pair.Key.Id, pair.Value))
                .ToArray();
            tables[table] = new JsonArray(rows);
        }
        Assert.True(JsonNode.DeepEquals(baseline["tables"], tables),
            $"Deepgram fallback persisted rows differ from Node: expected {baseline["tables"]?.ToJsonString()}, actual {tables.ToJsonString()}");
    }

    [Fact]
    public async Task Assessment_AssemblyAiFallbackSequenceMatchesNodeResponsesProviderRequestsAndRows()
    {
        var scenarioText = ReadAiParityResource("AssemblyScenarios");
        var scenario = JsonNode.Parse(scenarioText)!.AsObject();
        var baseline = JsonNode.Parse(ReadAiParityResource("AssemblyNode"))!.AsObject();
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());

        var driver = new Driver();
        using var handler = new SpeechHandler(request =>
        {
            var uri = request.RequestUri!;
            if (uri.Host == $"{scenario["azureRegion"]!.GetValue<string>()}.stt.speech.microsoft.com")
                return new HttpResponseMessage(HttpStatusCode.ServiceUnavailable);
            if (uri.AbsolutePath == "/v2/upload")
                return JsonResponse(new JsonObject { ["upload_url"] = scenario["uploadUrl"]!.DeepClone() }.ToJsonString());
            if (uri.AbsolutePath == "/v2/transcript" && request.Method == HttpMethod.Post)
                return JsonResponse(new JsonObject { ["id"] = scenario["transcriptId"]!.DeepClone() }.ToJsonString());
            return JsonResponse(new JsonObject
            {
                ["status"] = "completed",
                ["text"] = scenario["transcript"]!.DeepClone(),
                ["confidence"] = scenario["confidence"]!.DeepClone()
            }.ToJsonString());
        });
        using var app = CreateSpeechApp(driver, handler, new Dictionary<string, string?>
        {
            ["COC_AI_PROVIDER"] = "speech",
            ["COC_AZURE_SPEECH_KEY"] = "synthetic-assembly-azure-key",
            ["COC_AZURE_SPEECH_REGION"] = scenario["azureRegion"]!.GetValue<string>(),
            ["COC_ASSEMBLYAI_API_KEY"] = "synthetic-assemblyai-key"
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", scenario["user"]!.GetValue<string>());
        client.DefaultRequestHeaders.Add("Idempotency-Key", scenario["idempotencyKey"]!.GetValue<string>());

        var bytes = OneSecondWav();
        var body = new
        {
            jobId = scenario["jobId"]!.GetValue<string>(),
            referenceExerciseId = scenario["referenceExerciseId"]!.GetValue<string>(),
            lessonVersion = scenario["lessonVersion"]!.GetValue<string>(),
            locale = scenario["locale"]!.GetValue<string>(),
            wavBase64 = Convert.ToBase64String(bytes),
            audioSha256 = Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(bytes)),
            referenceText = scenario["referenceText"]!.GetValue<string>()
        };
        using var first = await client.PostAsJsonAsync("/v1/assessment-jobs", body);
        using var replay = await client.PostAsJsonAsync("/v1/assessment-jobs", body);
        using var read = await client.GetAsync($"/v1/assessment-jobs/{body.jobId}");
        var actualResults = new JsonObject
        {
            ["first"] = new JsonObject
            {
                ["status"] = (int)first.StatusCode,
                ["body"] = JsonNode.Parse(await first.Content.ReadAsStringAsync())
            },
            ["replay"] = new JsonObject
            {
                ["status"] = (int)replay.StatusCode,
                ["body"] = JsonNode.Parse(await replay.Content.ReadAsStringAsync())
            },
            ["read"] = new JsonObject
            {
                ["status"] = (int)read.StatusCode,
                ["body"] = JsonNode.Parse(await read.Content.ReadAsStringAsync())
            }
        };
        Assert.True(JsonNode.DeepEquals(baseline["results"], actualResults),
            $"AssemblyAI fallback response sequence differs from Node: expected {baseline["results"]?.ToJsonString()}, actual {actualResults.ToJsonString()}");

        var actualProviderRequests = new JsonArray();
        for (var index = 0; index < handler.Requests.Count; index++)
        {
            var requestHeaders = handler.Headers[index];
            var request = new JsonObject
            {
                ["method"] = handler.Methods[index],
                ["url"] = handler.Requests[index]!.ToString(),
                ["contentType"] = NormalizeProviderContentType(handler.ContentTypes[index]),
                ["bodyLength"] = checked((int)(handler.ContentLengths[index] ?? 0))
            };
            if (handler.Requests[index]!.Host.EndsWith(".stt.speech.microsoft.com", StringComparison.Ordinal))
            {
                var encoded = Convert.FromBase64String(requestHeaders["Pronunciation-Assessment"]);
                request["pronunciationAssessment"] = JsonNode.Parse(Encoding.UTF8.GetString(encoded));
            }
            else
            {
                var authorization = requestHeaders["Authorization"];
                var separator = authorization.IndexOf(' ');
                request["authorizationScheme"] = separator < 0 ? "raw" : authorization[..separator];
                if (handler.JsonBodies[index] is { } jsonBody) request["jsonBody"] = JsonNode.Parse(jsonBody);
            }
            actualProviderRequests.Add(request);
        }
        Assert.True(JsonNode.DeepEquals(baseline["providerRequests"], actualProviderRequests),
            $"AssemblyAI fallback provider requests differ from Node: expected {baseline["providerRequests"]?.ToJsonString()}, actual {actualProviderRequests.ToJsonString()}");
        Assert.Equal(4, handler.Requests.Count); // Azure, upload, transcript creation and one poll.

        var user = scenario["user"]!.GetValue<string>();
        var tables = new JsonObject();
        foreach (var tableNode in scenario["inspect"]!.AsArray())
        {
            var table = tableNode!.GetValue<string>();
            var rows = driver.Rows
                .Where(pair => pair.Key.Table == table &&
                    (pair.Value["userId"]?.GetValue<string>() == user ||
                     pair.Value["aggregateId"]?.GetValue<string>() == user ||
                     pair.Value["userId"]?.GetValue<string>() == "system-speech-azure"))
                .OrderBy(pair => pair.Key.Id, StringComparer.Ordinal)
                .Select(pair => (JsonNode?)ProjectSpeechRow(pair.Key.Id, pair.Value))
                .ToArray();
            tables[table] = new JsonArray(rows);
        }
        Assert.True(JsonNode.DeepEquals(baseline["tables"], tables),
            $"AssemblyAI fallback persisted rows differ from Node: expected {baseline["tables"]?.ToJsonString()}, actual {tables.ToJsonString()}");
    }

    [Fact]
    public async Task VoiceTurn_DeepgramFallbackSequenceMatchesNodeResponsesProviderRequestsAndRows()
    {
        var scenarioText = ReadAiParityResource("VoiceFallbackScenarios");
        var scenario = JsonNode.Parse(scenarioText)!.AsObject();
        var baseline = JsonNode.Parse(ReadAiParityResource("VoiceFallbackNode"))!.AsObject();
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());

        var user = scenario["user"]!.GetValue<string>();
        var driver = new Driver();
        driver.SeedEntitlement(user, "MAX");
        using var handler = new SpeechHandler(request =>
            request.RequestUri!.Host == $"{scenario["azureRegion"]!.GetValue<string>()}.stt.speech.microsoft.com"
                ? new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
                : JsonResponse(scenario["deepgramResponse"]!.ToJsonString()));
        using var app = CreateSpeechApp(driver, handler, new Dictionary<string, string?>
        {
            ["COC_AI_PROVIDER"] = "speech",
            ["COC_AZURE_SPEECH_KEY"] = "synthetic-voice-fallback-azure-key",
            ["COC_AZURE_SPEECH_REGION"] = scenario["azureRegion"]!.GetValue<string>(),
            ["COC_DEEPGRAM_API_KEY"] = "synthetic-voice-fallback-deepgram-key"
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", user);
        client.DefaultRequestHeaders.Add("Idempotency-Key", scenario["sessionKey"]!.GetValue<string>());
        using var session = await client.PostAsJsonAsync("/v1/voice-sessions", new
        {
            sessionId = scenario["sessionId"]!.GetValue<string>(),
            scenarioId = scenario["scenarioId"]!.GetValue<string>(),
            mode = "TURN",
            level = scenario["level"]!.GetValue<string>()
        });

        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", scenario["conversationKey"]!.GetValue<string>());
        using var conversation = await client.PostAsJsonAsync("/v1/conversations", new
        {
            kind = scenario["kind"]!.GetValue<string>(),
            courseId = scenario["courseId"]!.GetValue<string>(),
            scenarioId = scenario["scenarioId"]!.GetValue<string>(),
            voiceSessionId = scenario["voiceSessionId"]!.GetValue<string>()
        });

        var bytes = OneSecondWav();
        var turnBody = new
        {
            turnId = scenario["turnId"]!.GetValue<string>(),
            epoch = scenario["epoch"]!.GetValue<int>(),
            wavBase64 = Convert.ToBase64String(bytes),
            audioSha256 = Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(bytes))
        };
        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", scenario["turnKey"]!.GetValue<string>());
        var turnPath = $"/v1/voice-sessions/{scenario["sessionId"]!.GetValue<string>()}/turns";
        using var firstTurn = await client.PostAsJsonAsync(turnPath, turnBody);
        using var replayTurn = await client.PostAsJsonAsync(turnPath, turnBody);
        var actualResults = new JsonObject
        {
            ["session"] = new JsonObject
            {
                ["status"] = (int)session.StatusCode,
                ["body"] = JsonNode.Parse(await session.Content.ReadAsStringAsync())
            },
            ["conversation"] = new JsonObject
            {
                ["status"] = (int)conversation.StatusCode,
                ["body"] = JsonNode.Parse(await conversation.Content.ReadAsStringAsync())
            },
            ["firstTurn"] = new JsonObject
            {
                ["status"] = (int)firstTurn.StatusCode,
                ["body"] = JsonNode.Parse(await firstTurn.Content.ReadAsStringAsync())
            },
            ["replayTurn"] = new JsonObject
            {
                ["status"] = (int)replayTurn.StatusCode,
                ["body"] = JsonNode.Parse(await replayTurn.Content.ReadAsStringAsync())
            }
        };
        Assert.True(JsonNode.DeepEquals(baseline["results"], actualResults),
            $"Deepgram voice-turn fallback response sequence differs from Node: expected {baseline["results"]?.ToJsonString()}, actual {actualResults.ToJsonString()}");

        var actualProviderRequests = new JsonArray();
        for (var index = 0; index < handler.Requests.Count; index++)
        {
            var uri = handler.Requests[index]!;
            var requestHeaders = handler.Headers[index];
            var request = new JsonObject
            {
                ["method"] = handler.Methods[index],
                ["url"] = uri.ToString(),
                ["contentType"] = NormalizeProviderContentType(handler.ContentTypes[index]),
                ["bodyLength"] = checked((int)(handler.ContentLengths[index] ?? 0))
            };
            if (uri.Host.EndsWith(".stt.speech.microsoft.com", StringComparison.Ordinal))
            {
                var encoded = Convert.FromBase64String(requestHeaders["Pronunciation-Assessment"]);
                request["pronunciationAssessment"] = JsonNode.Parse(Encoding.UTF8.GetString(encoded));
            }
            else
            {
                request["authorizationScheme"] = requestHeaders["Authorization"].Split(' ')[0];
            }
            actualProviderRequests.Add(request);
        }
        Assert.True(JsonNode.DeepEquals(baseline["providerRequests"], actualProviderRequests),
            $"Deepgram voice-turn fallback requests differ from Node: expected {baseline["providerRequests"]?.ToJsonString()}, actual {actualProviderRequests.ToJsonString()}");
        Assert.Equal(2, handler.Requests.Count); // Replay does not call Azure or Deepgram again.

        var tables = new JsonObject();
        foreach (var tableNode in scenario["inspect"]!.AsArray())
        {
            var table = tableNode!.GetValue<string>();
            var rows = driver.Rows
                .Where(pair => pair.Key.Table == table &&
                    (pair.Value["userId"]?.GetValue<string>() == user ||
                     pair.Value["aggregateId"]?.GetValue<string>() == user ||
                     pair.Value["userId"]?.GetValue<string>() == "system-speech-azure"))
                .OrderBy(pair => pair.Key.Id, StringComparer.Ordinal)
                .Select(pair => (JsonNode?)ProjectSpeechRow(pair.Key.Id, pair.Value))
                .ToArray();
            tables[table] = new JsonArray(rows);
        }
        Assert.True(JsonNode.DeepEquals(baseline["tables"], tables),
            $"Deepgram voice-turn fallback persisted rows differ from Node: expected {baseline["tables"]?.ToJsonString()}, actual {tables.ToJsonString()}");
    }

    [Fact]
    public async Task Assessment_LowAzureConfidenceNeverReturnsNumericScores()
    {
        var driver = new Driver();
        using var handler = new SpeechHandler(_ => JsonResponse("""
            {"RecognitionStatus":"Success","NBest":[{"Display":"I like English.","Confidence":0.2,"PronunciationAssessment":{"AccuracyScore":90,"CompletenessScore":90}}]}
            """));
        using var app = CreateSpeechApp(driver, handler, new Dictionary<string, string?>
        {
            ["COC_AI_PROVIDER"] = "speech",
            ["COC_AZURE_SPEECH_KEY"] = "test-azure-key",
            ["COC_AZURE_SPEECH_REGION"] = "westus2"
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "34343434-3434-4434-8434-343434343434");
        var bytes = OneSecondWav();

        using var response = await client.PostAsJsonAsync("/v1/assessment-jobs", new
        {
            jobId = "45454545-4545-4454-8454-454545454545",
            referenceExerciseId = "exercise1",
            lessonVersion = "v1",
            locale = "en-US",
            wavBase64 = Convert.ToBase64String(bytes),
            audioSha256 = Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(bytes)),
            referenceText = "I like English."
        });

        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        var result = (await response.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("NULL_LOW_CONFIDENCE", result["scoreState"]!.GetValue<string>());
        Assert.Equal("LOW_CONFIDENCE", result["unavailableReason"]!.GetValue<string>());
        Assert.Null(result["accuracy"]);
        Assert.Null(result["fluency"]);
        Assert.Null(result["completeness"]);
        Assert.Null(result["prosody"]);
        Assert.Empty(result["words"]!.AsArray());
    }

    [Fact]
    public async Task Assessment_DeepgramFallbackReturnsTranscriptWithoutPronunciationScore()
    {
        var driver = new Driver();
        using var handler = new SpeechHandler(request =>
            request.RequestUri!.Host == "westus2.stt.speech.microsoft.com"
                ? new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
                : JsonResponse("""
                    {"results":{"channels":[{"alternatives":[{"transcript":"I like English.","confidence":0.89}]}]}}
                    """));
        using var app = CreateSpeechApp(driver, handler, new Dictionary<string, string?>
        {
            ["COC_AI_PROVIDER"] = "speech",
            ["COC_AZURE_SPEECH_KEY"] = "test-azure-key",
            ["COC_AZURE_SPEECH_REGION"] = "westus2",
            ["COC_DEEPGRAM_API_KEY"] = "test-deepgram-key"
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "56565656-5656-4656-8656-565656565656");
        var bytes = OneSecondWav();

        using var response = await client.PostAsJsonAsync("/v1/assessment-jobs", new
        {
            jobId = "67676767-6767-4676-8676-676767676767",
            referenceExerciseId = "exercise1",
            lessonVersion = "v1",
            locale = "en-US",
            wavBase64 = Convert.ToBase64String(bytes),
            audioSha256 = Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(bytes)),
            referenceText = "I like English."
        });

        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        var result = (await response.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("I like English.", result["transcript"]!.GetValue<string>());
        Assert.Equal("deepgram", result["provider"]!.GetValue<string>());
        Assert.Equal("NULL_UNAVAILABLE", result["scoreState"]!.GetValue<string>());
        Assert.Equal("AZURE_FAILED", result["unavailableReason"]!.GetValue<string>());
        Assert.Null(result["accuracy"]);
        Assert.Equal(2, handler.Requests.Count);
    }

    [Fact]
    public async Task Assessment_AssemblyAiFallbackUploadsThenPollsWithoutInventingScore()
    {
        var driver = new Driver();
        using var handler = new SpeechHandler(request => request.Method == HttpMethod.Post && request.RequestUri!.AbsolutePath == "/v2/upload"
            ? JsonResponse("""{"upload_url":"https://cdn.assemblyai.com/upload/test"}""")
            : request.Method == HttpMethod.Post
                ? JsonResponse("""{"id":"transcript-test"}""")
                : JsonResponse("""{"status":"completed","text":"I like English.","confidence":0.82}"""));
        using var app = CreateSpeechApp(driver, handler, new Dictionary<string, string?>
        {
            ["COC_AI_PROVIDER"] = "speech",
            ["COC_ASSEMBLYAI_API_KEY"] = "test-assembly-key"
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1");
        var bytes = OneSecondWav();

        using var response = await client.PostAsJsonAsync("/v1/assessment-jobs", new
        {
            jobId = "aaaaaaa2-aaaa-4aaa-8aaa-aaaaaaaaaaa2",
            referenceExerciseId = "exercise1",
            lessonVersion = "v1",
            locale = "en-US",
            wavBase64 = Convert.ToBase64String(bytes),
            audioSha256 = Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(bytes)),
            referenceText = "I like English."
        });

        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        var result = (await response.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("I like English.", result["transcript"]!.GetValue<string>());
        Assert.Equal("assemblyai", result["provider"]!.GetValue<string>());
        Assert.Equal("NULL_UNAVAILABLE", result["scoreState"]!.GetValue<string>());
        Assert.Equal("AZURE_DISABLED", result["unavailableReason"]!.GetValue<string>());
        Assert.Null(result["accuracy"]);
        Assert.Equal(3, handler.Requests.Count);
    }

    [Fact]
    public async Task Assessment_GlobalAzureDailyCapPreventsProviderCall()
    {
        var driver = new Driver();
        var globalUsageId = CanonicalWire.RowId("usage", "system-speech-azure", "2026-11-03");
        driver.Seed("a_usage", globalUsageId, new JsonObject
        {
            ["userId"] = "system-speech-azure",
            ["utcDay"] = "2026-11-03",
            ["liveReservedSeconds"] = 0,
            ["liveUsedSeconds"] = 0,
            ["liveGrants"] = 0,
            ["textRequests"] = 1,
            ["recordedSpeechSeconds"] = 540,
            ["recordedReservedSeconds"] = 0,
            ["reservationIdsJson"] = "[]"
        });
        using var handler = new SpeechHandler(_ => JsonResponse("""{"RecognitionStatus":"Success","NBest":[]}"""));
        using var app = CreateSpeechApp(driver, handler, new Dictionary<string, string?>
        {
            ["COC_AI_PROVIDER"] = "speech",
            ["COC_AZURE_SPEECH_KEY"] = "test-azure-key",
            ["COC_AZURE_SPEECH_REGION"] = "westus2"
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "aaaaaaa3-aaaa-4aaa-8aaa-aaaaaaaaaaa3");
        var bytes = OneSecondWav();

        using var response = await client.PostAsJsonAsync("/v1/assessment-jobs", new
        {
            jobId = "aaaaaaa4-aaaa-4aaa-8aaa-aaaaaaaaaaa4",
            referenceExerciseId = "exercise1",
            lessonVersion = "v1",
            locale = "en-US",
            wavBase64 = Convert.ToBase64String(bytes),
            audioSha256 = Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(bytes)),
            referenceText = "This quota is already full."
        });

        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        var result = (await response.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("NULL_UNAVAILABLE", result["scoreState"]!.GetValue<string>());
        Assert.Equal("DAILY_CAP", result["unavailableReason"]!.GetValue<string>());
        Assert.Null(result["transcript"]);
        Assert.Empty(handler.Requests);
        Assert.Equal(540, driver.Rows[("a_usage", globalUsageId)].Number("recordedSpeechSeconds"));
    }

    [Fact]
    public async Task VoiceTurn_UsesRecognizedAudioAndCurrentExpectedLineWithReceiptIdempotency()
    {
        var driver = new Driver();
        driver.SeedEntitlement("alice", "MAX");
        using var handler = new SpeechHandler(_ => JsonResponse("""
            {"RecognitionStatus":"Success","NBest":[{"Display":"I would like a coffee, please.","Confidence":0.93,"PronunciationAssessment":{"AccuracyScore":90,"FluencyScore":88,"CompletenessScore":100,"ProsodyScore":80}}]}
            """));
        using var app = CreateSpeechApp(driver, handler, new Dictionary<string, string?>
        {
            ["COC_AI_PROVIDER"] = "speech",
            ["COC_AZURE_SPEECH_KEY"] = "test-azure-key",
            ["COC_AZURE_SPEECH_REGION"] = "westus2"
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "78787878-7878-4878-8878-787878787878");
        const string sessionId = "89898989-8989-4898-8898-898989898989";
        using var created = await client.PostAsJsonAsync("/v1/voice-sessions", new
        {
            sessionId,
            scenarioId = "rp_cafe_order",
            mode = "TURN",
            level = "A1"
        });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var session = (await created.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("speech-azure-v1", session["configVersion"]!.GetValue<string>());
        Assert.Equal("TURN", session["mode"]!.GetValue<string>());

        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "90909090-9090-4909-8909-909090909090");
        using var conversationStart = await client.PostAsJsonAsync("/v1/conversations", new
        {
            kind = "ROLEPLAY",
            courseId = "course1",
            scenarioId = "rp_cafe_order",
            voiceSessionId = sessionId
        });
        Assert.Equal(HttpStatusCode.OK, conversationStart.StatusCode);

        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "abababab-abab-4bab-8bab-abababababab");
        var bytes = OneSecondWav();
        var wav = Convert.ToBase64String(bytes);
        var body = new
        {
            turnId = "bcbcbcbc-bcbc-4cbc-8cbc-bcbcbcbcbcbc",
            epoch = 0,
            wavBase64 = wav,
            audioSha256 = Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(bytes))
        };
        var turnPath = $"/v1/voice-sessions/{sessionId}/turns";

        using var submitted = await client.PostAsJsonAsync(turnPath, body);
        Assert.Equal(HttpStatusCode.OK, submitted.StatusCode);
        var result = (await submitted.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.True(result["transcript"]?.GetValue<string>() == "I would like a coffee, please.", result.ToJsonString());
        Assert.Equal("Sure. Small or large?", result["tutor"]!["tutorText"]!.GetValue<string>());
        Assert.True(result["tutor"]!["assessedPronunciation"]!.GetValue<bool>());
        Assert.Equal(90, result["score"]!["accuracy"]!.GetValue<double>());
        Assert.Equal("I would like a coffee, please.", result["score"]!["referenceText"]!.GetValue<string>());
        Assert.Single(handler.Requests);
        Assert.DoesNotContain(driver.Rows.Values, row => row.ToJsonString().Contains(wav, StringComparison.Ordinal));

        using var replay = await client.PostAsJsonAsync(turnPath, body);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.Equal(result.ToJsonString(), (await replay.Content.ReadFromJsonAsync<JsonObject>())!.ToJsonString());
        Assert.Single(handler.Requests);

        var changedBytes = OneSecondWav();
        changedBytes[^1] = 1;
        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "abababab-abab-4bab-8bab-abababababab");
        using var conflict = await client.PostAsJsonAsync(turnPath, new
        {
            turnId = body.turnId,
            epoch = body.epoch,
            wavBase64 = Convert.ToBase64String(changedBytes),
            audioSha256 = Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(changedBytes))
        });
        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
        Assert.Single(handler.Requests);
    }

    [Fact]
    public async Task VoiceTurn_AssemblyAiFallbackSequenceMatchesNodeResponsesProviderRequestsAndRows()
    {
        var scenarioText = ReadAiParityResource("VoiceAssemblyScenarios");
        var scenario = JsonNode.Parse(scenarioText)!.AsObject();
        var baseline = JsonNode.Parse(ReadAiParityResource("VoiceAssemblyNode"))!.AsObject();
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());

        var user = scenario["user"]!.GetValue<string>();
        var driver = new Driver();
        driver.SeedEntitlement(user, "MAX");
        using var handler = new SpeechHandler(request =>
        {
            var uri = request.RequestUri!;
            if (uri.Host == $"{scenario["azureRegion"]!.GetValue<string>()}.stt.speech.microsoft.com")
                return new HttpResponseMessage(HttpStatusCode.ServiceUnavailable);
            if (uri.AbsolutePath == "/v2/upload")
                return JsonResponse(new JsonObject { ["upload_url"] = scenario["uploadUrl"]!.DeepClone() }.ToJsonString());
            if (uri.AbsolutePath == "/v2/transcript" && request.Method == HttpMethod.Post)
                return JsonResponse(new JsonObject { ["id"] = scenario["transcriptId"]!.DeepClone() }.ToJsonString());
            return JsonResponse(new JsonObject
            {
                ["status"] = "completed",
                ["text"] = scenario["transcript"]!.DeepClone(),
                ["confidence"] = scenario["confidence"]!.DeepClone()
            }.ToJsonString());
        });
        using var app = CreateSpeechApp(driver, handler, new Dictionary<string, string?>
        {
            ["COC_AI_PROVIDER"] = "speech",
            ["COC_AZURE_SPEECH_KEY"] = "synthetic-voice-assembly-azure-key",
            ["COC_AZURE_SPEECH_REGION"] = scenario["azureRegion"]!.GetValue<string>(),
            ["COC_ASSEMBLYAI_API_KEY"] = "synthetic-voice-assemblyai-key"
        });
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", user);
        client.DefaultRequestHeaders.Add("Idempotency-Key", scenario["sessionKey"]!.GetValue<string>());
        using var session = await client.PostAsJsonAsync("/v1/voice-sessions", new
        {
            sessionId = scenario["sessionId"]!.GetValue<string>(),
            scenarioId = scenario["scenarioId"]!.GetValue<string>(),
            mode = "TURN",
            level = scenario["level"]!.GetValue<string>()
        });

        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", scenario["conversationKey"]!.GetValue<string>());
        using var conversation = await client.PostAsJsonAsync("/v1/conversations", new
        {
            kind = scenario["kind"]!.GetValue<string>(),
            courseId = scenario["courseId"]!.GetValue<string>(),
            scenarioId = scenario["scenarioId"]!.GetValue<string>(),
            voiceSessionId = scenario["voiceSessionId"]!.GetValue<string>()
        });

        var bytes = OneSecondWav();
        var turnBody = new
        {
            turnId = scenario["turnId"]!.GetValue<string>(),
            epoch = scenario["epoch"]!.GetValue<int>(),
            wavBase64 = Convert.ToBase64String(bytes),
            audioSha256 = Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(bytes))
        };
        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", scenario["turnKey"]!.GetValue<string>());
        var turnPath = $"/v1/voice-sessions/{scenario["sessionId"]!.GetValue<string>()}/turns";
        using var firstTurn = await client.PostAsJsonAsync(turnPath, turnBody);
        using var replayTurn = await client.PostAsJsonAsync(turnPath, turnBody);
        var actualResults = new JsonObject
        {
            ["session"] = new JsonObject
            {
                ["status"] = (int)session.StatusCode,
                ["body"] = JsonNode.Parse(await session.Content.ReadAsStringAsync())
            },
            ["conversation"] = new JsonObject
            {
                ["status"] = (int)conversation.StatusCode,
                ["body"] = JsonNode.Parse(await conversation.Content.ReadAsStringAsync())
            },
            ["firstTurn"] = new JsonObject
            {
                ["status"] = (int)firstTurn.StatusCode,
                ["body"] = JsonNode.Parse(await firstTurn.Content.ReadAsStringAsync())
            },
            ["replayTurn"] = new JsonObject
            {
                ["status"] = (int)replayTurn.StatusCode,
                ["body"] = JsonNode.Parse(await replayTurn.Content.ReadAsStringAsync())
            }
        };
        Assert.True(JsonNode.DeepEquals(baseline["results"], actualResults),
            $"AssemblyAI voice-turn fallback response sequence differs from Node: expected {baseline["results"]?.ToJsonString()}, actual {actualResults.ToJsonString()}");

        var actualProviderRequests = new JsonArray();
        for (var index = 0; index < handler.Requests.Count; index++)
        {
            var requestHeaders = handler.Headers[index];
            var request = new JsonObject
            {
                ["method"] = handler.Methods[index],
                ["url"] = handler.Requests[index]!.ToString(),
                ["contentType"] = NormalizeProviderContentType(handler.ContentTypes[index]),
                ["bodyLength"] = checked((int)(handler.ContentLengths[index] ?? 0))
            };
            if (handler.Requests[index]!.Host.EndsWith(".stt.speech.microsoft.com", StringComparison.Ordinal))
            {
                var encoded = Convert.FromBase64String(requestHeaders["Pronunciation-Assessment"]);
                request["pronunciationAssessment"] = JsonNode.Parse(Encoding.UTF8.GetString(encoded));
            }
            else
            {
                var authorization = requestHeaders["Authorization"];
                var separator = authorization.IndexOf(' ');
                request["authorizationScheme"] = separator < 0 ? "raw" : authorization[..separator];
                if (handler.JsonBodies[index] is { } jsonBody) request["jsonBody"] = JsonNode.Parse(jsonBody);
            }
            actualProviderRequests.Add(request);
        }
        Assert.True(JsonNode.DeepEquals(baseline["providerRequests"], actualProviderRequests),
            $"AssemblyAI voice-turn fallback requests differ from Node: expected {baseline["providerRequests"]?.ToJsonString()}, actual {actualProviderRequests.ToJsonString()}");
        Assert.Equal(4, handler.Requests.Count); // Azure, upload, transcript creation and one poll.

        var tables = new JsonObject();
        foreach (var tableNode in scenario["inspect"]!.AsArray())
        {
            var table = tableNode!.GetValue<string>();
            var rows = driver.Rows
                .Where(pair => pair.Key.Table == table &&
                    (pair.Value["userId"]?.GetValue<string>() == user ||
                     pair.Value["aggregateId"]?.GetValue<string>() == user ||
                     pair.Value["userId"]?.GetValue<string>() == "system-speech-azure"))
                .OrderBy(pair => pair.Key.Id, StringComparer.Ordinal)
                .Select(pair => (JsonNode?)ProjectSpeechRow(pair.Key.Id, pair.Value))
                .ToArray();
            tables[table] = new JsonArray(rows);
        }
        Assert.True(JsonNode.DeepEquals(baseline["tables"], tables),
            $"AssemblyAI voice-turn fallback persisted rows differ from Node: expected {baseline["tables"]?.ToJsonString()}, actual {tables.ToJsonString()}");
    }

    private sealed class AdvancingClock(DateTimeOffset now) : TimeProvider
    {
        private DateTimeOffset _now = now;
        public override DateTimeOffset GetUtcNow() => _now;
        public void Advance(TimeSpan elapsed) => _now = _now.Add(elapsed);
    }

    private static JsonObject ProjectSpeechRow(string id, JsonObject source)
    {
        var row = source.DeepClone().AsObject();
        foreach (var key in new[] { "feedbackJson", "payloadJson", "reservationIdsJson", "responseJson", "resultJson" })
            if (row[key] is JsonValue value && value.TryGetValue<string>(out var json)) row[key] = JsonNode.Parse(json);
        return new JsonObject { ["id"] = id, ["row"] = row };
    }

    private static string? NormalizeProviderContentType(string? value) => value is null
        ? null
        : string.Join("; ", value.Split(';', StringSplitOptions.RemoveEmptyEntries)
            .Select(part => part.Trim().Replace("\"", "", StringComparison.Ordinal))
            .Where(part => !part.StartsWith("charset=", StringComparison.OrdinalIgnoreCase)));

    private static WebApplicationFactory<CocEnglish.AI.Program> CreateSpeechApp(
        Driver driver,
        SpeechHandler handler,
        IReadOnlyDictionary<string, string?> speechSettings,
        TimeProvider? clock = null) =>
        new WebApplicationFactory<CocEnglish.AI.Program>().WithWebHostBuilder(builder =>
        {
            var settings = new Dictionary<string, string?>
            {
                ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1",
                ["APPWRITE_PROJECT_ID"] = "test",
                ["COC_AI_APPWRITE_KEY"] = "test-key",
                ["COC_AI_PERSISTENCE"] = "appwrite",
                ["COC_AI_ADMITTED"] = "reviewed-cloud-gate",
                ["COC_AI_SPEECH_ADMITTED"] = "reviewed-device-quality-privacy-cost",
                ["COC_SERVICE_KEYS"] = "[]"
            };
            foreach (var setting in speechSettings) settings[setting.Key] = setting.Value;
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(settings));
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<IRowDriver>();
                services.AddSingleton<IRowDriver>(driver);
                services.RemoveAll<IIdentityVerifier>();
                services.AddSingleton<IIdentityVerifier, Identity>();
                services.RemoveAll<TimeProvider>();
                services.AddSingleton<TimeProvider>(clock ?? new FixedClock(Now));
                services.RemoveAll<IAiSpeechEngine>();
                services.AddScoped<IAiSpeechEngine>(sp => new AiSpeechEngine(
                    new HttpClient(handler, disposeHandler: false),
                    sp.GetRequiredService<OwnerStore>(),
                    sp.GetRequiredService<TimeProvider>(),
                    sp.GetRequiredService<IConfiguration>()));
            });
        });

    private static HttpResponseMessage JsonResponse(string json) => new(HttpStatusCode.OK)
    {
        Content = new StringContent(json, Encoding.UTF8, "application/json")
    };

    private sealed class SpeechHandler(Func<HttpRequestMessage, HttpResponseMessage> respond) : HttpMessageHandler
    {
        public List<Uri?> Requests { get; } = [];
        public List<string> Methods { get; } = [];
        public List<Dictionary<string, string>> Headers { get; } = [];
        public List<string?> ContentTypes { get; } = [];
        public List<long?> ContentLengths { get; } = [];
        public List<string?> JsonBodies { get; } = [];

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            Requests.Add(request.RequestUri);
            Methods.Add(request.Method.Method);
            Headers.Add(request.Headers.ToDictionary(pair => pair.Key, pair => string.Join(",", pair.Value), StringComparer.OrdinalIgnoreCase));
            ContentTypes.Add(request.Content?.Headers.ContentType?.ToString());
            ContentLengths.Add(request.Content?.Headers.ContentLength);
            JsonBodies.Add(request.Content?.Headers.ContentType?.MediaType == "application/json"
                ? await request.Content.ReadAsStringAsync(cancellationToken)
                : null);
            return respond(request);
        }
    }
}
