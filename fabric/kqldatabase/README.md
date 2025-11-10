# 🏭 Ficsit KQL Database Documentation

## 📋 Overview

This folder contains the complete KQL database implementation for the Ficsit Remote Monitoring system. The database is designed to support comprehensive analysis of power networks, production optimization, and factory management for Satisfactory game data.

## 🎯 Business Requirements Addressed

| Requirement ID      | Description             | Status         |
| ------------------- | ----------------------- | -------------- |
| **Engineering-001** | Power Network Analysis  | ✅ Implemented |
| **Engineering-002** | Power Grid Clean up     | ✅ Implemented |
| **Engineering-003** | Production Optimisation | ✅ Implemented |

## 🏗️ Database Architecture

### 📊 **Data Flow**

```txt
RawData (Event Hub) → Update Policies → Fact Tables → Views → Analytics
```

### 📁 **Folder Structure**

```txt
fabric/kqldatabase/
├── README.md                 # This documentation file
├── tables/                   # Table creation scripts
│   ├── power_generators.kql
│   ├── factory_machines.kql
│   ├── production_items.kql
│   ├── power_grid_connections.kql
│   └── factory_items.kql
├── functions/                # Function creation scripts (replaces views)
│   ├── parse_generators_data.kql      # JSON parsing for generators
│   └── low_efficiency_machines.kql    # Machine efficiency analysis
├── policies/                 # Update policy scripts
│   └── power_generators_update_policy.kql
├── deployment/              # Deployment scripts
│   ├── deploy_all.kql        # Complete deployment script
│   └── quick_test.kql        # Testing and validation
└── testing/                 # Testing documentation
    └── TESTING.md            # Test results and validation
```

## 🗃️ **Database Schema**

### **Fact Tables**

- **`power_generators`** - Individual power generator performance tracking
- **`factory_machines`** - Production machine efficiency and status
- **`production_items`** - Item production rates and resource extraction
- **`power_grid_connections`** - Power network topology and health

### **Dimension Tables**

- **`factory_items`** - Master reference for all factory items and resources

### **Functions** (KQL Best Practice - replaces views)

- **`parse_generators_data()`** - Parse JSON data from power generators endpoint
- **`low_efficiency_machines()`** - Identify underperforming machines for optimization

### **Update Policies**

- **`power_generators_update_policy`** - Real-time processing of generator data using `parse_generators_data()` function

## 🔄 **Update Policies**

Real-time data processing is handled by update policies that transform incoming JSON data:

1. **Power Generators** - Uses `parse_generators_data()` function to process `getGenerators` endpoint data
   - Transforms JSON to structured data in `power_generators` table
   - Calculates efficiency metrics and location coordinates
   - **Status**: ✅ Implemented and tested with 39,516 records from 89 generators

## 📈 **Key Performance Indicators**

### Power Network Metrics

- Total power generation capacity
- Power efficiency percentage
- Generator performance by type
- Circuit health status
- Location-based power distribution

### Production Optimization Metrics

- Machine efficiency rankings
- Resource extraction rates
- Production bottleneck identification
- Supply chain flow analysis

### Grid Management Metrics

- Network topology visualization
- Connection health monitoring
- Fuse trigger alerts
- Circuit load balancing

## 🚀 **Deployment Instructions**

### Prerequisites

- Access to Microsoft Fabric KQL Database
- Connection to `ficsit-data` database
- Proper permissions for table creation and policy management

### Deployment Steps

1. **Execute Complete Deployment**: Use the optimized deployment script
2. **Validate Tables**: Verify all 5 tables are created successfully
3. **Validate Functions**: Confirm both functions are operational
4. **Test Update Policies**: Ensure real-time data processing works
5. **Monitor Ingestion**: Check data flow from FicsitRemote endpoints

### Quick Deploy

```kql
// Execute the complete deployment script (Azure Data Explorer compatible)
// This script consolidates all phases into a single execution
.execute script <'deployment/deploy_all.kql'>
```

### Validation Commands

```kql
// Check deployment status
.show tables | where TableName in ("power_generators", "factory_machines", "production_items", "power_grid_connections", "factory_items")

// Test functions
parse_generators_data() | take 5
low_efficiency_machines() | take 10

// Verify update policies
.show table power_generators policy update
```

## 🔍 **Usage Examples**

### Power Generator Analysis

```kql
// Test the parse_generators_data function
parse_generators_data()
| summarize
    TotalGenerators = count(),
    AvgEfficiency = avg(efficiency_percent),
    TotalPowerProduction = sum(power_production)
by generator_type
| order by TotalPowerProduction desc
```

### Production Optimization

```kql
// Find lowest efficiency machines using the function
low_efficiency_machines()
| where priority_score >= 3
| project machine_id, machine_type, efficiency_percent, location_description, priority_score
| order by priority_score desc, efficiency_percent asc
```

### Real-time Monitoring

```kql
// Monitor recent power generation data
power_generators
| where ingestion_time > ago(10m)
| summarize
    CurrentPowerOutput = sum(power_production),
    MaxPowerCapacity = sum(max_power_production),
    EfficiencyPercent = (sum(power_production) / sum(max_power_production)) * 100
by bin(ingestion_time, 1m)
| render timechart
```

## 📊 **Data Retention**

- **Fact Tables**: 90 days retention for detailed operational analysis
- **Dimension Tables**: 10 years retention for reference data
- **Raw Data**: Processed in real-time via update policies

## 🔧 **Maintenance**

### Regular Tasks

- Monitor update policy performance with `.show table power_generators policy update`
- Review data ingestion rates using `.show ingestion mappings`
- Test function performance with sample queries
- Validate data quality and completeness

### Troubleshooting

- Check function execution: `parse_generators_data() | take 5`
- Monitor ingestion health: `.show ingestion failures`
- Review query performance: `.show queries | where StartedOn >= ago(1h)`
- Validate table schemas: `.show table power_generators schema`

### Performance Optimization

- Azure Data Explorer automatically optimizes storage (no manual indexes needed)
- Use functions for complex transformations instead of views
- Leverage update policies for real-time data processing
- Monitor resource usage with built-in ADX metrics

## 👥 **Support**

For questions or issues related to this KQL database implementation:

- Review this documentation for current implementation details
- Check the `deployment/quick_test.kql` file for validation queries
- Consult the `testing/TESTING.md` file for test results and examples
- Reference individual KQL script files for detailed implementation comments

### Implementation Status

- ✅ **Tables**: All 5 tables created and validated
- ✅ **Functions**: `parse_generators_data()` and `low_efficiency_machines()` implemented
- ✅ **Update Policies**: Real-time data processing configured
- ✅ **Testing**: Successfully validated with 39,516 generator records
- ✅ **Deployment**: Azure Data Explorer compatible script ready

---

_Last Updated: July 11, 2025_
_Version: 1.0_
_Database: ficsit-data (Microsoft Fabric KQL Database)_
_Compatibility: Azure Data Explorer optimized_
