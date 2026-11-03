using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Contracts;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;

namespace CocEnglish.Shared.Hosting;

public sealed record ParsedRequestBody(string Raw, JsonNode? Value);

public sealed class ApiBoundaryMiddleware(RequestDelegate next)
{
    private static readonly string[] HmacHeaderNames = ["X-Service-Key-Id", "X-Service-Timestamp", "X-Service-Signature"];
    private static readonly HashSet<string> ReadySenders = ["maintainer", "learning", "progress", "ai"];

    public async Task InvokeAsync(HttpContext context, RuntimeSettings settings, IIdentityVerifier identity, TimeProvider clock)
    {
        var suppliedId = context.Request.Headers["X-Request-ID"].ToString();
        var requestId = Regex.IsMatch(suppliedId, "^[A-Za-z0-9-]{1,64}$", RegexOptions.CultureInvariant)
            ? suppliedId : Guid.NewGuid().ToString();
        context.Response.Headers["X-Request-ID"] = requestId;
        context.Response.Headers.Vary = "Origin";
        context.Response.Headers.CacheControl = "no-store";
        var origin = context.Request.Headers.Origin.ToString();
        if (settings.CorsOrigins.Contains(origin))
        {
            context.Response.Headers["Access-Control-Allow-Origin"] = origin;
            context.Response.Headers["Access-Control-Allow-Credentials"] = "true";
            context.Response.Headers["Access-Control-Allow-Methods"] = "GET, POST, PATCH, DELETE, OPTIONS";
            context.Response.Headers["Access-Control-Max-Age"] = "600";
            context.Response.Headers["Access-Control-Allow-Headers"] = "authorization, content-type, idempotency-key, x-appwrite-user-jwt, " + string.Join(", ", HmacHeaderNames).ToLowerInvariant();
        }
        try
        {
            if (HttpMethods.IsOptions(context.Request.Method)) { context.Response.StatusCode = 204; return; }
            if (HttpMethods.IsGet(context.Request.Method) && context.Request.Path.Value == "/health") { await next(context); return; }
            var operationId = context.GetEndpoint()?.Metadata.GetMetadata<ContractOperationAttribute>()?.OperationId;
            var contract = RouteCatalog.All.FirstOrDefault(o => o.OperationId == operationId);
            var limit = operationId is "createAssessment" or "submitVoiceTurn" ? 750000 : 64000;
            var raw = await ReadBody(context.Request, limit, context.RequestAborted);
            if ((HttpMethods.IsGet(context.Request.Method) || HttpMethods.IsHead(context.Request.Method)) && raw.Length > 0)
                throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "body" });
            if (context.Request.Path.Value?.StartsWith("/internal/", StringComparison.Ordinal) == true || context.Request.Path.Value == "/ready")
            {
                var rawTarget = context.Features.Get<IHttpRequestFeature>()?.RawTarget;
                if (string.IsNullOrEmpty(rawTarget)) rawTarget = context.Request.Path.ToString();
                var question = rawTarget.IndexOf('?');
                var path = question >= 0 ? rawTarget[..question] : rawTarget;
                var allowedSenders = context.Request.Path.Value == "/ready" ? ReadySenders : new HashSet<string>();
                var sender = ServiceHmac.Verify(settings.Keyring,
                    new(context.Request.Headers["X-Service-Key-Id"].ToString(), context.Request.Headers["X-Service-Timestamp"].ToString(), context.Request.Headers["X-Service-Signature"].ToString()),
                    context.Request.Method, path, context.Request.QueryString.Value ?? "", (contract?.QueryKeys ?? []).ToHashSet(StringComparer.Ordinal), raw,
                    clock.GetUtcNow().ToUnixTimeSeconds(), allowedSenders);
                context.Items["ServiceSender"] = sender;
            }
            else
            {
                if (!identity.Configured) throw new ServiceException("SERVICE_NOT_CONFIGURED");
                var subject = await identity.VerifyAsync(AppwriteIdentityVerifier.ExtractBearer(context.Request.Headers.Authorization), context.RequestAborted);
                context.Items[typeof(VerifiedSubject)] = subject;
                if (!settings.Admitted) throw new ServiceException("SERVICE_NOT_CONFIGURED");
            }
            // ASP.NET routes accept case and trailing-slash aliases; the existing router does not.
            if (contract is not null && !MatchesPath(contract.Path, context.Request.Path)) throw new ServiceException("NOT_FOUND");
            if (operationId is null)
            {
                var known = RouteCatalog.All.Any(o => o.Owner == settings.Service && o.Method == context.Request.Method && MatchesPath(o.Path, context.Request.Path));
                throw new ServiceException(known ? "SERVICE_NOT_CONFIGURED" : "NOT_FOUND");
            }
            if (!HttpMethods.IsGet(context.Request.Method) && !HttpMethods.IsHead(context.Request.Method))
            {
                try { context.Items[typeof(ParsedRequestBody)] = new ParsedRequestBody(raw, raw.Length == 0 ? null : CanonicalWire.ParseBody(raw)); }
                catch (JsonException) { throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "body" }); }
            }
            await next(context);
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested) { throw; }
        catch (Exception error)
        {
            var failure = error as ServiceException ?? new ServiceException("INTERNAL_ERROR");
            context.Response.StatusCode = failure.StatusCode;
            if (failure.RetryAfterSeconds is { } retry) context.Response.Headers.RetryAfter = retry.ToString(System.Globalization.CultureInfo.InvariantCulture);
            await context.Response.WriteAsJsonAsync(failure.Envelope(requestId), cancellationToken: context.RequestAborted);
        }
    }

    private static bool MatchesPath(string template, PathString path)
    {
        var expected = template.Split('/');
        var actual = path.ToString().Split('/');
        return expected.Length == actual.Length && expected.Zip(actual).All(p => p.First.StartsWith('{') || p.First == p.Second);
    }

    private static async Task<string> ReadBody(HttpRequest request, int limit, CancellationToken cancellationToken)
    {
        if (request.ContentLength > limit) throw new ServiceException("PAYLOAD_TOO_LARGE");
        request.EnableBuffering();
        using var output = new MemoryStream();
        var buffer = new byte[8192];
        int read;
        while ((read = await request.Body.ReadAsync(buffer, cancellationToken)) != 0)
        {
            if (output.Length + read > limit) throw new ServiceException("PAYLOAD_TOO_LARGE");
            output.Write(buffer, 0, read);
        }
        request.Body.Position = 0;
        try { return new UTF8Encoding(false, true).GetString(output.ToArray()); }
        catch (DecoderFallbackException) { throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "body" }); }
    }
}
