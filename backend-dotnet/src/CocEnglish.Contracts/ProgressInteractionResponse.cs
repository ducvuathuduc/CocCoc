namespace CocEnglish.Contracts;

/// <summary>Stored social interaction and the sender's current gem balance.</summary>
public sealed record InteractionResponse(string OperationId, string ToUserId, string Kind, string ContextId, string Day, long GemsCost, long Gems);
