param location string = resourceGroup().location

@description('The name of the primary ADLS Gen2 Storage Account. If not provided, the workspace name will be used.')
@minLength(3)
@maxLength(24)
param storageAccount string
param storageAccountContainer string


@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
  'Premium_LRS'
])
param storageAccountType string = 'Standard_LRS'

//https://docs.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts?tabs=bicep
//1. Create your Storage Account (ADLS Gen2 & HNS Enabled) for your Synapse Workspace
resource storageAccount_resource 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageAccount
  kind: 'StorageV2'
  location: location
  properties:{
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          enabled: true
        }
        blob: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
  sku: {
    name: storageAccountType
  }
  tags: {
    Type: 'Synapse Data Lake Storage'
  }
}

//2. Create your default/root folder structure
resource storageAccount_default 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  parent: storageAccount_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

//3. Create a container called fasthack-synapse in the root
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: '${storageAccount_resource.name}/default/${storageAccountContainer}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn:[
    storageAccount_default
  ]
} 

//4. Create another container called bronze in the root
resource containerBronze 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: '${storageAccount_resource.name}/default/bronze'
  properties: {
    publicAccess: 'None'
  }
  dependsOn:[
    storageAccount_default
  ]
} 

//5. Create another container called silver in the root
resource containerSilver 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: '${storageAccount_resource.name}/default/silver'
  properties: {
    publicAccess: 'None'
  }
  dependsOn:[
    storageAccount_default
  ]
} 

//6. Create another container called gold in the root
resource containerGold 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: '${storageAccount_resource.name}/default/gold'
  properties: {
    publicAccess: 'None'
  }
  dependsOn:[
    storageAccount_default
  ]
} 
