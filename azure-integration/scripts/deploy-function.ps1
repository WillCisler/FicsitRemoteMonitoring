# Deploy Azure Function App
# This script deploys the Satisfactory Data Streamer Function App

param(
    [Parameter(Mandatory=$true)]
    [string]$FunctionAppName,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "satisfactory-fabric-rg"
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Deploying Satisfactory Data Streamer Function App..." -ForegroundColor Green
Write-Host "Function App: $FunctionAppName" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Cyan

# Change to function app directory
$functionAppPath = Join-Path $PSScriptRoot "..\function-app"
Push-Location $functionAppPath

try {
    Write-Host "📁 Current directory: $(Get-Location)" -ForegroundColor Yellow
    
    # Verify function app exists
    Write-Host "🔍 Verifying Function App exists..." -ForegroundColor Yellow
    $functionApp = az functionapp show --name $FunctionAppName --resource-group $ResourceGroupName --query "name" -o tsv 2>$null
    
    if (-not $functionApp) {
        throw "Function App '$FunctionAppName' not found in resource group '$ResourceGroupName'"
    }
    
    Write-Host "✅ Function App found: $functionApp" -ForegroundColor Green
    
    # Clean build artifacts
    Write-Host "🧹 Cleaning build artifacts..." -ForegroundColor Yellow
    Remove-Item -Path "bin" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "obj" -Recurse -Force -ErrorAction SilentlyContinue
    
    # Deploy function
    Write-Host "🚀 Deploying function code..." -ForegroundColor Yellow
    func azure functionapp publish $FunctionAppName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Function deployment completed successfully!" -ForegroundColor Green
        
        # List deployed functions
        Write-Host "📋 Deployed functions:" -ForegroundColor Cyan
        func azure functionapp list-functions $FunctionAppName
    } else {
        throw "Function deployment failed with exit code $LASTEXITCODE"
    }
    
} catch {
    Write-Host "❌ Deployment failed: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}

Write-Host "🎉 Deployment process completed!" -ForegroundColor Green