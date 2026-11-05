namespace CocEnglish.Shared.Hosting;

[AttributeUsage(AttributeTargets.Method)]
public sealed class ServiceSendersAttribute(params string[] senders) : Attribute
{
    public IReadOnlySet<string> Senders { get; } = senders.ToHashSet(StringComparer.Ordinal);
}
