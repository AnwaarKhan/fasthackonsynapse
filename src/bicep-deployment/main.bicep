//Global Paramaters
param location string = resourceGroup().location
param prefix string = 'fasthack'
param utcValue string = utcNow()
var randomstring = toLower(replace(uniqueString(subscription().id, resourceGroup().id, utcValue), '-', ''))


//Synapse Module Parameters
var synapseName = '${prefix}${randomstring}'
param ipaddress string
param sqlAdministratorLogin string
param sqlAdministratorLoginPassword string
var storageAccountName = '${prefix}${randomstring}'
param storageAccountType string
param sqlpoolName string
param bigDataPoolName string
param nodeSize string
param sparkPoolMinNodeCount int
param sparkPoolMaxNodeCount int
param defaultDataLakeStorageFilesystemName string
param collation string
param userObjectId string
param dataLakeUrlFormat string


//Deploy the VNet
module vnet 'modules/deploy_vnet.bicep' = {
  name: 'deploy_vnet'
  params: {
    prefix: prefix
    location: location
  }
}

// Deploy Storage Accounts
module storage 'modules/deploy_storage.bicep' = {
  name: 'deploy_storage'
  params: {
    prefix: prefix
    location: location
  }
}

//Deploy Synapse Workspace
module synapse 'modules/deploy_synapse.bicep' = {
  name: 'deploy_synapse'
  params: {
    location: location
    synapseName: synapseName
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
    storageAccountName: storageAccountName
    storageAccountType: storageAccountType
    sqlpoolName: sqlpoolName
    bigDataPoolName: bigDataPoolName
    nodeSize: nodeSize
    sparkPoolMinNodeCount: sparkPoolMinNodeCount
    sparkPoolMaxNodeCount: sparkPoolMaxNodeCount
    defaultDataLakeStorageFilesystemName: defaultDataLakeStorageFilesystemName
    collation: collation
    startIpaddress: ipaddress
    endIpAddress: ipaddress
    userObjectId: userObjectId
    dataLakeUrlFormat: dataLakeUrlFormat
  }
}

output randomstringOut string = randomstring
output modMain string = deployment().name
output modVNet string = vnet.name
output modStorage string = storage.name

output synapseNameOut string = synapseName
output storageAccountNameOut string = storageAccountName
output sqlpoolNameOut string = sqlpoolName
output bigDataPoolNameOut string = bigDataPoolName
output startIpaddressOut string = ipaddress
output endIpAddressOut string = ipaddress
output dataLakeUrlFormatOut string = dataLakeUrlFormat

output storageRoleUniqueIdOut string = synapse.outputs.storageRoleUniqueIdOut
output storageRoleUserUniqueIdOut string = synapse.outputs.storageRoleUserUniqueIdOut
