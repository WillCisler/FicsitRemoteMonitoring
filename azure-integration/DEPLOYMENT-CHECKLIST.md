# Deployment Checklist & Validation Guide

This guide provides step-by-step validation to ensure your Satisfactory → Microsoft Fabric integration is working correctly.

## Pre-Deployment Checklist

### 1. Prerequisites Verification

- [ ] **Satisfactory Server**: Game running with FicsitRemoteMonitoring mod installed
- [ ] **Azure Subscription**: Active subscription with sufficient permissions
- [ ] **Microsoft Fabric**: Workspace with Real-Time Analytics enabled
- [ ] **Tools Installed**: Azure CLI 2.37+ or Azure PowerShell, Azure Functions Core Tools 4.x

### 2. FRM Mod Configuration

- [ ] **Mod Installation**: FicsitRemoteMonitoring mod installed in Satisfactory
- [ ] **Web Server Started**: Run `/frm http start` in game console
- [ ] **Port Access**: Port 8080 accessible (firewall/router configuration)
- [ ] **API Testing**: Verify endpoints respond at `http://your-server:8080/getPower`

### 3. Azure Resource Preparation

- [ ] **Parameters File**: Update `parameters.json` with correct server URL and name
- [ ] **Resource Group**: Choose appropriate Azure region for your location
- [ ] **Quotas**: Verify Azure subscription has sufficient quotas for Event Hubs and Function Apps

## Deployment Validation

### 1. Infrastructure Deployment

After running the Bicep deployment, verify these resources exist:

#### Event Hub Namespace

```bash
# Check Event Hub deployment
az eventhubs namespace show --name <your-eventhub-namespace> --resource-group satisfactory-fabric-rg
```

Expected output: Status should be "Active"

#### Function App

```bash
# Check Function App deployment
az functionapp show --name <your-function-app-name> --resource-group satisfactory-fabric-rg
```

Expected output: State should be "Running"

#### Managed Identity

```bash
# Verify managed identity has Event Hub permissions
az role assignment list --assignee <function-app-principal-id> --scope /subscriptions/<sub-id>/resourceGroups/satisfactory-fabric-rg
```

Expected output: Should show "Azure Event Hubs Data Sender" role assignment

### 2. Function App Configuration

Verify these application settings are configured:

```bash
az functionapp config appsettings list --name <your-function-app-name> --resource-group satisfactory-fabric-rg
```

Required settings:

- `SATISFACTORY_FRM_URL`: Your FRM server URL
- `SATISFACTORY_SERVER_NAME`: Your server identifier
- `EVENT_HUB_NAMESPACE`: Event Hub namespace name
- `EVENT_HUB_NAME`: Event Hub name (should be "satisfactory-data")

### 3. Function Code Deployment

```bash
# Deploy function code
cd azure-integration
func azure functionapp publish <your-function-app-name>

# Verify functions are deployed
func azure functionapp list-functions <your-function-app-name>
```

Expected output: Should list "SatisfactoryDataStreamer" function

## End-to-End Testing

### 1. Function Execution Test

```bash
# Trigger function manually for testing
az functionapp function invoke --name SatisfactoryDataStreamer --function-app <your-function-app-name> --resource-group satisfactory-fabric-rg
```

### 2. Monitor Function Logs

```bash
# Stream function logs in real-time
func azure functionapp logstream <your-function-app-name>
```

Look for these log messages:

- "Satisfactory data collection started"
- "Successfully processed endpoint [endpoint-name]"
- "Satisfactory data collection completed"

### 3. Event Hub Data Verification

In Azure Portal:

1. Navigate to your Event Hub namespace
2. Go to "Metrics" section
3. Check "Incoming Messages" metric
4. Should show message activity every 30 seconds

### 4. Application Insights Monitoring

Query Application Insights for function performance:

```kql
requests
| where name == "SatisfactoryDataStreamer"
| project timestamp, duration, success, resultCode
| order by timestamp desc
| take 50
```

Expected results: Should show successful executions every 30 seconds

## Microsoft Fabric Integration Test

### 1. Eventhouse Connection Verification

In your Fabric Eventhouse:

```kql
// Check if data is flowing
SatisfactoryEvents
| take 10
```

Expected result: Should return recent Satisfactory data

### 2. Data Schema Validation

```kql
// Verify data structure
SatisfactoryEvents
| where timestamp > ago(1h)
| summarize count() by endpoint
| order by count_ desc
```

Expected result: Should show counts for each monitored endpoint

### 3. Real-Time Dashboard Test

Create a simple dashboard query:

```kql
SatisfactoryEvents
| where endpoint == "getPower"
| where timestamp > ago(1h)
| extend PowerData = parse_json(data)
| mv-expand PowerData
| project
    timestamp,
    PowerProduction = PowerData.PowerProduction,
    PowerConsumed = PowerData.PowerConsumed
| render timechart
```

Expected result: Should show power production/consumption over time

## Troubleshooting Common Issues

### Function Not Executing

**Symptoms**: No logs in Application Insights, no Event Hub messages

**Solutions**:

1. Check function app is running: `az functionapp show`
2. Verify timer trigger configuration in `host.json`
3. Check for deployment errors in Azure Portal

### FRM Connection Issues

**Symptoms**: HTTP timeout errors in function logs

**Solutions**:

1. Test FRM API manually: `curl http://your-server:8080/getPower`
2. Check firewall/network connectivity
3. Verify FRM web server is started in game

### Event Hub Permission Issues

**Symptoms**: Authentication errors in function logs

**Solutions**:

1. Verify managed identity role assignment
2. Check Event Hub namespace and name configuration
3. Ensure managed identity is enabled on Function App

### Microsoft Fabric Data Issues

**Symptoms**: No data appearing in Eventhouse

**Solutions**:

1. Verify Event Hub connection in Fabric
2. Check ingestion mapping configuration
3. Review data format and schema matching

## Performance Optimization

### Function App Scaling

- **Consumption Plan**: Automatically scales based on demand
- **Premium Plan**: For guaranteed performance and VNet integration
- **Monitoring**: Use Application Insights to track execution times

### Event Hub Throughput

- **Standard Tier**: 1 MB/second or 1000 events/second per throughput unit
- **Partitioning**: Data is partitioned by endpoint type for optimal processing
- **Consumer Groups**: Use dedicated consumer groups for different downstream systems

### Fabric Performance

- **KQL Database**: Configure appropriate retention and cache policies
- **Continuous Export**: Set up automated data archival to Lakehouse for long-term storage
- **Query Optimization**: Use materialized views for frequently accessed aggregations

## Cost Monitoring

### Expected Monthly Costs

- **Event Hub Standard**: ~$11-22/month
- **Function App Consumption**: ~$0-5/month (based on executions)
- **Application Insights**: ~$2-10/month (based on data volume)
- **Microsoft Fabric**: Based on your Fabric licensing model

### Cost Optimization Tips

1. **Timer Frequency**: Adjust from 30 seconds to 1-5 minutes if real-time data isn't critical
2. **Endpoint Selection**: Monitor only essential endpoints to reduce data volume
3. **Data Retention**: Configure appropriate retention policies in both Event Hub and Fabric
4. **Regional Deployment**: Deploy in same region as your Fabric workspace to minimize egress costs

## Next Steps

Once validation is complete:

1. **Create Dashboards**: Build real-time monitoring dashboards in Fabric
2. **Set Up Alerts**: Configure Data Activator for critical factory issues
3. **Historical Analysis**: Set up continuous export to Lakehouse for trend analysis
4. **Automation**: Consider adding automatic factory optimization based on analytics insights
