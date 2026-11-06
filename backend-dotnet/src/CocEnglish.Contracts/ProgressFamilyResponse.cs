namespace CocEnglish.Contracts;

/// <summary>Family membership; invitation code is projected only for the active manager.</summary>
public sealed record FamilyResponse(string GroupId, string OwnerUserId, string Plan, string Status, IReadOnlyList<FamilyMemberResponse> Members, string? InviteCode, long Revision);
/// <summary>Public member identity, role and original join timestamp.</summary>
public sealed record FamilyMemberResponse(string UserId, string Nickname, string Role, string JoinedAt);
