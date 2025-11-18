# Quick Start Script for Satisfactory Local Streamer
# Builds, configures, and runs the application in one step

param(
    [switch]$Build,
    [switch]$Test,
    [switch]$Run,
    [switch]$Service,
    [string]$Environment = "Production"
)

$ErrorActionPreference = "Stop"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Satisfactory Local Data Streamer - Quick Start" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Build the application
if ($Build -or (-not (Test-Path "publish/SatisfactoryLocalStreamer.exe"))) {
    Write-Host "Building application..." -ForegroundColor Cyan
    dotnet restore
    dotnet publish -c Release -o publish
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ Build successful" -ForegroundColor Green
    Write-Host ""
}

# Test configuration
if ($Test) {
    Write-Host "Testing configuration..." -ForegroundColor Cyan
    & ".\test-config.ps1" -ConfigFile "appsettings.$Environment.json"
    Write-Host ""
}

# Run the application
if ($Run) {
    Write-Host "Starting application in console mode..." -ForegroundColor Cyan
    Write-Host "Environment: $Environment" -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
    Write-Host ""
    
    $env:DOTNET_ENVIRONMENT = $Environment
    & ".\publish\SatisfactoryLocalStreamer.exe"
}

# Install as Windows Service
if ($Service) {
    # Check if running as Administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "ERROR: Installing as a service requires Administrator privileges" -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator" -ForegroundColor Yellow
        exit 1
    }
    
    & ".\publish\install-service.ps1"
}

# Show help if no parameters
if (-not ($Build -or $Test -or $Run -or $Service)) {
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "  .\quick-start.ps1 -Build              # Build the application" -ForegroundColor White
    Write-Host "  .\quick-start.ps1 -Test               # Test configuration" -ForegroundColor White
    Write-Host "  .\quick-start.ps1 -Run                # Run in console mode" -ForegroundColor White
    Write-Host "  .\quick-start.ps1 -Service            # Install as Windows Service (requires Admin)" -ForegroundColor White
    Write-Host ""
    Write-Host "Combined:" -ForegroundColor Cyan
    Write-Host "  .\quick-start.ps1 -Build -Test -Run   # Build, test, and run" -ForegroundColor White
    Write-Host ""
    Write-Host "Environment:" -ForegroundColor Cyan
    Write-Host "  -Environment Development              # Use Development settings" -ForegroundColor White
    Write-Host "  -Environment Production               # Use Production settings (default)" -ForegroundColor White
    Write-Host ""
}
