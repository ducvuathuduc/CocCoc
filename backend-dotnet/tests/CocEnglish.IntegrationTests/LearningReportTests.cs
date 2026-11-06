using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed partial class LearningCompletionTests
{
    [Fact]
    public async Task CreateReport_StoresOwnerReportAndReplaysItsReceipt()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var exercises = new[] { Exercise("ex1") };
        var driver = Driver.WithEnrollment(now);
        using var app = CreateApp(driver, now, new Relay(), exercises);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "E4C2A130-71A0-4E93-9144-C1F27960D117");
        var body = new { exerciseId = "ex1", lessonVersion = "v1", category = "CONTENT" };

        using var first = await client.PostAsJsonAsync("/v1/reports", body);
        Assert.Equal(HttpStatusCode.Accepted, first.StatusCode);
        var firstResult = (await first.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("accepted", firstResult["status"]!.GetValue<string>());
        Assert.Equal("e4c2a130-71a0-4e93-9144-c1f27960d117", firstResult["operationId"]!.GetValue<string>());
        var report = Assert.Single(driver.Rows, row => row.Key.Table == "l_reports").Value;
        Assert.Equal("alice", report.Text("userId"));
        Assert.Equal("OPEN", report.Text("status"));
        Assert.Equal("", report.Text("note"));

        using var replay = await client.PostAsJsonAsync("/v1/reports", body);
        Assert.Equal(HttpStatusCode.Accepted, replay.StatusCode);
        Assert.Equal(firstResult.ToJsonString(), (await replay.Content.ReadFromJsonAsync<JsonObject>())!.ToJsonString());
        Assert.Single(driver.Rows, row => row.Key.Table == "l_reports");

        using var conflict = await client.PostAsJsonAsync("/v1/reports", new { exerciseId = "ex1", lessonVersion = "v1", category = "CONTENT", note = "changed" });
        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
        Assert.Equal("IDEMPOTENCY_CONFLICT", (await conflict.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
    }

    [Fact]
    public async Task CreateReport_RejectsUnknownFieldsAndOversizedNotes()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var driver = Driver.WithEnrollment(now);
        using var app = CreateApp(driver, now, new Relay(), [Exercise("ex1")]);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "F4C2A130-71A0-4E93-9144-C1F27960D117");

        using var unknown = await client.PostAsJsonAsync("/v1/reports", new { exerciseId = "ex1", lessonVersion = "v1", category = "OTHER", extra = true });
        Assert.Equal(HttpStatusCode.BadRequest, unknown.StatusCode);
        using var oversized = await client.PostAsJsonAsync("/v1/reports", new { exerciseId = "ex1", lessonVersion = "v1", category = "OTHER", note = new string('x', 513) });
        Assert.Equal(HttpStatusCode.BadRequest, oversized.StatusCode);
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table == "l_reports");
        Assert.Equal(0, driver.Commits);
    }
}
