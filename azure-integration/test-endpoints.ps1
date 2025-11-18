# Test Satisfactory FRM HTTP Endpoints
# This script tests the FRM endpoints and shows the data structure
# Includes load testing mode to determine optimal Azure Function frequencies

param(
    [Parameter(Mandatory=$true)]
    [string]$SatisfactoryServerUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerName = "test-server",
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowRawJson,
    
    [Parameter(Mandatory=$false)]
    [switch]$SaveToFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$LoadTest,
    
    [Parameter(Mandatory=$false)]
    [int]$LoadTestDurationMinutes = 5,
    
    [Parameter(Mandatory=$false)]
    [int]$DelayBetweenRequestsMs = 2000
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
Write-Host "Delay Between Requests: $DelayBetweenRequestsMs ms" -ForegroundColor Cyan

if ($LoadTest) {
    Write-Host "Load Test Mode: Enabled ($LoadTestDurationMinutes minutes)" -ForegroundColor Magenta
}

Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host ("-" * 60)

# Load test mode - run continuously and gather timing statistics
if ($LoadTest) {
    $endTime = (Get-Date).AddMinutes($LoadTestDurationMinutes)
    $testResults = @{}
    $iteration = 0
    
    # Initialize statistics for each endpoint
    foreach ($endpointName in $endpoints.Keys) {
        $testResults[$endpointName] = @{
            SuccessCount = 0
            FailureCount = 0
            ResponseTimes = @()
            Errors = @()
        }
    }
    
    Write-Host "Starting load test until $(Get-Date $endTime -Format 'HH:mm:ss')..." -ForegroundColor Yellow
    Write-Host ""
    
    while ((Get-Date) -lt $endTime) {
        $iteration++
        $iterationStart = Get-Date
        
        Write-Host "[Iteration $iteration] $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
        
        foreach ($endpointName in $endpoints.Keys) {
            $endpoint = $endpoints[$endpointName]
            $url = "$SatisfactoryServerUrl$endpoint"
            
            try {
                $startTime = Get-Date
                $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 30
                $endTime = Get-Date
                $responseTime = ($endTime - $startTime).TotalMilliseconds
                
                $testResults[$endpointName].SuccessCount++
                $testResults[$endpointName].ResponseTimes += $responseTime
                
                Write-Host "  ✅ $endpointName - ${responseTime}ms" -ForegroundColor Green
                
            } catch {
                $testResults[$endpointName].FailureCount++
                $testResults[$endpointName].Errors += $_.Exception.Message
                Write-Host "  ❌ $endpointName - $($_.Exception.Message)" -ForegroundColor Red
            }
            
            Start-Sleep -Milliseconds $DelayBetweenRequestsMs
        }
        
        $iterationTime = ((Get-Date) - $iterationStart).TotalSeconds
        Write-Host "  Iteration completed in ${iterationTime}s" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Display load test results and recommendations
    Write-Host ("-" * 60)
    Write-Host "📊 Load Test Results & Frequency Recommendations" -ForegroundColor Green
    Write-Host ("-" * 60)
    
    foreach ($endpointName in $endpoints.Keys | Sort-Object) {
        $stats = $testResults[$endpointName]
        $total = $stats.SuccessCount + $stats.FailureCount
        $successRate = if ($total -gt 0) { [math]::Round(($stats.SuccessCount / $total) * 100, 2) } else { 0 }
        
        if ($stats.ResponseTimes.Count -gt 0) {
            $avgResponseTime = [math]::Round(($stats.ResponseTimes | Measure-Object -Average).Average, 2)
            $maxResponseTime = [math]::Round(($stats.ResponseTimes | Measure-Object -Maximum).Maximum, 2)
            $minResponseTime = [math]::Round(($stats.ResponseTimes | Measure-Object -Minimum).Minimum, 2)
        } else {
            $avgResponseTime = 0
            $maxResponseTime = 0
            $minResponseTime = 0
        }
        
        Write-Host "`n${endpointName}:" -ForegroundColor Yellow
        Write-Host "  Success Rate: $successRate% ($($stats.SuccessCount)/$total)" -ForegroundColor $(if ($successRate -ge 95) { "Green" } elseif ($successRate -ge 80) { "Yellow" } else { "Red" })
        Write-Host "  Response Time: Avg=${avgResponseTime}ms, Min=${minResponseTime}ms, Max=${maxResponseTime}ms" -ForegroundColor Gray
        
        # Recommend frequency based on success rate and response time
        if ($successRate -lt 80) {
            Write-Host "  ⚠️  RECOMMENDATION: Disable or use very low frequency (>5 minutes)" -ForegroundColor Red
        } elseif ($avgResponseTime -lt 500) {
            Write-Host "  ✅ RECOMMENDATION: Can use high frequency (1-5 seconds)" -ForegroundColor Green
        } elseif ($avgResponseTime -lt 2000) {
            Write-Host "  ⚡ RECOMMENDATION: Medium frequency (10-30 seconds)" -ForegroundColor Cyan
        } else {
            Write-Host "  🐌 RECOMMENDATION: Low frequency (1-5 minutes)" -ForegroundColor Yellow
        }
        
        if ($stats.Errors.Count -gt 0) {
            $uniqueErrors = $stats.Errors | Select-Object -Unique
            Write-Host "  Errors encountered: $($uniqueErrors.Count) unique" -ForegroundColor Red
        }
    }
    
    Write-Host "`n" + ("-" * 60)
    Write-Host "💡 Azure Function Frequency Recommendations:" -ForegroundColor Green
    Write-Host ("-" * 60)
    
    # Categorize endpoints by recommended frequency
    $highFreq = @()
    $mediumFreq = @()
    $standardFreq = @()
    $disabled = @()
    
    foreach ($endpointName in $endpoints.Keys) {
        $stats = $testResults[$endpointName]
        $total = $stats.SuccessCount + $stats.FailureCount
        $successRate = if ($total -gt 0) { ($stats.SuccessCount / $total) * 100 } else { 0 }
        $avgResponseTime = if ($stats.ResponseTimes.Count -gt 0) { ($stats.ResponseTimes | Measure-Object -Average).Average } else { 0 }
        
        if ($successRate -lt 80) {
            $disabled += $endpointName
        } elseif ($avgResponseTime -lt 500) {
            $highFreq += $endpointName
        } elseif ($avgResponseTime -lt 2000) {
            $mediumFreq += $endpointName
        } else {
            $standardFreq += $endpointName
        }
    }
    
    Write-Host "`nHigh Frequency (1-5 seconds):" -ForegroundColor Green
    $highFreq | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
    
    Write-Host "`nMedium Frequency (10-30 seconds):" -ForegroundColor Cyan
    $mediumFreq | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
    
    Write-Host "`nStandard Frequency (1-5 minutes):" -ForegroundColor Yellow
    $standardFreq | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
    
    if ($disabled.Count -gt 0) {
        Write-Host "`n⚠️  Consider Disabling (Low Success Rate):" -ForegroundColor Red
        $disabled | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
    }
    
    # Save detailed results if requested
    if ($SaveToFile) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $filename = "frm-load-test-$timestamp.json"
        $filepath = Join-Path (Get-Location) $filename
        
        $testResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $filepath -Encoding UTF8
        Write-Host "`n💾 Detailed results saved to: $filepath" -ForegroundColor Cyan
    }
    
    return
}

# Standard single-pass test mode
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
    
    Start-Sleep -Milliseconds $DelayBetweenRequestsMs  # Configurable delay between requests to avoid server overload
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
Write-Host "  # Standard single test:" -ForegroundColor Gray
Write-Host "  .\test-endpoints.ps1 -SatisfactoryServerUrl 'http://136.243.46.118:26988' -ServerName 'sands'" -ForegroundColor Gray
Write-Host "  .\test-endpoints.ps1 -SatisfactoryServerUrl 'http://136.243.46.118:26988' -ShowRawJson" -ForegroundColor Gray
Write-Host "  .\test-endpoints.ps1 -SatisfactoryServerUrl 'http://136.243.46.118:26988' -SaveToFile" -ForegroundColor Gray
Write-Host ""
Write-Host "  # Load test with frequency recommendations:" -ForegroundColor Gray
Write-Host "  .\test-endpoints.ps1 -SatisfactoryServerUrl 'http://136.243.46.118:26988' -LoadTest -LoadTestDurationMinutes 5" -ForegroundColor Gray
Write-Host "  .\test-endpoints.ps1 -SatisfactoryServerUrl 'http://136.243.46.118:26988' -LoadTest -DelayBetweenRequestsMs 3000" -ForegroundColor Gray
Write-Host "  .\test-endpoints.ps1 -SatisfactoryServerUrl 'http://136.243.46.118:26988' -LoadTest -SaveToFile" -ForegroundColor Gray