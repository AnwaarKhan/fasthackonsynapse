/*region Header
      SCRIPT STEPS 
      1 - Create Synapse Workspace
      2 - Create your Firewall settings
      3 - Create and apply RBAC
      4 - Set the minimal TLS version for the SQL Pools 
      5 - Grant SQL control to Synapse Managed Identity
      6 - Create your Dedicated SQL Pool
      7 - Create your Dedicated Apache Spark Pool
*/

//Declare Parameters---------------------------------------------------------------------
param synapseName string
param location string = resourceGroup().location

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
param allowAllConnections bool = true
param createManagedPrivateEndpoint bool = false
param startIpaddress string
param endIpAddress string

//Paramaters for Role Assignments 
param userObjectId string
var defaultDataLakeStorageAccountUrl = 'https://${defaultDataLakeStorageAccountName}.dfs.core.windows.net'
var storageRoleUniqueId = guid(resourceId('Microsoft.Storage/storageAccounts', synapseName), defaultDataLakeStorageAccountName)
var storageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' //This is the roleDefinitionId for the Storage Blob Data Contributor. See here: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var storageRoleUserUniqueId = guid(resourceId('Microsoft.Storage/storageAccounts', synapseName), userObjectId)

//Paramaters for SQL Pools
param sqlpoolName string
param collation string
param bigDataPoolName string
param nodeSize string
param sparkPoolMinNodeCount int
param sparkPoolMaxNodeCount int

//Create Resources---------------------------------------------------------------------

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces?tabs=bicep
//1. Create your Synapse Workspace
resource synapse 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: synapseName
  location: location
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
    trustedServiceBypassEnabled: true
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/firewallrules
//2. Create your Firewall settings for your Synapse Workspace - Allow Azure services and resources to access this workspace
resource firewall_allowazure4synapse 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  name: 'AllowAllWindowsAzureIps' //Please be aware that you have to name it exactly 'AllowAllWindowsAzureIps' or it will error out on you.
  parent: synapse
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/firewallrules
resource firewall_allowLocalIP 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  name: 'allowLocalIP'
  parent: synapse
  properties: {
    endIpAddress: endIpAddress
    startIpAddress: startIpaddress
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/firewallrules
resource name_allowAll 'Microsoft.Synapse/workspaces/firewallrules@2021-06-01' = if (allowAllConnections) {
  name: 'allowAll'
  parent: synapse
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.authorization/roleassignments
//3.A Create and apply RBAC to your synapse managed identity to the synapse adls storage account
resource synapseroleassing1 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: storageRoleUniqueId
  scope: resourceGroup()       
  properties:{
    principalId: synapse.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleID)
  }
}

//3.B Apply RBAC role to your User or Service Principal
resource userroleassing 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: storageRoleUserUniqueId
  scope: resourceGroup()  
  properties:{
    principalId: userObjectId
    principalType: 'User'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleID)
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/dedicatedsqlminimaltlssetting
//4. Set the minimal TLS version for the SQL Pools 
resource symbolicname 'Microsoft.Synapse/workspaces/dedicatedSQLminimalTlsSettings@2021-06-01' = {
  name: 'default'
  parent: synapse
  properties: {
    minimalTlsVersion: '1.2'
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/managedidentitysqlcontrolsettings
//5. Grant SQL control to Synapse Managed Identity
resource manageid4Pipeline 'Microsoft.Synapse/workspaces/managedIdentitySqlControlSettings@2021-06-01' = {
  name: 'default'
  parent: synapse
  properties: {
    grantSqlControlToManagedIdentity: {
      desiredState:'Enabled'
    }
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/sqlpools
//6. Create your Dedicated SQL Pool
resource sqlpool 'Microsoft.Synapse/workspaces/sqlPools@2021-06-01' = {
  name: sqlpoolName
  location: location
  parent: synapse
  sku:{
    name: 'DW100c'
  }
  properties:{
    collation: collation
    createMode: 'Default'
  }
}

//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/bigdatapools
//7. Create your Dedicated Apache Spark Pool
// resource sparkpool 'Microsoft.Synapse/workspaces/bigDataPools@2021-06-01' = {
//   name: bigDataPoolName
//   location: location
//   parent: synapse
//   properties:{
//     nodeSize: nodeSize
//     nodeSizeFamily: 'MemoryOptimized'
//     autoScale:{
//       enabled: true
//       minNodeCount: sparkPoolMinNodeCount
//       maxNodeCount: sparkPoolMaxNodeCount
//     }
//     autoPause:{
//       enabled: true
//       delayInMinutes: 15
//     }
//     sparkVersion: '3.1'
//   }
// }

output synapsePrincipalId string = synapse.identity.principalId
