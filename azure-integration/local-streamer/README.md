# Satisfactory Local Data Streamer

A standalone Windows application that streams Satisfactory FRM (Ficsit Remote Monitoring) data to Azure Event Hub. This local version runs on the same PC as your Satisfactory dedicated server, bypassing any server API limitations.

## Features

- ✅ **Four-tier frequency system**: High (1s), Medium (5s), Standard (30s), Hourly (1 hour) data collection
- ✅ **Azure Event Hub integration**: Same streaming destination as Azure Function version
- ✅ **Automatic retry logic**: Polly-based exponential backoff for resilience
- ✅ **Concurrent processing**: Configurable parallelism with semaphore control
- ✅ **File & Console logging**: Serilog-based logging with daily rotation
- ✅ **Windows Service support**: Run as background service with auto-restart
- ✅ **Azure CLI authentication**: Uses DefaultAzureCredential (no secrets in config)
- ✅ **Configurable endpoints**: JSON-based configuration for all settings

## Prerequisites

1. **Satisfactory Server** with FicsitRemoteMonitoring mod installed and running
2. **.NET 8 Runtime** - [Download here](https://dotnet.microsoft.com/download/dotnet/8.0)
3. **Azure CLI** - [Download here](https://docs.microsoft.com/cli/azure/install-azure-cli)
4. **Azure Event Hub** instance (should already exist from main deployment)

## Quick Start

### 1. Build the Application

```powershell
cd azure-integration/local-streamer
dotnet restore
dotnet build -c Release
dotnet publish -c Release -o publish
```

### 2. Configure Settings

Edit `publish/appsettings.Production.json`:

```json
{
  "Satisfactory": {
    "FrmUrl": "http://localhost:26988", // Update port if needed
    "ServerName": "sands"
  }
}
```

**To test which port Satisfactory is using:**

```powershell
# Try common ports
Invoke-WebRequest http://localhost:8080/getPower
Invoke-WebRequest http://localhost:26988/getPower
```

### 3. Authenticate with Azure

```powershell
az login
```

This only needs to be done once. The application will use your Azure CLI credentials.

### 4. Test Configuration

```powershell
cd publish
.\test-config.ps1 -ConfigFile appsettings.Production.json
```

This will verify:

- FRM endpoint connectivity
- Azure CLI authentication
- Configuration validity

### 5. Run the Application

**Console Mode (for testing):**

```powershell
cd publish
$env:DOTNET_ENVIRONMENT="Production"
.\SatisfactoryLocalStreamer.exe
```

Press `Ctrl+C` to stop.

**Windows Service Mode (for production):**

```powershell
cd publish
# Run as Administrator
.\install-service.ps1
```

## Configuration Reference

### appsettings.json Structure

```json
{
  "Satisfactory": {
    "FrmUrl": "http://localhost:8080", // FRM API base URL
    "ServerName": "local-server" // Server identifier in Event Hub data
  },
  "EventHub": {
    "Namespace": "your-eventhub.servicebus.windows.net",
    "Name": "satisfactory-data",
    "UseConnectionString": false, // Set true to use connection string
    "ConnectionString": "" // Only if UseConnectionString=true
  },
  "Streaming": {
    "HighFrequencyIntervalSeconds": 1, // High-priority endpoints
    "MediumFrequencyIntervalSeconds": 5, // Medium-priority endpoints
    "StandardFrequencyIntervalSeconds": 30, // Standard endpoints
    "HourlyFrequencyIntervalSeconds": 3600, // Hourly static data (1 hour)
    "MaxConcurrentRequests": 5, // Parallel request limit
    "HttpTimeoutSeconds": 30,
    "EnableHighFrequency": true, // Enable/disable tiers
    "EnableMediumFrequency": true,
    "EnableStandardFrequency": true,
    "EnableHourlyFrequency": true
  },
  "Endpoints": {
    "HighFrequency": ["getPower", "getPlayer"],
    "MediumFrequency": ["getGenerators", "getVehicles", "getSessionInfo"],
    "StandardFrequency": [
      "getFactory",
      "getExtractor"
      // ... more endpoints
    ],
    "HourlyFrequency": ["getRecipes"]
  }
}
```

### Environment-Specific Settings

- `appsettings.json` - Base configuration
- `appsettings.Development.json` - Slower intervals for testing
- `appsettings.Production.json` - Production settings (localhost URL)

Set environment:

```powershell
$env:DOTNET_ENVIRONMENT="Production"  # or "Development"
```

## Endpoint Frequency Tiers

| Tier         | Default Interval | Purpose                   | Default Endpoints                                |
| ------------ | ---------------- | ------------------------- | ------------------------------------------------ |
| **High**     | 1 second         | Real-time critical data   | `getPower`, `getPlayer`                          |
| **Medium**   | 5 seconds        | Semi-frequent updates     | `getGenerators`, `getVehicles`, `getSessionInfo` |
| **Standard** | 30 seconds       | Less critical data        | `getFactory`, `getExtractor`, `getBelts`, etc.   |
| **Hourly**   | 1 hour (3600s)   | Static game configuration | `getRecipes` (⚠️ runs on game thread)            |

**To change intervals:** Edit `Streaming:*IntervalSeconds` in `appsettings.json`

**To move endpoints:** Edit the `Endpoints:*Frequency` arrays in `appsettings.json`

## Windows Service Management

### Install Service

```powershell
# Run as Administrator
cd publish
.\install-service.ps1
```

Options:

- Service Name: `SatisfactoryDataStreamer`
- Startup Type: Automatic
- Recovery: Auto-restart on failure

### Manage Service

```powershell
# Start
Start-Service -Name SatisfactoryDataStreamer

# Stop
Stop-Service -Name SatisfactoryDataStreamer

# Restart
Restart-Service -Name SatisfactoryDataStreamer

# Check status
Get-Service -Name SatisfactoryDataStreamer

# View logs
Get-Content logs\satisfactory-streamer-*.log -Tail 50 -Wait
```

### Uninstall Service

```powershell
# Run as Administrator
cd publish
.\uninstall-service.ps1
```

## Logging

Logs are written to both console and files.

**Log Location:** `logs/satisfactory-streamer-YYYYMMDD.log`

**Log Retention:** 7 days (configurable in `appsettings.json`)

**View Recent Logs:**

```powershell
Get-Content logs\satisfactory-streamer-*.log -Tail 100
```

**Follow Logs in Real-Time:**

```powershell
Get-Content logs\satisfactory-streamer-*.log -Tail 50 -Wait
```

## Troubleshooting

### FRM Endpoints Not Reachable

**Symptom:** `Failed to fetch data from endpoint`

**Solutions:**

1. Verify Satisfactory server is running
2. Check FRM mod is enabled in the game
3. Test endpoint manually: `Invoke-WebRequest http://localhost:8080/getPower`
4. Try different port (common: 8080, 26988)
5. Update `FrmUrl` in `appsettings.Production.json`

### Azure Event Hub Authentication Failed

**Symptom:** `Authentication failed` or `Unauthorized`

**Solutions:**

1. Run `az login` to authenticate
2. Verify correct subscription: `az account show`
3. Check Event Hub permissions (need "Azure Event Hubs Data Sender" role)
4. Alternative: Use connection string (set `UseConnectionString: true`)

### Service Won't Start

**Symptom:** Service shows "Stopped" status

**Solutions:**

1. Check logs in `logs/` folder for errors
2. Run in console mode first to test: `.\SatisfactoryLocalStreamer.exe`
3. Verify .NET 8 Runtime is installed
4. Check Event Hub namespace is correct in config

### High CPU/Memory Usage

**Solutions:**

1. Reduce `MaxConcurrentRequests` (default: 5)
2. Increase frequency intervals for less critical data
3. Disable tiers you don't need (set `Enable*Frequency: false`)

## Comparison: Local vs Azure Function

| Feature          | Local Streamer           | Azure Function        |
| ---------------- | ------------------------ | --------------------- |
| **Cost**         | Free (uses PC resources) | Azure compute costs   |
| **Latency**      | ~1-5ms (localhost)       | ~50-200ms (network)   |
| **API Limits**   | None (direct HTTP)       | May hit server limits |
| **Availability** | Depends on PC uptime     | 99.95% SLA            |
| **Scalability**  | Single instance          | Auto-scales           |
| **Maintenance**  | Manual updates           | Managed service       |

## Advanced Configuration

### Custom Endpoint Frequencies

Add a new tier in `appsettings.json`:

```json
"Streaming": {
  "UltraHighFrequencyIntervalSeconds": 0.5  // 500ms
},
"Endpoints": {
  "UltraHighFrequency": ["getPower"]
}
```

Then update `DataStreamWorker.cs` to add a new timer.

### Connection String Authentication

If Azure CLI auth doesn't work, use a connection string:

```json
"EventHub": {
  "UseConnectionString": true,
  "ConnectionString": "Endpoint=sb://your-namespace.servicebus.windows.net/;SharedAccessKeyName=..."
}
```

Get connection string from Azure Portal → Event Hubs → Shared Access Policies

### Multiple Servers

Run separate instances with different config files:

```powershell
.\SatisfactoryLocalStreamer.exe --contentRoot "C:\server1-config"
.\SatisfactoryLocalStreamer.exe --contentRoot "C:\server2-config"
```

## Performance Tips

1. **Adjust concurrency** based on your PC specs:

   - Low-end PC: `MaxConcurrentRequests: 3`
   - High-end PC: `MaxConcurrentRequests: 10`

2. **Optimize intervals** for your needs:

   - Power monitoring critical? Keep at 1s
   - Factory data can go to 60s for large factories

3. **Disable unused tiers** to save resources:
   ```json
   "EnableStandardFrequency": false  // If you only want real-time data
   ```

## Files in This Directory

| File                           | Purpose                                         |
| ------------------------------ | ----------------------------------------------- |
| `Program.cs`                   | Application entry point with host configuration |
| `DataStreamWorker.cs`          | Background service with periodic timers         |
| `SatisfactoryDataStreamer.cs`  | Core streaming logic (HTTP + Event Hub)         |
| `appsettings.json`             | Base configuration                              |
| `appsettings.Production.json`  | Production overrides                            |
| `appsettings.Development.json` | Development overrides                           |
| `install-service.ps1`          | Windows Service installation script             |
| `uninstall-service.ps1`        | Windows Service removal script                  |
| `test-config.ps1`              | Configuration validation script                 |

## Support

For issues or questions:

1. Check logs in `logs/` folder
2. Run `test-config.ps1` to validate setup
3. Test in console mode before installing as service
4. Verify Azure Event Hub is receiving data in Azure Portal

## License

Same as parent project (FicsitRemoteMonitoring)
