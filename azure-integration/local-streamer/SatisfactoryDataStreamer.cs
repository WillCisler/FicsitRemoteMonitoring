using System.Text;
using System.Text.Json;
using Azure.Identity;
using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Polly;
using Polly.Retry;

namespace SatisfactoryLocalStreamer;

/// <summary>
/// Core data streaming logic adapted from Azure Function
/// Collects data from Satisfactory FRM API endpoints and streams to Azure Event Hub
/// </summary>
public class SatisfactoryDataStreamer : IDisposable
{
    private readonly HttpClient _httpClient;
    private readonly EventHubProducerClient _eventHubClient;
    private readonly ILogger<SatisfactoryDataStreamer> _logger;
    private readonly IConfiguration _configuration;
    private readonly ResiliencePipeline<HttpResponseMessage> _retryPipeline;
    private readonly SemaphoreSlim _semaphore;
    private readonly string _frmBaseUrl;
    private readonly string _serverName;
    private readonly string[] _highFrequencyEndpoints;
    private readonly string[] _mediumFrequencyEndpoints;
    private readonly string[] _standardFrequencyEndpoints;

    public SatisfactoryDataStreamer(
        IHttpClientFactory httpClientFactory,
        ILogger<SatisfactoryDataStreamer> logger,
        IConfiguration configuration)
    {
        _httpClient = httpClientFactory.CreateClient("SatisfactoryFRM");
        _logger = logger;
        _configuration = configuration;

        // Load configuration
        _frmBaseUrl = configuration.GetValue<string>("Satisfactory:FrmUrl") ?? "http://localhost:8080";
        _serverName = configuration.GetValue<string>("Satisfactory:ServerName") ?? "local-server";
        var maxConcurrent = configuration.GetValue<int>("Streaming:MaxConcurrentRequests", 5);

        _semaphore = new SemaphoreSlim(maxConcurrent, maxConcurrent);

        // Load endpoint configurations from appsettings
        _highFrequencyEndpoints = configuration.GetSection("Endpoints:HighFrequency").Get<string[]>() ?? Array.Empty<string>();
        _mediumFrequencyEndpoints = configuration.GetSection("Endpoints:MediumFrequency").Get<string[]>() ?? Array.Empty<string>();
        _standardFrequencyEndpoints = configuration.GetSection("Endpoints:StandardFrequency").Get<string[]>() ?? Array.Empty<string>();

        // Configure retry policy with exponential backoff using Polly v8
        _retryPipeline = new ResiliencePipelineBuilder<HttpResponseMessage>()
            .AddRetry(new RetryStrategyOptions<HttpResponseMessage>
            {
                ShouldHandle = new PredicateBuilder<HttpResponseMessage>()
                    .Handle<HttpRequestException>()
                    .Handle<TaskCanceledException>()
                    .HandleResult(r => !r.IsSuccessStatusCode),
                MaxRetryAttempts = 3,
                Delay = TimeSpan.FromSeconds(1),
                BackoffType = DelayBackoffType.Exponential,
                OnRetry = args =>
                {
                    _logger.LogWarning(
                        "Retry {AttemptNumber} after {Delay}s for endpoint (Status: {Status})",
                        args.AttemptNumber,
                        args.RetryDelay.TotalSeconds,
                        args.Outcome.Result?.StatusCode);
                    return ValueTask.CompletedTask;
                }
            })
            .Build();

        // Initialize Event Hub client
        _eventHubClient = CreateEventHubClient();

        _logger.LogInformation("Data Streamer initialized");
        _logger.LogInformation("FRM Base URL: {Url}", _frmBaseUrl);
        _logger.LogInformation("Server Name: {Server}", _serverName);
        _logger.LogInformation("Max Concurrent Requests: {Max}", maxConcurrent);
        _logger.LogInformation("High Freq Endpoints: {Count}", _highFrequencyEndpoints.Length);
        _logger.LogInformation("Medium Freq Endpoints: {Count}", _mediumFrequencyEndpoints.Length);
        _logger.LogInformation("Standard Freq Endpoints: {Count}", _standardFrequencyEndpoints.Length);
    }

    private EventHubProducerClient CreateEventHubClient()
    {
        var useConnectionString = _configuration.GetValue<bool>("EventHub:UseConnectionString", false);
        var eventHubNamespace = _configuration.GetValue<string>("EventHub:Namespace");
        var eventHubName = _configuration.GetValue<string>("EventHub:Name");

        if (string.IsNullOrEmpty(eventHubNamespace) || string.IsNullOrEmpty(eventHubName))
        {
            throw new InvalidOperationException("EventHub:Namespace and EventHub:Name must be configured in appsettings.json");
        }

        if (useConnectionString)
        {
            var connectionString = _configuration.GetValue<string>("EventHub:ConnectionString");
            if (string.IsNullOrEmpty(connectionString))
            {
                throw new InvalidOperationException("EventHub:ConnectionString must be configured when UseConnectionString is true");
            }
            _logger.LogInformation("Using Event Hub connection string");
            return new EventHubProducerClient(connectionString, eventHubName);
        }
        else
        {
            // Use DefaultAzureCredential (Azure CLI, Managed Identity, etc.)
            _logger.LogInformation("Using DefaultAzureCredential for Event Hub authentication");
            _logger.LogInformation("Make sure you've run 'az login' on this machine");
            var credential = new DefaultAzureCredential();
            var fullyQualifiedNamespace = eventHubNamespace.Contains("://") 
                ? eventHubNamespace 
                : $"{eventHubNamespace}";
            return new EventHubProducerClient(fullyQualifiedNamespace, eventHubName, credential);
        }
    }

    public async Task CollectHighFrequencyData(CancellationToken cancellationToken)
    {
        await RunDataCollection(_highFrequencyEndpoints, "HighFreq", cancellationToken);
    }

    public async Task CollectMediumFrequencyData(CancellationToken cancellationToken)
    {
        await RunDataCollection(_mediumFrequencyEndpoints, "MediumFreq", cancellationToken);
    }

    public async Task CollectStandardFrequencyData(CancellationToken cancellationToken)
    {
        await RunDataCollection(_standardFrequencyEndpoints, "StandardFreq", cancellationToken);
    }

    private async Task RunDataCollection(string[] endpoints, string frequencyType, CancellationToken cancellationToken)
    {
        if (endpoints.Length == 0)
        {
            _logger.LogDebug("{FrequencyType}: No endpoints configured", frequencyType);
            return;
        }

        var startTime = DateTime.UtcNow;
        _logger.LogDebug("{FrequencyType} data collection started", frequencyType);

        // Process endpoints concurrently with controlled parallelism
        var tasks = new List<Task>();

        foreach (var endpoint in endpoints)
        {
            tasks.Add(ProcessEndpointWithSemaphore(endpoint, cancellationToken));
        }

        await Task.WhenAll(tasks);

        var duration = DateTime.UtcNow - startTime;
        _logger.LogDebug("{FrequencyType} data collection completed in {Duration}ms", frequencyType, duration.TotalMilliseconds);
    }

    private async Task ProcessEndpointWithSemaphore(string endpoint, CancellationToken cancellationToken)
    {
        await _semaphore.WaitAsync(cancellationToken);
        try
        {
            await ProcessEndpoint(endpoint, cancellationToken);
        }
        finally
        {
            _semaphore.Release();
        }
    }

    private async Task ProcessEndpoint(string endpoint, CancellationToken cancellationToken)
    {
        try
        {
            // Call the FRM API endpoint with retry policy
            var url = $"{_frmBaseUrl}/{endpoint}";

            var response = await _retryPipeline.ExecuteAsync(async (ctx) =>
            {
                _logger.LogTrace("Calling FRM endpoint: {Url}", url);
                var httpResponse = await _httpClient.GetAsync(url, ctx);

                if (!httpResponse.IsSuccessStatusCode)
                {
                    _logger.LogWarning("FRM endpoint {Endpoint} returned {StatusCode}", endpoint, httpResponse.StatusCode);
                }

                return httpResponse;
            }, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("Failed to fetch data from {Endpoint} after retries. Status: {Status}", endpoint, response.StatusCode);
                return;
            }

            var jsonData = await response.Content.ReadAsStringAsync(cancellationToken);

            // Validate JSON data before processing
            if (string.IsNullOrWhiteSpace(jsonData))
            {
                _logger.LogWarning("Empty response from endpoint {Endpoint}", endpoint);
                return;
            }

            JsonElement parsedData;
            try
            {
                parsedData = JsonSerializer.Deserialize<JsonElement>(jsonData);
            }
            catch (JsonException ex)
            {
                _logger.LogError(ex, "Invalid JSON response from endpoint {Endpoint}", endpoint);
                return;
            }

            // Create event data with metadata
            var eventData = new
            {
                timestamp = DateTime.UtcNow,
                endpoint = endpoint,
                server = _serverName,
                data = parsedData
            };

            await SendToEventHub(eventData, endpoint, cancellationToken);
            _logger.LogTrace("Successfully processed endpoint {Endpoint}", endpoint);
        }
        catch (OperationCanceledException)
        {
            _logger.LogDebug("Endpoint {Endpoint} processing cancelled", endpoint);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing endpoint {Endpoint}: {Message}", endpoint, ex.Message);
        }
    }

    private async Task SendToEventHub(object eventData, string endpoint, CancellationToken cancellationToken)
    {
        try
        {
            var eventDataJson = JsonSerializer.Serialize(eventData, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            });
            var eventDataBytes = Encoding.UTF8.GetBytes(eventDataJson);

            // Send to Event Hub with proper partitioning and metadata
            using var eventBatch = await _eventHubClient.CreateBatchAsync(cancellationToken);
            var hubEventData = new EventData(eventDataBytes);

            // Add custom properties for routing/filtering in downstream systems
            hubEventData.Properties.Add("endpoint", endpoint);
            hubEventData.Properties.Add("server", _serverName);
            hubEventData.Properties.Add("timestamp", DateTime.UtcNow.ToString("O"));
            hubEventData.Properties.Add("source", "satisfactory-frm-local");
            hubEventData.Properties.Add("partitionKey", endpoint);

            if (!eventBatch.TryAdd(hubEventData))
            {
                _logger.LogWarning("Event too large for batch for endpoint {Endpoint}", endpoint);
                return;
            }

            await _eventHubClient.SendAsync(eventBatch, cancellationToken);
            _logger.LogTrace("Successfully sent {Endpoint} data to Event Hub", endpoint);
        }
        catch (OperationCanceledException)
        {
            _logger.LogDebug("Event Hub send for {Endpoint} cancelled", endpoint);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send {Endpoint} data to Event Hub: {Message}", endpoint, ex.Message);
            throw;
        }
    }

    public void Dispose()
    {
        _logger.LogInformation("Disposing Data Streamer resources");
        _eventHubClient?.DisposeAsync().AsTask().Wait();
        _semaphore?.Dispose();
        _httpClient?.Dispose();
    }
}
