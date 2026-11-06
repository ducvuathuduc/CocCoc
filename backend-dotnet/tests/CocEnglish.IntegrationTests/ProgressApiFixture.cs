using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Progress.Application;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace CocEnglish.IntegrationTests;

internal sealed class ProgressApiFixture : WebApplicationFactory<Progress.Program>
{
    public FixtureDriver Driver { get; } = new();
    public ParityWatermark Watermark { get; } = new();
    public bool UseParityWatermark { get; init; }
    public ParityRelay Relay { get; } = new();
    public ParityRandom Random { get; } = new();
    public bool UseParityRelay { get; init; }
    public bool EnableSimulatedCommerce { get; init; }
    public DateTimeOffset Now { get; set; } = DateTimeOffset.Parse("2026-11-03T10:00:00Z");
    public string? CodeSecret { get; init; }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1", ["APPWRITE_PROJECT_ID"] = "isolated-test", ["COC_PROGRESS_APPWRITE_KEY"] = "not-real",
            ["COC_PROGRESS_PERSISTENCE"] = "appwrite", ["COC_PROGRESS_ADMITTED"] = "reviewed-cloud-gate", ["COC_PROGRESS_WORKER_ENABLED"] = "false", ["COC_PROGRESS_CODE_SECRET"] = CodeSecret,
            ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"parity-ai\",\"sender\":\"ai\",\"secretHex\":\"" + string.Concat(Enumerable.Repeat("0c", 32)) + "\"},{\"keyId\":\"parity-learning\",\"sender\":\"learning\",\"secretHex\":\"" + string.Concat(Enumerable.Repeat("0d", 32)) + "\"},{\"keyId\":\"parity-scheduler\",\"sender\":\"scheduler\",\"secretHex\":\"" + string.Concat(Enumerable.Repeat("0e", 32)) + "\"},{\"keyId\":\"parity-maintainer\",\"sender\":\"maintainer\",\"secretHex\":\"" + string.Concat(Enumerable.Repeat("0f", 32)) + "\"}]"
        }));
        builder.ConfigureServices(services =>
        {
            if (EnableSimulatedCommerce)
            {
                services.RemoveAll<ProgressCommercePolicy>();
                services.AddSingleton(new ProgressCommercePolicy(true));
            }
            services.RemoveAll<IIdentityVerifier>(); services.AddSingleton<IIdentityVerifier, Identity>();
            services.RemoveAll<TimeProvider>(); services.AddSingleton<TimeProvider>(new Clock(() => Now));
            services.RemoveAll<IRowDriver>(); services.AddSingleton<IRowDriver>(Driver);
            if (UseParityWatermark)
            {
                services.RemoveAll<ILearningWatermark>(); services.AddSingleton<ILearningWatermark>(Watermark);
            }
            if (UseParityRelay)
            {
                services.RemoveAll<IProgressRelayTransport>(); services.AddSingleton<IProgressRelayTransport>(Relay);
                services.RemoveAll<IRelayJitterSource>(); services.AddSingleton<IRelayJitterSource>(Random);
            }
        });
    }

    private sealed class Clock(Func<DateTimeOffset> now) : TimeProvider { public override DateTimeOffset GetUtcNow() => now(); }
    private sealed class Identity : IIdentityVerifier
    {
        public bool Configured => true;
        public Task<VerifiedSubject> VerifyAsync(string jwt, CancellationToken ct) => jwt switch
        {
            "alice-jwt" => Task.FromResult(new VerifiedSubject("alice")),
            "bob-jwt" => Task.FromResult(new VerifiedSubject("bob")),
            "a-private-jwt" => Task.FromResult(new VerifiedSubject("a-private")),
            "carol-jwt" => Task.FromResult(new VerifiedSubject("carol")),
            "quest-claimed-jwt" => Task.FromResult(new VerifiedSubject("quest-claimed")),
            "quest-ready-jwt" => Task.FromResult(new VerifiedSubject("quest-ready")),
            _ => throw new ServiceException("AUTH_EXPIRED")
        };
    }

    internal sealed class ParityWatermark : ILearningWatermark
    {
        public long? PendingBefore { get; set; }
        public Task<long> PendingBeforeAsync(DateTimeOffset cutoff, CancellationToken ct)
        {
            ct.ThrowIfCancellationRequested();
            return PendingBefore is { } pending
                ? Task.FromResult(pending)
                : Task.FromException<long>(new InvalidOperationException("WATERMARK_NOT_CONFIGURED"));
        }
    }

    internal sealed class ParityRelay : IProgressRelayTransport
    {
        public bool Configured => true;
        public RelayOutcome Outcome { get; set; } = RelayOutcome.Ack;
        public List<JsonObject> Deliveries { get; } = [];
        public Task<RelayOutcome> DeliverAsync(string target, JsonObject envelope, CancellationToken ct)
        {
            ct.ThrowIfCancellationRequested();
            var normalized = envelope.DeepClone().AsObject();
            normalized["eventId"] = "$event-id";
            normalized["requestId"] = "$event-id";
            Deliveries.Add(new JsonObject { ["target"] = target, ["event"] = normalized });
            return Task.FromResult(Outcome);
        }
    }

    internal sealed class ParityRandom : IRelayJitterSource
    {
        public double Value { get; set; } = 0.5;
        public double NextDouble() => Value;
    }

    internal sealed class FixtureDriver : IRowDriver
    {
        private readonly object _sync = new();
        private readonly Dictionary<(string Table, string Id), int> _versions = [];
        private string? _barrierTable;
        private string? _barrierId;
        private int _barrierParticipants;
        private int _barrierReads;
        private TaskCompletionSource<bool>? _readBarrier;

        public string Owner => "progress";
        public bool Configured => true;
        public bool EnforceReadVersions { get; set; }
        public int BarrierReads => _barrierReads;
        public int Reads { get; private set; }
        public int Commits { get; private set; }
        public int Attempts { get; private set; }
        public int Conflicts { get; set; }
        public IReadOnlyList<RowWrite> LastWrites { get; private set; } = [];
        public Dictionary<(string Table, string Id), JsonObject> Rows { get; } = new()
        { [("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))] = new() { ["userId"] = "alice", ["learningZone"] = "UTC" } };
        public void ArmReadBarrier(string table, string id, int participants)
        {
            lock (_sync)
            {
                _barrierTable = table;
                _barrierId = id;
                _barrierParticipants = participants;
                _barrierReads = 0;
                _readBarrier = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
            }
        }
        public async Task<RowDocument?> ReadAsync(string table, string id, CancellationToken ct)
        {
            RowDocument? snapshot;
            Task? barrier = null;
            lock (_sync)
            {
                Reads++;
                snapshot = Rows.TryGetValue((table, id), out var row)
                    ? new RowDocument(id, row.DeepClone().AsObject(), $"v{VersionOf((table, id))}")
                    : null;
                if (table == _barrierTable && id == _barrierId && _readBarrier is not null && _barrierReads < _barrierParticipants)
                {
                    _barrierReads++;
                    barrier = _readBarrier.Task;
                    if (_barrierReads == _barrierParticipants) _readBarrier.TrySetResult(true);
                }
            }
            if (barrier is not null) await barrier.WaitAsync(ct);
            return snapshot;
        }
        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken ct) => Task.FromResult<IReadOnlyList<RowDocument>>(Rows.Where(p => p.Key.Table == table &&
            (query.Where is null || query.Where.All(q => p.Value[q.Key]?.ToString() == q.Value?.ToString())) &&
            (query.AnyOf is null || query.AnyOf.All(q => q.Value.Contains(p.Value[q.Key]?.ToString(), StringComparer.Ordinal))) &&
            (query.GreaterThanEqual is null || query.GreaterThanEqual.All(q => StringComparer.Ordinal.Compare(p.Value[q.Key]?.ToString(), q.Value?.ToString()) >= 0)) &&
            (query.LessThan is null || query.LessThan.All(q => StringComparer.Ordinal.Compare(p.Value[q.Key]?.ToString(), q.Value?.ToString()) < 0)))
            .Select(p => new RowDocument(p.Key.Id, p.Value.DeepClone().AsObject(), "v1")).ToArray());
        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken ct) => Task.FromResult((long)Rows.Count(p => p.Key.Table == table && where.All(q => p.Value[q.Key]?.ToString() == q.Value?.ToString())));
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken ct)
        {
            lock (_sync)
            {
                Attempts++;
                if (Conflicts-- > 0) throw new TransactionConflictException();
                if (EnforceReadVersions)
                {
                    foreach (var read in reads)
                    {
                        var key = (read.Table, read.Id);
                        var exists = Rows.ContainsKey(key);
                        if (read.Document is null ? exists : !exists || read.Document.Version != $"v{VersionOf(key)}")
                            throw new TransactionConflictException();
                    }
                }
                Commits++; LastWrites = writes;
                foreach (var write in writes)
                {
                    var key = (write.Table, write.Id);
                    if (write.Action == "delete") Rows.Remove(key);
                    else Rows[key] = write.Data!.DeepClone().AsObject();
                    _versions[key] = VersionOf(key) + 1;
                }
            }
            return Task.CompletedTask;
        }

        private int VersionOf((string Table, string Id) key) => _versions.TryGetValue(key, out var version) ? version : 1;
    }
}
