using System.Text.Json.Nodes;
using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressWriteController(OwnerStore store, ProgressWrites writes) : ControllerBase
{
    private const string Token = "^[A-Za-z0-9][A-Za-z0-9_.-]*$";

    /// <summary>Durably request account deletion and enqueue the existing owner-purge event.</summary>
    [HttpPost("/v1/me/deletion")]
    [ContractOperation("deleteAccount")]
    [ProducesResponseType<DeletionReceiptResponse>(202)]
    public Task<IActionResult> DeleteAccount(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["confirmation"], "confirmation");
        if (ProgressInput.Text(body["confirmation"], "confirmation", 0, int.MaxValue) != "DELETE") throw RequestQuery.Bad("confirmation");
        return ProgressMutation.ExecuteAsync(HttpContext, store, "deleteAccount", (tx, user, _, token) => writes.RequestDeletionAsync(tx, user, token), 202);
    }

    /// <summary>Update the private profile with revision checks and deferred timezone changes.</summary>
    [HttpPatch("/v1/me")]
    [ContractOperation("updateMe")]
    [ProducesResponseType<ProfileResponse>(200)]
    public Task<IActionResult> Profile(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["nickname", "avatarId", "publicOptIn", "dailyGoal", "learningZone", "expectedRevision"], "expectedRevision");
        var revision = ProgressInput.Integer(body["expectedRevision"], "expectedRevision", 0, int.MaxValue);
        var nickname = body.ContainsKey("nickname") ? ProgressInput.Text(body["nickname"], "nickname", 0, 40) : null;
        var hasAvatar = body.ContainsKey("avatarId");
        var avatar = hasAvatar && body["avatarId"] is not null ? ProgressInput.Text(body["avatarId"], "avatarId", 1, 36, Token) : null;
        bool? optIn = body.ContainsKey("publicOptIn") ? ProgressInput.Boolean(body["publicOptIn"], "publicOptIn") : null;
        long? goal = body.ContainsKey("dailyGoal") ? ProgressInput.Integer(body["dailyGoal"], "dailyGoal", 5, 20) : null;
        if (goal is not null and not (5 or 10 or 15 or 20)) throw RequestQuery.Bad("dailyGoal");
        var zone = body.ContainsKey("learningZone") ? ProgressInput.Text(body["learningZone"], "learningZone", 0, 64) : null;
        var patch = new ProfilePatchRequest(revision, nickname, avatar, optIn, goal, zone) { HasAvatarId = hasAvatar };
        return ProgressMutation.ExecuteAsync(HttpContext, store, "updateMe", (tx, user, _, token) => writes.UpdateProfileAsync(tx, user, patch, token));
    }

    /// <summary>Initialize the verified account and grant its initial wallet credit once.</summary>
    [HttpPost("/v1/me/initialize")]
    [ContractOperation("initializeProfile")]
    [ProducesResponseType<ProfileResponse>(200)]
    public Task<IActionResult> Initialize(CancellationToken ct)
    {
        ProgressInput.Empty(HttpContext);
        return ProgressMutation.ExecuteAsync(HttpContext, store, "initializeProfile", (tx, user, _, token) => writes.InitializeProfileAsync(tx, user, token));
    }

    /// <summary>Update only supplied preferences using the expected revision and an idempotency receipt.</summary>
    [HttpPatch("/v1/me/preferences")]
    [ContractOperation("updatePreferences")]
    [ProducesResponseType<PreferencesResponse>(200)]
    public Task<IActionResult> Preferences(CancellationToken ct)
    {
        string[] booleans = ["smartScheduling", "soundEffects", "haptics", "motivationalMessages", "listeningExercises", "speakingExercises", "friendStreakInvites"];
        var body = ProgressInput.Object(HttpContext, ["notificationsOff", "reminderMinute", "expectedRevision", .. booleans], "expectedRevision");
        var revision = ProgressInput.Integer(body["expectedRevision"], "expectedRevision", 0, int.MaxValue);
        IReadOnlyList<string>? notifications = null;
        if (body.ContainsKey("notificationsOff"))
        {
            if (body["notificationsOff"] is not JsonArray array || array.Count > 32) throw RequestQuery.Bad("notificationsOff");
            notifications = array.Select(v => ProgressInput.Text(v, "notificationsOff", 1, 64, Token)).ToArray();
        }
        long? minute = body.ContainsKey("reminderMinute") ? ProgressInput.Integer(body["reminderMinute"], "reminderMinute", 0, 1439) : null;
        foreach (var field in booleans) if (body.ContainsKey(field)) ProgressInput.Boolean(body[field], field);
        bool? Flag(string field) => body.ContainsKey(field) ? body[field]!.GetValue<bool>() : null;
        var patch = new PreferencesPatchRequest(revision, notifications, Flag("smartScheduling"), minute, Flag("soundEffects"), Flag("haptics"),
            Flag("motivationalMessages"), Flag("listeningExercises"), Flag("speakingExercises"), Flag("friendStreakInvites"));
        return ProgressMutation.ExecuteAsync(HttpContext, store, "updatePreferences", (tx, user, _, token) => writes.UpdatePreferencesAsync(tx, user, patch, token));
    }

    /// <summary>Store feedback from the verified account exactly once per operation key.</summary>
    [HttpPost("/v1/feedback")]
    [ContractOperation("sendFeedback")]
    [ProducesResponseType<OperationReceiptResponse>(200)]
    public Task<IActionResult> Feedback(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["topic", "message", "appVersion", "platform"], "topic", "message", "appVersion", "platform");
        var topic = ProgressInput.Text(body["topic"], "topic", 1, 64, Token);
        var message = ProgressInput.Text(body["message"], "message", 1, 2000);
        var version = ProgressInput.Text(body["appVersion"], "appVersion", 1, 32);
        var platform = ProgressInput.Text(body["platform"], "platform", 1, int.MaxValue);
        if (platform is not ("ANDROID" or "IOS" or "WEB")) throw RequestQuery.Bad("platform");
        var request = new FeedbackRequest(topic, message, version, platform);
        return ProgressMutation.ExecuteAsync(HttpContext, store, "sendFeedback", async (tx, user, key, token) =>
        {
            await writes.SendFeedbackAsync(tx, user, request, key, token);
            return new OperationReceiptResponse(key, "completed", Response.Headers["X-Request-ID"].ToString());
        });
    }
}
