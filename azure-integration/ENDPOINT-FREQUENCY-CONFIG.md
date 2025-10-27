# Satisfactory Data Streamer - Endpoint Frequency Configuration

This document explains how to configure the frequency of different FRM API endpoints without needing to understand CRON expressions.

## Current Configuration

### High Frequency (Every 500ms)

**Real-time critical data**

- `getPower` - Power grid status monitoring
- `getPlayer` - Player status and location tracking

### Medium Frequency (Every 5 seconds)

**Semi-frequent updates**

- `getGenerators` - Power generation status
- `getVehicles` - Train/truck/drone status
- `getSessionInfo` - Session metadata

### Standard Frequency (Every 30 seconds)

**Less critical data**

- `getFactory` - All factory buildings
- `getExtractor` - Resource extraction rates
- `getBelts` - Conveyor belt networks
- `getLifts` - Conveyor lifts
- `getPipes` - Pipeline networks
- `getCables` - Power cables
- `getTrainRails` - Railway connections
- `getHypertube` - Hyperloop networks
- `getSplitterMerger` - Factory connection points
- `getThroughputCounter` - Flow monitoring

## How to Change Frequencies

### Option 1: Move Endpoints Between Categories

1. Open `SatisfactoryDataStreamer.cs`
2. Find the endpoint arrays (lines ~42-67)
3. Move endpoints between `_highFrequencyEndpoints`, `_mediumFrequencyEndpoints`, and `_standardFrequencyEndpoints`

### Option 2: Change Timer Frequencies

1. Find the Function attributes (lines ~110-125)
2. Modify the timer expressions:

**Common Timer Expressions:**

- Every 500ms: `"*/500 * * * * *"`
- Every 1 second: `"*/1 * * * * *"`
- Every 2 seconds: `"*/2 * * * * *"`
- Every 5 seconds: `"*/5 * * * * *"`
- Every 10 seconds: `"*/10 * * * * *"`
- Every 30 seconds: `"*/30 * * * * *"`
- Every minute: `"0 * * * * *"`

## Examples

### Make Power Monitoring Even Faster (250ms)

```csharp
[Function("SatisfactoryDataStreamer_HighFreq")]
public async Task RunHighFrequency([TimerTrigger("*/250 * * * * *")] TimerInfo myTimer)
```

### Move Factory Data to Medium Frequency (5 seconds)

Move `"getFactory"` from `_standardFrequencyEndpoints` to `_mediumFrequencyEndpoints` array.

### Create Ultra-High Frequency for Player Only (100ms)

1. Create new endpoint array: `_ultraHighFrequencyEndpoints = { "getPlayer" };`
2. Add new function:

```csharp
[Function("SatisfactoryDataStreamer_UltraHighFreq")]
public async Task RunUltraHighFrequency([TimerTrigger("*/100 * * * * *")] TimerInfo myTimer)
{
    await RunDataCollection(_ultraHighFrequencyEndpoints, "UltraHighFreq");
}
```

## Performance Considerations

- **High frequency (≤1s)**: Use only for critical real-time data
- **Medium frequency (1-10s)**: Good for status monitoring
- **Standard frequency (≥30s)**: Suitable for configuration and bulk data

Monitor Azure Function costs and FRM server load when using very high frequencies.
