using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Azure.Identity;
using Polly;
using Polly.Extensions.Http;

namespace SatisfactoryDataStreamer
{
    public class SatisfactoryDataStreamer
    {
        private readonly HttpClient _httpClient;
        private readonly EventHubProducerClient _eventHubClient;
        private readonly ILogger<SatisfactoryDataStreamer> _logger;
        private readonly IAsyncPolicy<HttpResponseMessage> _retryPolicy;
        
        // FRM API endpoints we want to monitor
        private readonly string[] _monitoredEndpoints = {
            "getPower",           // Power grid status
            "getFactory",         // All factory buildings
            "getPlayer",          // Player status and location
            "getExtractor",       // Resource extraction rates
            "getGenerators",      // Power generation
            "getVehicles",        // Train/truck/drone status
            "getSessionInfo"      // Session metadata
        };

        public SatisfactoryDataStreamer(HttpClient httpClient, ILogger<SatisfactoryDataStreamer> logger)
        {
            _httpClient = httpClient;
            _logger = logger;
            
            // Configure retry policy with exponential backoff
            _retryPolicy = Policy
                .HandleResult<HttpResponseMessage>(r => !r.IsSuccessStatusCode)
                .Or<HttpRequestException>()
                .Or<TaskCanceledException>()
                .WaitAndRetryAsync(
                    retryCount: 3,
                    sleepDurationProvider: retryAttempt => TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)),
                    onRetry: (outcome, timespan, retryCount, context) =>
                    {
                        _logger.LogWarning($"Retry {retryCount} for {context.OperationKey} after {timespan}s");
                    });
            
            // Use managed identity for Event Hubs connection - follows Azure security best practices
            var credential = new DefaultAzureCredential();
            var eventHubNamespace = Environment.GetEnvironmentVariable("EVENT_HUB_NAMESPACE");
            var eventHubName = Environment.GetEnvironmentVariable("EVENT_HUB_NAME");
            
            if (string.IsNullOrEmpty(eventHubNamespace) || string.IsNullOrEmpty(eventHubName))
            {
                throw new InvalidOperationException("EVENT_HUB_NAMESPACE and EVENT_HUB_NAME must be configured");
            }
            
            _eventHubClient = new EventHubProducerClient(eventHubNamespace, eventHubName, credential);
        }

        // Timer-triggered function that runs every 30 seconds
        [Function("SatisfactoryDataStreamer")]
        public async Task Run([TimerTrigger("*/30 * * * * *")] TimerInfo myTimer)
        {
            var startTime = DateTime.UtcNow;
            _logger.LogInformation($"Satisfactory data collection started at: {startTime}");

            var frmBaseUrl = Environment.GetEnvironmentVariable("SATISFACTORY_FRM_URL") ?? "http://localhost:8080";
            var serverName = Environment.GetEnvironmentVariable("SATISFACTORY_SERVER_NAME") ?? "default";
            
            // Process endpoints concurrently with controlled parallelism
            var semaphore = new SemaphoreSlim(5, 5); // Limit to 5 concurrent requests
            var tasks = new List<Task>();

            foreach (var endpoint in _monitoredEndpoints)
            {
                tasks.Add(ProcessEndpointWithSemaphore(semaphore, frmBaseUrl, endpoint, serverName));
            }

            await Task.WhenAll(tasks);
            
            var duration = DateTime.UtcNow - startTime;
            _logger.LogInformation($"Satisfactory data collection completed in {duration.TotalMilliseconds}ms");
        }

        private async Task ProcessEndpointWithSemaphore(SemaphoreSlim semaphore, string baseUrl, string endpoint, string serverName)
        {
            await semaphore.WaitAsync();
            try
            {
                await ProcessEndpoint(baseUrl, endpoint, serverName);
            }
            finally
            {
                semaphore.Release();
            }
        }

        private async Task ProcessEndpoint(string baseUrl, string endpoint, string serverName)
        {
            try
            {
                // Call the FRM API endpoint with retry policy
                var url = $"{baseUrl}/{endpoint}";
                var context = new Context(endpoint);
                
                var response = await _retryPolicy.ExecuteAsync(async (context) =>
                {
                    _logger.LogDebug($"Calling FRM endpoint: {url}");
                    var httpResponse = await _httpClient.GetAsync(url);
                    
                    if (!httpResponse.IsSuccessStatusCode)
                    {
                        _logger.LogWarning($"FRM endpoint {endpoint} returned {httpResponse.StatusCode}");
                    }
                    
                    return httpResponse;
                }, context);

                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogError($"Failed to fetch data from {endpoint} after retries. Status: {response.StatusCode}");
                    return;
                }
                
                var jsonData = await response.Content.ReadAsStringAsync();
                
                // Validate JSON data before processing
                if (string.IsNullOrWhiteSpace(jsonData))
                {
                    _logger.LogWarning($"Empty response from endpoint {endpoint}");
                    return;
                }

                JsonElement parsedData;
                try
                {
                    parsedData = JsonSerializer.Deserialize<JsonElement>(jsonData);
                }
                catch (JsonException ex)
                {
                    _logger.LogError(ex, $"Invalid JSON response from endpoint {endpoint}");
                    return;
                }
                
                // Create event data with metadata
                var eventData = new
                {
                    timestamp = DateTime.UtcNow,
                    endpoint = endpoint,
                    server = serverName,
                    data = parsedData
                };

                await SendToEventHub(eventData, endpoint, serverName);
                _logger.LogInformation($"Successfully processed endpoint {endpoint}");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error processing endpoint {endpoint}: {ex.Message}");
            }
        }

        private async Task SendToEventHub(object eventData, string endpoint, string serverName)
        {
            try
            {
                var eventDataJson = JsonSerializer.Serialize(eventData, new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                });
                var eventDataBytes = Encoding.UTF8.GetBytes(eventDataJson);

                // Send to Event Hub with proper partitioning and metadata
                using var eventBatch = await _eventHubClient.CreateBatchAsync();
                var eventHubData = new EventData(eventDataBytes);
                
                // Add custom properties for routing/filtering in downstream systems
                eventHubData.Properties.Add("endpoint", endpoint);
                eventHubData.Properties.Add("server", serverName);
                eventHubData.Properties.Add("timestamp", DateTime.UtcNow.ToString("O"));
                eventHubData.Properties.Add("source", "satisfactory-frm");
                eventHubData.Properties.Add("partitionKey", endpoint); // Add as property instead

                if (!eventBatch.TryAdd(eventHubData))
                {
                    _logger.LogWarning($"Event too large for batch for endpoint {endpoint}");
                    return;
                }

                await _eventHubClient.SendAsync(eventBatch);
                _logger.LogDebug($"Successfully sent {endpoint} data to Event Hub");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to send {endpoint} data to Event Hub: {ex.Message}");
                throw; // Re-throw to trigger retry logic at higher level
            }
        }

        // Dispose of resources properly
        public void Dispose()
        {
            _eventHubClient?.DisposeAsync().AsTask().Wait();
            _httpClient?.Dispose();
        }
    }

    // Data models based on FRM API structure
    public class PowerData
    {
        public int CircuitGroupID { get; set; }
        public float PowerProduction { get; set; }
        public float PowerConsumed { get; set; }
        public float PowerCapacity { get; set; }
        public float BatteryPercent { get; set; }
        public bool FuseTriggered { get; set; }
    }

    public class PlayerData
    {
        public string ID { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public LocationData? Location { get; set; }
        public bool Online { get; set; }
        public float PlayerHP { get; set; }
        public bool Dead { get; set; }
    }

    public class LocationData
    {
        public float X { get; set; }
        public float Y { get; set; }
        public float Z { get; set; }
        public float Rotation { get; set; }
    }

    public class FactoryData
    {
        public string ID { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string ClassName { get; set; } = string.Empty;
        public LocationData? Location { get; set; }
        public float Productivity { get; set; }
        public ProductionData[] Production { get; set; } = Array.Empty<ProductionData>();
    }

    public class ProductionData
    {
        public string Name { get; set; } = string.Empty;
        public float CurrentProd { get; set; }
        public float MaxProd { get; set; }
        public float ProdPercent { get; set; }
    }
}
