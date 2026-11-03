using System.Reflection;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using System.Text.Json.Serialization;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace CocEnglish.Shared.Hosting;

public static class ServiceHost
{
    public static async Task<int> RunAsync(string service, string[] args, Assembly applicationAssembly, Action<IServiceCollection>? registerModule = null)
    {
        if (args is ["--probe"])
        {
            using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
            return await ServiceProbe.CheckAsync(client, service);
        }
        await Build(service, args, applicationAssembly, registerModule).RunAsync();
        return 0;
    }

    public static WebApplication Build(string service, string[] args, Assembly applicationAssembly, Action<IServiceCollection>? registerModule = null)
    {
        if (service is not ("learning" or "progress" or "ai")) throw new ArgumentOutOfRangeException(nameof(service));
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions { Args = args, ApplicationName = applicationAssembly.GetName().Name });
        builder.Logging.ClearProviders();
        builder.Logging.AddJsonConsole();
        builder.Services.AddSingleton<TimeProvider>(TimeProvider.System);
        builder.Services.AddSingleton(sp => RuntimeSettings.From(sp.GetRequiredService<IConfiguration>(), service));
        builder.Services.AddHttpClient("appwrite", client => client.Timeout = TimeSpan.FromSeconds(30))
            .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
        builder.Services.AddScoped<IIdentityVerifier>(sp =>
        {
            var settings = sp.GetRequiredService<RuntimeSettings>();
            return new AppwriteIdentityVerifier(sp.GetRequiredService<IHttpClientFactory>().CreateClient("appwrite"), settings.Endpoint,
                settings.ProjectId, timeProvider: sp.GetRequiredService<TimeProvider>());
        });
        builder.Services.AddScoped<IRowDriver>(sp => new AppwriteRowDriver(
            sp.GetRequiredService<IHttpClientFactory>().CreateClient("appwrite"),
            sp.GetRequiredService<RuntimeSettings>().Storage ?? throw new ServiceException("SERVICE_NOT_CONFIGURED"), service));
        builder.Services.AddScoped(sp => new OwnerStore(sp.GetRequiredService<IRowDriver>(), sp.GetRequiredService<TimeProvider>()));
        registerModule?.Invoke(builder.Services);
        builder.Services.AddControllers().AddApplicationPart(typeof(HealthController).Assembly).AddApplicationPart(applicationAssembly)
            .AddJsonOptions(options =>
            {
                options.JsonSerializerOptions.UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow;
                options.JsonSerializerOptions.Converters.Add(new UtcMillisecondsConverter());
            });
        builder.Services.Configure<ApiBehaviorOptions>(options => options.InvalidModelStateResponseFactory = context =>
            new BadRequestObjectResult(new ServiceException("VALIDATION_ERROR").Envelope(context.HttpContext.Response.Headers["X-Request-ID"].ToString())));
        var app = builder.Build();
        app.UseRouting();
        app.UseMiddleware<ApiBoundaryMiddleware>();
        app.MapControllers();
        app.MapFallback((HttpContext _) => Task.FromException(new ServiceException("NOT_FOUND")));
        return app;
    }
}
