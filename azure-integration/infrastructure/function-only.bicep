@description('Prefix for the new function app')
param functionPrefix string = 'satisfactory-v2'

@description('Location for the function app')
param location string = resourceGroup().location

@description('URL of your Satisfactory server with FRM mod')
param satisfactoryServerUrl string

@description('Name identifier for your Satisfactory server')
param satisfactoryServerName string = 'sands'

@description('Existing Event Hub Namespace name')
param existingEventHubNamespace string = 'satisfactory-eventhub-rwp7wtublc2uy'

@description('Existing Event Hub name')
param existingEventHubName string = 'satisfactory-data'

@description('Existing Application Insights name')
param existingAppInsightsName string = 'satisfactory-insights-rwp7wtublc2uy'

// Generate unique names for new resources
var newFunctionAppName = '${functionPrefix}-func-${uniqueString(resourceGroup().id, functionPrefix)}'
var newStorageAccountName = 'st${take(uniqueString(resourceGroup().id, functionPrefix), 18)}'

// Reference existing resources
resource existingEventHubNamespaceRef 'Microsoft.EventHub/namespaces@2021-11-01' existing = {
  name: existingEventHubNamespace
}

resource existingAppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: existingAppInsightsName
}

// Create new storage account for the new function
resource newStorageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: newStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// Create new function app plan
resource newFunctionAppPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${newFunctionAppName}-plan'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
  kind: 'functionapp'
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

// Create new function app with correct .NET 8 isolated configuration
resource newFunctionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: newFunctionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    serverFarmId: newFunctionAppPlan.id
    reserved: false
    isXenon: false
    hyperV: false
    siteConfig: {
      numberOfWorkers: 1
      acrUseManagedIdentityCreds: false
      alwaysOn: false
      http20Enabled: false
      functionAppScaleLimit: 200
      minimumElasticInstanceCount: 0
      netFrameworkVersion: 'v8.0'
      use32BitWorkerProcess: false
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
    scmSiteAlsoStopped: false
    clientAffinityEnabled: false
    clientCertEnabled: false
    httpsOnly: true
    redundancyMode: 'None'
    storageAccountRequired: false
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
}

// Configure the new function app settings
resource newFunctionAppSettings 'Microsoft.Web/sites/config@2021-03-01' = {
  parent: newFunctionApp
  name: 'appsettings'
  properties: {
    AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${newStorageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${newStorageAccount.listKeys().keys[0].value}'
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${newStorageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${newStorageAccount.listKeys().keys[0].value}'
    WEBSITE_CONTENTSHARE: toLower(newFunctionAppName)
    FUNCTIONS_EXTENSION_VERSION: '~4'
    FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'
    APPINSIGHTS_INSTRUMENTATIONKEY: existingAppInsights.properties.InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: existingAppInsights.properties.ConnectionString
    EVENT_HUB_NAMESPACE: '${existingEventHubNamespace}.servicebus.windows.net'
    EVENT_HUB_NAME: existingEventHubName
    SATISFACTORY_FRM_URL: satisfactoryServerUrl
    SATISFACTORY_SERVER_NAME: satisfactoryServerName
  }
}

// Grant the new function app permission to send to existing Event Hub
resource eventHubDataSenderRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, newFunctionAppName, 'EventHubDataSender')
  scope: existingEventHubNamespaceRef
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2b629674-e913-4c01-ae53-ef4638d8f975')
    principalId: newFunctionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output newFunctionAppName string = newFunctionAppName
output newStorageAccountName string = newStorageAccountName
output usingExistingEventHub string = '${existingEventHubNamespace}/${existingEventHubName}'
output usingExistingAppInsights string = existingAppInsightsName
