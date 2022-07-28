/*region Header
      =========================================================================================================
      Created by:       Author: Your Name | your.name@microsoft.com 
      Created on:       7/28/2022
      =========================================================================================================

      Dependencies:
        Install Azure CLI
        https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest 

      SCRIPT STEPS 
      1 - Create Managed VNet
      2 - Create Storage Accounts
      3 - Create Synapse Workspace
      4 - 
*/

//Declare Parameters---------------------------------------------------------------------
//Global Paramaters
targetScope = 'resourceGroup'

param prefix string = 'fasthack'
param location string = resourceGroup().location
param utcValue string = utcNow()
var randomstring = substring(toLower(replace(uniqueString(subscription().id, resourceGroup().id, utcValue), '-', '')), 1, 3) 

//Data Lake Storage Account for Synapse Workspace
param storageAccountType string
var storageAccount = '${prefix}adls${randomstring}'

//Synapse Module Parameters
var synapseWorkspace = '${prefix}-synapse-${randomstring}'

param defaultDataLakeStorageFileSystemName string
param userObjectId string //This is your Service Principal ID
param ipaddress string    //This is your local ip address

@description('Managed resource group is a container that holds ancillary resources created by Azure Synapse Analytics for your workspace. By default, a managed resource group is created for you when your workspace is created. Optionally, you can specify the name of the resource group that will be created by Azure Synapse Analytics to satisfy your organization’s resource group name policies.')
param synapseManagedResourceGroup string

@description('Provide the user name for SQL login.')
param sqlAdministratorLogin string

@description('The passwords must meet the following guidelines:<ul><li> The password does not contain the account name of the user.</li><li> The password is at least eight characters long.</li><li> The password contains characters from three of the following four categories:</li><ul><li>Latin uppercase letters (A through Z)</li><li>Latin lowercase letters (a through z)</li><li>Base 10 digits (0 through 9)</li><li>Non-alphanumeric characters such as: exclamation point (!), dollar sign ($), number sign (#), or percent (%).</li></ul></ul> Passwords can be up to 128 characters long. Use passwords that are as long and complex as possible. Visit <a href=https://aka.ms/azuresqlserverpasswordpolicy>aka.ms/azuresqlserverpasswordpolicy</a> for more details.')
param sqlAdministratorLoginPassword string

//Enabling Double Encryption using a customer-managed key
//Choose to encrypt all data at rest in the workspace with a key managed by you (customer-managed key). This will provide double encryption with encryption at the infrastructure layer that uses platform-managed keys.
//The encryption key must be in an Azure Key Vault located in the same region as the Synapse workspace.
//https://go.microsoft.com/fwlink/?linkid=2147714
@description('The uri to a key in your Key Vault to add a second layer of encryption on top of the default infrastructure encryption. Key identifier should be in the format of: (i.e. https://{keyvaultname}.vault.azure.net/keys/{keyname}')
param cmkUri string = ''
var cmkUriStripVersion = (empty(cmkUri) ? '' : substring(cmkUri, 0, lastIndexOf(cmkUri, '/')))
var withCmk = {
  cmk: {
    key: {
      name: 'default'
      keyVaultUrl: cmkUriStripVersion
    }
  }
}
var encryption = (empty(cmkUri) ? json('{}') : withCmk)


//Synapse Workspace SQL Pool Parameters
param sqlpoolName string
param collation string
param bigDataPoolName string
param nodeSize string
param sparkPoolMinNodeCount int
param sparkPoolMaxNodeCount int

//Create Resources---------------------------------------------------------------------

//Deploy the VNet (The VNet Module needs to be expanded and will be expanded when we place Synapse Workspace within a Managed VNet that uses Private Endpoints.)
module vnet 'modules/deploy_vnet.bicep' = {
  name: 'deploy_vnet'
  params: {
    prefix: prefix
    location: location
  }
}

// Deploy Storage Accounts (Create your Storage Account (ADLS Gen2 & HNS Enabled) for your Synapse Workspace)
module storage 'modules/deploy_storage.bicep' = {
  name: 'deploy_storage'
  params: {
    location: location
    storageAccount: storageAccount
    storageAccountContainer: toLower('${prefix}-synapse')
    storageAccountType: storageAccountType
  }
}

//Deploy Synapse Workspace
 module synapse 'modules/deploy_synapse.bicep' = {
  name: 'deploy_synapse'
  params: {
    location: location
    synapseName: toLower(synapseWorkspace)
    defaultDataLakeStorageAccountName: storageAccount
    defaultDataLakeStorageFileSystemName: toLower('${prefix}-synapse')
    encryption: encryption
    managedResourceGroupName: synapseManagedResourceGroup
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword

    //Send in your ipAddress(s) into the synapse module to enable access to your Local IP
    startIpaddress: ipaddress
    endIpAddress: ipaddress
    //Send in your Service Principal ID
    userObjectId: userObjectId

    //Send in SQL Pool and Apache Spark Pool Parameters
    sqlpoolName: sqlpoolName
    collation: collation
    bigDataPoolName: bigDataPoolName
    nodeSize: nodeSize
    sparkPoolMinNodeCount: sparkPoolMinNodeCount
    sparkPoolMaxNodeCount: sparkPoolMaxNodeCount
  }
  dependsOn: [
    storage
  ]
}


output modMain string = deployment().name
output modVNet string = vnet.name
output modStorage string = storage.name
output modSynapse string = synapse.name

output princOut string = synapse.outputs.synapsePrincipalId
