namespace CocEnglish.Contracts;

/// <summary>Revision-checked profile changes; avatar presence distinguishes clearing from omission.</summary>
public sealed record ProfilePatchRequest(long ExpectedRevision, string? Nickname = null, string? AvatarId = null,
    bool? PublicOptIn = null, long? DailyGoal = null, string? LearningZone = null)
{
    [System.Text.Json.Serialization.JsonIgnore]
    public bool HasAvatarId { get; init; }
}

/// <summary>Revision-checked partial update of private account preferences.</summary>
public sealed record PreferencesPatchRequest(long ExpectedRevision, IReadOnlyList<string>? NotificationsOff = null,
    bool? SmartScheduling = null, long? ReminderMinute = null, bool? SoundEffects = null, bool? Haptics = null,
    bool? MotivationalMessages = null, bool? ListeningExercises = null, bool? SpeakingExercises = null, bool? FriendStreakInvites = null);

/// <summary>Feedback submitted by the verified account.</summary>
public sealed record FeedbackRequest(string Topic, string Message, string AppVersion, string Platform);

/// <summary>Receipt-backed completion of a client operation.</summary>
public sealed record OperationReceiptResponse(string OperationId, string Status, string RequestId);
