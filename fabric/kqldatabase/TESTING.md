# 🧪 KQL Testing Strategy for Ficsit Database

## 📋 Overview

This document outlines the comprehensive testing approach for the Ficsit KQL database implementation, covering unit tests, integration tests, and performance validation.

## 🎯 Testing Phases

### **Phase 1: Function Testing (Unit Tests)**

Test individual functions in isolation before deploying policies.

### **Phase 2: Table Structure Testing**

Validate table schemas and basic operations.

### **Phase 3: Integration Testing**

Test complete data flow from RawData through functions to target tables.

### **Phase 4: Performance Testing**

Validate query performance and ingestion rates.

### **Phase 5: Business Logic Testing**

Verify calculated fields and business rules.

---

## 🔧 **Phase 1: Function Testing**

### **Test the parse_generators_data() Function**

```kusto
// Test 1: Basic function execution
parse_generators_data()
| take 1
| project timestamp, generator_id, generator_name, current_production

// Test 2: Validate output schema matches table schema
parse_generators_data()
| take 1
| getschema
| project ColumnName, DataType
| order by ColumnName

// Test 3: Check for null/empty values
parse_generators_data()
| where timestamp >= ago(1h)
| summarize
    total_records = count(),
    null_generator_ids = countif(isnull(generator_id) or generator_id == ""),
    null_names = countif(isnull(generator_name) or generator_name == ""),
    null_production = countif(isnull(current_production)),
    zero_production = countif(current_production == 0)

// Test 4: Validate derived calculations
parse_generators_data()
| where timestamp >= ago(1h)
| extend
    calculated_efficiency = case(
        power_production_potential > 0,
        current_production / power_production_potential,
        0.0
    )
| where abs(production_efficiency - calculated_efficiency) > 0.001
| take 10  // Should return no results if calculations are correct

// Test 5: Data type validation
parse_generators_data()
| where timestamp >= ago(1h)
| summarize
    timestamp_type = typeof(timestamp),
    generator_id_type = typeof(generator_id),
    production_efficiency_type = typeof(production_efficiency),
    circuit_group_id_type = typeof(circuit_group_id)
| extend validation_passed =
    timestamp_type == "datetime" and
    generator_id_type == "string" and
    production_efficiency_type == "real" and
    circuit_group_id_type == "long"
```

---

## 🗃️ **Phase 2: Table Structure Testing**

### **Test Table Creation and Schema**

```kusto
// Test 1: Verify all tables exist
.show tables
| where TableName in ("power_generators", "factory_machines", "production_items", "power_grid_connections", "factory_items")
| project TableName, exists = true
| join kind=rightouter (
    datatable(TableName:string)["power_generators", "factory_machines", "production_items", "power_grid_connections", "factory_items"]
) on TableName
| project TableName, exists = isnotempty(exists)

// Test 2: Check table schemas
.show table power_generators schema
| project ColumnName, DataType, ColumnType
| order by ColumnName

// Test 3: Test basic insert operations
.set-or-append power_generators <|
datatable(
    timestamp:datetime, server:string, generator_id:string, generator_name:string,
    generator_class:string, circuit_group_id:long, circuit_id:long,
    power_production_potential:real, current_production:real, production_efficiency:real,
    load_percentage:long, fuel_resource:string, fuel_amount:real, fuel_max_amount:real,
    fuel_percentage:real, is_full_speed:bool, can_start:bool, is_producing:bool,
    somersloops:long, power_shards:long, location_x:real, location_y:real, location_z:real,
    fuse_triggered:bool, power_consumed:real, max_power_consumed:real, nuclear_warning:string,
    geo_min_power:real, geo_max_power:real, ingestion_time:datetime
)[
    datetime(2025-07-11T10:00:00Z), "test-server", "test-gen-001", "Test Coal Generator",
    "Build_GeneratorCoal_C", 1, 1,
    75.0, 60.0, 0.8,
    80, "Coal", 100.0, 200.0,
    0.5, true, true, true,
    0, 0, 1000.0, 2000.0, 100.0,
    false, 2.0, 5.0, "",
    0.0, 0.0, now()
]

// Test 4: Verify test data was inserted
power_generators
| where generator_id == "test-gen-001"
| project generator_name, current_production, production_efficiency

// Test 5: Clean up test data
.delete table power_generators records <| power_generators | where generator_id == "test-gen-001"
```

---

## 🔄 **Phase 3: Integration Testing**

### **Test Complete Data Flow**

```kusto
// Test 1: Check if RawData has generator data
RawData
| where endpoint == "getGenerators"
| where timestamp >= ago(24h)
| take 5
| project timestamp, endpoint, server, data_preview = substring(tostring(data), 0, 200)

// Test 2: Test function against real RawData
parse_generators_data()
| where timestamp >= ago(1h)
| take 5
| project timestamp, generator_id, generator_name, current_production, production_efficiency

// Test 3: Simulate update policy execution
// This tests what the policy would do without actually creating the policy
parse_generators_data()
| where timestamp >= ago(1h)
| where generator_id != ""
| summarize
    records_processed = count(),
    unique_generators = dcount(generator_id),
    avg_efficiency = avg(production_efficiency),
    min_timestamp = min(timestamp),
    max_timestamp = max(timestamp)

// Test 4: Test join operations between tables
power_generators pg
| where timestamp >= ago(1h)
| join kind=inner (
    PowerCircuits pc
    | where Timestamp >= ago(1h)
) on $left.circuit_group_id == $right.CircuitGroupID
| take 10
| project
    generator_name = pg.generator_name,
    generator_production = pg.current_production,
    circuit_production = pc.PowerProduction,
    circuit_capacity = pc.PowerCapacity
```

---

## 🏎️ **Phase 4: Performance Testing**

### **Test Query Performance and Optimization**

```kusto
// Test 1: Function execution time
let start_time = now();
parse_generators_data()
| where timestamp >= ago(1h)
| summarize count()
| extend execution_time = now() - start_time

// Test 2: Index effectiveness
// Before creating indexes
let start_time = now();
power_generators
| where timestamp >= ago(24h)
| where generator_class == "Build_GeneratorCoal_C"
| summarize count()
| extend query_time_without_index = now() - start_time

// Test 3: Memory usage estimation
parse_generators_data()
| where timestamp >= ago(24h)
| summarize
    estimated_rows = count(),
    estimated_size_mb = count() * 0.001  // Rough estimate

// Test 4: Ingestion rate testing
power_generators
| where ingestion_time >= ago(1h)
| summarize
    total_records = count(),
    unique_generators = dcount(generator_id),
    records_per_minute = count() / 60.0
by bin(ingestion_time, 1m)
| order by ingestion_time desc
| take 10
```

---

## 📊 **Phase 5: Business Logic Testing**

### **Test Calculated Fields and Business Rules**

```kusto
// Test 1: Production efficiency calculations
parse_generators_data()
| where timestamp >= ago(1h)
| where power_production_potential > 0
| extend manual_efficiency = current_production / power_production_potential
| where abs(production_efficiency - manual_efficiency) > 0.001
| project generator_id, production_efficiency, manual_efficiency, difference = abs(production_efficiency - manual_efficiency)

// Test 2: Fuel percentage calculations
parse_generators_data()
| where timestamp >= ago(1h)
| where fuel_max_amount > 0
| extend manual_fuel_percentage = fuel_amount / fuel_max_amount
| where abs(fuel_percentage - manual_fuel_percentage) > 0.001
| project generator_id, fuel_percentage, manual_fuel_percentage

// Test 3: Business rule validation
parse_generators_data()
| where timestamp >= ago(1h)
| extend validation_issues = pack_array(
    case(production_efficiency < 0 or production_efficiency > 1, "Invalid efficiency range", ""),
    case(fuel_percentage < 0 or fuel_percentage > 1, "Invalid fuel percentage", ""),
    case(current_production < 0, "Negative production", ""),
    case(power_production_potential < 0, "Negative potential", "")
)
| mv-expand validation_issue = validation_issues
| where validation_issue != ""
| summarize issues = make_list(validation_issue) by generator_id
| where array_length(issues) > 0

// Test 4: Test view functionality
low_efficiency_machines
| where last_seen >= ago(1h)
| take 5
| project machine_name, avg_production_efficiency, efficiency_category, optimization_priority
```

---

## 🔍 **Test Execution Order**

### **Recommended Testing Sequence:**

1. **Create Test Environment**

   ```kusto
   // Create test database or use existing with test data
   .create table test_power_generators (timestamp:datetime, test_data:string)
   ```

2. **Run Function Tests**

   ```kusto
   // Execute all Phase 1 tests
   parse_generators_data() | take 1  // Basic smoke test
   ```

3. **Deploy Tables**

   ```kusto
   // Run table creation scripts
   .execute script <'tables/power_generators.kql'>
   ```

4. **Test Integration**

   ```kusto
   // Run Phase 3 integration tests
   ```

5. **Performance Validation**

   ```kusto
   // Run Phase 4 performance tests
   ```

6. **Business Logic Validation**
   ```kusto
   // Run Phase 5 business logic tests
   ```

---

## 🚨 **Error Scenarios to Test**

### **Common Failure Modes:**

```kusto
// Test 1: Invalid JSON in RawData
RawData
| where endpoint == "getGenerators"
| where timestamp >= ago(1h)
| extend parse_test = parse_json(data)
| where isnull(parse_test)
| take 5

// Test 2: Missing required fields
parse_generators_data()
| where timestamp >= ago(1h)
| where isnull(generator_id) or generator_id == ""
| take 5

// Test 3: Data type conversion errors
// This should be handled gracefully by the function
parse_generators_data()
| where timestamp >= ago(1h)
| where isnull(current_production) or current_production < 0
| take 5
```

---

## 📈 **Success Criteria**

### **Test Pass Criteria:**

- ✅ **Function Tests**: All functions execute without errors
- ✅ **Schema Validation**: Table schemas match expected structure
- ✅ **Data Quality**: No null values in required fields
- ✅ **Performance**: Queries complete within acceptable time limits
- ✅ **Business Logic**: Calculated fields are accurate
- ✅ **Integration**: Data flows correctly from source to target

### **Performance Benchmarks:**

- Function execution: < 10 seconds for 1 hour of data
- Table queries: < 5 seconds for standard dashboard queries
- Ingestion rate: Handles real-time data without lag
- Memory usage: Within allocated database limits

---

## 🔧 **Testing Tools and Commands**

### **Useful KQL Commands for Testing:**

```kusto
// Check function exists
.show functions | where Name == "parse_generators_data"

// Monitor query performance
.show queries | where StartedOn >= ago(1h) | order by StartedOn desc

// Check table statistics
.show table power_generators details

// Monitor ingestion
.show ingestion failures | order by FailedOn desc

// Check data distribution
power_generators
| where timestamp >= ago(24h)
| summarize count() by bin(timestamp, 1h)
| render timechart
```

This comprehensive testing approach ensures that your KQL implementation is robust, performant, and ready for production use! 🎯
