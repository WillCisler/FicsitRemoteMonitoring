# Install Satisfactory Data Streamer as a Windows Service
# Must be run as Administrator

param(
    [string]$ServiceName = "SatisfactoryDataStreamer",
    [string]$DisplayName = "Satisfactory Data Streamer",
    [string]$Description = "Streams Satisfactory FRM data to Azure Event Hub",
    [string]$ExecutablePath = ".\SatisfactoryLocalStreamer.exe"
)

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Installing Satisfactory Data Streamer as Windows Service" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Get the full path to the executable
$fullPath = Resolve-Path $ExecutablePath -ErrorAction SilentlyContinue
if (-not $fullPath) {
    Write-Host "ERROR: Executable not found at: $ExecutablePath" -ForegroundColor Red
    Write-Host "Please build the project first with: dotnet publish -c Release" -ForegroundColor Yellow
    exit 1
}

Write-Host "Executable: $fullPath" -ForegroundColor Green
Write-Host "Service Name: $ServiceName" -ForegroundColor Green
Write-Host "Display Name: $DisplayName" -ForegroundColor Green
Write-Host ""

# Check if service already exists
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "WARNING: Service '$ServiceName' already exists" -ForegroundColor Yellow
    Write-Host "Current Status: $($existingService.Status)" -ForegroundColor Yellow
    
    $response = Read-Host "Do you want to reinstall? This will stop and remove the existing service. (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Installation cancelled" -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Stopping existing service..." -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    Write-Host "Removing existing service..." -ForegroundColor Yellow
    sc.exe delete $ServiceName
    Start-Sleep -Seconds 2
}

# Create the service
Write-Host "Creating Windows Service..." -ForegroundColor Cyan
try {
    New-Service -Name $ServiceName `
                -BinaryPathName $fullPath `
                -DisplayName $DisplayName `
                -Description $Description `
                -StartupType Automatic `
                -ErrorAction Stop
    
    Write-Host "Service created successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Configure service recovery options (restart on failure)
    Write-Host "Configuring service recovery options..." -ForegroundColor Cyan
    sc.exe failure $ServiceName reset= 86400 actions= restart/60000/restart/60000/restart/60000
    
    Write-Host "Service recovery configured (auto-restart on failure)" -ForegroundColor Green
    Write-Host ""
    
    # Ask if user wants to start the service now
    $response = Read-Host "Do you want to start the service now? (Y/n)"
    if ($response -ne 'n' -and $response -ne 'N') {
        Write-Host "Starting service..." -ForegroundColor Cyan
        Start-Service -Name $ServiceName
        Start-Sleep -Seconds 2
        
        $service = Get-Service -Name $ServiceName
        Write-Host "Service Status: $($service.Status)" -ForegroundColor Green
        Write-Host ""
        Write-Host "Check logs in: logs\satisfactory-streamer-*.log" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "Installation Complete!" -ForegroundColor Green
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Useful Commands:" -ForegroundColor Cyan
    Write-Host "  Start Service:   Start-Service -Name $ServiceName" -ForegroundColor White
    Write-Host "  Stop Service:    Stop-Service -Name $ServiceName" -ForegroundColor White
    Write-Host "  Restart Service: Restart-Service -Name $ServiceName" -ForegroundColor White
    Write-Host "  Check Status:    Get-Service -Name $ServiceName" -ForegroundColor White
    Write-Host "  View Logs:       Get-Content logs\satisfactory-streamer-*.log -Tail 50" -ForegroundColor White
    Write-Host ""
    
}
catch {
    Write-Host "ERROR: Failed to create service" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
