namespace CocEnglish.Progress.Application;

// Only explicitly composed local/test hosts may enable simulated commerce.
// Hosted composition always registers false; no environment flag enables billing.
public sealed record ProgressCommercePolicy(bool AllowSimulation);
