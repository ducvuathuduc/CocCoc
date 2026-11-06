using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.Shared.Tests;

/// <summary>Opt-in durable probes. Never infer cloud admission from their default skipped result.</summary>
public sealed class AppwriteLiveTests
{
    private const string Table = "l_active_slots";

    [AppwriteLiveFact]
    [Trait("Category", "AppwriteLive")]
    public async Task CommittedRow_SurvivesNewClientAndRejectsStaleRevision()
    {
        var connection = AppwriteLiveConfiguration.FromEnvironment();
        var id = "dn_" + Guid.NewGuid().ToString("N");
        using var deadline = new CancellationTokenSource(TimeSpan.FromMinutes(2));
        using var client = NewClient();
        var writer = new AppwriteRowDriver(client, connection, "learning");
        try
        {
            Assert.Null(await writer.ReadAsync(Table, id, deadline.Token));
            await writer.CommitAsync([new(Table, id, "create", Slot(id))], [(Table, id, null)], deadline.Token);

            using var readerClient = NewClient();
            var reader = new AppwriteRowDriver(readerClient, connection, "learning");
            var original = Assert.IsType<RowDocument>(await reader.ReadAsync(Table, id, deadline.Token));
            Assert.Equal(id, original.Data["userId"]!.GetValue<string>());
            Assert.Equal("probe-original", original.Data["sessionId"]!.GetValue<string>());
            Assert.Equal(0, original.Data["revision"]!.GetValue<int>());

            var updated = Change(original, "probe-updated");
            await writer.CommitAsync([new(Table, id, "update", updated)], [(Table, id, original)], deadline.Token);
            await Assert.ThrowsAsync<TransactionConflictException>(() => reader.CommitAsync(
                [new(Table, id, "update", Change(original, "probe-stale"))], [(Table, id, original)], deadline.Token));

            var stored = Assert.IsType<RowDocument>(await reader.ReadAsync(Table, id, deadline.Token));
            Assert.Equal("probe-updated", stored.Data["sessionId"]!.GetValue<string>());
            Assert.Equal(1, stored.Data["revision"]!.GetValue<int>());
            await reader.CommitAsync([new(Table, id, "delete")], [(Table, id, stored)], deadline.Token);
            Assert.Null(await writer.ReadAsync(Table, id, deadline.Token));
        }
        finally { await Cleanup(connection, id); }
    }

    [AppwriteLiveFact]
    [Trait("Category", "AppwriteLive")]
    public async Task ProgressProfile_PersistsAcrossClientsAndRejectsStaleRevision()
    {
        var connection = AppwriteLiveConfiguration.FromEnvironment();
        var userId = "dn_" + Guid.NewGuid().ToString("N");
        var id = CanonicalWire.RowId("p_profiles", userId);
        var username = AppwriteOwnerProbeRows.ProgressUsername(userId);
        using var deadline = new CancellationTokenSource(TimeSpan.FromMinutes(2));
        using var writerClient = NewClient();
        var writer = new AppwriteRowDriver(writerClient, connection, "progress");
        try
        {
            Assert.Null(await writer.ReadAsync("p_profiles", id, deadline.Token));
            var seed = AppwriteOwnerProbeRows.ProgressProfile(userId, "probe-original");
            await writer.CommitAsync([new("p_profiles", id, "create", seed)], [("p_profiles", id, null)], deadline.Token);

            using var readerClient = NewClient();
            var reader = new AppwriteRowDriver(readerClient, connection, "progress");
            var original = Assert.IsType<RowDocument>(await reader.ReadAsync("p_profiles", id, deadline.Token));
            Assert.Equal(userId, original.Data["userId"]!.GetValue<string>());
            Assert.Equal(username, original.Data["username"]!.GetValue<string>());
            Assert.Equal("probe-original", original.Data["nickname"]!.GetValue<string>());
            Assert.Equal(0, original.Data["revision"]!.GetValue<int>());

            var updated = AppwriteOwnerProbeRows.Change("progress", "p_profiles", original.Data, "nickname", "probe-updated");
            await writer.CommitAsync([new("p_profiles", id, "update", updated)], [("p_profiles", id, original)], deadline.Token);
            var stale = AppwriteOwnerProbeRows.Change("progress", "p_profiles", original.Data, "nickname", "probe-stale");
            await Assert.ThrowsAsync<TransactionConflictException>(() => reader.CommitAsync(
                [new("p_profiles", id, "update", stale)], [("p_profiles", id, original)], deadline.Token));

            var stored = Assert.IsType<RowDocument>(await reader.ReadAsync("p_profiles", id, deadline.Token));
            Assert.Equal("probe-updated", stored.Data["nickname"]!.GetValue<string>());
            Assert.Equal(1, stored.Data["revision"]!.GetValue<int>());
            await reader.CommitAsync([new("p_profiles", id, "delete")], [("p_profiles", id, stored)], deadline.Token);
            Assert.Null(await writer.ReadAsync("p_profiles", id, deadline.Token));
        }
        finally { await CleanupProgressProfile(connection, id, userId, username); }
    }

    [AppwriteLiveFact]
    [Trait("Category", "AppwriteLive")]
    public async Task AiActiveSlot_PersistsAcrossClientsAndRejectsStaleRevision()
    {
        var connection = AppwriteLiveConfiguration.FromEnvironment();
        var userId = "dn_" + Guid.NewGuid().ToString("N");
        var id = CanonicalWire.RowId("slot", userId);
        using var deadline = new CancellationTokenSource(TimeSpan.FromMinutes(2));
        using var writerClient = NewClient();
        var writer = new AppwriteRowDriver(writerClient, connection, "ai");
        try
        {
            Assert.Null(await writer.ReadAsync("a_active_slots", id, deadline.Token));
            var seed = AppwriteOwnerProbeRows.AiActiveSlot(userId, "probe-original");
            await writer.CommitAsync([new("a_active_slots", id, "create", seed)], [("a_active_slots", id, null)], deadline.Token);

            using var readerClient = NewClient();
            var reader = new AppwriteRowDriver(readerClient, connection, "ai");
            var original = Assert.IsType<RowDocument>(await reader.ReadAsync("a_active_slots", id, deadline.Token));
            Assert.Equal(userId, original.Data["userId"]!.GetValue<string>());
            Assert.Equal("probe-original", original.Data["sessionId"]!.GetValue<string>());
            Assert.Equal(7, original.Data["epoch"]!.GetValue<int>());
            Assert.Equal(0, original.Data["revision"]!.GetValue<int>());

            var updated = AppwriteOwnerProbeRows.Change("ai", "a_active_slots", original.Data, "sessionId", "probe-updated");
            await writer.CommitAsync([new("a_active_slots", id, "update", updated)], [("a_active_slots", id, original)], deadline.Token);
            var stale = AppwriteOwnerProbeRows.Change("ai", "a_active_slots", original.Data, "sessionId", "probe-stale");
            await Assert.ThrowsAsync<TransactionConflictException>(() => reader.CommitAsync(
                [new("a_active_slots", id, "update", stale)], [("a_active_slots", id, original)], deadline.Token));

            var stored = Assert.IsType<RowDocument>(await reader.ReadAsync("a_active_slots", id, deadline.Token));
            Assert.Equal("probe-updated", stored.Data["sessionId"]!.GetValue<string>());
            Assert.Equal(1, stored.Data["revision"]!.GetValue<int>());
            await reader.CommitAsync([new("a_active_slots", id, "delete")], [("a_active_slots", id, stored)], deadline.Token);
            Assert.Null(await writer.ReadAsync("a_active_slots", id, deadline.Token));
        }
        finally { await CleanupAiSlot(connection, id, userId); }
    }

    [AppwriteLiveFact]
    [Trait("Category", "AppwriteLive")]
    public async Task CompetingTransactions_CommitExactlyOneRevision()
    {
        var connection = AppwriteLiveConfiguration.FromEnvironment();
        var id = "dn_" + Guid.NewGuid().ToString("N");
        using var deadline = new CancellationTokenSource(TimeSpan.FromMinutes(2));
        using var client = NewClient();
        var driver = new AppwriteRowDriver(client, connection, "learning");
        try
        {
            Assert.Null(await driver.ReadAsync(Table, id, deadline.Token));
            await driver.CommitAsync([new(Table, id, "create", Slot(id))], [(Table, id, null)], deadline.Token);
            var snapshot = Assert.IsType<RowDocument>(await driver.ReadAsync(Table, id, deadline.Token));
            var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var first = Compete("probe-first");
            var second = Compete("probe-second");
            start.SetResult();
            var outcomes = await Task.WhenAll(first, second);
            Assert.Equal(1, outcomes.Count(committed => committed));
            Assert.Equal(1, outcomes.Count(committed => !committed));

            var stored = Assert.IsType<RowDocument>(await driver.ReadAsync(Table, id, deadline.Token));
            Assert.Equal(1, stored.Data["revision"]!.GetValue<int>());
            Assert.Equal(outcomes[0] ? "probe-first" : "probe-second", stored.Data["sessionId"]!.GetValue<string>());
            Assert.Equal(id, stored.Data["userId"]!.GetValue<string>());

            async Task<bool> Compete(string session)
            {
                using var contenderClient = NewClient();
                var contender = new AppwriteRowDriver(contenderClient, connection, "learning");
                await start.Task.WaitAsync(deadline.Token);
                try
                {
                    await contender.CommitAsync([new(Table, id, "update", Change(snapshot, session))],
                        [(Table, id, snapshot)], deadline.Token);
                    return true;
                }
                catch (TransactionConflictException) { return false; }
            }
        }
        finally { await Cleanup(connection, id); }
    }

    [AppwriteLiveFact]
    [Trait("Category", "AppwriteLive")]
    public async Task ListAsync_CursorsAcrossDurablePagesAndKeepsOwnerFilter()
    {
        var connection = AppwriteLiveConfiguration.FromEnvironment();
        var owner = Guid.NewGuid().ToString();
        var foreignOwner = Guid.NewGuid().ToString();
        var run = Guid.NewGuid().ToString("N");
        var coursePrefix = "p" + run[..24];
        var rows = Enumerable.Range(0, 101)
            .Select(index => new ProbeSlot(
                "dn_" + Guid.NewGuid().ToString("N"),
                owner,
                $"{coursePrefix}-{index:D3}",
                $"s{index:D3}{run[..20]}"))
            .Append(new ProbeSlot("dn_" + Guid.NewGuid().ToString("N"), foreignOwner, coursePrefix + "-foreign", "foreign-session"))
            .ToArray();
        using var deadline = new CancellationTokenSource(TimeSpan.FromMinutes(3));
        using var client = NewClient();
        var driver = new AppwriteRowDriver(client, connection, "learning");
        try
        {
            Assert.Empty(await driver.ListAsync(Table, OwnerQuery(owner), deadline.Token));
            foreach (var batch in rows.Chunk(95))
            {
                await driver.CommitAsync(batch.Select(row => new RowWrite(Table, row.Id, "create", Slot(row.UserId, row.CourseId, row.SessionId))).ToArray(), [], deadline.Token);
            }

            var result = await driver.ListAsync(Table, OwnerQuery(owner) with
            {
                OrderBy = [new RowOrder("courseId")],
                Limit = 101
            }, deadline.Token);
            var expectedCourses = rows.Where(row => row.UserId == owner).Select(row => row.CourseId).OrderBy(value => value, StringComparer.Ordinal);

            Assert.Equal(101, result.Count);
            Assert.Equal(101, result.Select(row => row.Id).Distinct(StringComparer.Ordinal).Count());
            Assert.All(result, row => Assert.Equal(owner, row.Data["userId"]!.GetValue<string>()));
            Assert.Equal(expectedCourses, result.Select(row => row.Data["courseId"]!.GetValue<string>()));
            Assert.Equal(101, await driver.CountAsync(Table, OwnerQuery(owner), deadline.Token));
        }
        finally { await Cleanup(connection, rows, coursePrefix, deadline.Token); }
    }

    private static HttpClient NewClient() => new() { Timeout = TimeSpan.FromSeconds(15) };

    private static RowQuery OwnerQuery(string owner) => new(Where: new Dictionary<string, object?> { ["userId"] = owner }, Limit: 500);

    private static JsonObject Slot(string id)
    {
        var now = OwnerSchema.Iso(DateTimeOffset.UtcNow);
        return Slot(id, "dotnet-probe", "probe-original");
    }

    private static JsonObject Slot(string userId, string courseId, string sessionId)
    {
        var now = OwnerSchema.Iso(DateTimeOffset.UtcNow);
        return new()
        {
            ["userId"] = userId, ["courseId"] = courseId, ["sessionId"] = sessionId,
            ["expiresAt"] = OwnerSchema.Iso(DateTimeOffset.UtcNow.AddHours(1)),
            ["revision"] = 0, ["createdAt"] = now, ["updatedAt"] = now
        };
    }

    private sealed record ProbeSlot(string Id, string UserId, string CourseId, string SessionId);

    private static JsonObject Change(RowDocument original, string session)
    {
        var row = original.Data.DeepClone().AsObject();
        row["sessionId"] = session;
        row["revision"] = original.Data["revision"]!.GetValue<int>() + 1;
        row["updatedAt"] = OwnerSchema.Iso(DateTimeOffset.UtcNow);
        return row;
    }

    private static async Task Cleanup(AppwriteConnection connection, string id)
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(30));
        using var client = NewClient();
        var driver = new AppwriteRowDriver(client, connection, "learning");
        var row = await driver.ReadAsync(Table, id, timeout.Token);
        if (row is null) return;
        if (row.Data["userId"]?.GetValue<string>() != id || row.Data["courseId"]?.GetValue<string>() != "dotnet-probe")
            throw new InvalidOperationException("Probe cleanup refused a row with an unexpected owner.");
        await driver.CommitAsync([new(Table, id, "delete")], [(Table, id, row)], timeout.Token);
        Assert.Null(await driver.ReadAsync(Table, id, timeout.Token));
    }

    private static async Task CleanupProgressProfile(AppwriteConnection connection, string id, string userId, string username)
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(30));
        using var client = NewClient();
        var driver = new AppwriteRowDriver(client, connection, "progress");
        var row = await driver.ReadAsync("p_profiles", id, timeout.Token);
        if (row is null) return;
        if (row.Data["userId"]?.GetValue<string>() != userId || row.Data["username"]?.GetValue<string>() != username)
            throw new InvalidOperationException("Progress probe cleanup refused a profile with an unexpected owner or marker.");
        await driver.CommitAsync([new("p_profiles", id, "delete")], [("p_profiles", id, row)], timeout.Token);
        Assert.Null(await driver.ReadAsync("p_profiles", id, timeout.Token));
    }

    private static async Task CleanupAiSlot(AppwriteConnection connection, string id, string userId)
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(30));
        using var client = NewClient();
        var driver = new AppwriteRowDriver(client, connection, "ai");
        var row = await driver.ReadAsync("a_active_slots", id, timeout.Token);
        if (row is null) return;
        if (row.Data["userId"]?.GetValue<string>() != userId || row.Data["epoch"]?.GetValue<int>() != 7 ||
            row.Data["sessionId"]?.GetValue<string>() is not { } sessionId || !sessionId.StartsWith("probe-", StringComparison.Ordinal))
            throw new InvalidOperationException("AI probe cleanup refused a slot with an unexpected owner or marker.");
        await driver.CommitAsync([new("a_active_slots", id, "delete")], [("a_active_slots", id, row)], timeout.Token);
        Assert.Null(await driver.ReadAsync("a_active_slots", id, timeout.Token));
    }

    private static async Task Cleanup(AppwriteConnection connection, IReadOnlyList<ProbeSlot> probes, string coursePrefix, CancellationToken cancellationToken)
    {
        using var client = NewClient();
        var driver = new AppwriteRowDriver(client, connection, "learning");
        var owners = probes.Select(probe => probe.UserId).Distinct(StringComparer.Ordinal).ToArray();
        var documents = new List<RowDocument>();
        foreach (var owner in owners)
        {
            var rows = await driver.ListAsync(Table, OwnerQuery(owner), cancellationToken);
            foreach (var row in rows)
            {
                if (!row.Data["courseId"]!.GetValue<string>().StartsWith(coursePrefix, StringComparison.Ordinal) || row.Data["userId"]!.GetValue<string>() != owner)
                    throw new InvalidOperationException("Probe cleanup refused a row with an unexpected owner or course.");
                documents.Add(row);
            }
        }

        foreach (var batch in documents.Chunk(95))
        {
            await driver.CommitAsync(
                batch.Select(row => new RowWrite(Table, row.Id, "delete")).ToArray(),
                batch.Select(row => (Table, row.Id, (RowDocument?)row)).ToArray(),
                cancellationToken);
        }

        foreach (var owner in owners)
            Assert.Empty(await driver.ListAsync(Table, OwnerQuery(owner), cancellationToken));
    }
}

public sealed class AppwriteLiveFactAttribute : FactAttribute
{
    public AppwriteLiveFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("COC_DOTNET_APPWRITE_LIVE") != "1")
            Skip = "Live Appwrite probe is disabled; requires explicit test-project admission and credentials.";
    }
}

internal static class AppwriteLiveConfiguration
{
    public static AppwriteConnection FromEnvironment() => Create(Environment.GetEnvironmentVariable);

    internal static AppwriteConnection Create(Func<string, string?> read)
    {
        if (read("COC_DOTNET_APPWRITE_LIVE") != "1" || read("APPWRITE_PROJECT_ENV") != "test" ||
            read("ALLOW_LIVE_PROBE") != "reviewed-test-project" ||
            read("APPWRITE_ENDPOINT") != "https://sgp.cloud.appwrite.io/v1" ||
            read("APPWRITE_PROJECT_ID") != "6acc656d0025cc57bd81" ||
            read("COC_DATABASE_ID") is not (null or "cocenglish") ||
            string.IsNullOrWhiteSpace(read("APPWRITE_API_KEY")))
            throw new InvalidOperationException("Live probe requires explicit admission, the selected coccoc-test project and local server credentials. Configuration values are withheld.");
        return new(new("https://sgp.cloud.appwrite.io/v1"), "6acc656d0025cc57bd81", read("APPWRITE_API_KEY")!);
    }
}

public sealed class AppwriteLiveConfigurationTests
{
    [Theory]
    [InlineData("COC_DOTNET_APPWRITE_LIVE", null)]
    [InlineData("APPWRITE_PROJECT_ENV", "production")]
    [InlineData("ALLOW_LIVE_PROBE", null)]
    [InlineData("APPWRITE_ENDPOINT", "https://other.example/v1")]
    [InlineData("APPWRITE_PROJECT_ID", "another-project")]
    [InlineData("COC_DATABASE_ID", "another-database")]
    [InlineData("APPWRITE_API_KEY", " ")]
    public void Create_RefusesMissingAdmissionOrWrongTarget(string key, string? value)
    {
        var values = Valid();
        values[key] = value;
        var error = Assert.Throws<InvalidOperationException>(() => AppwriteLiveConfiguration.Create(name => values.GetValueOrDefault(name)));
        Assert.DoesNotContain("synthetic-probe-key", error.Message);
    }

    [Fact]
    public void Create_AcceptsOnlySelectedTestProjectAndRedactsCredentials()
    {
        var values = Valid();
        var connection = AppwriteLiveConfiguration.Create(name => values.GetValueOrDefault(name));
        Assert.Equal("6acc656d0025cc57bd81", connection.ProjectId);
        Assert.Equal("https://sgp.cloud.appwrite.io/v1", connection.Endpoint.AbsoluteUri);
        Assert.Equal("cocenglish", connection.DatabaseId);
        Assert.DoesNotContain("synthetic-probe-key", connection.ToString());
    }

    private static Dictionary<string, string?> Valid() => new()
    {
        ["COC_DOTNET_APPWRITE_LIVE"] = "1", ["APPWRITE_PROJECT_ENV"] = "test",
        ["ALLOW_LIVE_PROBE"] = "reviewed-test-project", ["APPWRITE_ENDPOINT"] = "https://sgp.cloud.appwrite.io/v1",
        ["APPWRITE_PROJECT_ID"] = "6acc656d0025cc57bd81", ["APPWRITE_API_KEY"] = "synthetic-probe-key"
    };
}
