/*region Header
      Module Steps 
      1 - Create Streaming Analytics Job
*/

//Declare Parameters--------------------------------------------------------------------------------------------------------------------------
param ctrlDeployStreaming bool
param ctrlDeployOperationalDB bool
param ctrlDeployCosmosDB bool 

param dataLakeAccountName string
param synapseWorkspaceName string
param synapseWorkspaceIdentityPrincipalID string
param UAMIPrincipalID string

var azureRBACStorageBlobDataReaderRoleID = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' //Storage Blob Data Reader Role: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-reader
var azureRBACStorageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' //Storage Blob Data Contributor Role: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor
var azureRBACContributorRoleID = 'b24988ac-6180-42a0-ab88-20f7382dd24c' //Contributor: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor
var azureRBACOwnerRoleID = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' //Owner: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner
var azureRBACReaderRoleID = 'acdd72a7-3385-48ef-bd42-f606fba81ae7' //Reader: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#reader

//Reference existing resources for permission assignment scope
resource r_dataLakeStorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: dataLakeAccountName
}

resource r_synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' existing = {
  name: synapseWorkspaceName
}

//Create Resources----------------------------------------------------------------------------------------------------------------------------

//https://docs.microsoft.com/en-us/azure/templates/microsoft.authorization/roleassignments
//https://docs.microsoft.com/en-us/azure/synapse-analytics/security/how-to-grant-workspace-managed-identity-permissions
//1. Assign Owner Role to UAMI in the Synapse Workspace. UAMI needs to be Owner so it can assign itself as Synapse Admin and create resources in the Data Plane.
resource r_synapseWorkspaceOwner 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  //name: guid('cbe28037-09a6-4b35-a751-8dfd3f03f59d', subscription().subscriptionId, resourceGroup().id)
  //name: guid(resourceId('Microsoft.Synapse/workspaces', synapseWorkspaceName), subscription().subscriptionId, resourceGroup().id)
  name: guid(resourceId('Microsoft.Storage/storageAccounts', synapseWorkspaceName), UAMIPrincipalID)
  scope: r_synapseWorkspace
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACOwnerRoleID)
    principalId: UAMIPrincipalID
    principalType:'ServicePrincipal'
  }
}

//2. Deployment script UAMI is set as Resource Group owner so it can have authorization to perform post deployment tasks
resource r_deploymentScriptUAMIRGOwner 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid('139d07dd-a26c-4b29-9619-8f70ea215795', subscription().subscriptionId, resourceGroup().id)
  scope: resourceGroup()
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACOwnerRoleID)
    principalId: UAMIPrincipalID
    principalType:'ServicePrincipal'
  }
}

// resource r_dataLakeRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
//   name: guid(r_synapseWorkspace.name, defaultDataLakeStorageAccountName)
//   scope: r_storageAccount     
//   properties:{
//     principalId: r_synapseWorkspace.identity.principalId
//     principalType: 'ServicePrincipal'
//     roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleID)
//   }
// }

// resource userroleassing 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
//   name: guid(r_synapseWorkspace.name, userObjectId)
//   scope: r_storageAccount 
//   properties:{
//     principalId: userObjectId
//     principalType: 'User'
//     roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleID)
//   }
// }

//3. Assign Storage Blob Data Contributor Role to Synapse Workspace in the Raw Data Lake Account as per https://docs.microsoft.com/en-us/azure/synapse-analytics/security/how-to-grant-workspace-managed-identity-permissions#grant-the-managed-identity-permissions-to-adls-gen2-storage-account
//Create and apply RBAC to your synapse managed identity to the synapse adls storage account -Synapse Workspace Role Assignment as Blob Data Contributor Role in the Data Lake Storage Account
resource r_synapseWorkspacetorageBlobDataContributor 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  //name: guid('a1fb98aa-4c53-4a4d-951f-3ac730a27a5b', subscription().subscriptionId, resourceGroup().id)
  name: guid(resourceId('Microsoft.Storage/storageAccounts', synapseWorkspaceName), r_dataLakeStorageAccount.name)
  scope: r_dataLakeStorageAccount
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataContributorRoleID)
    principalId: synapseWorkspaceIdentityPrincipalID
    principalType:'ServicePrincipal'
  }
}

//https://docs.microsoft.com/en-us/azure/synapse-analytics/security/how-to-manage-synapse-rbac-role-assignments
//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/administrators
//4. Make the User Assigned Managed Identity a Synapse Administrator
resource r_userObjectId_workspace_admin 'Microsoft.Synapse/workspaces/administrators@2021-06-01' = {
  name: 'activeDirectory'
  parent: r_synapseWorkspace
  properties: {
    administratorType: 'ActiveDirectory'
    sid: UAMIPrincipalID
    tenantId: subscription().tenantId
  }
}
