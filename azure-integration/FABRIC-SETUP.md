# Microsoft Fabric Eventhouse Setup Guide

This guide walks you through setting up Microsoft Fabric to receive and analyze real-time Satisfactory data from your Azure Event Hub.

## Prerequisites

- **Microsoft Fabric workspace** with Real-Time Analytics enabled
- **Azure Event Hub** deployed (from main deployment)
- **Power BI Premium** or **Fabric Trial** license

## Architecture Decision Guide

Choose the right Fabric approach based on your use case:

### 1. **Eventhouse** (Recommended for Real-Time)

- **Best for**: Live dashboards, real-time alerts, streaming analytics
- **Use case**: Monitor factory performance, power issues, player activity as it happens
- **Technology**: KQL Database with real-time ingestion
- **Data retention**: 7-365 days (configurable)
- **Query language**: KQL (Kusto Query Language)

### 2. **Lakehouse** (Recommended for Historical Analysis)

- **Best for**: Long-term storage, batch analytics, machine learning
- **Use case**: Trend analysis, efficiency optimization, predictive modeling
- **Technology**: Delta Lake with scheduled processing
- **Data retention**: Unlimited (cost-dependent)
- **Query language**: SQL, Spark, Python

### 3. **Hybrid Approach** (Best of Both Worlds)

- **Eventhouse**: For real-time monitoring (last 7-30 days)
- **Lakehouse**: For historical data (months/years of data)
- **Data flows** from Eventhouse to Lakehouse for long-term storage
- **Use case**: Real-time operations + long-term analytics

## Option 1: Eventhouse Setup (Real-Time Analytics)

### Step 1: Create Eventhouse

1. Open your **Microsoft Fabric workspace**
2. Click **+ New** → **Eventhouse**
3. Name it: `satisfactory-realtime`
4. This creates both an Eventhouse and a KQL Database

### Step 2: Configure Event Hub Connection

1. In your KQL Database, go to **Get Data** → **Event Hub**
2. Configure connection settings:

   ```yaml
   Event Hub Namespace: <your-eventhub-namespace>
   Event Hub Name: satisfactory-data
   Consumer Group: $Default
   Authentication: Managed Identity
   Compression: None
   Event System Properties: Include
   ```

3. **Test connection** to verify Event Hub accessibility

### Step 3: Create Data Table

Run this KQL command to create the data table:

```kql
.create table SatisfactoryEvents (
    timestamp: datetime,
    endpoint: string,
    server: string,
    data: dynamic
)
```

### Step 4: Set Up Data Mapping

Create ingestion mapping for JSON data:

```kql
.create table SatisfactoryEvents ingestion json mapping 'SatisfactoryMapping' '[
    {"column":"timestamp","path":"$.timestamp","datatype":"datetime"},
    {"column":"endpoint","path":"$.endpoint","datatype":"string"},
    {"column":"server","path":"$.server","datatype":"string"},
    {"column":"data","path":"$.data","datatype":"dynamic"}
]'
```

### Step 5: Configure Continuous Export (Optional)

To also store data in Lakehouse for long-term analysis:

```kql
.create-or-alter continuous-export SatisfactoryToLakehouse
over (SatisfactoryEvents)
to table SatisfactoryHistorical in ('https://your-lakehouse-endpoint')
with (intervalBetweenRuns=1h, forcedLatency=10m, sizeLimit=104857600)
<| SatisfactoryEvents | where timestamp > ago(1h)
```

## Option 2: Lakehouse Setup (Batch Analytics)

### Step 1: Create Lakehouse

1. In your Fabric workspace: **+ New** → **Lakehouse**
2. Name it: `satisfactory-analytics`

### Step 2: Create Event Hub Connection

1. In Lakehouse, go to **Get data** → **New source**
2. Select **Azure Event Hubs**
3. Configure the same Event Hub details

### Step 3: Set Up Batch Processing

Create a notebook or pipeline to process Event Hub data in batches.

## Real-Time Dashboard Examples

### Power Grid Monitoring Dashboard

```kql
// Real-time power status
SatisfactoryEvents
| where endpoint == "getPower"
| where timestamp > ago(10m)
| mv-expand data
| evaluate bag_unpack(data)
| project
    timestamp,
    toint( PowerProduction),
    toint( PowerConsumed),
    toint( PowerCapacity),
    toint( BatteryPercent),
    toint( FuseTriggered)
| summarize
    AvgProduction = avg(PowerProduction),
    AvgConsumption = avg(PowerConsumed),
    AvgBattery = avg(BatteryPercent),
    FuseCount = countif(FuseTriggered == true)
    by bin(timestamp, 1m)
| render timechart with (ysplit=panels )
```

### Factory Efficiency Tracking

```kql
// Production efficiency over time
SatisfactoryEvents
| where endpoint == "getFactory"
| where timestamp > ago(1h)
| mv-expand data
| evaluate bag_unpack(data)
| where isnotnull(Productivity)
| project
    timestamp,
    FactoryName = Name,
    Productivity,
    LocationX = location.x,
    LocationY = location.y
| summarize
    avg(Productivity) as AvgEfficiency,
    count() as FactoryCount
    by bin(timestamp, 5m), FactoryName
| render timechart
```

### Player Activity Heatmap

```kql
// Player location heatmap
SatisfactoryEvents
| where endpoint == "getPlayer"
| where timestamp > ago(30m)
| mv-expand data
| evaluate bag_unpack(data)
| where Online == true
| project
    timestamp,
    PlayerName = Name,
    X = toint(location.x / 1000) * 1000,  // Grid to 1km squares
    Y = toint(location.y / 1000) * 1000,
    Z = toint(location.z / 100) * 100     // Grid to 100m height
| summarize
    PlayerMinutes = count() * 0.5,  // Each record = 30 seconds
    UniqueVisits = dcount(PlayerName)
    by X, Y, Z
| where PlayerMinutes > 2  // Filter out brief visits
| render scatterchart with (xcolumn=X, ycolumn=Y, series=Z)
```

## Real-Time Alerts Setup

### Data Activator (Optional)

Set up alerts for critical factory conditions:

1. **Power Outage Alert**:

   - Trigger: `FuseTriggered == true`
   - Action: Send Teams message, email

2. **Low Efficiency Alert**:

   - Trigger: `avg(Productivity) < 0.8 over 10 minutes`
   - Action: Notify factory operators

3. **Resource Shortage Alert**:
   - Trigger: Production rate drops > 50%
   - Action: Discord webhook notification

## Performance Optimization

### Eventhouse Partitioning

````kql
// Partition by endpoint for better query performance
.alter table SatisfactoryEvents policy partitioning ```
{
  "PartitionKeys": [
    {
      "ColumnName": "endpoint",
      "Kind": "Hash",
      "Properties": {
        "Function": "XxHash64",
        "MaxPartitionCount": 16
      }
    }
  ]
}
````

### Data Retention Policy

```kql
// Keep 30 days in hot cache, 1 year total
.alter table SatisfactoryEvents policy retention softdelete = 365d recoverability = disabled
.alter table SatisfactoryEvents policy caching hot = 30d
```

## Cost Optimization

### Eventhouse Pricing

- **Compute**: ~$200-400/month for continuous queries
- **Storage**: ~$0.10/GB/month for active data
- **Ingestion**: Free for first 10GB/day

### Recommended Setup

- **Development**: Eventhouse only (~$50-100/month)
- **Production**: Eventhouse + Lakehouse (~$200-300/month)
- **Enterprise**: Add Data Activator alerts (~$300-500/month)

## Troubleshooting

### Common Issues

1. **Data not appearing**:

   - Check Event Hub connection status
   - Verify JSON mapping configuration
   - Check ingestion errors in diagnostics

2. **Query performance issues**:

   - Add partitioning policy
   - Optimize KQL queries with `where` filters
   - Use materialized views for complex aggregations

3. **Cost management**:
   - Set up data retention policies
   - Monitor query complexity
   - Use summarized tables for historical data

### Monitoring Queries

```kql
// Check ingestion rate
.show ingestion failures | where Table == "SatisfactoryEvents" | top 10 by IngestionSourceCreationTime desc

// Monitor data freshness
SatisfactoryEvents | summarize max(timestamp) by endpoint | order by max_timestamp desc

// Query performance stats
.show queries | where Text contains "SatisfactoryEvents" | project StartedOn, Duration, Text
```

This setup gives you production-ready real-time analytics for your Satisfactory factory data!
