# Incremental Loading Solution for FicsitRemote HTTP Endpoints

## Problem Statement

The current HTTP endpoints in FicsitRemoteMonitoring grab entire snapshots of the game state on every request. When requesting incremental loads every second (for Azure Functions integration), this causes:

- Duplicate data being sent repeatedly
- Unnecessary network traffic
- Higher processing overhead
- Inefficient resource usage

## Current Data Structure

Based on the example data from `getLifts` endpoint:

```json
{
  "timestamp": "2025-07-10T20:49:05.3932883Z",
  "endpoint": "getLifts",
  "server": "sands",
  "data": [
    {
      "ID": "Build_ConveyorLiftMk1_C_2147452298",
      "Name": "Conveyor Lift Mk.1",
      "ClassName": "Build_ConveyorLiftMk1_C",
      "location": {"x": 377710.5, "y": -110651.9921875, "z": 9202},
      "ItemsPerMinute": 60,
      "Connected0": true,
      "Connected1": true,
      "Length": 2800
    }
  ]
}
```

## Solution Approaches

### 1. Timestamp-Based Filtering (Recommended)

Modify endpoint functions to accept a `since` parameter and only return objects that have changed since that timestamp.

#### Implementation in C++

```cpp
// In FactoryLibrary.h
static void getFactory(UObject* WorldContext, FRequestData RequestData, TArray<TSharedPtr<FJsonValue>>& OutJsonArray) {
    // Check for 'since' parameter in query params
    FDateTime SinceTime = FDateTime::MinValue();
    if (RequestData.QueryParams.Contains("since")) {
        FString SinceParam = RequestData.QueryParams["since"];
        FDateTime::ParseIso8601(*SinceParam, SinceTime);
    }

    OutJsonArray = getFactory_Helper(WorldContext, AFGBuildableManufacturer::StaticClass(), SinceTime);
}

// Helper function with change tracking
TArray<TSharedPtr<FJsonValue>> UFactoryLibrary::getFactory_Helper(UObject* WorldContext, UClass* TypedBuildable, FDateTime SinceTime)
{
    AFGBuildableSubsystem* BuildableSubsystem = AFGBuildableSubsystem::Get(WorldContext->GetWorld());
    TArray<AFGBuildable*> Buildables;
    BuildableSubsystem->GetTypedBuildable(TypedBuildable, Buildables);
    TArray<TSharedPtr<FJsonValue>> JFactoryArray;

    for (AFGBuildable* Buildable : Buildables) {
        FString BuildableID = Buildable->GetName();

        // Check if this building has changed since the requested time
        if (HasBuildingChanged(Buildable, SinceTime, BuildableID)) {
            // Include this building in the response
            TSharedPtr<FJsonObject> JFactory = CreateFactoryJsonObject(Buildable);

            // Update tracking
            LastModifiedTimes[BuildableID] = FDateTime::Now();
            LastKnownStates[BuildableID] = JFactory;

            JFactoryArray.Add(MakeShared<FJsonValueObject>(JFactory));
        }
    }

    return JFactoryArray;
}
```

#### Change Detection Logic

```cpp
// Static tracking variables
static TMap<FString, FDateTime> LastModifiedTimes;
static TMap<FString, TSharedPtr<FJsonObject>> LastKnownStates;

bool UFactoryLibrary::HasBuildingChanged(AFGBuildable* Buildable, FDateTime SinceTime, const FString& BuildableID)
{
    AFGBuildableManufacturer* Manufacturer = Cast<AFGBuildableManufacturer>(Buildable);
    if (!Manufacturer) return false;

    // Check if we've seen this building before
    if (!LastKnownStates.Contains(BuildableID)) {
        return true; // New building
    }

    // Check if it changed since the requested time
    if (LastModifiedTimes.Contains(BuildableID) && LastModifiedTimes[BuildableID] > SinceTime) {
        return true;
    }

    // Compare current state with last known state
    TSharedPtr<FJsonObject> CurrentState = CreateFactoryJsonObject(Buildable);
    TSharedPtr<FJsonObject> LastState = LastKnownStates[BuildableID];

    return !AreStatesEqual(CurrentState, LastState);
}
```

### 2. State Hash Comparison

Create a hash of the building's state to quickly detect changes:

```cpp
uint32 UFactoryLibrary::GetBuildingStateHash(AFGBuildableManufacturer* Manufacturer)
{
    // Create a hash from key properties that indicate state changes
    uint32 Hash = 0;

    if (Manufacturer->GetCurrentRecipe()) {
        Hash = HashCombine(Hash, GetTypeHash(Manufacturer->GetCurrentRecipe()->GetName()));
    }

    Hash = HashCombine(Hash, GetTypeHash(Manufacturer->GetProductivity()));
    Hash = HashCombine(Hash, GetTypeHash(Manufacturer->IsProducing()));
    Hash = HashCombine(Hash, GetTypeHash(Manufacturer->IsProductionPaused()));
    Hash = HashCombine(Hash, GetTypeHash(Manufacturer->GetCurrentPotential()));

    return Hash;
}
```

### 3. Azure Functions Integration

Modify the `SatisfactoryDataStreamer.cs` to use timestamps:

```csharp
public class SatisfactoryDataStreamer
{
    private static readonly Dictionary<string, DateTime> LastSyncTimes = new();

    private async Task ProcessEndpoint(string baseUrl, string endpoint, string serverName)
    {
        try
        {
            // Get the last sync time for this endpoint
            var lastSync = GetLastSyncTime(endpoint, serverName);

            // Add timestamp parameter to the request
            var url = $"{baseUrl}/{endpoint}?since={lastSync:yyyy-MM-ddTHH:mm:ssZ}";

            var response = await _retryPolicy.ExecuteAsync(async (context) =>
            {
                return await _httpClient.GetAsync(url);
            }, new Context(endpoint));

            if (response.IsSuccessStatusCode)
            {
                var jsonData = await response.Content.ReadAsStringAsync();

                // Only process if there are actual changes
                if (!string.IsNullOrEmpty(jsonData) && jsonData != "[]")
                {
                    var eventData = new
                    {
                        timestamp = DateTime.UtcNow,
                        endpoint = endpoint,
                        server = serverName,
                        data = JsonSerializer.Deserialize<JsonElement>(jsonData),
                        changeType = "incremental" // Mark as incremental update
                    };

                    await SendToEventHub(eventData, endpoint, serverName);

                    // Update the last sync time
                    UpdateLastSyncTime(endpoint, serverName, DateTime.UtcNow);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error processing incremental endpoint {endpoint}");
        }
    }

    private DateTime GetLastSyncTime(string endpoint, string serverName)
    {
        var key = $"{serverName}:{endpoint}";
        return LastSyncTimes.TryGetValue(key, out var lastSync)
            ? lastSync
            : DateTime.UtcNow.AddMinutes(-1); // Default to 1 minute ago for first run
    }

    private void UpdateLastSyncTime(string endpoint, string serverName, DateTime syncTime)
    {
        var key = $"{serverName}:{endpoint}";
        LastSyncTimes[key] = syncTime;
    }
}
```

### 4. WebSocket-Based Approach (Most Efficient)

Enhance the existing WebSocket system to only send changes:

```cpp
// In FicsitRemoteMonitoring.cpp
void AFicsitRemoteMonitoring::PushUpdatedData() {
    for (auto& Elem : EndpointSubscribers) {
        FString Endpoint = Elem.Key;

        if (Elem.Value.Num() == 0) {
            continue;
        }

        // Get current state
        FString CurrentJson = GetCurrentEndpointData(Endpoint);

        // Compare with previous state
        FString PreviousJson = GetPreviousEndpointData(Endpoint);

        // Only send if there are changes
        if (CurrentJson != PreviousJson) {
            // Store current state as previous for next comparison
            StorePreviousEndpointData(Endpoint, CurrentJson);

            // Send the update
            FTCHARToUTF8 Converted(*CurrentJson);
            const char* UWSOutput = Converted.Get();

            for (uWS::WebSocket<false, true, FWebSocketUserData>* Client : Elem.Value) {
                Client->send(UWSOutput, uWS::OpCode::TEXT);
            }
        }
    }
}
```

## Implementation Strategy

### Phase 1: Timestamp-Based Filtering (Short-term)

1. Modify endpoint functions to accept `since` parameter
2. Implement change tracking using timestamps
3. Update Azure Functions to use incremental requests

### Phase 2: State Comparison (Medium-term)

1. Add state hash comparison for more efficient change detection
2. Implement proper state diffing logic
3. Add memory management for tracking data structures

### Phase 3: WebSocket Enhancement (Long-term)

1. Enhance WebSocket system to send only changes
2. Add event-driven change detection
3. Implement real-time incremental updates

## Benefits

- ✅ **Eliminates duplicates** - Only changed objects are returned
- ✅ **Reduces network traffic** - Significantly less data transferred
- ✅ **Improves performance** - Less processing overhead
- ✅ **Better scalability** - Scales better with large factories
- ✅ **Azure Functions efficiency** - Reduces function execution time and costs

## Considerations

- **Memory Usage**: Tracking state requires additional memory
- **Complexity**: More complex logic for change detection
- **Synchronization**: Ensuring incremental updates don't miss changes
- **Backwards Compatibility**: Existing integrations need updates

## Example Usage

```http
GET /getFactory?since=2025-07-10T20:49:05Z
```

Returns only factory buildings that have changed since the specified timestamp.

## Related Files

- `Source/FicsitRemoteMonitoring/Public/Endpoints/Factory/FactoryLibrary.h`
- `azure-integration/SatisfactoryDataStreamer.cs`
- `Source/FicsitRemoteMonitoring/Private/FicsitRemoteMonitoring.cpp`

## Next Steps

1. Implement timestamp-based filtering in `FactoryLibrary.cpp`
2. Add change detection logic to all endpoint helpers
3. Update Azure Functions to use incremental requests
4. Test with high-frequency polling scenarios
5. Monitor memory usage and performance impact

# Factory Graph Connection Implementation

### Problem

The current `getFactory` endpoint provides building locations and production data but lacks connection information needed to build a factory graph showing how buildings are connected:

- Extractor → Conveyor → Splitter → Conveyor → Machine
- No way to trace material flow through the factory
- Missing connection data between factory components

### Current Connection Data Available

From the codebase analysis, connection information is available through:

1. **UFGFactoryConnectionComponent** - Used by conveyor belts, factory buildings
2. **UFGPipeConnectionComponent** - Used by pipes and fluid systems
3. **UFGCircuitConnectionComponent** - Used by power connections
4. **Connection methods** - `GetConnection0()`, `GetConnection1()`, `IsConnected()`

### Solution: New Factory Graph Endpoints

#### 1. Enhanced Factory Endpoint with Connections

```cpp
// In FactoryLibrary.h
static void getFactoryConnections(UObject* WorldContext, FRequestData RequestData, TArray<TSharedPtr<FJsonValue>>& OutJsonArray);

// In FactoryLibrary.cpp
void UFactoryLibrary::getFactoryConnections(UObject* WorldContext, FRequestData RequestData, TArray<TSharedPtr<FJsonValue>>& OutJsonArray)
{
    AFGBuildableSubsystem* BuildableSubsystem = AFGBuildableSubsystem::Get(WorldContext->GetWorld());
    TArray<AFGBuildable*> Buildables;
    BuildableSubsystem->GetTypedBuildable(AFGBuildableManufacturer::StaticClass(), Buildables);

    for (AFGBuildable* Buildable : Buildables) {
        AFGBuildableManufacturer* Manufacturer = Cast<AFGBuildableManufacturer>(Buildable);
        if (!Manufacturer) continue;

        TSharedPtr<FJsonObject> JFactory = CreateBuildableBaseJsonObject(Manufacturer);

        // Add connection information
        TArray<TSharedPtr<FJsonValue>> JConnections;

        // Get input connections
        for (UFGFactoryConnectionComponent* Connection : Manufacturer->GetConnectionComponents()) {
            if (Connection->GetDirection() == EFactoryConnectionDirection::FCD_INPUT) {
                TSharedPtr<FJsonObject> JConnection = MakeShared<FJsonObject>();
                JConnection->Values.Add("Type", MakeShared<FJsonValueString>("Input"));
                JConnection->Values.Add("ConnectionIndex", MakeShared<FJsonValueNumber>(Connection->GetConnectionIndex()));
                JConnection->Values.Add("IsConnected", MakeShared<FJsonValueBoolean>(Connection->IsConnected()));

                if (Connection->IsConnected()) {
                    UFGFactoryConnectionComponent* ConnectedComponent = Connection->GetConnection();
                    AFGBuildable* ConnectedBuilding = Cast<AFGBuildable>(ConnectedComponent->GetOwner());
                    if (ConnectedBuilding) {
                        JConnection->Values.Add("ConnectedBuildingID", MakeShared<FJsonValueString>(ConnectedBuilding->GetName()));
                        JConnection->Values.Add("ConnectedBuildingType", MakeShared<FJsonValueString>(UKismetSystemLibrary::GetClassDisplayName(ConnectedBuilding->GetClass())));
                    }
                }

                JConnections.Add(MakeShared<FJsonValueObject>(JConnection));
            }
        }

        // Get output connections
        for (UFGFactoryConnectionComponent* Connection : Manufacturer->GetConnectionComponents()) {
            if (Connection->GetDirection() == EFactoryConnectionDirection::FCD_OUTPUT) {
                TSharedPtr<FJsonObject> JConnection = MakeShared<FJsonObject>();
                JConnection->Values.Add("Type", MakeShared<FJsonValueString>("Output"));
                JConnection->Values.Add("ConnectionIndex", MakeShared<FJsonValueNumber>(Connection->GetConnectionIndex()));
                JConnection->Values.Add("IsConnected", MakeShared<FJsonValueBoolean>(Connection->IsConnected()));

                if (Connection->IsConnected()) {
                    UFGFactoryConnectionComponent* ConnectedComponent = Connection->GetConnection();
                    AFGBuildable* ConnectedBuilding = Cast<AFGBuildable>(ConnectedComponent->GetOwner());
                    if (ConnectedBuilding) {
                        JConnection->Values.Add("ConnectedBuildingID", MakeShared<FJsonValueString>(ConnectedBuilding->GetName()));
                        JConnection->Values.Add("ConnectedBuildingType", MakeShared<FJsonValueString>(UKismetSystemLibrary::GetClassDisplayName(ConnectedBuilding->GetClass())));
                    }
                }

                JConnections.Add(MakeShared<FJsonValueObject>(JConnection));
            }
        }

        JFactory->Values.Add("Connections", MakeShared<FJsonValueArray>(JConnections));

        // Add existing factory data
        // ... existing code from getFactory_Helper ...

        OutJsonArray.Add(MakeShared<FJsonValueObject>(JFactory));
    }
}
```

#### 2. Factory Graph Endpoint

```cpp
// New comprehensive factory graph endpoint
static void getFactoryGraph(UObject* WorldContext, FRequestData RequestData, TArray<TSharedPtr<FJsonValue>>& OutJsonArray);

void UFactoryLibrary::getFactoryGraph(UObject* WorldContext, FRequestData RequestData, TArray<TSharedPtr<FJsonValue>>& OutJsonArray)
{
    AFGBuildableSubsystem* BuildableSubsystem = AFGBuildableSubsystem::Get(WorldContext->GetWorld());

    TSharedPtr<FJsonObject> JGraph = MakeShared<FJsonObject>();
    TArray<TSharedPtr<FJsonValue>> JNodes;
    TArray<TSharedPtr<FJsonValue>> JEdges;

    // Get all factory buildings
    TArray<AFGBuildable*> AllBuildings;
    BuildableSubsystem->GetTypedBuildable(AFGBuildable::StaticClass(), AllBuildings);

    // Filter for factory-related buildings
    TArray<AFGBuildable*> FactoryBuildings;
    for (AFGBuildable* Building : AllBuildings) {
        if (IsFactoryBuilding(Building)) {
            FactoryBuildings.Add(Building);
        }
    }

    // Create nodes for each building
    for (AFGBuildable* Building : FactoryBuildings) {
        TSharedPtr<FJsonObject> JNode = MakeShared<FJsonObject>();
        JNode->Values.Add("ID", MakeShared<FJsonValueString>(Building->GetName()));
        JNode->Values.Add("Type", MakeShared<FJsonValueString>(GetBuildingType(Building)));
        JNode->Values.Add("ClassName", MakeShared<FJsonValueString>(UKismetSystemLibrary::GetClassDisplayName(Building->GetClass())));
        JNode->Values.Add("Location", MakeShared<FJsonValueObject>(ConvertVectorToFJsonObject(Building->GetActorLocation())));

        // Add building-specific data
        if (AFGBuildableManufacturer* Manufacturer = Cast<AFGBuildableManufacturer>(Building)) {
            if (Manufacturer->GetCurrentRecipe()) {
                JNode->Values.Add("Recipe", MakeShared<FJsonValueString>(UFGRecipe::GetRecipeName(Manufacturer->GetCurrentRecipe()).ToString()));
            }
        }

        JNodes.Add(MakeShared<FJsonValueObject>(JNode));
    }

    // Create edges for connections
    for (AFGBuildable* Building : FactoryBuildings) {
        TArray<UFGFactoryConnectionComponent*> Connections = GetBuildingConnections(Building);

        for (UFGFactoryConnectionComponent* Connection : Connections) {
            if (Connection->IsConnected() && Connection->GetDirection() == EFactoryConnectionDirection::FCD_OUTPUT) {
                UFGFactoryConnectionComponent* TargetConnection = Connection->GetConnection();
                AFGBuildable* TargetBuilding = Cast<AFGBuildable>(TargetConnection->GetOwner());

                if (TargetBuilding && FactoryBuildings.Contains(TargetBuilding)) {
                    TSharedPtr<FJsonObject> JEdge = MakeShared<FJsonObject>();
                    JEdge->Values.Add("From", MakeShared<FJsonValueString>(Building->GetName()));
                    JEdge->Values.Add("To", MakeShared<FJsonValueString>(TargetBuilding->GetName()));
                    JEdge->Values.Add("Type", MakeShared<FJsonValueString>("Factory"));
                    JEdge->Values.Add("ConnectionType", MakeShared<FJsonValueString>(GetConnectionType(Connection)));

                    JEdges.Add(MakeShared<FJsonValueObject>(JEdge));
                }
            }
        }
    }

    JGraph->Values.Add("Nodes", MakeShared<FJsonValueArray>(JNodes));
    JGraph->Values.Add("Edges", MakeShared<FJsonValueArray>(JEdges));

    OutJsonArray.Add(MakeShared<FJsonValueObject>(JGraph));
}

// Helper functions
bool UFactoryLibrary::IsFactoryBuilding(AFGBuildable* Building) {
    return Cast<AFGBuildableManufacturer>(Building) ||
           Cast<AFGBuildableResourceExtractor>(Building) ||
           Cast<AFGBuildableConveyorBelt>(Building) ||
           Cast<AFGBuildableConveyorAttachment>(Building) ||
           Cast<AFGBuildableStorage>(Building);
}

FString UFactoryLibrary::GetBuildingType(AFGBuildable* Building) {
    if (Cast<AFGBuildableManufacturer>(Building)) return "Manufacturer";
    if (Cast<AFGBuildableResourceExtractor>(Building)) return "Extractor";
    if (Cast<AFGBuildableConveyorBelt>(Building)) return "ConveyorBelt";
    if (Cast<AFGBuildableConveyorAttachment>(Building)) return "ConveyorAttachment";
    if (Cast<AFGBuildableStorage>(Building)) return "Storage";
    return "Unknown";
}

TArray<UFGFactoryConnectionComponent*> UFactoryLibrary::GetBuildingConnections(AFGBuildable* Building) {
    TArray<UFGFactoryConnectionComponent*> Connections;

    if (AFGBuildableManufacturer* Manufacturer = Cast<AFGBuildableManufacturer>(Building)) {
        Connections = Manufacturer->GetConnectionComponents();
    }
    else if (AFGBuildableResourceExtractor* Extractor = Cast<AFGBuildableResourceExtractor>(Building)) {
        Connections = Extractor->GetConnectionComponents();
    }
    else if (AFGBuildableConveyorBelt* Belt = Cast<AFGBuildableConveyorBelt>(Building)) {
        Connections.Add(Belt->GetConnection0());
        Connections.Add(Belt->GetConnection1());
    }

    return Connections;
}
```

#### 3. Enhanced Belt/Logistics Connections

```cpp
// Enhanced getBelts with connection targets
void ULogistics::getBeltsWithConnections(UObject* WorldContext, FRequestData RequestData, TArray<TSharedPtr<FJsonValue>>& OutJsonArray)
{
    AFGBuildableSubsystem* BuildableSubsystem = AFGBuildableSubsystem::Get(WorldContext->GetWorld());
    TArray<AFGBuildableConveyorBase*> Conveyors;
    BuildableSubsystem->GetTypedBuildable<AFGBuildableConveyorBase>(Conveyors);

    for (AFGBuildableConveyorBase* Conveyor : Conveyors) {
        TSharedPtr<FJsonObject> JConveyor = CreateBuildableBaseJsonObject(Conveyor);

        UFGFactoryConnectionComponent* ConnectionZero = Conveyor->GetConnection0();
        UFGFactoryConnectionComponent* ConnectionOne = Conveyor->GetConnection1();

        // Add connection target information
        TSharedPtr<FJsonObject> JConnection0 = MakeShared<FJsonObject>();
        JConnection0->Values.Add("IsConnected", MakeShared<FJsonValueBoolean>(ConnectionZero->IsConnected()));
        JConnection0->Values.Add("Location", MakeShared<FJsonValueObject>(getActorFactoryCompXYZ(Conveyor, ConnectionZero)));

        if (ConnectionZero->IsConnected()) {
            UFGFactoryConnectionComponent* TargetConnection = ConnectionZero->GetConnection();
            AFGBuildable* TargetBuilding = Cast<AFGBuildable>(TargetConnection->GetOwner());
            if (TargetBuilding) {
                JConnection0->Values.Add("ConnectedBuildingID", MakeShared<FJsonValueString>(TargetBuilding->GetName()));
                JConnection0->Values.Add("ConnectedBuildingType", MakeShared<FJsonValueString>(UKismetSystemLibrary::GetClassDisplayName(TargetBuilding->GetClass())));
            }
        }

        TSharedPtr<FJsonObject> JConnection1 = MakeShared<FJsonObject>();
        JConnection1->Values.Add("IsConnected", MakeShared<FJsonValueBoolean>(ConnectionOne->IsConnected()));
        JConnection1->Values.Add("Location", MakeShared<FJsonValueObject>(getActorFactoryCompXYZ(Conveyor, ConnectionOne)));

        if (ConnectionOne->IsConnected()) {
            UFGFactoryConnectionComponent* TargetConnection = ConnectionOne->GetConnection();
            AFGBuildable* TargetBuilding = Cast<AFGBuildable>(TargetConnection->GetOwner());
            if (TargetBuilding) {
                JConnection1->Values.Add("ConnectedBuildingID", MakeShared<FJsonValueString>(TargetBuilding->GetName()));
                JConnection1->Values.Add("ConnectedBuildingType", MakeShared<FJsonValueString>(UKismetSystemLibrary::GetClassDisplayName(TargetBuilding->GetClass())));
            }
        }

        JConveyor->Values.Add("Connection0", MakeShared<FJsonValueObject>(JConnection0));
        JConveyor->Values.Add("Connection1", MakeShared<FJsonValueObject>(JConnection1));

        OutJsonArray.Add(MakeShared<FJsonValueObject>(JConveyor));
    }
}
```

### Expected JSON Output

#### Factory Graph Response

```json
{
  "Nodes": [
    {
      "ID": "Build_ConstructorMk1_C_2147123456",
      "Type": "Manufacturer",
      "ClassName": "Build_ConstructorMk1_C",
      "Location": {"x": 100, "y": 200, "z": 300},
      "Recipe": "Iron Plate"
    },
    {
      "ID": "Build_ConveyorBeltMk1_C_2147123457",
      "Type": "ConveyorBelt",
      "ClassName": "Build_ConveyorBeltMk1_C",
      "Location": {"x": 150, "y": 250, "z": 300}
    }
  ],
  "Edges": [
    {
      "From": "Build_ConstructorMk1_C_2147123456",
      "To": "Build_ConveyorBeltMk1_C_2147123457",
      "Type": "Factory",
      "ConnectionType": "Output"
    }
  ]
}
```

#### Factory with Connections Response

```json
{
  "ID": "Build_ConstructorMk1_C_2147123456",
  "Name": "Constructor Mk.1",
  "Recipe": "Iron Plate",
  "Connections": [
    {
      "Type": "Input",
      "ConnectionIndex": 0,
      "IsConnected": true,
      "ConnectedBuildingID": "Build_ConveyorBeltMk1_C_2147123455",
      "ConnectedBuildingType": "Build_ConveyorBeltMk1_C"
    },
    {
      "Type": "Output",
      "ConnectionIndex": 0,
      "IsConnected": true,
      "ConnectedBuildingID": "Build_ConveyorBeltMk1_C_2147123457",
      "ConnectedBuildingType": "Build_ConveyorBeltMk1_C"
    }
  ]
}
```

### Implementation Steps

1. **Add new endpoints** to `FactoryLibrary.h`
2. **Implement connection logic** in `FactoryLibrary.cpp`
3. **Register endpoints** in `FicsitRemoteMonitoring.cpp`
4. **Test with factory setup** to verify connections
5. **Update Azure Functions** to use new graph endpoints

### Benefits for Azure Integration

- **Complete factory topology** - Map entire production chains
- **Flow analysis** - Track materials through the factory
- **Bottleneck detection** - Identify production constraints
- **Optimization opportunities** - Find efficiency improvements
- **Real-time monitoring** - Track production flow changes

This implementation provides the foundation for building comprehensive factory graphs showing exactly how your production lines are connected.

### WorldContext Creation and Management

#### How WorldContext is Created

The `WorldContext` parameter passed to all endpoint functions is created and managed by the mod subsystem:

1. **Main Subsystem**: `AFicsitRemoteMonitoring` inherits from `AModSubsystem` and is automatically created by the Unreal Engine when the mod loads.

2. **Subsystem Access**: The subsystem is accessed via:

   ```cpp
   AFicsitRemoteMonitoring* AFicsitRemoteMonitoring::Get(UWorld* WorldContext)
   {
       for (TActorIterator<AFicsitRemoteMonitoring> It(WorldContext, StaticClass(), EActorIteratorFlags::AllActors); It; ++It) {
           AFicsitRemoteMonitoring* CurrentActor = *It;
           return CurrentActor;
       };
       return NULL;
   }
   ```

3. **World Access**: The subsystem provides access to the game world through:

   ```cpp
   UWorld* World = WorldContext->GetWorld();
   ```

4. **Common Pattern**: All endpoints use this pattern to access game subsystems:

   ```cpp
   AFGBuildableSubsystem* BuildableSubsystem = AFGBuildableSubsystem::Get(WorldContext->GetWorld());
   ```

#### Configuration Access

Configuration is accessed through the world context:

```cpp
auto HttpConfig = FConfig_HTTPStruct::GetActiveConfig(GetWorld());
// or in endpoints:
FConfig_HTTPStruct::GetActiveConfig(WorldContext);
```

### Asset Path References

#### Asset Path Pattern

Asset paths in the mod follow a specific pattern for loading Unreal Engine classes:

```cpp
LoadObject<UClass>(nullptr, TEXT("/Game/FactoryGame/Buildable/Factory/AssemblerMk1/Build_AssemblerMk1.Build_AssemblerMk1_C"))
```

#### Common Asset Path Categories

##### Factory Buildings

```cpp
// Assembler
TEXT("/Game/FactoryGame/Buildable/Factory/AssemblerMk1/Build_AssemblerMk1.Build_AssemblerMk1_C")

// Blender
TEXT("/Game/FactoryGame/Buildable/Factory/Blender/Build_Blender.Build_Blender_C")

// Constructor
TEXT("/Game/FactoryGame/Buildable/Factory/ConstructorMk1/Build_ConstructorMk1.Build_ConstructorMk1_C")

// Foundry
TEXT("/Game/FactoryGame/Buildable/Factory/FoundryMk1/Build_FoundryMk1.Build_FoundryMk1_C")

// Manufacturer
TEXT("/Game/FactoryGame/Buildable/Factory/ManufacturerMk1/Build_ManufacturerMk1.Build_ManufacturerMk1_C")

// Refinery
TEXT("/Game/FactoryGame/Buildable/Factory/OilRefinery/Build_OilRefinery.Build_OilRefinery_C")

// Smelter
TEXT("/Game/FactoryGame/Buildable/Factory/SmelterMk1/Build_SmelterMk1.Build_SmelterMk1_C")
```

##### Power Generators

```cpp
// Biomass Generator
TEXT("/Game/FactoryGame/Buildable/Factory/GeneratorBiomass/Build_GeneratorBiomass_Automated.Build_GeneratorBiomass_Automated_C")

// Coal Generator
TEXT("/Game/FactoryGame/Buildable/Factory/GeneratorCoal/Build_GeneratorCoal.Build_GeneratorCoal_C")

// Fuel Generator
TEXT("/Game/FactoryGame/Buildable/Factory/GeneratorFuel/Build_GeneratorFuel.Build_GeneratorFuel_C")

// Nuclear Generator
TEXT("/Game/FactoryGame/Buildable/Factory/GeneratorNuclear/Build_GeneratorNuclear.Build_GeneratorNuclear_C")
```

##### Vehicles

```cpp
// Explorer
TEXT("/Game/FactoryGame/Buildable/Vehicle/Explorer/BP_Explorer.BP_Explorer_C")

// Tractor
TEXT("/Game/FactoryGame/Buildable/Vehicle/Tractor/BP_Tractor.BP_Tractor_C")

// Truck
TEXT("/Game/FactoryGame/Buildable/Vehicle/Truck/BP_Truck.BP_Truck_C")

// Factory Cart
TEXT("/Game/FactoryGame/Buildable/Vehicle/Golfcart/BP_Golfcart.BP_Golfcart_C")
```

##### Creatures

```cpp
// Doggo (Space Rabbit)
TEXT("/Game/FactoryGame/Character/Creature/Wildlife/SpaceRabbit/Char_SpaceRabbit.Char_SpaceRabbit_C")
```

#### Asset Path Structure

The path structure follows this pattern:

```text
/Game/FactoryGame/[Category]/[Subcategory]/[AssetName]/[Blueprint].[Blueprint]_C
```

Where:

- `Category`: Main category (Buildable, Character, etc.)
- `Subcategory`: Type-specific folder (Factory, Vehicle, etc.)
- `AssetName`: Specific asset folder name
- `Blueprint`: The actual blueprint file (often matches AssetName)
- `_C`: Suffix indicating this is a compiled Blueprint class

#### Alternative: Using StaticClass()

For base classes, you can use `StaticClass()` instead of asset paths:

```cpp
// Get all manufacturers
AFGBuildableManufacturer::StaticClass()

// Get all generators
AFGBuildableGenerator::StaticClass()

// Get all vehicles
AFGWheeledVehicle::StaticClass()
```

#### Asset Path Discovery

While there's no built-in enumeration method shown in the codebase, asset paths are typically discovered through:

1. **Game Documentation**: Official Satisfactory modding documentation
2. **Asset Browser**: Using Unreal Engine's asset browser in the editor
3. **Reflection**: Using Unreal Engine's reflection system to enumerate classes
4. **Community Resources**: Mod community wikis and documentation

#### Usage Pattern in Endpoints

```cpp
static void getSpecificFactory(UObject* WorldContext, FRequestData RequestData, TArray<TSharedPtr<FJsonValue>>& OutJsonArray) {
    // Load specific class by asset path
    OutJsonArray = getFactory_Helper(WorldContext, LoadObject<UClass>(nullptr, TEXT("/Game/FactoryGame/Buildable/Factory/AssemblerMk1/Build_AssemblerMk1.Build_AssemblerMk1_C")));
}

static void getAllFactories(UObject* WorldContext, FRequestData RequestData, TArray<TSharedPtr<FJsonValue>>& OutJsonArray) {
    // Use base class to get all instances
    OutJsonArray = getFactory_Helper(WorldContext, AFGBuildableManufacturer::StaticClass());
}
```

This approach allows for both specific filtering (using exact asset paths) and broad queries (using base classes).
