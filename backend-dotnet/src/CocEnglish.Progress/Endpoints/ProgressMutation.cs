using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Contracts;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

internal static class ProgressMutation
{
    private static readonly JsonSerializerOptions WireOptions = new(JsonSerializerDefaults.Web) { Converters = { new UtcMillisecondsConverter() } };

    public static async Task<IActionResult> ExecuteAsync<T>(HttpContext context, OwnerStore store, string operation,
        Func<OwnerSession, string, string, CancellationToken, Task<T>> effect, int statusCode = 200)
    {
        var user = ((VerifiedSubject)context.Items[typeof(VerifiedSubject)]!).UserId;
        var key = context.Request.Headers["Idempotency-Key"].ToString();
        if (!Regex.IsMatch(key, "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant))
            throw RequestQuery.Bad("Idempotency-Key");
        var parameters = new JsonObject();
        foreach (var segment in RouteCatalog.All.Single(o => o.OperationId == operation).Path.Split('/').Where(p => p.StartsWith('{')))
        {
            var name = segment[1..^1];
            parameters[name] = context.Request.RouteValues[name]?.ToString();
        }
        var rawBody = (context.Items[typeof(ParsedRequestBody)] as ParsedRequestBody)?.Value;
        var bodyHash = CanonicalWire.BodyHash(new JsonObject { ["body"] = rawBody?.DeepClone(), ["params"] = parameters });
        var result = await store.CommitWithReceiptAsync(new(user, operation, key), bodyHash, async (tx, ct) =>
            new OperationResponse(statusCode, JsonSerializer.SerializeToNode(await effect(tx, user, key, ct), WireOptions)), context.RequestAborted);
        var response = result.Body;
        if (result.Status == "replayed" && response is JsonObject obj && obj.ContainsKey("operationId") && obj.ContainsKey("status"))
        {
            obj["status"] = "replayed";
            obj["requestId"] = context.Response.Headers["X-Request-ID"].ToString();
        }
        return new ObjectResult(response) { StatusCode = result.StatusCode };
    }
}
