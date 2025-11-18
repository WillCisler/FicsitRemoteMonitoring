# 🚀 Satisfactory Local Streamer - Quick Reference

## One-Command Setup

```powershell
cd azure-integration/local-streamer
.\quick-start.ps1 -Build -Test -Run
```

## Prerequisites Checklist

- [ ] .NET 8 Runtime installed
- [ ] Azure CLI installed (`az --version`)
- [ ] Logged into Azure (`az login`)
- [ ] Satisfactory server running with FRM mod
- [ ] Event Hub namespace and name from deployment

## Configuration (5 minutes)

1. **Edit `appsettings.Production.json`:**

   ```json
   {
     "Satisfactory": {
       "FrmUrl": "http://localhost:26988", // YOUR PORT HERE
       "ServerName": "sands" // YOUR SERVER NAME
     }
   }
   ```

2. **Test FRM connectivity:**

   ```powershell
   Invoke-WebRequest http://localhost:26988/getPower
   ```

   If it fails, try port 8080:

   ```powershell
   Invoke-WebRequest http://localhost:8080/getPower
   ```

3. **Verify Azure auth:**
   ```powershell
   az account show
   ```

## Running Options

### Console Mode (Testing)

```powershell
cd publish
$env:DOTNET_ENVIRONMENT="Production"
.\SatisfactoryLocalStreamer.exe
```

Press Ctrl+C to stop.

### Windows Service (Production)

```powershell
# Install (requires Admin)
cd publish
.\install-service.ps1

# Manage
Start-Service SatisfactoryDataStreamer
Stop-Service SatisfactoryDataStreamer
Get-Service SatisfactoryDataStreamer

# Uninstall
.\uninstall-service.ps1
```

## Troubleshooting

### ❌ "Failed to fetch data from endpoint"

- Check Satisfactory is running
- Verify FRM mod is enabled: `/frm http start` in game console
- Test endpoint: `Invoke-WebRequest http://localhost:8080/getPower`
- Try different port in config (8080, 26988)

### ❌ "Event Hub authentication failed"

- Run: `az login`
- Check subscription: `az account show`
- Verify you have "Event Hubs Data Sender" role

### ❌ "Service won't start"

- Check logs: `Get-Content logs\*.log -Tail 50`
- Run in console mode first to see errors
- Verify .NET 8 Runtime installed: `dotnet --version`

## Monitoring

### View Logs

```powershell
# Latest logs
Get-Content logs\satisfactory-streamer-*.log -Tail 100

# Follow in real-time
Get-Content logs\satisfactory-streamer-*.log -Tail 50 -Wait

# Search for errors
Select-String -Path logs\*.log -Pattern "error" -CaseSensitive
```

### Service Status

```powershell
Get-Service SatisfactoryDataStreamer | Format-List *
```

## Performance Tuning

### High-End PC (more concurrent requests)

In `appsettings.json`:

```json
"Streaming": {
  "MaxConcurrentRequests": 10
}
```

### Low-End PC (fewer requests)

```json
"Streaming": {
  "MaxConcurrentRequests": 3,
  "StandardFrequencyIntervalSeconds": 60
}
```

### Disable Unused Tiers

```json
"Streaming": {
  "EnableStandardFrequency": false  // Only high/medium data
}
```

## Common Tasks

### Change Data Collection Frequency

Edit `appsettings.json`:

```json
"Streaming": {
  "HighFrequencyIntervalSeconds": 2,     // Changed from 1s
  "MediumFrequencyIntervalSeconds": 10,  // Changed from 5s
  "StandardFrequencyIntervalSeconds": 60 // Changed from 30s
}
```

### Add Custom Endpoints

Edit `appsettings.json`:

```json
"Endpoints": {
  "HighFrequency": [
    "getPower",
    "getPlayer",
    "getTrains"  // NEW ENDPOINT
  ]
}
```

### Switch to Connection String Auth

If Azure CLI auth doesn't work:

```json
"EventHub": {
  "UseConnectionString": true,
  "ConnectionString": "Endpoint=sb://your-ns.servicebus.windows.net/;..."
}
```

## File Locations

| File                | Location                                  | Purpose             |
| ------------------- | ----------------------------------------- | ------------------- |
| **Executable**      | `publish/SatisfactoryLocalStreamer.exe`   | Main application    |
| **Config**          | `publish/appsettings.Production.json`     | Production settings |
| **Logs**            | `logs/satisfactory-streamer-YYYYMMDD.log` | Daily log files     |
| **Service Scripts** | `publish/*.ps1`                           | Management scripts  |

## Key Features

✅ **Three-tier frequencies**: 1s, 5s, 30s intervals  
✅ **Automatic retries**: Exponential backoff on failures  
✅ **Concurrent processing**: 5 parallel requests (configurable)  
✅ **File + console logging**: Serilog with daily rotation  
✅ **Windows Service support**: Run 24/7 in background  
✅ **Azure CLI auth**: No secrets in config files

## Getting Help

1. Check logs: `logs/*.log`
2. Test config: `.\test-config.ps1`
3. Run in console mode to see live output
4. Check Event Hub in Azure Portal for incoming data
5. Review [README.md](README.md) for detailed docs

## Links

- **Full Documentation**: [README.md](README.md)
- **Azure Function vs Local**: [LOCAL-VS-CLOUD.md](../LOCAL-VS-CLOUD.md)
- **Endpoint Frequencies**: [ENDPOINT-FREQUENCY-CONFIG.md](../ENDPOINT-FREQUENCY-CONFIG.md)
- **Main Integration Guide**: [../README.md](../README.md)
