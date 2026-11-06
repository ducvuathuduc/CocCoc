using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressSocialController(OwnerStore store, ProgressSocial social) : ControllerBase
{
    /// <summary>Block an account and end existing pair relationships atomically.</summary>
    [HttpPost("/v1/blocks")]
    [ContractOperation("blockUser")]
    [ProducesResponseType<OperationReceiptResponse>(200)]
    public Task<IActionResult> Block(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["targetUserId"], "targetUserId");
        var target = ProgressInput.Text(body["targetUserId"], "targetUserId", 1, 36, "^[A-Za-z0-9][A-Za-z0-9_.-]*$");
        return SafetyMutation("blockUser", (tx, user, token) => social.BlockAsync(tx, user, target, token));
    }

    /// <summary>Remove only the caller's block without restoring follows or streaks.</summary>
    [HttpDelete("/v1/blocks/{userId}")]
    [ContractOperation("unblockUser")]
    [ProducesResponseType<OperationReceiptResponse>(200)]
    public Task<IActionResult> Unblock([FromRoute] string userId, CancellationToken ct)
    {
        ProgressInput.Empty(HttpContext);
        return SafetyMutation("unblockUser", (tx, user, token) => social.UnblockAsync(tx, user, userId, token));
    }

    /// <summary>Persist one moderation report per reporter, target and reason.</summary>
    [HttpPost("/v1/user-reports")]
    [ContractOperation("reportUser")]
    [ProducesResponseType<OperationReceiptResponse>(200)]
    public Task<IActionResult> Report(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["targetUserId", "reason", "note"], "targetUserId", "reason", "note");
        var target = ProgressInput.Text(body["targetUserId"], "targetUserId", 1, 36, "^[A-Za-z0-9][A-Za-z0-9_.-]*$");
        var reason = ProgressInput.Text(body["reason"], "reason", 0, int.MaxValue);
        if (reason is not ("SPAM" or "INAPPROPRIATE_NAME" or "INAPPROPRIATE_AVATAR" or "HARASSMENT" or "CHEATING" or "OTHER")) throw RequestQuery.Bad("reason");
        var note = body["note"] is null ? null : ProgressInput.Text(body["note"], "note", 0, 512);
        return SafetyMutation("reportUser", (tx, user, token) => social.ReportAsync(tx, user, target, reason, note, token));
    }

    private Task<IActionResult> SafetyMutation(string operation, Func<OwnerSession, string, CancellationToken, Task<string>> effect) =>
        ProgressMutation.ExecuteAsync(HttpContext, store, operation, async (tx, user, key, token) =>
        {
            await effect(tx, user, token);
            return new OperationReceiptResponse(key, "completed", Response.Headers["X-Request-ID"].ToString());
        });
    /// <summary>Read visible mutual friends with the existing scanned-candidate cursor.</summary>
    [HttpGet("/v1/friends")]
    [ContractOperation("listFriends")]
    [ProducesResponseType<FriendsPageResponse>(200)]
    public Task<FriendsPageResponse> Friends(CancellationToken ct)
    {
        var (offset, limit) = ProgressPaging.Parse(Request);
        return store.TransactAsync((tx, token) => social.FriendsAsync(tx, ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId, offset, limit, token), ct);
    }

    /// <summary>Read own activity and privacy-filtered followed-account activity.</summary>
    [HttpGet("/v1/activity")]
    [ContractOperation("listActivity")]
    [ProducesResponseType<ActivityPageResponse>(200)]
    public Task<ActivityPageResponse> Activity(CancellationToken ct)
    {
        var (offset, limit) = ProgressPaging.Parse(Request);
        return store.TransactAsync((tx, token) => social.ActivityAsync(tx, ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId, offset, limit, token), ct);
    }
    /// <summary>Read only the visible public projection of a target account.</summary>
    [HttpGet("/v1/profiles/{userId}")]
    [ContractOperation("getPublicProfile")]
    [ProducesResponseType<PublicProfileResponse>(200)]
    public Task<PublicProfileResponse> Profile([FromRoute] string userId, CancellationToken ct) =>
        store.TransactAsync((tx, token) => social.GetProfileAsync(tx, ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId, userId, token), ct);

    /// <summary>Follow a visible adult account using an idempotent operation receipt.</summary>
    [HttpPost("/v1/follows")]
    [ContractOperation("followUser")]
    [ProducesResponseType<OperationReceiptResponse>(200)]
    public Task<IActionResult> Follow(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["targetUserId"], "targetUserId");
        var target = ProgressInput.Text(body["targetUserId"], "targetUserId", 1, 36, "^[A-Za-z0-9][A-Za-z0-9_.-]*$");
        return Mutate("followUser", target, false);
    }

    /// <summary>Remove a follow silently even if the target no longer exists or is private.</summary>
    [HttpDelete("/v1/follows/{userId}")]
    [ContractOperation("unfollowUser")]
    [ProducesResponseType<OperationReceiptResponse>(200)]
    public Task<IActionResult> Unfollow([FromRoute] string userId, CancellationToken ct)
    {
        ProgressInput.Empty(HttpContext);
        return Mutate("unfollowUser", userId, true);
    }

    private Task<IActionResult> Mutate(string operation, string target, bool remove) =>
        ProgressMutation.ExecuteAsync(HttpContext, store, operation, async (tx, user, key, ct) =>
        {
            if (remove) await social.UnfollowAsync(tx, user, target, ct);
            else await social.FollowAsync(tx, user, target, ct);
            return new OperationReceiptResponse(key, "completed", Response.Headers["X-Request-ID"].ToString());
        });
}
