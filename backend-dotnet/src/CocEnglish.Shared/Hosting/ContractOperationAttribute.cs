namespace CocEnglish.Shared.Hosting;

[AttributeUsage(AttributeTargets.Method)]
public sealed class ContractOperationAttribute(string operationId) : Attribute
{
    public string OperationId { get; } = operationId;
}
