param location string
param prefix string
param tags object

// Azure AI Service
resource aiService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: '${prefix}-ai'
  location: location
  tags: tags
  sku: {
    name: 'S0'
  }
  kind: 'CognitiveServices'
  properties: {
    customSubDomainName: '${prefix}-ai'
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
  }
}

output aiEndpoint string = aiService.properties.endpoint
output aiServiceName string = aiService.name
