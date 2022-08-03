/*region Header
      Module Steps 
      1 - Create Synapse Workspace
      2 - Create your Firewall settings
      3 - Set the minimal TLS version for the SQL Pools 
      4 - Create your Dedicated SQL Pool
      5 - Create your Dedicated Apache Spark Pool
      6 - Create your Dedicated ADX Kusto Pool
      7 - Grant/Set Synapse MSI as SQL Admin
      8 - Create and apply RBAC
*/

//Declare Parameters--------------------------------------------------------------------------------------------------------------------------
param synapseWorkspaceName string
param resourceLocation string = resourceGroup().location

param networkIsolationMode string

param ctrlDeploySynapseSQLPool bool
param ctrlDeploySynapseSparkPool bool
param ctrlDeploySynapseADXPool bool

@description('Provide the user name for SQL login.')
param sqlAdministratorLogin string

@description('The passwords must meet the following guidelines:<ul><li> The password does not contain the account name of the user.</li><li> The password is at least eight characters long.</li><li> The password contains characters from three of the following four categories:</li><ul><li>Latin uppercase letters (A through Z)</li><li>Latin lowercase letters (a through z)</li><li>Base 10 digits (0 through 9)</li><li>Non-alphanumeric characters such as: exclamation point (!), dollar sign ($), number sign (#), or percent (%).</li></ul></ul> Passwords can be up to 128 characters long. Use passwords that are as long and complex as possible. Visit <a href=https://aka.ms/azuresqlserverpasswordpolicy>aka.ms/azuresqlserverpasswordpolicy</a> for more details.')
@secure()
param sqlAdministratorLoginPassword string

@description('Data Lake Storage account that you will use for Synapse Workspace.')
param defaultDataLakeStorageAccountName string
param defaultDataLakeStorageFileSystemName string
param defaultAdlsGen2AccountResourceId string = ''
param managedResourceGroupName string

@description('The encryption object containing your customer-managed key used for double encryption (optional).')
param encryption object = {
}

//Parameters for the Synapse Firewall
param createManagedPrivateEndpoint bool = false
param startIpaddress string
param endIpAddress string

//Paramaters for Role Assignments 
param userObjectId string
var defaultDataLakeStorageAccountUrl = 'https://${defaultDataLakeStorageAccountName}.dfs.core.windows.net'
var storageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' //This is the roleDefinitionId for the Storage Blob Data Contributor. See here: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
// var storageRoleUniqueId     = guid(resourceId('Microsoft.Storage/storageAccounts', synapseWorkspaceName), defaultDataLakeStorageAccountName)
// var storageRoleUserUniqueId = guid(resourceId('Microsoft.Storage/storageAccounts', synapseWorkspaceName), userObjectId)
param uamiPrincipalID string

//Paramaters for SQL Pools
param synapseDedicatedSQLPoolName string
param synapseSQLPoolSKU string
param collation string

//Paramaters for Spark Pools
param synapseSparkPoolName string
param synapseSparkPoolNodeSize string
param sparkPoolMinNodeCount int
param sparkPoolMaxNodeCount int

//Paramaters for ADX Kusto Pools
param synapseADXPoolName string
param synapseADXDatabaseName string
param synapseADXPoolEnableAutoScale bool
param synapseADXPoolMinSize int
param synapseADXPoolMaxSize int

//Create Resources----------------------------------------------------------------------------------------------------------------------------

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces?tabs=bicep
//1. Create your Synapse Workspace
resource r_synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: synapseWorkspaceName
  location: resourceLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: {
      accountUrl: defaultDataLakeStorageAccountUrl
      createManagedPrivateEndpoint: createManagedPrivateEndpoint
      filesystem: defaultDataLakeStorageFileSystemName
      resourceId: defaultAdlsGen2AccountResourceId
    }
    encryption: encryption
    managedResourceGroupName: managedResourceGroupName
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
     //publicNetworkAccess: Post Deployment Script will disable public network access for vNet integrated deployments.
     managedVirtualNetwork: (networkIsolationMode == 'vNet') ? 'default' : ''
     managedVirtualNetworkSettings: (networkIsolationMode == 'vNet')? {
       preventDataExfiltration:true
     }: null

    trustedServiceBypassEnabled: true
    workspaceRepositoryConfiguration: {
      accountName: 'APOps'
      collaborationBranch: 'main'
      hostName: 'https://dev.azure.com' //https://dev.azure.com/APOps/_git/FastHacks
      projectName: 'FastHacks'
      repositoryName: 'SynapseRepo'
      rootFolder: '/'
      tenantId: environment().authentication.tenant
      type: 'WorkspaceVSTSConfiguration' //This can either be WorkspaceVSTSConfiguration or WorkspaceGitHubConfiguration
    }
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/firewallrules
//2. Create your Firewall settings for your Synapse Workspace 
resource r_synapseWorkspaceFirewallAllowAll 'Microsoft.Synapse/workspaces/firewallrules@2021-06-01' = if (networkIsolationMode == 'default') {
  name: 'AllowAllNetworks'
  parent: r_synapseWorkspace 
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

//Allow Azure Services and resources to access this workspace
//Required for Post-Deployment Scripts
resource r_synapseWorkspaceFirewallAllowAzure 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  name: 'AllowAllWindowsAzureIps' //Please be aware that you have to name it exactly 'AllowAllWindowsAzureIps' or it will error out on you.
  parent: r_synapseWorkspace 
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/firewallrules
resource r_firewall_allowLocalIP 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  name: 'allowLocalIP'
  parent: r_synapseWorkspace 
  properties: {
    endIpAddress: endIpAddress
    startIpAddress: startIpaddress
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/dedicatedsqlminimaltlssetting
//3. Set the minimal TLS version for the SQL Pools 
resource r_minimumTLS 'Microsoft.Synapse/workspaces/dedicatedSQLminimalTlsSettings@2021-06-01' = {
  name: 'default'
  parent: r_synapseWorkspace
  properties: {
    minimalTlsVersion: '1.2'
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/sqlpools
//4. Create your Dedicated SQL Pool
resource r_sqlPool 'Microsoft.Synapse/workspaces/sqlPools@2021-06-01' = if (ctrlDeploySynapseSQLPool == true) {
  name: synapseDedicatedSQLPoolName
  location: resourceLocation
  parent: r_synapseWorkspace
  sku:{
    name: synapseSQLPoolSKU
  }
  properties:{
    collation: collation
    createMode: 'Default'
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/bigdatapools
//5. Create your Dedicated Apache Spark Pool
resource r_sparkPool 'Microsoft.Synapse/workspaces/bigDataPools@2021-06-01' = if(ctrlDeploySynapseSparkPool == true) {
  name: synapseSparkPoolName
  location: resourceLocation
  parent: r_synapseWorkspace
  properties:{
    autoPause:{
      enabled:true
      delayInMinutes: 15
    }
    autoScale:{
      enabled: true
      minNodeCount: sparkPoolMinNodeCount
      maxNodeCount: sparkPoolMaxNodeCount
    }
    nodeSize: synapseSparkPoolNodeSize
    nodeSizeFamily: 'MemoryOptimized'
    sparkVersion: '3.1'
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/kustopools
//6. Create your Dedicated ADX Kusto Pool
resource r_adxPool 'Microsoft.Synapse/workspaces/kustoPools@2021-06-01-preview' = if (ctrlDeploySynapseADXPool == true) {
  name: synapseADXPoolName
  location: resourceLocation
  parent: r_synapseWorkspace
  properties: {
    enablePurge: false
    enableStreamingIngest: true
    optimizedAutoscale: {
      isEnabled: synapseADXPoolEnableAutoScale
      maximum: synapseADXPoolMaxSize
      minimum: synapseADXPoolMinSize
      version: 1
    } 
  }
  //Double check this syntax ->https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/kustopools/databases
  resource r_adxDatabase 'databases' = {
    name: synapseADXDatabaseName
    kind: 'ReadWrite'
    location: resourceLocation
  }
  sku: {
    capacity: 2
    name: 'Compute optimized'
    size: 'Extra small'
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/managedidentitysqlcontrolsettings
//7. Grant/Set Synapse MSI as SQL Admin
resource r_managedIdentitySqlControlSettings 'Microsoft.Synapse/workspaces/managedIdentitySqlControlSettings@2021-06-01' = {
  name: 'default'
  parent: r_synapseWorkspace
  properties: {
    grantSqlControlToManagedIdentity: {
      desiredState:'Enabled'
    }
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.authorization/roleassignments
//https://docs.microsoft.com/en-us/azure/synapse-analytics/security/how-to-grant-workspace-managed-identity-permissions
//8.A Create and apply RBAC to your synapse managed identity to the synapse adls storage account -Synapse Workspace Role Assignment as Blob Data Contributor Role in the Data Lake Storage Account
resource r_storageAccount  'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: defaultDataLakeStorageAccountName
}

resource r_dataLakeRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(r_synapseWorkspace.name, defaultDataLakeStorageAccountName)
  scope: r_storageAccount     
  properties:{
    principalId: r_synapseWorkspace.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleID)
  }
}

// resource r_dataLakeRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
//   name: storageRoleUniqueId
//   scope: resourceGroup()       
//   properties:{
//     principalId: r_synapseWorkspace.identity.principalId
//     principalType: 'ServicePrincipal'
//     roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleID)
//   }
// }

//------------------------------------------------------------------this is causing issues------------------------------------------------------
//8.B Apply RBAC role to your User or Service Principal
// resource userroleassing 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
//   name: guid(r_synapseWorkspace.name, userObjectId)
//   scope: r_storageAccount 
//   properties:{
//     principalId: userObjectId
//     principalType: 'User'
//     roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleID)
//   }
// }


resource r_uami_workspace_admin 'Microsoft.Synapse/workspaces/administrators@2021-06-01' = {
  name: 'activeDirectory'
  parent: r_synapseWorkspace
  properties: {
    administratorType: 'ActiveDirectory'
    sid: uamiPrincipalID
    tenantId: subscription().tenantId
  }
}

// resource azureIR_1 'Microsoft.Synapse/workspaces/integrationRuntimes@2021-06-01' = {
//   name: 'AzureIR1'
//   parent: synapse
//   properties: {
//     description: 'string'
//     type: 'string'
//     // For remaining properties, see IntegrationRuntime objects
//   }
// }

// param storageAccountKey string
// param akvuri string

// resource LS_AKV 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
//   name: 'LS_AKV'
//   parent: synapse
//   properties: {
//     connectVia: {
//       parameters: {}
//       referenceName: 'AutoResolveIntegrationRuntime'
//       type: 'IntegrationRuntimeReference'
//     }
//     type: 'AzureKeyVault'
//     typeProperties: {
//     baseUrl: akvuri //${prefix}-keyvault-${randomstring} "baseUrl": "https://opnhckdaakv.vault.azure.net/"
//     credential: {
//       referenceName: 'string'
//       type: 'CredentialReference'
//     }
//   }
//   }
// }


// resource LS_ADLS_G2 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
//   name: 'string'
//   parent: synapse
//   properties: {
//     connectVia: {
//       referenceName: 'AutoResolveIntegrationRuntime'
//       type: 'IntegrationRuntimeReference' 
//     }
//     type: 'AzureBlobFS'
//     // For remaining properties, see LinkedService objects
//     typeProperties: {
//       accountKey: any(storageAccountKey)
//       azureCloudType: any('AzurePublic')
//       credential: {
//         referenceName: 'string'
//         type: 'CredentialReference'
//       }
//       //encryptedCredential: any()
//       servicePrincipalCredential: {
//         type: 'string'
//         // For remaining properties, see SecretBase objects
//       }
//       // servicePrincipalCredentialType: any()
//       // servicePrincipalId: any()
//       // servicePrincipalKey: {
//       //   type: 'string'
//       //   // For remaining properties, see SecretBase objects
//       // }
//       tenant: subscription().tenantId
//       url: any(defaultDataLakeStorageAccountUrl)//any('https://opnhckadlstorage.dfs.core.windows.net')
//     }
//   }
// }


//output workspaceDataLakeAccountID string = r_workspaceDataLakeAccount.id
//output workspaceDataLakeAccountName string = r_workspaceDataLakeAccount.name
output synapseWorkspaceID string = r_synapseWorkspace.id
output synapseWorkspaceName string = r_synapseWorkspace.name

output synapseSQLDedicatedEndpoint string = r_synapseWorkspace.properties.connectivityEndpoints.sql
output synapseSQLServerlessEndpoint string = r_synapseWorkspace.properties.connectivityEndpoints.sqlOnDemand

output synapseWorkspaceSparkID string = ctrlDeploySynapseSparkPool ? r_sparkPool.id : ''
output synapseWorkspaceSparkName string = ctrlDeploySynapseSparkPool ? r_sparkPool.name : ''

output synapseWorkspaceIdentityPrincipalID string = r_synapseWorkspace.identity.principalId
output synapsePrincipalId string = r_synapseWorkspace.identity.principalId
