# Uninstall Satisfactory Data Streamer Windows Service
# Must be run as Administrator

param(
    [string]$ServiceName = "SatisfactoryDataStreamer"
)

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Uninstalling Satisfactory Data Streamer Windows Service" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Check if service exists
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if (-not $service) {
    Write-Host "Service '$ServiceName' not found. Nothing to uninstall." -ForegroundColor Yellow
    exit 0
}

Write-Host "Service Name: $ServiceName" -ForegroundColor Green
Write-Host "Current Status: $($service.Status)" -ForegroundColor Yellow
Write-Host ""

$response = Read-Host "Are you sure you want to remove this service? (y/N)"
if ($response -ne 'y' -and $response -ne 'Y') {
    Write-Host "Uninstallation cancelled" -ForegroundColor Yellow
    exit 0
}

try {
    # Stop the service if it's running
    if ($service.Status -eq 'Running') {
        Write-Host "Stopping service..." -ForegroundColor Cyan
        Stop-Service -Name $ServiceName -Force
        Start-Sleep -Seconds 2
        Write-Host "Service stopped" -ForegroundColor Green
    }
    
    # Remove the service
    Write-Host "Removing service..." -ForegroundColor Cyan
    sc.exe delete $ServiceName
    Start-Sleep -Seconds 2
    
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "Service uninstalled successfully!" -ForegroundColor Green
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "NOTE: Log files in 'logs\' directory have NOT been deleted" -ForegroundColor Yellow
    Write-Host ""
}
catch {
    Write-Host "ERROR: Failed to uninstall service" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
