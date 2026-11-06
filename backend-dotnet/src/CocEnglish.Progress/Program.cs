using CocEnglish.Shared.Hosting;
using CocEnglish.Progress.Application;
using Microsoft.Extensions.Configuration;
using CocEnglish.Shared.Security;

namespace CocEnglish.Progress;

public partial class Program
{
    public static Task<int> Main(string[] args) => ServiceHost.RunAsync("progress", args, typeof(Program).Assembly,
        services => {
            services.AddSingleton(new ProgressCommercePolicy(false));
            services.AddScoped(sp => new ProgressFamily(new ProgressCodes(sp.GetRequiredService<IConfiguration>()["COC_PROGRESS_CODE_SECRET"])));
            services.AddScoped(sp => new ProgressReferrals(new ProgressCodes(sp.GetRequiredService<IConfiguration>()["COC_PROGRESS_CODE_SECRET"])));
            services.AddScoped<IProgressReads, ProgressReads>(); services.AddScoped<ProgressWrites>(); services.AddScoped<ProgressEconomy>(); services.AddScoped<ProgressShop>(); services.AddScoped<ProgressSocial>(); services.AddScoped<ProgressFriendStreaks>(); services.AddScoped<ProgressClassrooms>(); services.AddScoped<ProgressLeagueResults>(); services.AddScoped<ProgressLeagues>();
            services.AddScoped<ProgressSettlement>();
            services.AddSingleton<IRelayJitterSource, SystemRelayJitterSource>();
            services.AddScoped<ProgressJobRunner>(); services.AddScoped<IProgressScheduledTick, ProgressScheduledTick>(); services.AddHostedService<ProgressWorkerService>();
            services.AddHttpClient("progress-relay").ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
            services.AddScoped<IProgressRelayTransport>(sp => {
                var config = sp.GetRequiredService<IConfiguration>(); var targets = new Dictionary<string, Uri>(StringComparer.Ordinal);
                foreach (var target in new[] { "learning", "ai" }) if (Uri.TryCreate(config["COC_" + target.ToUpperInvariant() + "_URL"], UriKind.Absolute, out var endpoint)) targets[target] = endpoint;
                var key = sp.GetRequiredService<RuntimeSettings>().SigningKey("progress");
                return new HttpProgressRelay(sp.GetRequiredService<IHttpClientFactory>().CreateClient("progress-relay"), targets, key, sp.GetRequiredService<TimeProvider>());
            });
            services.AddHttpClient("learning-watermark").ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
            services.AddScoped<ILearningWatermark>(sp => {
                Uri.TryCreate(sp.GetRequiredService<IConfiguration>()["COC_LEARNING_URL"], UriKind.Absolute, out var endpoint);
                var key = sp.GetRequiredService<RuntimeSettings>().SigningKey("progress");
                return new HttpLearningWatermark(sp.GetRequiredService<IHttpClientFactory>().CreateClient("learning-watermark"), endpoint, key, sp.GetRequiredService<TimeProvider>());
            });
        });
}
