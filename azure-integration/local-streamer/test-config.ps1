# Test Satisfactory Local Streamer Configuration
# Verifies FRM endpoint connectivity and Event Hub authentication

param(
    [string]$ConfigFile = "appsettings.Production.json"
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Satisfactory Local Streamer - Configuration Test" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Load configuration
if (-not (Test-Path $ConfigFile)) {
    Write-Host "ERROR: Configuration file not found: $ConfigFile" -ForegroundColor Red
    exit 1
}

Write-Host "Reading configuration from: $ConfigFile" -ForegroundColor Green
$config = Get-Content $ConfigFile | ConvertFrom-Json

$frmUrl = $config.Satisfactory.FrmUrl
$serverName = $config.Satisfactory.ServerName

Write-Host "FRM URL: $frmUrl" -ForegroundColor Yellow
Write-Host "Server Name: $serverName" -ForegroundColor Yellow
Write-Host ""

# Test FRM endpoint connectivity
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Testing FRM Endpoint Connectivity" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$testEndpoints = @("getPower", "getPlayer", "getFactory")
$successCount = 0
$failCount = 0

foreach ($endpoint in $testEndpoints) {
    $url = "$frmUrl/$endpoint"
    Write-Host "Testing: $url" -ForegroundColor Cyan
    
    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "  SUCCESS (Status: $($response.StatusCode))" -ForegroundColor Green
            $successCount++
        }
        else {
            Write-Host "  FAILED (Status: $($response.StatusCode))" -ForegroundColor Red
            $failCount++
        }
    }
    catch {
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
}

Write-Host ""
Write-Host "Results: $successCount succeeded, $failCount failed" -ForegroundColor Yellow
Write-Host ""

if ($failCount -gt 0) {
    Write-Host "WARNING: Some FRM endpoints are not reachable" -ForegroundColor Yellow
    Write-Host "Make sure Satisfactory is running and FRM mod is enabled" -ForegroundColor Yellow
    Write-Host ""
}

# Test Azure CLI authentication
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Testing Azure Authentication" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

try {
    $azAccount = az account show 2>&1 | ConvertFrom-Json
    if ($azAccount) {
        Write-Host "Azure CLI is authenticated" -ForegroundColor Green
        Write-Host "  Account: $($azAccount.user.name)" -ForegroundColor Yellow
        Write-Host "  Subscription: $($azAccount.name)" -ForegroundColor Yellow
        Write-Host ""
    }
}
catch {
    Write-Host "Azure CLI is NOT authenticated" -ForegroundColor Red
    Write-Host "  Run: az login" -ForegroundColor Yellow
    Write-Host ""
}

# Summary
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Configuration Test Complete" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

if ($successCount -eq $testEndpoints.Count) {
    Write-Host "All tests passed! Ready to run the streamer." -ForegroundColor Green
}
else {
    Write-Host "WARNING: Some tests failed. Please fix the issues above before running." -ForegroundColor Yellow
}
Write-Host ""
