# Satisfactory Data Streamer - Endpoint Frequency Configuration

This document explains how to configure the frequency of different FRM API endpoints and customize the data collection schedule.

## Current Function Configuration

The solution uses 5 separate Azure Functions with different timer schedules:

### High Frequency (Every 1 second) - `SatisfactoryDataStreamer_HighFreq`

**Real-time critical data** - Timer: `"0/1 * * * * *"`

- `getPower` - Power grid status monitoring
- `getPlayer` - Player status and location tracking

### Medium Frequency (Every 5 seconds) - `SatisfactoryDataStreamer_MediumFreq`

**Semi-frequent updates** - Timer: `"0/5 * * * * *"`

- `getGenerators` - Power generation status
- `getVehicles` - Train/truck/drone status
- `getSessionInfo` - Session metadata

### Standard Frequency (Every 30 seconds) - `SatisfactoryDataStreamer_StandardFreq`

**Less critical data** - Timer: `"0/30 * * * * *"`

- `getFactory` - All factory buildings
- `getExtractor` - Resource extraction rates
- `getBelts` - Conveyor belt networks
- `getLifts` - Conveyor lifts
- `getPipes` - Pipeline networks
- `getPump` - Pipeline pumps
- `getCables` - Power cables
- `getHypertube` - Hyperloop networks
- `getSplitterMerger` - Factory connection points
- `getThroughputCounter` - Flow monitoring
- `getPipeJunctions` - Pipeline junction points
- `getFrackingActivator` - Resource Well Pressurizers
- `getTrainStation` - Train station status and cargo
- `getTruckStation` - Truck station status and cargo

### Hourly Frequency (Every 1 hour) - `SatisfactoryDataStreamer_HourlyFreq`

**Static game configuration data** - Timer: `"0 0 * * * *"` (top of every hour)

- `getRecipes` - All available recipes ⚠️ **Runs on game thread** (but data is chunked and smaller than getFactory)

> **Note:** The `getRecipes` endpoint runs on the game thread, which means it blocks game execution while collecting data. However, this endpoint is scheduled hourly because:
>
> - Recipe data is static and rarely changes (only with game updates or mod installations)
> - The data is automatically chunked for efficient streaming
> - The dataset is smaller than `getFactory` which runs every 30 seconds
> - One-hour intervals minimize any potential performance impact on the game server

### Legacy Function (Every 30 seconds) - `SatisfactoryDataStreamer`

**Backward compatibility** - Timer: `"0/30 * * * * *"`

- Redirects to standard frequency function
- Can be removed in future versions

## How to Change Frequencies

### Option 1: Move Endpoints Between Categories

1. Open `SatisfactoryDataStreamer.cs`
2. Find the endpoint arrays (lines ~42-77)
3. Move endpoints between `_highFrequencyEndpoints`, `_mediumFrequencyEndpoints`, `_standardFrequencyEndpoints`, and `_hourlyFrequencyEndpoints`

### Option 2: Change Timer Frequencies

1. Find the Function attributes (lines ~110-132)
2. Modify the timer expressions:

**Common Timer Expressions:**

- Every 500ms: `"*/500 * * * * *"`
- Every 1 second: `"*/1 * * * * *"`
- Every 2 seconds: `"*/2 * * * * *"`
- Every 5 seconds: `"*/5 * * * * *"`
- Every 10 seconds: `"*/10 * * * * *"`
- Every 30 seconds: `"*/30 * * * * *"`
- Every minute: `"0 * * * * *"`
- Every hour: `"0 0 * * * *"`
- Every 6 hours: `"0 0 */6 * * *"`
- Every day at midnight: `"0 0 0 * * *"`

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
- **Hourly frequency (≥1 hour)**: For static game configuration data that rarely changes

### Game Thread Endpoints

Some endpoints run on the game thread and block game execution during data collection. These should be scheduled less frequently:

- `getRecipes` - Currently scheduled hourly (recommended minimum: 1 hour)
- `getSchematics` - Not currently scheduled (consider hourly if needed)
- `getResearchTrees` - Not currently scheduled (consider hourly if needed)
- `getSessionInfo` - Currently scheduled at 5 seconds (lightweight despite game thread usage)

Monitor Azure Function costs and FRM server load when using very high frequencies.
