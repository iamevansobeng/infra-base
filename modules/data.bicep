param location string
param prefix string
param tags object
param environment string

// Cosmos DB Account
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-09-15' = {
  name: '${prefix}-cosmos'
  location: location
  tags: tags
  kind: 'MongoDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    enableFreeTier: environment == 'dev'
    capabilities: [
      {
        name: 'EnableServerless'
      }
      {
        name: 'EnableMongo'
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    networkAclBypass: 'None'
    ipRules: []
    networkAclBypassResourceIds: []
  }
}

// Redis Cache
resource redis 'Microsoft.Cache/Redis@2023-08-01' = {
  name: '${prefix}-redis'
  location: location
  tags: tags
  properties: {
    sku: {
      name: environment == 'prod' ? 'Basic' : 'Basic'
      family: 'C'
      capacity: environment == 'prod' ? 1 : 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// Database
resource database 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2023-09-15' = {
  parent: cosmosAccount
  name: 'tuagye'
  properties: {
    resource: {
      id: 'tuagye'
    }
  }
}

// Collections
resource addressesCollection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2023-09-15' = {
  parent: database
  name: 'addresses'
  properties: {
    resource: {
      id: 'addresses'
      indexes: [
        {
          key: {
            keys: [
              '_id'
            ]
          }
        }
        {
          key: {
            keys: [
              'location'
            ]
          }
        }
      ]
      shardKey: {
        region: 'Hash'
      }
    }
  }
}

// We only output the resource names, not the connection strings
output cosmosDbName string = cosmosAccount.name
output redisName string = redis.name
output databaseName string = database.name
