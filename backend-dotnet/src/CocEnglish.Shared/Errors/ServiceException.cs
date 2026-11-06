using System.Text.Json.Nodes;
using CocEnglish.Contracts;

namespace CocEnglish.Shared.Errors;

public sealed class ServiceException : Exception
{
    public ServiceException(string code, JsonObject? details = null, string? message = null, int? retryAfterSeconds = null)
        : base(message ?? ErrorCatalog.Messages.GetValueOrDefault(code) ?? code)
    {
        if (!ErrorCatalog.StatusCodes.ContainsKey(code)) throw new ArgumentOutOfRangeException(nameof(code));
        Code = code;
        Details = details ?? [];
        RetryAfterSeconds = retryAfterSeconds;
    }

    public string Code { get; }
    public JsonObject Details { get; }
    public int? RetryAfterSeconds { get; }
    public int StatusCode => ErrorCatalog.StatusCodes[Code];
    public bool Retryable => StatusCode is 429 or 503 or 504 && Code is not ("NATIVE_LIVE_DISABLED" or "SERVICE_NOT_CONFIGURED");

    public JsonObject Envelope(string requestId) => new()
    {
        ["error"] = new JsonObject
        {
            ["code"] = Code, ["message"] = Message[..Math.Min(Message.Length, 256)],
            ["requestId"] = requestId, ["details"] = Details.DeepClone(), ["retryable"] = Retryable
        }
    };
}
