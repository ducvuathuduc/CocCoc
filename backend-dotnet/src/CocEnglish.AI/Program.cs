using CocEnglish.Shared.Hosting;
using Microsoft.Extensions.DependencyInjection;

namespace CocEnglish.AI;

public partial class Program
{
    public static Task<int> Main(string[] args) => ServiceHost.RunAsync("ai", args, typeof(Program).Assembly, services =>
    {
        services.AddScoped<AiConversationService>();
        services.AddScoped<IAiVoiceService, AiVoiceService>();
        services.AddHttpClient("ai-speech", client => client.Timeout = Timeout.InfiniteTimeSpan)
            .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
        services.AddScoped<IAiSpeechEngine>(sp => new AiSpeechEngine(
            sp.GetRequiredService<IHttpClientFactory>().CreateClient("ai-speech"),
            sp.GetRequiredService<CocEnglish.Shared.Persistence.OwnerStore>(),
            sp.GetRequiredService<TimeProvider>(),
            sp.GetRequiredService<Microsoft.Extensions.Configuration.IConfiguration>()));
        services.AddHttpClient("ai-relay").ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
        services.AddScoped<IAiRelayTransport>(sp =>
        {
            var config = sp.GetRequiredService<Microsoft.Extensions.Configuration.IConfiguration>();
            Uri.TryCreate(config["COC_PROGRESS_URL"], UriKind.Absolute, out var progressUrl);
            var key = sp.GetRequiredService<RuntimeSettings>().SigningKey("ai");
            return new HttpAiRelay(sp.GetRequiredService<IHttpClientFactory>().CreateClient("ai-relay"), progressUrl, key,
                sp.GetRequiredService<TimeProvider>());
        });
        services.AddScoped<AiOutboxJobRunner>();
        services.AddScoped<IAiScheduledTick, AiScheduledTick>();
        services.AddHostedService<AiWorkerService>();
    });
}
