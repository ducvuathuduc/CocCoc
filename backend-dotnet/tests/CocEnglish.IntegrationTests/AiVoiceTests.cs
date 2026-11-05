using System.Net;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed partial class AiConversationTests
{
    [Fact]
    public async Task VoiceCreation_KeepsLiveAndTurnDisabledWithoutReservationsOrReceipts()
    {
        var driver = new Driver();
        using var app = CreateApp(driver);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "77777777-7777-4777-8777-777777777777");

        using var live = await client.PostAsJsonAsync("/v1/voice-sessions", new { sessionId = "88888888-8888-4888-8888-888888888888", scenarioId = "rp_cafe_order", mode = "LIVE", level = "A1" });
        Assert.Equal(HttpStatusCode.ServiceUnavailable, live.StatusCode);
        Assert.Equal("NATIVE_LIVE_DISABLED", (await live.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());

        using var turn = await client.PostAsJsonAsync("/v1/voice-sessions", new { sessionId = "99999999-9999-4999-8999-999999999999", scenarioId = "rp_cafe_order", mode = "TURN", level = "A1" });
        Assert.Equal(HttpStatusCode.ServiceUnavailable, turn.StatusCode);
        Assert.Equal("AI_PROVIDER_UNAVAILABLE", (await turn.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
        Assert.Equal(0, driver.Commits);
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table is "a_voice_sessions" or "a_active_slots" or "a_receipts");
    }

    [Fact]
    public async Task VoiceTurn_ValidatesAudioAndOwnershipThenFailsClosedWithoutWrites()
    {
        var driver = new Driver();
        var sessionId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
        driver.Seed("a_voice_sessions", CanonicalWire.RowId("voice", sessionId), new JsonObject
        {
            ["userId"] = "alice", ["sessionId"] = sessionId, ["mode"] = "TURN", ["status"] = "ACTIVE",
            ["expiresAt"] = OwnerSchema.Iso(Now.AddMinutes(10)), ["epoch"] = 0, ["consumedSeconds"] = 0
        });
        using var app = CreateApp(driver);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "abababab-abab-4bab-8bab-abababababab");
        var bytes = OneSecondWav();
        var body = new
        {
            turnId = "bcbcbcbc-bcbc-4cbc-8cbc-bcbcbcbcbcbc",
            epoch = 0,
            wavBase64 = Convert.ToBase64String(bytes),
            audioSha256 = Convert.ToHexStringLower(SHA256.HashData(bytes))
        };

        using var result = await client.PostAsJsonAsync($"/v1/voice-sessions/{sessionId}/turns", body);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, result.StatusCode);
        Assert.Equal("AI_PROVIDER_UNAVAILABLE", (await result.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
        Assert.Equal(0, driver.Commits);
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table is "a_receipts" or "a_usage");
    }

    [Fact]
    public async Task VoiceLifecycle_HeartbeatIsMonotonicAndCloseReleasesOnlyItsOwnedSlot()
    {
        var driver = new Driver();
        var sessionId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
        var sessionRowId = CanonicalWire.RowId("voice", sessionId);
        var slotId = CanonicalWire.RowId("slot", "alice");
        driver.Seed("a_voice_sessions", sessionRowId, new JsonObject
        {
            ["userId"] = "alice", ["sessionId"] = sessionId, ["providerAlias"] = "scripted", ["mode"] = "TURN", ["status"] = "ACTIVE",
            ["createdAt"] = OwnerSchema.Iso(Now.AddMinutes(-1)), ["expiresAt"] = OwnerSchema.Iso(Now.AddMinutes(10)),
            ["lastHeartbeatAt"] = OwnerSchema.Iso(Now.AddMinutes(-1)), ["epoch"] = 3, ["consumedSeconds"] = 5,
            ["configVersion"] = "scripted-v1", ["revision"] = 0, ["updatedAt"] = OwnerSchema.Iso(Now.AddMinutes(-1))
        });
        driver.Seed("a_active_slots", slotId, new JsonObject
        {
            ["userId"] = "alice", ["sessionId"] = sessionId, ["expiresAt"] = OwnerSchema.Iso(Now.AddMinutes(10)),
            ["epoch"] = 3, ["revision"] = 0, ["createdAt"] = OwnerSchema.Iso(Now.AddMinutes(-1)), ["updatedAt"] = OwnerSchema.Iso(Now.AddMinutes(-1))
        });
        using var app = CreateApp(driver);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");

        using var heartbeat = await client.PostAsJsonAsync($"/v1/voice-sessions/{sessionId}/heartbeat", new { epoch = 3, elapsedSeconds = 120, turnCount = 8 });
        Assert.Equal(HttpStatusCode.OK, heartbeat.StatusCode);
        Assert.Equal(120, (await heartbeat.Content.ReadFromJsonAsync<JsonObject>())!["accountedSeconds"]!.GetValue<int>());
        using var regressed = await client.PostAsJsonAsync($"/v1/voice-sessions/{sessionId}/heartbeat", new { epoch = 3, elapsedSeconds = 40, turnCount = 2 });
        Assert.Equal(120, (await regressed.Content.ReadFromJsonAsync<JsonObject>())!["accountedSeconds"]!.GetValue<int>());
        var commits = driver.Commits;
        using var stale = await client.PostAsJsonAsync($"/v1/voice-sessions/{sessionId}/heartbeat", new { epoch = 2, elapsedSeconds = 10, turnCount = 1 });
        Assert.Equal(HttpStatusCode.Conflict, stale.StatusCode);
        Assert.Equal("VOICE_EPOCH_CONFLICT", (await stale.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
        Assert.Equal(commits, driver.Commits);

        using var closed = await client.PostAsJsonAsync($"/v1/voice-sessions/{sessionId}/close", new { });
        Assert.Equal(HttpStatusCode.OK, closed.StatusCode);
        Assert.Equal("CLOSED", (await closed.Content.ReadFromJsonAsync<JsonObject>())!["status"]!.GetValue<string>());
        Assert.Null(await driver.ReadAsync("a_active_slots", slotId, CancellationToken.None));
        var closeCommits = driver.Commits;
        using var closeReplay = await client.PostAsJsonAsync($"/v1/voice-sessions/{sessionId}/close", new { });
        Assert.Equal(HttpStatusCode.OK, closeReplay.StatusCode);
        Assert.Equal(closeCommits, driver.Commits);

        client.DefaultRequestHeaders.Authorization = new("Bearer", "bob");
        using var foreign = await client.PostAsJsonAsync($"/v1/voice-sessions/{sessionId}/close", new { });
        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);
    }

    [Fact]
    public async Task Assessment_ValidatesWavStoresOnlyHashAndReturnsNullScoreWithoutScorer()
    {
        var driver = new Driver();
        using var app = CreateApp(driver);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb");
        var bytes = OneSecondWav();
        var sha = Convert.ToHexStringLower(SHA256.HashData(bytes));
        var body = new
        {
            jobId = "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
            referenceExerciseId = "exercise1",
            lessonVersion = "v1",
            locale = "en-US",
            wavBase64 = Convert.ToBase64String(bytes),
            audioSha256 = sha
        };

        using var created = await client.PostAsJsonAsync("/v1/assessment-jobs", body);
        Assert.Equal(HttpStatusCode.Accepted, created.StatusCode);
        var result = (await created.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("SUCCEEDED", result["status"]!.GetValue<string>());
        Assert.Equal("NULL_UNAVAILABLE", result["scoreState"]!.GetValue<string>());
        Assert.Equal("AZURE_DISABLED", result["unavailableReason"]!.GetValue<string>());
        Assert.Null(result["accuracy"]);
        Assert.Null(result["transcript"]);
        var jobId = CanonicalWire.RowId("job", "alice", body.jobId);
        var job = driver.Rows[("a_jobs", jobId)];
        Assert.Equal(sha, job["inputHash"]!.GetValue<string>());
        Assert.Null(job["audioFileId"]);
        Assert.Equal("ASSESSMENT", job["kind"]!.GetValue<string>());

        var commits = driver.Commits;
        using var replay = await client.PostAsJsonAsync("/v1/assessment-jobs", body);
        Assert.Equal(HttpStatusCode.Accepted, replay.StatusCode);
        Assert.Equal(result.ToJsonString(), (await replay.Content.ReadFromJsonAsync<JsonObject>())!.ToJsonString());
        Assert.Equal(commits, driver.Commits);

        var read = await client.GetFromJsonAsync<JsonObject>($"/v1/assessment-jobs/{body.jobId}");
        Assert.Equal(body.jobId, read!["jobId"]!.GetValue<string>());
        client.DefaultRequestHeaders.Authorization = new("Bearer", "bob");
        using var foreign = await client.GetAsync($"/v1/assessment-jobs/{body.jobId}");
        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);
    }

    private static byte[] OneSecondWav()
    {
        var bytes = new byte[44 + 32000];
        Encoding.ASCII.GetBytes("RIFF").CopyTo(bytes, 0);
        BitConverter.GetBytes(bytes.Length - 8).CopyTo(bytes, 4);
        Encoding.ASCII.GetBytes("WAVEfmt ").CopyTo(bytes, 8);
        BitConverter.GetBytes(16).CopyTo(bytes, 16);
        BitConverter.GetBytes((short)1).CopyTo(bytes, 20);
        BitConverter.GetBytes((short)1).CopyTo(bytes, 22);
        BitConverter.GetBytes(16000).CopyTo(bytes, 24);
        BitConverter.GetBytes(32000).CopyTo(bytes, 28);
        BitConverter.GetBytes((short)2).CopyTo(bytes, 32);
        BitConverter.GetBytes((short)16).CopyTo(bytes, 34);
        Encoding.ASCII.GetBytes("data").CopyTo(bytes, 36);
        BitConverter.GetBytes(32000).CopyTo(bytes, 40);
        return bytes;
    }
}
