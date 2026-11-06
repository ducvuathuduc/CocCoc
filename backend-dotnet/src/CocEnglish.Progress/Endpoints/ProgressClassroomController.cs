using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;
using System.Globalization;
using System.Text.RegularExpressions;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressClassroomController(OwnerStore store, ProgressClassrooms classrooms) : ControllerBase
{
    /// <summary>Join an active classroom by its normalized code.</summary>
    [HttpPost("/v1/classrooms/join")]
    [ContractOperation("joinClassroom")]
    [ProducesResponseType<ClassroomMembershipResponse>(200)]
    public Task<IActionResult> Join(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["joinCode"], "joinCode");
        var code = ProgressInput.Text(body["joinCode"], "joinCode", 4, 16, "^[A-Za-z0-9-]+$");
        return ProgressMutation.ExecuteAsync(HttpContext, store, "joinClassroom", (tx, user, _, token) => classrooms.JoinAsync(tx, user, code, token));
    }

    /// <summary>Leave only the verified account's membership.</summary>
    [HttpDelete("/v1/classrooms/{classroomId}/membership")]
    [ContractOperation("leaveClassroom")]
    [ProducesResponseType<OperationReceiptResponse>(200)]
    public Task<IActionResult> Leave([FromRoute] string classroomId, CancellationToken ct)
    {
        ProgressInput.Empty(HttpContext);
        return ProgressMutation.ExecuteAsync(HttpContext, store, "leaveClassroom", async (tx, user, key, token) =>
        {
            await classrooms.LeaveAsync(tx, user, classroomId, token);
            return new OperationReceiptResponse(key, "completed", Response.Headers["X-Request-ID"].ToString());
        });
    }

    /// <summary>Read own yearly summary, freezing completed years on first generation.</summary>
    [HttpGet("/v1/me/year-review/{year}")]
    [ContractOperation("getYearReview")]
    [ProducesResponseType<YearReviewResponse>(200)]
    public Task<YearReviewResponse> Year([FromRoute] string year, CancellationToken ct)
    {
        if (!Regex.IsMatch(year, "^[0-9]{4}$", RegexOptions.CultureInvariant)) throw RequestQuery.Bad("year");
        return store.TransactAsync((tx, token) => classrooms.YearAsync(tx, ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId, int.Parse(year, CultureInfo.InvariantCulture), token), ct);
    }
}
