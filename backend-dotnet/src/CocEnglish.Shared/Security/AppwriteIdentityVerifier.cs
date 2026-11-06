using System.Net;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;

namespace CocEnglish.Shared.Security;

public sealed record VerifiedSubject(string UserId);

public interface IIdentityVerifier
{
    bool Configured { get; }
    Task<VerifiedSubject> VerifyAsync(string jwt, CancellationToken cancellationToken);
}

public sealed class AppwriteIdentityVerifier(HttpClient client, Uri? endpoint, string? projectId, TimeSpan? deadline = null, TimeProvider? timeProvider = null) : IIdentityVerifier
{
    public bool Configured => endpoint is { Scheme: "https", UserInfo.Length: 0, Query.Length: 0, Fragment.Length: 0 } && !string.IsNullOrWhiteSpace(projectId);

    public async Task<VerifiedSubject> VerifyAsync(string jwt, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!Configured) throw new ServiceException("SERVICE_NOT_CONFIGURED");
        if (jwt.Length is 0 or > 8192) throw new ServiceException("AUTH_REQUIRED");
        var clock = timeProvider ?? TimeProvider.System;
        for (var attempt = 0; attempt < 2; attempt++)
        {
            try
            {
                using var timeout = new CancellationTokenSource(deadline ?? TimeSpan.FromSeconds(2), clock);
                using var linked = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, timeout.Token);
                using var request = new HttpRequestMessage(HttpMethod.Get, endpoint!.AbsoluteUri.TrimEnd('/') + "/account");
                request.Headers.Add("X-Appwrite-Project", projectId);
                request.Headers.Add("X-Appwrite-JWT", jwt);
                using var response = await client.SendAsync(request, linked.Token);
                var body = await response.Content.ReadAsStringAsync(linked.Token);
                if (!response.IsSuccessStatusCode)
                {
                    if (response.StatusCode is HttpStatusCode.RequestTimeout or HttpStatusCode.TooManyRequests || (int)response.StatusCode >= 500)
                        throw new ServiceException("AUTH_UNAVAILABLE");
                    string? type = null;
                    try { type = JsonNode.Parse(body)?["type"]?.GetValue<string>(); }
                    catch (JsonException) { /* Status still determines an invalid session. */ }
                    throw new ServiceException(type == "user_blocked" ? "ACCOUNT_BLOCKED" : "AUTH_EXPIRED");
                }
                var id = JsonNode.Parse(body)?["$id"]?.GetValue<string>();
                if (id is null || !Regex.IsMatch(id, "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$", RegexOptions.CultureInvariant))
                    throw new ServiceException("AUTH_UNAVAILABLE");
                return new(id);
            }
            catch (Exception e) when (e is HttpRequestException or JsonException or InvalidOperationException ||
                                      e is OperationCanceledException && !cancellationToken.IsCancellationRequested ||
                                      e is ServiceException { Code: "AUTH_UNAVAILABLE" })
            {
                if (attempt == 1) throw new ServiceException("AUTH_UNAVAILABLE");
            }
            await Task.Delay(TimeSpan.FromMilliseconds(100), clock, cancellationToken);
        }
        throw new ServiceException("AUTH_UNAVAILABLE");
    }

    public static string ExtractBearer(string? authorization)
    {
        if (authorization is null) throw new ServiceException("AUTH_REQUIRED");
        var match = Regex.Match(authorization.Trim(), "^Bearer ([A-Za-z0-9._~+/=-]{1,8192})$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
        return match.Success ? match.Groups[1].Value : throw new ServiceException("AUTH_REQUIRED");
    }
}
