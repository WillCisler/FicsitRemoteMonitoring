# Test Satisfactory FRM HTTP Endpoints
# This script tests the FRM endpoints and shows the data structure

param(
    [Parameter(Mandatory=$true)]
    [string]$SatisfactoryServerUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerName = "test-server",
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowRawJson,
    
    [Parameter(Mandatory=$false)]
    [switch]$SaveToFile
)

# FRM API endpoints - organized by frequency tier
$endpoints = @{
    # High-frequency endpoints (every 1 second)
    "getPower" = "/getPower"
    "getPlayer" = "/getPlayer"
    
    # Medium-frequency endpoints (every 5 seconds)
    "getGenerators" = "/getGenerators"
    "getVehicles" = "/getVehicles"
    "getSessionInfo" = "/getSessionInfo"
    
    # Standard-frequency endpoints (every 30 seconds)
    "getFactory" = "/getFactory"
    "getExtractor" = "/getExtractor"
    "getBelts" = "/getBelts"
    "getLifts" = "/getLifts"
    "getPipes" = "/getPipes"
    "getPumps" = "/getPumps"
    "getSplitterMerger" = "/getSplitterMerger"
    "getCables" = "/getCables"
    "getTrainRails" = "/getTrainRails"
    "getHypertube" = "/getHypertube"
    "getThroughputCounter" = "/getThroughputCounter"
}

Write-Host "🔍 Testing Satisfactory FRM Endpoints" -ForegroundColor Green
Write-Host "Server: $SatisfactoryServerUrl" -ForegroundColor Cyan
Write-Host "Server Name: $ServerName" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host ("-" * 60)

$results = @{}
$allSuccess = $true

foreach ($endpointName in $endpoints.Keys) {
    $endpoint = $endpoints[$endpointName]
    $url = "$SatisfactoryServerUrl$endpoint"
    
    Write-Host "Testing $endpointName..." -ForegroundColor Yellow -NoNewline
    
    try {
        # Test the endpoint with timeout
        $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10
        
        Write-Host " ✅ SUCCESS" -ForegroundColor Green
        
        # Store result
        $results[$endpointName] = @{
            Success = $true
            Data = $response
            Url = $url
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
        
        # Show basic info about the response
        if ($response -is [array]) {
            Write-Host "  → Array with $($response.Count) items" -ForegroundColor Gray
        } elseif ($response -is [hashtable] -or $response.GetType().Name -eq 'PSCustomObject') {
            $propCount = ($response | Get-Member -MemberType Properties).Count
            Write-Host "  → Object with $propCount properties" -ForegroundColor Gray
        } else {
            Write-Host "  → Type: $($response.GetType().Name)" -ForegroundColor Gray
        }
        
        # Show raw JSON if requested
        if ($ShowRawJson) {
            Write-Host "  Raw JSON:" -ForegroundColor Cyan
            $jsonOutput = $response | ConvertTo-Json -Depth 10
            Write-Host "  $jsonOutput" -ForegroundColor White
        }
        
    } catch {
        Write-Host " ❌ FAILED" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        
        $allSuccess = $false
        $results[$endpointName] = @{
            Success = $false
            Error = $_.Exception.Message
            Url = $url
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
    }
    
    Start-Sleep -Milliseconds 8000  # 8w second delay between requests to avoid server overload
}

Write-Host ("-" * 60)

if ($allSuccess) {
    Write-Host "🎉 All endpoints responded successfully!" -ForegroundColor Green
    
    # Show data structure summary
    Write-Host "`n📊 Data Structure Summary:" -ForegroundColor Green
    foreach ($endpointName in $results.Keys) {
        if ($results[$endpointName].Success) {
            $data = $results[$endpointName].Data
            Write-Host "`n${endpointName}:" -ForegroundColor Yellow
            
            if ($data -is [array] -and $data.Count -gt 0) {
                # Show first item structure for arrays
                $firstItem = $data[0]
                $properties = $firstItem | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name
                Write-Host "  Array of $($data.Count) items, each with properties:" -ForegroundColor Gray
                foreach ($prop in $properties) {
                    $value = $firstItem.$prop
                    $type = if ($value -eq $null) { "null" } else { $value.GetType().Name }
                    Write-Host "    - $prop ($type)" -ForegroundColor Gray
                }
            } elseif ($data -is [hashtable] -or $data.GetType().Name -eq 'PSCustomObject') {
                # Show object properties
                $properties = $data | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name
                Write-Host "  Object with properties:" -ForegroundColor Gray
                foreach ($prop in $properties) {
                    $value = $data.$prop
                    $type = if ($value -eq $null) { "null" } else { $value.GetType().Name }
                    Write-Host "    - $prop ($type)" -ForegroundColor Gray
                }
            }
        }
    }
    
} else {
    Write-Host "❌ Some endpoints failed. Check FRM setup:" -ForegroundColor Red
    Write-Host "1. Is Satisfactory running?" -ForegroundColor Yellow
    Write-Host "2. Is FRM mod installed and enabled?" -ForegroundColor Yellow
    Write-Host "3. Is FRM web server started? Run: /frm http start" -ForegroundColor Yellow
    Write-Host "4. Is the server URL correct and accessible?" -ForegroundColor Yellow
}

# Save results to file if requested
if ($SaveToFile) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $filename = "frm-test-results-$timestamp.json"
    $filepath = Join-Path (Get-Location) $filename
    
    $testResults = @{
        TestInfo = @{
            ServerUrl = $SatisfactoryServerUrl
            ServerName = $ServerName
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            AllSuccess = $allSuccess
        }
        Results = $results
    }
    
    $testResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $filepath -Encoding UTF8
    Write-Host "`n💾 Results saved to: $filepath" -ForegroundColor Cyan
}

Write-Host "`n🔧 Example usage:" -ForegroundColor Cyan
Write-Host "  .\test-endpoints.ps1 -SatisfactoryServerUrl 'http://136.243.46.118:8080' -ServerName 'sands'" -ForegroundColor Gray
Write-Host "  .\test-endpoints.ps1 -SatisfactoryServerUrl 'http://136.243.46.118:8080' -ShowRawJson" -ForegroundColor Gray
Write-Host "  .\test-endpoints.ps1 -SatisfactoryServerUrl 'http://136.243.46.118:8080' -SaveToFile" -ForegroundColor Gray