targetScope = 'subscription'

@description('Environment name (dev/prod)')
@allowed([
  'dev'
  'prod'
])
param environment string

@description('Project name')
param projectName string

@description('Azure region')
@allowed([
  'uksouth'
  'westeurope'
])
param location string = 'uksouth'

@description('API container image tag')
param apiImageTag string

@description('Domain name')
param domainName string

// Variables
var prefix = '${projectName}-${environment}'
var rgName = '${prefix}-rg'
var defaultTags = {
  Environment: environment
  Project: projectName
  ManagedBy: 'Bicep'
}

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: location
  tags: defaultTags
}

// Networking
module networking 'modules/networking.bicep' = {
  scope: rg
  name: 'networkingDeployment'
  params: {
    location: location
    prefix: prefix
    tags: defaultTags
  }
}

// Compute Resources (App Service & Container Apps)
module compute 'modules/compute.bicep' = {
  scope: rg
  name: 'computeDeployment'
  params: {
    location: location
    prefix: prefix
    tags: defaultTags
    apiImageTag: apiImageTag
    frontendSubnetId: networking.outputs.frontendSubnetId
    apiSubnetId: networking.outputs.apiSubnetId
    environment: environment
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsKey // Fixed parameter name
  }
  dependsOn: [
    networking
  ]
}

// Data Resources (Cosmos DB & Redis)
module data 'modules/data.bicep' = {
  scope: rg
  name: 'dataDeployment'
  params: {
    location: location
    prefix: prefix
    tags: defaultTags
    environment: environment
  }
  dependsOn: [
    networking
  ]
}

// Monitoring & Logging
module monitoring 'modules/monitoring.bicep' = {
  scope: rg
  name: 'monitoringDeployment'
  params: {
    location: location
    prefix: prefix
    tags: defaultTags
  }
}

// AI Services
module ai 'modules/ai.bicep' = {
  scope: rg
  name: 'aiDeployment'
  params: {
    location: location
    prefix: prefix
    tags: defaultTags
  }
}

// Front Door & WAF
module frontDoor 'modules/frontDoor.bicep' = {
  scope: rg
  name: 'frontDoorDeployment'
  params: {
    prefix: prefix
    frontendUrl: compute.outputs.frontendUrl
    apiUrl: compute.outputs.apiUrl
    tags: defaultTags
  }
  dependsOn: [
    compute
  ]
}
// Outputs
output resourceGroupName string = rgName
output frontendUrl string = frontDoor.outputs.frontendEndpoint
output apiUrl string = frontDoor.outputs.apiEndpoint
output cosmosDbName string = data.outputs.cosmosDbName
output redisName string = data.outputs.redisName
output appInsightsKey string = monitoring.outputs.appInsightsKey
output aiEndpoint string = ai.outputs.aiEndpoint

// Connection strings will be retrieved post-deployment using Azure CLI
