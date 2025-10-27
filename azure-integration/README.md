# Satisfactory → Microsoft Fabric Data Streaming

This solution streams real-time data from your Satisfactory game (via the FicsitRemoteMonitoring mod) into Microsoft Fabric for analytics and reporting. Built using Azure serverless technologies with enterprise-grade security and reliability.

## Architecture

```
Satisfactory Game + FRM Mod → Azure Function → Event Hubs → Microsoft Fabric (Eventhouse/Lakehouse)
                                     ↓
                            Application Insights (Monitoring)
```

### Key Components

- **Azure Function**: Timer-triggered serverless function (C#) that polls FRM endpoints
- **Event Hubs**: High-throughput data ingestion service for streaming data
- **Microsoft Fabric**: Cloud analytics platform (Eventhouse for real-time, Lakehouse for historical)
- **Managed Identity**: Secure authentication without credentials
- **Application Insights**: End-to-end monitoring and telemetry

## Data Sources Available

The FicsitRemoteMonitoring mod provides 80+ API endpoints including:

### Factory Data

- **Production metrics**: Assembly lines, manufacturers, refineries
- **Efficiency data**: Productivity percentages, throughput rates
- **Inventory tracking**: Input/output buffers, storage levels

### Power Grid

- **Circuit monitoring**: Power production, consumption, capacity
- **Generator status**: Coal, nuclear, biomass, geothermal
- **Battery systems**: Charge levels, time estimates

### Logistics

- **Transportation**: Trains, trucks, drones, belts
- **Resource flow**: Extraction rates, pipeline status
- **Station monitoring**: Loading/unloading progress

### Player & World

- **Player tracking**: Location, health, inventory
- **Resource nodes**: Mining operations, fracking sites
- **Research progress**: MAM trees, schematics

## Prerequisites

1. **Satisfactory with FicsitRemoteMonitoring mod installed**
2. **Azure subscription with Microsoft Fabric enabled**
3. **PowerShell 7.0+** or **Azure CLI 2.37+**
4. **Azure Functions Core Tools 4.x** (for local development)

## Quick Start Deployment

### 1. Deploy Azure Infrastructure

Choose one of these deployment methods:

#### Option A: Azure CLI (Recommended)

```bash
# Login to Azure
az login

# Create resource group
az group create --name "satisfactory-fabric-rg" --location "East US 2"

# Validate deployment (what-if analysis)
az deployment group what-if \
  --resource-group "satisfactory-fabric-rg" \
  --template-file "azure-integration/infrastructure/satisfactory-fabric-integration-fixed.bicep" \
  --parameters "@azure-integration/infrastructure/parameters.json"

# Deploy infrastructure
az deployment group create \
  --resource-group "satisfactory-fabric-rg" \
  --template-file "azure-integration/infrastructure/satisfactory-fabric-integration-fixed.bicep" \
  --parameters "@azure-integration/infrastructure/parameters.json"
```

#### Option B: Azure PowerShell

```powershell
# Login to Azure
Connect-AzAccount

# Create resource group
New-AzResourceGroup -Name "satisfactory-fabric-rg" -Location "East US 2"

# Deploy infrastructure
New-AzResourceGroupDeployment `
  -ResourceGroupName "satisfactory-fabric-rg" `
  -TemplateFile "azure-integration/infrastructure/satisfactory-fabric-integration-fixed.bicep" `
  -TemplateParameterFile "azure-integration/infrastructure/parameters.json"
```

**Important**: Update the `parameters.json` file with your actual Satisfactory server URL and name before deployment.

### 2. Enable FRM Web Server

In your Satisfactory game, open the console (`` ` `` key) and run:

```console
/frm http start
```

The web server will be available at `http://localhost:8080` (or your server IP if hosted remotely).

### 3. Deploy Function Code

```bash
# Navigate to the function directory
cd azure-integration

# Build and deploy the Azure Function
func azure functionapp publish <your-function-app-name>

# Verify deployment - you should see SatisfactoryDataStreamer listed
func azure functionapp list-functions <your-function-app-name>
```

**Note**: The function is configured to run every 30 seconds and monitor 7 FRM endpoints.

### 4. Configure Microsoft Fabric

See the detailed [Microsoft Fabric Setup Guide](FABRIC-SETUP.md) for complete instructions.

#### Quick Setup (Eventhouse for Real-Time)

1. **Create an Eventhouse** in your Fabric workspace (Real-Time Analytics)
2. **Create a KQL Database** within the Eventhouse
3. **Set up Event Hubs connection** as a data source
4. **Create real-time dashboards** using KQL queries

#### Alternative Options

- **Lakehouse**: For batch analytics and historical data storage
- **Data Activator**: For real-time alerts (power outages, production issues)

## Data Schema

Each event sent to Event Hubs follows this structure:

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "endpoint": "getPower",
  "server": "production-server",
  "data": [
    {
      "CircuitGroupID": 0,
      "PowerProduction": 1500.0,
      "PowerConsumed": 1200.0,
      "PowerCapacity": 2000.0,
      "BatteryPercent": 85.5,
      "FuseTriggered": false
    }
  ]
}
```

## Sample Analytics Queries

### Power Grid Monitoring

```kql
SatisfactoryEvents
| where endpoint == "getPower"
| extend PowerData = parse_json(data)
| mv-expand PowerData
| project
    timestamp,
    CircuitID = PowerData.CircuitGroupID,
    Production = PowerData.PowerProduction,
    Consumption = PowerData.PowerConsumed,
    Efficiency = (PowerData.PowerConsumed / PowerData.PowerCapacity) * 100
| summarize avg(Efficiency) by bin(timestamp, 5m), CircuitID
```

### Factory Performance

```kql
SatisfactoryEvents
| where endpoint == "getFactory"
| extend FactoryData = parse_json(data)
| mv-expand FactoryData
| project
    timestamp,
    FactoryName = FactoryData.Name,
    Productivity = FactoryData.Productivity,
    Location = FactoryData.location
| summarize avg(Productivity) by bin(timestamp, 10m), FactoryName
```

### Player Activity Heatmap

```kql
SatisfactoryEvents
| where endpoint == "getPlayer"
| extend PlayerData = parse_json(data)
| mv-expand PlayerData
| where PlayerData.Online == true
| project
    timestamp,
    PlayerName = PlayerData.Name,
    X = PlayerData.location.x,
    Y = PlayerData.location.y,
    Z = PlayerData.location.z
| summarize count() by bin(X, 1000), bin(Y, 1000)
```

## Key Benefits

### Real-Time Monitoring

- **Live factory performance** tracking
- **Power grid stability** alerts
- **Resource bottleneck** identification

### Historical Analytics

- **Production trend** analysis
- **Efficiency optimization** insights
- **Player behavior** patterns

### Advanced Use Cases

- **Predictive maintenance** for power systems
- **Supply chain optimization** recommendations
- **Automated alert** systems for critical issues

## Configuration Options

### Function App Settings

- `SATISFACTORY_FRM_URL`: Your FRM server URL
- `SATISFACTORY_SERVER_NAME`: Server identifier
- `EVENT_HUB_NAMESPACE`: Event Hubs namespace
- `EVENT_HUB_NAME`: Target Event Hub name

### Monitored Endpoints

Customize the endpoints to monitor in `SatisfactoryDataStreamer.cs`:

```csharp
private readonly string[] _monitoredEndpoints = {
    "getPower",           // Power grid status
    "getFactory",         // Production buildings
    "getPlayer",          // Player locations
    "getExtractor",       // Resource mining
    "getGenerators",      // Power generation
    "getVehicles",        // Transportation
    "getSessionInfo"      // Game session data
};
```

## Troubleshooting

### Common Deployment Issues

1. **Storage account name conflicts**

   ```bash
   # Error: Storage account name must be unique globally
   # Solution: The Bicep template uses uniqueString() to avoid conflicts
   # If still failing, try a different resource group name
   ```

2. **Azure CLI authentication issues**

   ```bash
   # Clear cached credentials and re-login
   az logout
   az login --tenant <your-tenant-id>
   ```

3. **Bicep template validation errors**

   ```bash
   # Run what-if to see potential issues before deployment
   az deployment group what-if \
     --resource-group "satisfactory-fabric-rg" \
     --template-file "infrastructure/satisfactory-fabric-integration-fixed.bicep" \
     --parameters "@infrastructure/parameters.json"
   ```

### Function Runtime Issues

1. **Function not receiving data**

   - Verify FRM web server is running: `/frm http start`
   - Check server URL in function app settings
   - Ensure firewall allows access to port 8080
   - Test FRM endpoint manually: `curl http://your-server:8080/getPower`

2. **Event Hub connection errors**

   - Verify managed identity has "Azure Event Hubs Data Sender" role
   - Check Event Hub namespace and name in app settings
   - Review Application Insights logs for detailed error messages

3. **Data not appearing in Fabric**
   - Confirm Event Hub connection is configured in Fabric
   - Check data format matches expected schema
   - Verify KQL ingestion mapping is correct

### Monitoring & Debugging

- **Application Insights**: Monitor function execution and errors

  ```kql
  traces
  | where customDimensions.Category == "Function.SatisfactoryDataStreamer.User"
  | project timestamp, message, severityLevel
  | order by timestamp desc
  ```

- **Event Hub metrics**: Track message ingestion rates in Azure portal
- **Fabric monitoring**: Verify data pipeline health in workspace

### Security Considerations

This solution follows Azure security best practices:

- **Managed Identity**: No stored credentials, Azure handles authentication automatically
- **HTTPS enforced**: All communication uses TLS 1.2+
- **Least privilege**: Function app only has Event Hub Data Sender permissions
- **Network security**: Event Hub access can be restricted to specific VNets (optional)
- **Monitoring**: All activities logged in Application Insights for audit trails

### Performance Optimization

- **Timer frequency**: Default 30-second intervals (configurable in function trigger)
- **Batch processing**: Multiple endpoints processed concurrently
- **Partitioning**: Events partitioned by endpoint type for optimal processing
- **Error handling**: Exponential backoff and retry logic for transient failures

## Advanced Features

### WebSocket Streaming

For real-time data streaming, the solution can be extended to use WebSocket connections to FRM:

```csharp
// Subscribe to multiple endpoints for real-time updates
{
  "action": "subscribe",
  "endpoints": ["getPower", "getFactory", "getPlayer"]
}
```

### Custom Data Transformations

Add business logic to enrich data before sending to Fabric:

```csharp
// Add calculated metrics
var enrichedData = new {
    timestamp = DateTime.UtcNow,
    endpoint = endpoint,
    server = serverName,
    data = rawData,
    metrics = new {
        efficiency = CalculateEfficiency(rawData),
        alerts = CheckForAlerts(rawData)
    }
};
```

## Cost Optimization

- **Event Hub Standard tier**: ~$11/month for light usage
- **Function Consumption plan**: Pay-per-execution
- **Storage**: Minimal costs for function storage
- **Total estimated cost**: $15-30/month for typical usage

## Next Steps

1. **Deploy the infrastructure** using the Bicep template
2. **Install and configure** the FRM mod in Satisfactory
3. **Set up Fabric workspace** and connect to Event Hubs
4. **Create dashboards** for real-time monitoring
5. **Build analytics** for optimization insights

For detailed deployment validation, see [Deployment Checklist](DEPLOYMENT-CHECKLIST.md).

## Documentation

- **[Microsoft Fabric Setup Guide](FABRIC-SETUP.md)**: Complete Fabric configuration
- **[Deployment Checklist](DEPLOYMENT-CHECKLIST.md)**: Step-by-step validation and testing
- **[FRM Documentation](https://docs.ficsit.app/ficsitremotemonitoring/latest/)**: Official mod documentation

## Support and Resources

- **FRM Mod Community**: [Discord](https://discord.gg/c6446HTHpu)
- **Azure Documentation**: [Azure Functions](https://docs.microsoft.com/azure/azure-functions/) | [Event Hubs](https://docs.microsoft.com/azure/event-hubs/)
- **Microsoft Fabric**: [Documentation](https://docs.microsoft.com/fabric/) | [KQL Reference](https://docs.microsoft.com/azure/data-explorer/kql-quick-reference)

## Contributing

This solution follows Azure Well-Architected Framework principles:

- **Reliability**: Retry policies, error handling, monitoring
- **Security**: Managed identity, HTTPS enforcement, least privilege access
- **Cost Optimization**: Consumption-based pricing, configurable retention
- **Operational Excellence**: Comprehensive logging, automated deployment
- **Performance Efficiency**: Concurrent processing, optimal partitioning

To contribute improvements or report issues, please follow standard Azure development practices and ensure all changes maintain these principles.
