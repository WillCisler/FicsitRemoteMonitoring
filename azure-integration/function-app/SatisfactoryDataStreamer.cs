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
    /// <summary>
    /// Satisfactory FRM Data Streamer with configurable endpoint frequencies
    /// 
    /// FREQUENCY CONFIGURATION:
    /// - High Frequency (1s): Critical real-time data like power and player status
    /// - Medium Frequency (5s): Semi-frequent updates like generators and vehicles  
    /// - Standard Frequency (30s): Less critical data like factory buildings and logistics
    /// 
    /// NOTE: Azure Functions minimum timer interval is 1 second (not 500ms)
    /// 
    /// TO MODIFY FREQUENCIES:
    /// 1. Move endpoints between the frequency arrays below
    /// 2. Change timer expressions in the Function attributes:
    ///    - Every 1 second: "0/1 * * * * *"
    ///    - Every 2 seconds: "0/2 * * * * *"
    ///    - Every 5 seconds: "0/5 * * * * *"
    ///    - Every 30 seconds: "0/30 * * * * *"
    ///    - Every minute: "0 * * * * *"
    /// 
    /// EXAMPLES:
    /// - For 2-second power monitoring: Change timer to "0/2 * * * * *"
    /// - For real-time factory data: Move "getFactory" to high frequency array
    /// </summary>
    public class SatisfactoryDataStreamer
    {
        private readonly HttpClient _httpClient;
        private readonly EventHubProducerClient _eventHubClient;
        private readonly ILogger<SatisfactoryDataStreamer> _logger;
        private readonly IAsyncPolicy<HttpResponseMessage> _retryPolicy;
        
        // High-frequency endpoints (every 1 second) - Real-time critical data
        private readonly string[] _highFrequencyEndpoints = {
            "getPower",           // Power grid status - critical for monitoring
            "getPlayer"           // Player status and location - real-time tracking
        };

        // Medium-frequency endpoints (every 5 seconds) - Semi-frequent updates
        private readonly string[] _mediumFrequencyEndpoints = {
            "getGenerators",      // Power generation
            "getVehicles",        // Train/truck/drone status
            "getSessionInfo"      // Session metadata
        };

        // Standard-frequency endpoints (every 30 seconds) - Less critical data
        private readonly string[] _standardFrequencyEndpoints = {
            "getFactory",         // All factory buildings
            "getExtractor",       // Resource extraction rates
            "getBelts",           // Conveyor belt networks - DIGITAL TWIN: material flow
            "getLifts",           // Conveyor lifts  
            "getPipes",           // Pipeline networks - DIGITAL TWIN: fluid flow
            "getPump",            // Pipeline pumps - DIGITAL TWIN: fluid transport
            "getSplitterMerger",       // Belt/pipe splitters - DIGITAL TWIN: flow splitting
            "getCables",          // Power cables
            "getHypertube",       // Hyperloop networks
            "getThroughputCounter", // Flow monitoring
            "getPipeJunctions",   // Pipeline junction points
            "getFrackingActivator", // Resource Well Pressurizers
            "getTrainStation",    // Train station status and cargo
            "getTruckStation"     // Truck station status and cargo
        };

        // Hourly-frequency endpoints (every 1 hour) - Static game configuration data
        private readonly string[] _hourlyFrequencyEndpoints = {
            "getRecipes"          // All recipes - runs on game thread but chunked
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

        // High-frequency function: runs every 1 second for real-time critical data
        // Note: Azure Functions minimum timer interval is 1 second, not 500ms
        [Function("SatisfactoryDataStreamer_HighFreq")]
        public async Task RunHighFrequency([TimerTrigger("0/1 * * * * *")] TimerInfo myTimer)
        {
            await RunDataCollection(_highFrequencyEndpoints, "HighFreq");
        }

        // Medium-frequency function: runs every 5 seconds for semi-frequent updates
        [Function("SatisfactoryDataStreamer_MediumFreq")]
        public async Task RunMediumFrequency([TimerTrigger("0/5 * * * * *")] TimerInfo myTimer)
        {
            await RunDataCollection(_mediumFrequencyEndpoints, "MediumFreq");
        }

        // Standard-frequency function: runs every 30 seconds for less critical data
        [Function("SatisfactoryDataStreamer_StandardFreq")]
        public async Task RunStandardFrequency([TimerTrigger("0/30 * * * * *")] TimerInfo myTimer)
        {
            await RunDataCollection(_standardFrequencyEndpoints, "StandardFreq");
        }

        // Hourly-frequency function: runs every hour for static game configuration data
        [Function("SatisfactoryDataStreamer_HourlyFreq")]
        public async Task RunHourly([TimerTrigger("0 0 * * * *")] TimerInfo myTimer)
        {
            await RunDataCollection(_hourlyFrequencyEndpoints, "HourlyFreq");
        }

        // Legacy function maintained for backward compatibility (can be removed later)
        [Function("SatisfactoryDataStreamer")]
        public async Task Run([TimerTrigger("0/30 * * * * *")] TimerInfo myTimer)
        {
            // Redirect to standard frequency for backward compatibility
            await RunStandardFrequency(myTimer);
        }

        // Core data collection logic shared by all frequency functions
        private async Task RunDataCollection(string[] endpoints, string functionType)
        {
            var startTime = DateTime.UtcNow;
            _logger.LogInformation($"Satisfactory {functionType} data collection started at: {startTime}");

            var frmBaseUrl = Environment.GetEnvironmentVariable("SATISFACTORY_FRM_URL") ?? "http://localhost:8080";
            var serverName = Environment.GetEnvironmentVariable("SATISFACTORY_SERVER_NAME") ?? "default";
            
            // Process endpoints concurrently with controlled parallelism
            var semaphore = new SemaphoreSlim(5, 5); // Limit to 5 concurrent requests
            var tasks = new List<Task>();

            foreach (var endpoint in endpoints)
            {
                tasks.Add(ProcessEndpointWithSemaphore(semaphore, frmBaseUrl, endpoint, serverName));
            }

            await Task.WhenAll(tasks);
            
            var duration = DateTime.UtcNow - startTime;
            _logger.LogInformation($"Satisfactory {functionType} data collection completed in {duration.TotalMilliseconds}ms");
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

        private List<object> ChunkArrayResponse(JsonElement data, string endpoint)
        {
            var chunks = new List<object>();
            var maxItemsPerChunk = int.Parse(Environment.GetEnvironmentVariable("MAX_ITEMS_PER_CHUNK") ?? "50");
            var excludedEndpoints = (Environment.GetEnvironmentVariable("CHUNKING_EXCLUDED_ENDPOINTS") ?? "getSessionInfo")
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

            // Skip chunking for excluded endpoints
            if (excludedEndpoints.Contains(endpoint))
            {
                chunks.Add(data);
                return chunks;
            }

            // Check if data is an array
            if (data.ValueKind != JsonValueKind.Array)
            {
                chunks.Add(data);
                return chunks;
            }

            var array = data.EnumerateArray().ToList();
            var totalItems = array.Count;

            // If array is small enough, don't chunk
            if (totalItems <= maxItemsPerChunk)
            {
                chunks.Add(array);
                return chunks;
            }

            // Split into chunks
            for (int i = 0; i < totalItems; i += maxItemsPerChunk)
            {
                var chunk = array.Skip(i).Take(maxItemsPerChunk).ToList();
                chunks.Add(chunk);
            }

            _logger.LogInformation($"Split {endpoint} response: {totalItems} items into {chunks.Count} chunks");
            return chunks;
        }

        private async Task SendToEventHub(object eventData, string endpoint, string serverName)
        {
            // Extract the data field for chunking analysis
            var dataField = eventData.GetType().GetProperty("data")?.GetValue(eventData);
            if (dataField is JsonElement jsonElement)
            {
                var chunks = ChunkArrayResponse(jsonElement, endpoint);
                var chunkId = Guid.NewGuid().ToString();
                var totalChunks = chunks.Count;

                for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++)
                {
                    try
                    {
                        // Reconstruct event data with chunked data
                        var chunkedEventData = new
                        {
                            timestamp = eventData.GetType().GetProperty("timestamp")?.GetValue(eventData),
                            endpoint = endpoint,
                            server = serverName,
                            data = chunks[chunkIndex]
                        };

                        var eventDataJson = JsonSerializer.Serialize(chunkedEventData, new JsonSerializerOptions
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
                        eventHubData.Properties.Add("partitionKey", endpoint);

                        if (!eventBatch.TryAdd(eventHubData))
                        {
                            var errorMessage = $"Chunk {chunkIndex + 1}/{totalChunks} too large for endpoint {endpoint}";
                            _logger.LogError(errorMessage);
                            
                            // Send error to EventHub with endpoint="error"
                            await SendErrorToEventHub(endpoint, errorMessage, serverName, chunkIndex, totalChunks);
                            continue;
                        }

                        await _eventHubClient.SendAsync(eventBatch);
                        
                        if (totalChunks > 1)
                        {
                            _logger.LogDebug($"Successfully sent {endpoint} chunk {chunkIndex + 1}/{totalChunks} to Event Hub");
                        }
                        else
                        {
                            _logger.LogDebug($"Successfully sent {endpoint} data to Event Hub");
                        }
                    }
                    catch (Exception ex)
                    {
                        var errorMessage = $"Failed to send chunk {chunkIndex + 1}/{totalChunks}: {ex.Message}";
                        _logger.LogError(ex, $"Error sending {endpoint} chunk: {errorMessage}");
                        
                        // Send error to EventHub with endpoint="error"
                        await SendErrorToEventHub(endpoint, errorMessage, serverName, chunkIndex, totalChunks);
                    }
                }
            }
        }

        private async Task SendErrorToEventHub(string originalEndpoint, string errorMessage, string serverName, int? chunkIndex = null, int? totalChunks = null)
        {
            try
            {
                var errorData = new
                {
                    timestamp = DateTime.UtcNow,
                    endpoint = "error",
                    server = serverName,
                    data = new[]
                    {
                        new
                        {
                            originalEndpoint = originalEndpoint,
                            errorMessage = errorMessage,
                            timestamp = DateTime.UtcNow.ToString("O"),
                            chunkInfo = chunkIndex.HasValue ? $"{chunkIndex.Value + 1}/{totalChunks}" : null
                        }
                    }
                };

                var eventDataJson = JsonSerializer.Serialize(errorData, new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                });
                var eventDataBytes = Encoding.UTF8.GetBytes(eventDataJson);

                using var eventBatch = await _eventHubClient.CreateBatchAsync();
                var eventHubData = new EventData(eventDataBytes);
                
                eventHubData.Properties.Add("endpoint", "error");
                eventHubData.Properties.Add("server", serverName);
                eventHubData.Properties.Add("timestamp", DateTime.UtcNow.ToString("O"));
                eventHubData.Properties.Add("source", "satisfactory-frm");
                eventHubData.Properties.Add("partitionKey", "error");

                if (eventBatch.TryAdd(eventHubData))
                {
                    await _eventHubClient.SendAsync(eventBatch);
                    _logger.LogDebug($"Sent error event for {originalEndpoint} to Event Hub");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to send error event for {originalEndpoint}: {ex.Message}");
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
