using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.Configuration;

namespace CocEnglish.Learning;

public partial class Program
{
    public static Task<int> Main(string[] args) => ServiceHost.RunAsync("learning", args, typeof(Program).Assembly, services => {
        services.AddScoped(sp => new LearningStorageFiles(sp.GetRequiredService<IHttpClientFactory>().CreateClient("appwrite"),
            sp.GetRequiredService<RuntimeSettings>().Storage ?? throw new ServiceException("SERVICE_NOT_CONFIGURED")));
        services.AddScoped(sp => new LearningContentRepository(sp.GetRequiredService<IRowDriver>(), sp.GetRequiredService<LearningStorageFiles>(),
            LearningIntegrity.ParseKeyring(sp.GetRequiredService<IConfiguration>()["COC_CONTENT_PUBLIC_KEYS"])));
        services.AddScoped<ILearningContentReader>(sp => sp.GetRequiredService<LearningContentRepository>());
        services.AddHttpClient("learning-relay").ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
        services.AddScoped<ILearningRelayTransport>(sp => {
            var config = sp.GetRequiredService<IConfiguration>();
            Uri.TryCreate(config["COC_PROGRESS_URL"], UriKind.Absolute, out var progressUrl);
            var key = sp.GetRequiredService<RuntimeSettings>().SigningKey("learning");
            return new HttpLearningRelay(sp.GetRequiredService<IHttpClientFactory>().CreateClient("learning-relay"), progressUrl, key,
                sp.GetRequiredService<TimeProvider>());
        });
        services.AddScoped<LearningOutboxJobRunner>();
        services.AddScoped<ILearningScheduledTick, LearningScheduledTick>();
        services.AddScoped<ILearningOutboxWatermarkService, LearningOutboxWatermarkService>();
        services.AddScoped<ILearningStudyReadService, LearningStudyReadService>();
        services.AddScoped<ILearningWordsReadService, LearningWordsReadService>();
        services.AddHostedService<LearningWorkerService>();
    });
}
