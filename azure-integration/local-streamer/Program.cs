using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Serilog;
using SatisfactoryLocalStreamer;

// Build configuration first to set up Serilog
var configuration = new ConfigurationBuilder()
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile($"appsettings.{Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production"}.json", optional: true, reloadOnChange: true)
    .AddEnvironmentVariables()
    .Build();

// Configure Serilog from configuration
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(configuration)
    .CreateLogger();

try
{
    Log.Information("=================================================================");
    Log.Information("Satisfactory Local Data Streamer starting...");
    Log.Information("Environment: {Environment}", Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production");
    Log.Information("=================================================================");

    var builder = Host.CreateApplicationBuilder(args);

    // Use Serilog for logging
    builder.Services.AddSerilog();

    // Add configuration
    builder.Configuration.Sources.Clear();
    builder.Configuration.AddConfiguration(configuration);

    // Configure HTTP client with timeout
    var httpTimeout = configuration.GetValue<int>("Streaming:HttpTimeoutSeconds", 30);
    builder.Services.AddHttpClient("SatisfactoryFRM", client =>
    {
        client.Timeout = TimeSpan.FromSeconds(httpTimeout);
    });

    // Register core services
    builder.Services.AddSingleton<SatisfactoryDataStreamer>();
    
    // Register background worker
    builder.Services.AddHostedService<DataStreamWorker>();

    // Enable Windows Service support (works in console mode too)
    builder.Services.AddWindowsService(options =>
    {
        options.ServiceName = "SatisfactoryDataStreamer";
    });

    var host = builder.Build();

    // Display startup configuration using static Serilog logger
    Log.Information("FRM URL: {Url}", configuration.GetValue<string>("Satisfactory:FrmUrl"));
    Log.Information("Server Name: {Server}", configuration.GetValue<string>("Satisfactory:ServerName"));
    Log.Information("Event Hub Namespace: {Namespace}", configuration.GetValue<string>("EventHub:Namespace"));
    Log.Information("Event Hub Name: {Name}", configuration.GetValue<string>("EventHub:Name"));
    Log.Information("Using Connection String: {UseConnStr}", configuration.GetValue<bool>("EventHub:UseConnectionString"));
    
    Log.Information("=================================================================");
    Log.Information("Press Ctrl+C to stop the service");
    Log.Information("=================================================================");

    await host.RunAsync();

    Log.Information("Satisfactory Local Data Streamer stopped successfully");
    return 0;
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
    return 1;
}
finally
{
    await Log.CloseAndFlushAsync();
}
