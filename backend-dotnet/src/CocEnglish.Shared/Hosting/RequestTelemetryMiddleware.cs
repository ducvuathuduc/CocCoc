using System.Diagnostics;
using System.Diagnostics.Metrics;
using CocEnglish.Contracts;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace CocEnglish.Shared.Hosting;

/// <summary>Bounded request metadata only; never logs request/response content or credentials.</summary>
public sealed class RequestTelemetryMiddleware(RequestDelegate next, ILogger<RequestTelemetryMiddleware> logger)
{
    internal static readonly object ErrorCodeItemKey = new();
    private static readonly Meter Meter = new("CocEnglish.Api", "1.0.0");
    private static readonly Counter<long> Requests = Meter.CreateCounter<long>("cocenglish.api.requests", "{request}");
    private static readonly Histogram<double> Duration = Meter.CreateHistogram<double>("cocenglish.api.request.duration", "ms");
    private static readonly EventId Completed = new(1001, "ApiRequestCompleted");

    public async Task InvokeAsync(HttpContext context, RuntimeSettings settings)
    {
        var started = Stopwatch.GetTimestamp();
        var aborted = false;
        var unhandled = false;
        try
        {
            await next(context);
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            aborted = true;
            throw;
        }
        catch
        {
            unhandled = true;
            throw;
        }
        finally
        {
            var elapsed = Stopwatch.GetElapsedTime(started).TotalMilliseconds;
            var operation = context.GetEndpoint()?.Metadata.GetMetadata<ContractOperationAttribute>()?.OperationId;
            var contract = RouteCatalog.All.FirstOrDefault(o => o.Owner == settings.Service && o.OperationId == operation);
            var operationName = contract?.OperationId ?? (operation is "getHealth" or "getReadiness" ? operation : "unmatched");
            var route = contract?.Path ?? (operation switch { "getHealth" => "/health", "getReadiness" => "/ready", _ => "unmatched" });
            var method = context.Request.Method is "GET" or "POST" or "PATCH" or "DELETE" or "PUT" or "HEAD" or "OPTIONS"
                ? context.Request.Method : "OTHER";
            // 499 is telemetry for a disconnected client; it is not written to the response.
            var status = aborted ? 499 : unhandled ? 500 : context.Response.StatusCode;
            var errorCode = aborted ? "REQUEST_ABORTED" : unhandled ? "UNHANDLED_ERROR" :
                context.Items.TryGetValue(ErrorCodeItemKey, out var value) && value is string code ? code : "none";
            var requestId = context.Response.Headers["X-Request-ID"].ToString();
            if (requestId.Length == 0) requestId = context.TraceIdentifier;

            var tags = new TagList
            {
                { "service", settings.Service }, { "operation", operationName }, { "method", method },
                { "status_code", status }, { "error_code", errorCode }
            };
            Requests.Add(1, tags);
            Duration.Record(elapsed, tags);
            logger.Log(status >= 500 ? LogLevel.Error : status >= 400 ? LogLevel.Warning : LogLevel.Information,
                Completed,
                "API completed: service {Service}, build {BuildId}, operation {Operation}, route {Route}, method {Method}, status {StatusCode}, duration {ElapsedMs} ms, request {RequestId}, error {ErrorCode}, aborted {Aborted}",
                settings.Service, settings.BuildId, operationName, route, method, status, Math.Round(elapsed, 2), requestId, errorCode, aborted);
        }
    }
}
