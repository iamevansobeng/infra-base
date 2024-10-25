param location string
param prefix string
param tags object
param environment string
param apiImageTag string
param frontendSubnetId string
param apiSubnetId string
param appInsightsInstrumentationKey string

var containerAppSettings = [
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: 'InstrumentationKey=${appInsightsInstrumentationKey}'
  }
  {
    name: 'ENVIRONMENT'
    value: environment
  }
]

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${prefix}-plan'
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'B1' : 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true
  }
}

// Frontend App Service
resource frontendApp 'Microsoft.Web/sites@2023-01-01' = {
  name: '${prefix}-frontend'
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    virtualNetworkSubnetId: frontendSubnetId
    siteConfig: {
      nodeVersion: '18-lts'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${appInsightsInstrumentationKey}'
        }
      ]
    }
  }
}

// Container Apps Environment
resource containerAppsEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: '${prefix}-env'
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: apiSubnetId
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
    }
  }
}

// API Container App
resource apiApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${prefix}-api'
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerAppsEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 3000
      }
      secrets: []
    }
    template: {
      containers: [
        {
          name: 'api'
          image: '${prefix}acr.azurecr.io/${prefix}-api:${apiImageTag}'
          env: containerAppSettings
          resources: {
            cpu: json(environment == 'prod' ? '1.0' : '0.5')
            memory: '2Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: environment == 'prod' ? 10 : 2
      }
    }
  }
}

output frontendUrl string = frontendApp.properties.defaultHostName
output apiUrl string = apiApp.properties.configuration.ingress.fqdn
