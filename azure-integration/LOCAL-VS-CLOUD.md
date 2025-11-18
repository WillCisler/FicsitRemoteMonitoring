# Local Streamer vs Azure Function - Quick Comparison

## When to Use Each Solution

### Use **Local Streamer** when:

- ✅ You have a dedicated server PC that runs 24/7
- ✅ You're hitting server API rate limits or throttling
- ✅ You want to minimize Azure costs
- ✅ You want the lowest possible latency
- ✅ You have admin access to install Windows services

### Use **Azure Function** when:

- ✅ You want a fully managed, hands-off solution
- ✅ You don't have a dedicated server (cloud-hosted Satisfactory)
- ✅ You need automatic scaling and high availability
- ✅ You prefer not to manage local installations
- ✅ You want Azure's monitoring and diagnostics

## Side-by-Side Comparison

| Feature              | Local Streamer              | Azure Function                     |
| -------------------- | --------------------------- | ---------------------------------- |
| **Cost**             | Free (uses PC resources)    | ~$5-20/month (compute + bandwidth) |
| **Latency**          | 1-5ms (localhost)           | 50-200ms (internet round-trip)     |
| **API Limits**       | None (direct HTTP)          | May hit FRM server limits          |
| **Availability**     | Depends on PC uptime        | 99.95% SLA                         |
| **Setup Complexity** | Medium (build + configure)  | Low (deploy to Azure)              |
| **Maintenance**      | Manual updates              | Automatic scaling & updates        |
| **Authentication**   | Azure CLI (one-time login)  | Managed Identity (built-in)        |
| **Monitoring**       | File logs + console         | Application Insights               |
| **Scalability**      | Single instance             | Auto-scales                        |
| **Network**          | Requires PC on same network | Works from anywhere                |

## Architecture Comparison

### Local Streamer Flow

```
Satisfactory Server (localhost:8080)
    ↓ (1-5ms, HTTP)
Local Streamer App (same PC)
    ↓ (HTTPS, authenticated)
Azure Event Hub
    ↓
Microsoft Fabric
```

### Azure Function Flow

```
Satisfactory Server (public IP:8080)
    ↓ (50-200ms, HTTP over internet)
Azure Function (cloud)
    ↓ (internal, HTTPS)
Azure Event Hub
    ↓
Microsoft Fabric
```

## Data Collection Frequency

Both solutions support the same three-tier frequency system:

| Tier         | Interval   | Example Endpoints          |
| ------------ | ---------- | -------------------------- |
| **High**     | 1 second   | getPower, getPlayer        |
| **Medium**   | 5 seconds  | getGenerators, getVehicles |
| **Standard** | 30 seconds | getFactory, getExtractor   |

## Cost Analysis (Monthly)

### Local Streamer

- **Compute**: $0 (uses existing PC)
- **Bandwidth**: $0 (local network)
- **Event Hub**: ~$10/month (shared with Azure Function)
- **Total**: ~$10/month

### Azure Function

- **Function Compute**: ~$5/month (based on executions)
- **Bandwidth**: ~$5-10/month (outbound data)
- **Event Hub**: ~$10/month
- **Application Insights**: ~$2/month
- **Total**: ~$22-27/month

**Savings with Local Streamer**: ~$12-17/month (~50-60% cost reduction)

## Performance Comparison

### Request Latency (getPower endpoint)

- **Local Streamer**: 1-5ms average
- **Azure Function**: 50-200ms average

### Data Freshness (High Frequency - 1s interval)

- **Local Streamer**: Data in Event Hub within 10-20ms
- **Azure Function**: Data in Event Hub within 100-250ms

### Concurrency

- **Local Streamer**: 5 concurrent requests (configurable)
- **Azure Function**: 5 concurrent requests (same)

## Security Comparison

### Authentication

- **Local Streamer**: DefaultAzureCredential (Azure CLI login)
- **Azure Function**: Managed Identity (automatic)

Both are secure and don't require secrets in configuration files.

### Network Security

- **Local Streamer**:
  - FRM endpoint: localhost (no internet exposure)
  - Event Hub: TLS 1.2+ encrypted
- **Azure Function**:
  - FRM endpoint: public IP (must be internet-accessible)
  - Event Hub: TLS 1.2+ encrypted

## Recommendation

### Best of Both Worlds

You can run **both** solutions simultaneously:

1. **Local Streamer** for high-frequency data (1s, 5s intervals)
2. **Azure Function** as backup/failover for standard data (30s interval)

This provides:

- Maximum data freshness for critical metrics
- Redundancy if local PC goes down
- Cost optimization (less Azure Function executions)

To implement this:

1. Configure Local Streamer with only `HighFrequency` and `MediumFrequency` enabled
2. Configure Azure Function with only `StandardFrequency` enabled
3. Both stream to the same Event Hub with different source tags

## Quick Decision Matrix

| Your Situation                          | Recommended Solution |
| --------------------------------------- | -------------------- |
| Dedicated server PC, want to save costs | **Local Streamer**   |
| Cloud-hosted Satisfactory server        | **Azure Function**   |
| Need ultra-low latency (<10ms)          | **Local Streamer**   |
| Want zero maintenance                   | **Azure Function**   |
| Hitting API rate limits                 | **Local Streamer**   |
| Need 99.9% uptime guarantee             | **Azure Function**   |
| Budget-conscious setup                  | **Local Streamer**   |
| Enterprise production deployment        | **Azure Function**   |
| Want both redundancy and performance    | **Both (hybrid)**    |

## Migration Path

### From Azure Function → Local Streamer

1. Build and test local streamer in console mode
2. Verify data appears in Event Hub
3. Disable Azure Function timer triggers
4. Monitor for 24 hours
5. Delete Azure Function resources (optional)

### From Local Streamer → Azure Function

1. Deploy Azure Function
2. Configure with same endpoints
3. Verify data in Event Hub
4. Stop local streamer service
5. Uninstall local service (optional)

No data loss during migration - Event Hub buffers data during transition.
