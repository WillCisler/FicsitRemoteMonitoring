# Satisfactory to Microsoft Fabric - Deployment Script
# This script deploys all the necessary Azure resources to stream Satisfactory data to Microsoft Fabric

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$true)]
    [string]$SatisfactoryServerUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$SatisfactoryServerName = "primary",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourcePrefix = "satisfactory"
)

# Colors for output
$ErrorColor = "Red"
$SuccessColor = "Green"
$InfoColor = "Cyan"
$WarningColor = "Yellow"

function Write-Info {
    param([string]$Message)
    Write-Host $Message -ForegroundColor $InfoColor
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $SuccessColor
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $ErrorColor
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $WarningColor
}

# Main deployment function
function Deploy-SatisfactoryFabricIntegration {
    Write-Info "=== Satisfactory → Microsoft Fabric Integration Deployment ==="
    Write-Info ""
    
    try {
        # Step 1: Validate prerequisites
        Write-Info "1. Validating prerequisites..."
        
        # Check if Azure CLI is installed
        $azVersion = az version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Azure CLI not found. Please install Azure CLI first."
            Write-Info "Download from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
            return
        }
        Write-Success "Azure CLI found"
        
        # Check if logged in to Azure
        $account = az account show 2>$null | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Not logged in to Azure. Please run 'az login' first."
            return
        }
        Write-Success "Logged in to Azure as $($account.user.name)"
        
        # Set subscription if provided
        if ($SubscriptionId) {
            Write-Info "Setting subscription to $SubscriptionId..."
            az account set --subscription $SubscriptionId
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to set subscription"
                return
            }
        }
        
        $currentSub = az account show | ConvertFrom-Json
        Write-Success "Using subscription: $($currentSub.name) ($($currentSub.id))"
        
        # Step 2: Create resource group
        Write-Info ""
        Write-Info "2. Creating resource group..."
        
        $rgExists = az group exists --name $ResourceGroupName
        if ($rgExists -eq "true") {
            Write-Warning "Resource group '$ResourceGroupName' already exists"
        } else {
            az group create --name $ResourceGroupName --location $Location --output none
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Created resource group '$ResourceGroupName'"
            } else {
                Write-Error "Failed to create resource group"
                return
            }
        }
        
        # Step 3: Deploy infrastructure
        Write-Info ""
        Write-Info "3. Deploying Azure infrastructure..."
        Write-Info "   This may take 5-10 minutes..."
        
        $templatePath = Join-Path $PSScriptRoot "infrastructure\satisfactory-fabric-integration.json"
        if (-not (Test-Path $templatePath)) {
            Write-Error "Template file not found: $templatePath"
            return
        }
        
        $deploymentName = "satisfactory-fabric-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        
        $deployment = az deployment group create `
            --resource-group $ResourceGroupName `
            --name $deploymentName `
            --template-file $templatePath `
            --parameters resourcePrefix=$ResourcePrefix `
                        location=$Location `
                        satisfactoryServerUrl=$SatisfactoryServerUrl `
                        satisfactoryServerName=$SatisfactoryServerName `
            --output json | ConvertFrom-Json
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Infrastructure deployed successfully"
            
            # Extract deployment outputs
            $outputs = $deployment.properties.outputs
            $functionAppName = $outputs.functionAppName.value
            $eventHubNamespace = $outputs.eventHubNamespace.value
            $eventHubName = $outputs.eventHubName.value
            
            Write-Info ""
            Write-Info "Deployed Resources:"
            Write-Info "- Function App: $functionAppName"
            Write-Info "- Event Hub Namespace: $eventHubNamespace"
            Write-Info "- Event Hub: $eventHubName"
        } else {
            Write-Error "Infrastructure deployment failed"
            return
        }
        
        # Step 4: Test Satisfactory server connectivity
        Write-Info ""
        Write-Info "4. Testing Satisfactory server connectivity..."
        
        try {
            $response = Invoke-RestMethod -Uri "$SatisfactoryServerUrl/api" -TimeoutSec 10 -ErrorAction Stop
            Write-Success "Successfully connected to Satisfactory server"
            Write-Info "Available endpoints: $($response.Length) found"
        } catch {
            Write-Warning "Could not connect to Satisfactory server at $SatisfactoryServerUrl"
            Write-Warning "Make sure:"
            Write-Warning "  1. Satisfactory is running with FRM mod installed"
            Write-Warning "  2. FRM web server is started: /frm http start"
            Write-Warning "  3. Server URL is correct and accessible"
        }
        
        # Step 5: Display next steps
        Write-Info ""
        Write-Success "=== Deployment Complete! ==="
        Write-Info ""
        Write-Info "Next Steps:"
        Write-Info "1. Deploy the Function App code:"
        Write-Info "   cd azure-integration"
        Write-Info "   func azure functionapp publish $functionAppName"
        Write-Info ""
        Write-Info "2. In Satisfactory, start the FRM web server:"
        Write-Info "   Open console and run: /frm http start"
        Write-Info ""
        Write-Info "3. In Microsoft Fabric:"
        Write-Info "   - Create a new Eventhouse (Real-Time Analytics workspace)"
        Write-Info "   - Create a KQL Database within the Eventhouse"
        Write-Info "   - Add Event Hub as a data source"
        Write-Info "   - Event Hub Namespace: $eventHubNamespace"
        Write-Info "   - Event Hub Name: $eventHubName"
        Write-Info "   - Alternative: Use Lakehouse for batch analytics"
        Write-Info ""
        Write-Info "4. Monitor data flow:"
        Write-Info "   - Function App Logs: https://portal.azure.com/#resource$(az functionapp show --name $functionAppName --resource-group $ResourceGroupName --query id -o tsv)"
        Write-Info "   - Event Hub Metrics: Check message ingestion in Azure portal"
        Write-Info ""
        Write-Info "Estimated monthly cost: $15-30 USD for typical usage"
        
    } catch {
        Write-Error "Deployment failed: $($_.Exception.Message)"
        Write-Info "Check the detailed error message above and retry."
    }
}

# Validation function for parameters
function Test-Parameters {
    $valid = $true
    
    if (-not $SatisfactoryServerUrl.StartsWith("http")) {
        Write-Error "SatisfactoryServerUrl must start with http:// or https://"
        $valid = $false
    }
    
    if ($ResourceGroupName.Length -lt 3 -or $ResourceGroupName.Length -gt 90) {
        Write-Error "ResourceGroupName must be between 3 and 90 characters"
        $valid = $false
    }
    
    $validLocations = @("eastus", "eastus2", "westus", "westus2", "centralus", "northcentralus", "southcentralus", "westcentralus", "northeurope", "westeurope", "eastasia", "southeastasia", "japaneast", "japanwest", "australiaeast", "australiasoutheast", "brazilsouth", "canadacentral", "canadaeast", "uksouth", "ukwest", "francecentral", "germanywestcentral", "norwayeast", "switzerlandnorth", "uaenorth", "southafricanorth", "centralindia", "southindia", "koreacentral", "koreasouth")
    
    if ($Location.ToLower() -notin $validLocations) {
        Write-Warning "Location '$Location' may not be valid. Common locations: eastus2, westus2, northeurope, westeurope"
    }
    
    return $valid
}

# Function to check if FRM mod is installed and working
function Test-FRMConnection {
    param([string]$ServerUrl)
    
    Write-Info "Testing FRM API endpoints..."
    
    $testEndpoints = @("getPower", "getPlayer", "getFactory")
    $workingEndpoints = @()
    
    foreach ($endpoint in $testEndpoints) {
        try {
            $response = Invoke-RestMethod -Uri "$ServerUrl/$endpoint" -TimeoutSec 5 -ErrorAction Stop
            $workingEndpoints += $endpoint
            Write-Success "✓ $endpoint - Working ($($response.Count) items)"
        } catch {
            Write-Warning "✗ $endpoint - Failed: $($_.Exception.Message)"
        }
    }
    
    if ($workingEndpoints.Count -eq 0) {
        Write-Error "No FRM endpoints are responding. Check your setup:"
        Write-Info "1. Is Satisfactory running?"
        Write-Info "2. Is FRM mod installed?"
        Write-Info "3. Is FRM web server started? (Run: /frm http start)"
        return $false
    } else {
        Write-Success "$($workingEndpoints.Count)/$($testEndpoints.Count) test endpoints working"
        return $true
    }
}

# Main execution
Write-Info "Satisfactory → Microsoft Fabric Integration"
Write-Info "Parameters:"
Write-Info "- Resource Group: $ResourceGroupName"
Write-Info "- Location: $Location"
Write-Info "- Satisfactory Server: $SatisfactoryServerUrl"
Write-Info "- Server Name: $SatisfactoryServerName"
Write-Info ""

if (Test-Parameters) {
    # Test FRM connection before deployment
    if ($SatisfactoryServerUrl -and (Test-FRMConnection -ServerUrl $SatisfactoryServerUrl)) {
        Deploy-SatisfactoryFabricIntegration
    } else {
        Write-Warning "Proceeding with deployment despite connection issues..."
        Write-Warning "You can fix the FRM connection later."
        Deploy-SatisfactoryFabricIntegration
    }
} else {
    Write-Error "Parameter validation failed. Please correct the issues and try again."
}
