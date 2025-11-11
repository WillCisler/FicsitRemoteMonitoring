# Satisfactory → Microsoft Fabric Deployment Guide & Troubleshooting

This comprehensive guide covers deployment, validation, and troubleshooting based on real-world deployment experience and common issues.

## 🚀 Quick Start Deployment

### Prerequisites

- Azure CLI installed and authenticated
- Azure Functions Core Tools v4.x
- .NET 8.0 SDK
- Satisfactory game with FicsitRemoteMonitoring mod installed

### Automated Deployment

The easiest way to deploy is using our PowerShell automation script:

```powershell
cd azure-integration/scripts
.\Deploy-SatisfactoryFabric.ps1 -ResourceGroupName "ficsit-production" -Location "westus3" -SatisfactoryServerUrl "http://your-server:8080" -SatisfactoryServerName "your-server-name"
```

This script will:

- ✅ Validate prerequisites and connectivity
- ✅ Create/update resource group
- ✅ Deploy Azure infrastructure with managed identity
- ✅ Deploy function code
- ✅ Test connectivity to your Satisfactory server

## 📋 Manual Deployment Steps

If you prefer manual control or the automated script fails:

### 1. Deploy Infrastructure

```bash
# Create resource group
az group create --name "ficsit-production" --location "westus3"

# Deploy infrastructure
az deployment group create \
  --resource-group "ficsit-production" \
  --template-file "azure-integration/infrastructure/satisfactory-fabric-integration-fixed.bicep" \
  --parameters "@azure-integration/infrastructure/parameters.json"
```

### 2. Deploy Function Code

```bash
cd azure-integration/function-app
func azure functionapp publish <function-app-name-from-output>
```

### 3. Verify Deployment

```bash
# Check functions are discovered
func azure functionapp list-functions <function-app-name>

# Test endpoint connectivity
cd ../
.\test-endpoints.ps1 -SatisfactoryServerUrl "http://your-server:8080" -ServerName "your-server"
```

## 🔧 Architecture Overview

```
Satisfactory + FRM Mod → Azure Functions (Timer Triggered) → Event Hubs → Microsoft Fabric
                              ↓
                     Application Insights (Monitoring)
```

### Deployed Resources

- **Function App**: 4 timer-triggered functions with different frequencies
- **Event Hub Namespace**: High-throughput message ingestion
- **Storage Account**: Function runtime storage (managed identity)
- **Application Insights**: Monitoring and telemetry
- **Role Assignments**: Managed identity permissions for security

### Function Schedule

- `SatisfactoryDataStreamer`: Every 30 seconds (main data collection)
- `SatisfactoryDataStreamer_HighFreq`: Every 10 seconds (high-frequency monitoring)
- `SatisfactoryDataStreamer_MediumFreq`: Every 2 minutes (medium-frequency data)
- `SatisfactoryDataStreamer_StandardFreq`: Every 5 minutes (standard monitoring)

## 🚨 Common Issues & Troubleshooting

### Issue 1: KeyBasedAuthenticationNotPermitted

**Symptoms**: Function logs show storage authentication errors

**Root Cause**: Azure security policy prevents storage account key usage

**Solution**: The latest template uses managed identity (already implemented)

- Storage account has `allowSharedKeyAccess: false`
- Function app uses `AzureWebJobsStorage__accountName` + `AzureWebJobsStorage__credential: 'managedidentity'`
- Proper RBAC roles assigned automatically

### Issue 2: Functions Not Discovered

**Symptoms**: `func azure functionapp list-functions` shows no functions

**Root Cause**: File share access issues or storage configuration problems

**Solution**:

1. Remove problematic settings: `WEBSITE_CONTENTAZUREFILECONNECTIONSTRING` and `WEBSITE_CONTENTSHARE`
2. Let Azure handle file shares automatically
3. Redeploy function code after infrastructure update

### Issue 3: 403 Forbidden Storage Errors

**Symptoms**: Deployment fails with storage file share access denied

**Root Cause**: Template trying to create file shares with connection strings

**Solution**: Use minimal storage configuration approach

- Remove file share settings from app settings
- Use managed identity for all storage access
- Let Azure Functions runtime handle file shares

### Issue 4: FRM Connectivity Issues

**Symptoms**: Functions execute but can't reach Satisfactory server

**Diagnosis**:

```powershell
# Test FRM endpoints directly
.\test-endpoints.ps1 -SatisfactoryServerUrl "http://your-server:8080" -ShowRawJson
```

**Common Solutions**:

- Ensure Satisfactory is running
- Verify FRM mod is installed and enabled
- Start FRM web server: `/frm http start` in Satisfactory console
- Check firewall/network connectivity
- Verify server URL format (include http://)

### Issue 5: Event Hub Data Not Flowing

**Diagnosis Steps**:

1. **Check Function Execution**:

   ```bash
   # View real-time logs
   func azure functionapp logstream <function-app-name>
   ```

2. **Check Event Hub Metrics**:

   - Go to Azure Portal → Event Hubs Namespace
   - View "Metrics" for incoming messages
   - Check "Overview" for activity

3. **Verify Managed Identity Permissions**:
   ```bash
   # List role assignments
   az role assignment list --assignee <function-app-principal-id> --scope <event-hub-resource-id>
   ```

**Solutions**:

- Ensure managed identity has "Azure Event Hubs Data Sender" role
- Check Event Hub namespace allows managed identity access
- Verify function app system-assigned identity is enabled

## ✅ Validation Checklist

### Infrastructure Validation

- [ ] Resource group created successfully
- [ ] Function App shows "Running" status
- [ ] Event Hub Namespace is active
- [ ] Storage account created with managed identity enabled
- [ ] Application Insights connected

### Function Validation

- [ ] All 4 timer functions discovered: `func azure functionapp list-functions <app-name>`
- [ ] Functions show timer trigger configuration
- [ ] No deployment errors in function publish output

### Connectivity Validation

- [ ] FRM endpoints respond: `.\test-endpoints.ps1 -SatisfactoryServerUrl "http://your-server:8080"`
- [ ] Function logs show successful execution (not just timeouts)
- [ ] Event Hub shows incoming message activity
- [ ] Application Insights receives telemetry

### Data Flow Validation

- [ ] Functions execute on schedule (check Application Insights)
- [ ] Event Hub metrics show message ingestion
- [ ] No authentication errors in function logs
- [ ] Satisfactory data appears in Event Hub messages

## 🔍 Monitoring & Debugging

### Real-time Function Monitoring

```bash
# Stream function logs
func azure functionapp logstream <function-app-name>

# Check specific function configuration
az functionapp function show --name <function-app-name> --resource-group <rg-name> --function-name SatisfactoryDataStreamer
```

### Event Hub Monitoring

```bash
# Check Event Hub activity
az eventhubs eventhub show --name satisfactory-data --namespace-name <namespace-name> --resource-group <rg-name>
```

### Application Insights Queries

```kql
// Function execution tracking
traces
| where message contains "SatisfactoryDataStreamer"
| order by timestamp desc
| take 20

// Error tracking
exceptions
| where timestamp > ago(1h)
| project timestamp, type, message, details
```

## 📊 Performance Optimization

### Function App Settings

The deployment uses optimized settings:

- **Consumption Plan**: Cost-effective for periodic data collection
- **Managed Identity**: Secure, no credential management
- **Application Insights**: Comprehensive monitoring
- **Retry Policies**: Built-in resilience

### Event Hub Configuration

- **Standard Tier**: Good balance of cost and performance
- **Single Partition**: Sufficient for Satisfactory data volumes
- **7-day Retention**: Adequate for most analytics scenarios

### Cost Optimization

Estimated monthly costs (typical usage):

- Function App (Consumption): ~$5-15
- Event Hub (Standard): ~$10-20
- Storage Account: ~$1-5
- Application Insights: ~$5-10
- **Total**: ~$25-50/month

## 🔗 Next Steps

After successful deployment:

1. **[Set up Microsoft Fabric](FABRIC-SETUP.md)** to consume Event Hub data
2. **[Configure endpoint frequencies](ENDPOINT-FREQUENCY-CONFIG.md)** based on your needs
3. **Monitor performance** and adjust timer schedules if needed
4. **Build dashboards** for real-time factory monitoring

## 💡 Best Practices

- **Use managed identity** for all Azure service authentication
- **Monitor costs** with Azure Cost Management
- **Set up alerts** for function failures or high costs
- **Test changes** in a separate resource group first
- **Document customizations** for your specific setup

## 🆘 Getting Help

If you encounter issues not covered here:

1. **Check function logs** first with `func azure functionapp logstream`
2. **Test FRM connectivity** with `.\test-endpoints.ps1`
3. **Review Azure Portal** for resource status and metrics
4. **Check Application Insights** for detailed error information

Common Azure locations that work well: `eastus2`, `westus2`, `northeurope`, `westeurope`
