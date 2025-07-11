## GetPlayerData Response Schema

```json
{
  "timestamp": "datetime",
  "endpoint": "string",
  "server": "string",
  "data": [
    {
      "ID": "string",
      "Name": "string",
      "ClassName": "string",
      "location": {
        "x": "real",
        "y": "real",
        "z": "string",
        "rotation": "string"
      },
      "Inventory": [
        {
          "Name": "string",
          "ClassName": "string",
          "Amount": "long",
          "MaxAmount": "long"
        }
      ],
      "features": {
        "properties": {
          "name": "string",
          "type": "string"
        },
        "geometry": {
          "type": "string",
          "coordinates": {
            "x": "real",
            "y": "real",
            "z": "string"
          }
        }
      },
      "Speed": "long",
      "Online": "bool",
      "PlayerHP": "long",
      "Dead": "bool"
    }
  ],
  "x-opt-enqueued-time": "datetime",
  "x-opt-sequence-number": "long",
  "x-opt-offset": "long",
  "x-opt-publisher": "string",
  "x-opt-partition-key": "string"
}
```

## Enpoint GetVechcle

```json
{
  "timestamp": "datetime",
  "endpoint": "string",
  "server": "string",
  "data": [
    {
      "ID": "string",
      "Name": "string",
      "ClassName": "string",
      "location": {
        "x": "real",
        "y": "real",
        "z": "string",
        "rotation": "string"
      },
      "PathName": "string",
      "Status": "string",
      "CurrentGear": "long",
      "ForwardSpeed": "long",
      "EngineRPM": "real",
      "ThrottlePercent": "long",
      "Airborne": "bool",
      "FollowingPath": "bool",
      "Autopilot": "bool",
      "HasFuel": "bool",
      "HasFuelForRoundtrip": "bool",
      "TotalFuelEnergy": "real",
      "MaxFuelEnergy": "real",
      "Inventory": [
        {
          "Name": "string",
          "ClassName": "string",
          "Amount": "long",
          "MaxAmount": "long"
        }
      ],
      "FuelInventory": [
        {
          "Name": "string",
          "ClassName": "string",
          "Amount": "long",
          "MaxAmount": "long"
        }
      ],
      "features": {
        "properties": {
          "name": "string",
          "type": "string"
        },
        "geometry": {
          "type": "string",
          "coordinates": {
            "x": "real",
            "y": "real",
            "z": "string"
          }
        }
      }
    }
  ],
  "x-opt-enqueued-time": "datetime",
  "x-opt-sequence-number": "long",
  "x-opt-offset": "long",
  "x-opt-publisher": "string",
  "x-opt-partition-key": "string"
}
```

## getSessionInfo

```json
{
  "timestamp": "datetime",
  "endpoint": "string",
  "server": "string",
  "data": {
    "SessionName": "string",
    "IsPaused": "bool",
    "DayLength": "long",
    "NightLength": "long",
    "PassedDays": "long",
    "NumberOfDaysSinceLastDeath": "long",
    "Hours": "long",
    "Minutes": "long",
    "Seconds": "real",
    "IsDay": "bool",
    "TotalPlayDuration": "long",
    "TotalPlayDurationText": "string"
  },
  "x-opt-enqueued-time": "datetime",
  "x-opt-sequence-number": "long",
  "x-opt-offset": "long",
  "x-opt-publisher": "string",
  "x-opt-partition-key": "string"
}
```

## get Generators

```json
{
  "timestamp": "datetime",
  "endpoint": "string",
  "server": "string",
  "data": [
    {
      "ID": "string",
      "Name": "string",
      "ClassName": "string",
      "location": {
        "x": "real",
        "y": "real",
        "z": "string",
        "rotation": "real"
      },
      "FuelInventory": [
        {
          "Name": "string",
          "ClassName": "string",
          "Amount": "long",
          "MaxAmount": "long"
        }
      ],
      "features": {
        "properties": {
          "name": "string",
          "type": "string"
        },
        "geometry": {
          "type": "string",
          "coordinates": {
            "x": "real",
            "y": "real",
            "z": "string"
          }
        }
      },
      "BoundingBox": {
        "min": {
          "x": "real",
          "y": "real",
          "z": "string"
        },
        "max": {
          "x": "real",
          "y": "real",
          "z": "string"
        }
      },
      "ColorSlot": {
        "PrimaryColor": "string",
        "SecondaryColor": "string"
      },
      "BaseProd": "long",
      "DynamicProdCapacity": "long",
      "DynamicProdDemandFactor": "long",
      "RegulatedDemandProd": "long",
      "IsFullSpeed": "bool",
      "CanStart": "bool",
      "LoadPercentage": "long",
      "ProdPowerConsumption": "long",
      "CurrentPotential": "long",
      "ProductionCapacity": "long",
      "DefaultProductionCapacity": "long",
      "PowerProductionPotential": "long",
      "Somersloops": "long",
      "PowerShards": "long",
      "FuelAmount": "real",
      "Supplement": {
        "Name": "string",
        "ClassName": "string",
        "CurrentConsumed": "long",
        "MaxConsumed": "long",
        "PercentFull": "real"
      },
      "NuclearWarning": "string",
      "FuelResource": "string",
      "GeoMinPower": "long",
      "GeoMaxPower": "long",
      "AvailableFuel": [
        {
          "Name": "string",
          "ClassName": "string",
          "Amount": "long"
        }
      ],
      "WasteInventory": [
        {
          "Name": "string",
          "ClassName": "string",
          "Amount": "long",
          "MaxAmount": "long"
        }
      ],
      "PowerInfo": {
        "CircuitGroupID": "long",
        "CircuitID": "long",
        "FuseTriggered": "bool",
        "PowerConsumed": "long",
        "MaxPowerConsumed": "long"
      }
    }
  ],
  "x-opt-enqueued-time": "datetime",
  "x-opt-sequence-number": "long",
  "x-opt-offset": "long",
  "x-opt-publisher": "string",
  "x-opt-partition-key": "string"
}
```

## getPower

```json
{
  "timestamp": "datetime",
  "endpoint": "string",
  "server": "string",
  "data": [
    {
      "CircuitGroupID": "long",
      "FuseTriggered": "bool",
      "PowerConsumed": "real",
      "PowerProduction": "real",
      "PowerCapacity": "real",
      "PowerMaxConsumed": "real",
      "BatteryInput": "real",
      "BatteryOutput": "real",
      "BatteryDifferential": "real",
      "BatteryPercent": "long",
      "BatteryCapacity": "long",
      "BatteryTimeEmpty": "string",
      "BatteryTimeFull": "string",
      "AssociatedCircuits": ["long"]
    }
  ],
  "x-opt-enqueued-time": "datetime",
  "x-opt-sequence-number": "long",
  "x-opt-offset": "long",
  "x-opt-publisher": "string",
  "x-opt-partition-key": "string"
}
```

## get Player

```json
{
  "timestamp": "datetime",
  "endpoint": "string",
  "server": "string",
  "data": [
    {
      "ID": "string",
      "Name": "string",
      "ClassName": "string",
      "location": {
        "x": "real",
        "y": "real",
        "z": "string",
        "rotation": "string"
      },
      "Inventory": [
        {
          "Name": "string",
          "ClassName": "string",
          "Amount": "long",
          "MaxAmount": "long"
        }
      ],
      "features": {
        "properties": {
          "name": "string",
          "type": "string"
        },
        "geometry": {
          "type": "string",
          "coordinates": {
            "x": "real",
            "y": "real",
            "z": "string"
          }
        }
      },
      "Speed": "long",
      "Online": "bool",
      "PlayerHP": "long",
      "Dead": "bool"
    }
  ],
  "x-opt-enqueued-time": "datetime",
  "x-opt-sequence-number": "long",
  "x-opt-offset": "long",
  "x-opt-publisher": "string",
  "x-opt-partition-key": "string"
}
```

## getExtractors

```json
{
  "timestamp": "datetime",
  "endpoint": "string",
  "server": "string",
  "data": [
    {
      "ID": "string",
      "Name": "string",
      "ClassName": "string",
      "location": {
        "x": "real",
        "y": "real",
        "z": "real",
        "rotation": "string"
      },
      "features": {
        "properties": {
          "name": "string",
          "type": "string"
        },
        "geometry": {
          "type": "string",
          "coordinates": {
            "x": "real",
            "y": "real",
            "z": "real"
          }
        }
      },
      "IsPaused": "bool",
      "BoundingBox": {
        "min": {
          "x": "real",
          "y": "real",
          "z": "real"
        },
        "max": {
          "x": "real",
          "y": "real",
          "z": "real"
        }
      },
      "ColorSlot": {
        "PrimaryColor": "string",
        "SecondaryColor": "string"
      },
      "Somersloops": "long",
      "PowerShards": "long",
      "PowerInfo": {
        "CircuitGroupID": "long",
        "CircuitID": "long",
        "FuseTriggered": "bool",
        "PowerConsumed": "real",
        "MaxPowerConsumed": "real"
      },
      "Recipe": "string",
      "RecipeClassName": "string",
      "production": [
        {
          "Name": "string",
          "ClassName": "string",
          "Amount": "real",
          "MaxAmount": "long",
          "CurrentProd": "real",
          "MaxProd": "long",
          "ProdPercent": "real"
        }
      ],
      "ManuSpeed": "long",
      "IsConfigured": "bool",
      "IsProducing": "bool"
    }
  ],
  "x-opt-enqueued-time": "datetime",
  "x-opt-sequence-number": "long",
  "x-opt-offset": "long",
  "x-opt-publisher": "string",
  "x-opt-partition-key": "string"
}
```
