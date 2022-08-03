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
      3 - Create Key Vault
      4 - Create Synapse Workspace
      5 - Create Synapse Workspace ADF Assets (Integration Runtimes, Linkd Services, Datasets, Pipelines, Notebooks, Triggers, etc. )
      6 - Create Event Hub
*/

//********************************************************
// Workload Deployment Control Parameters
//********************************************************
param ctrlDeployStreaming bool = false        //Controls the deployment of EventHubs and Stream Analytics
param ctrlDeployOperationalDB bool = false   //Controls the creation of operational Azure database data sources
param ctrlDeployCosmosDB bool = false        //Controls the creation of CosmosDB if (ctrlDeployOperationalDBs == true)
param ctrlDeploySampleArtifacts bool = false //Controls the creation of sample artifcats (SQL Scripts, Notebooks, Linked Services, Datasets, Dataflows, Pipelines) based on chosen template.

param ctrlDeployPurview bool = true          //Controls the deployment of Azure Purview
param ctrlDeployAI bool = true               //Controls the deployment of Azure ML and Cognitive Services
param ctrlDeployDataShare bool = true        //Controls the deployment of Azure Data Share
param ctrlDeployPrivateDNSZones bool = true  //Controls the creation of private DNS zones for private links

//********************************************************
// Global Parameters
//********************************************************
param utcValue string = utcNow()

@description('Unique Prefix')
param prefix string = 'fasthack'

@description('Unique Suffix')
//param uniqueSuffix string = substring(uniqueString(resourceGroup().id),0,3)
param uniqueSuffix string = substring(toLower(replace(uniqueString(subscription().id, resourceGroup().id, utcValue), '-', '')), 1, 3) 

@description('Resource Location')
param resourceLocation string = resourceGroup().location

@allowed([
  'new'
  'existing'
])
param ctrlNewOrExistingVNet string = 'new'

@allowed([
  'default'
  'vNet'
])
@description('Network Isolation Mode')
param networkIsolationMode string = 'vNet'

@allowed([
  'eventhub'
  'iothub'
])
param ctrlStreamIngestionService string = 'eventhub'


//********************************************************
// Resource Config Parameters
//********************************************************

//vNet Module Parameters
param existingVNetResourceGroupName string = resourceGroup().name

@description('Virtual Network Name')
param vNetName string = '${prefix}-vnet'

@description('Virtual Network IP Address Space')
param vNetIPAddressPrefixes array = [
  '10.17.0.0/16'
]

@description('Virtual Network Default Subnet Name')
param vNetSubnetName string = 'default'

//----------------------------------------------------------------------


//Storage Account Module Parameters - Data Lake Storage Account for Synapse Workspace
@description('Storage Account Type')
param storageAccountType string
var storageAccountName = '${prefix}adls${uniqueSuffix}'

//----------------------------------------------------------------------

//Key Vault Module Parameters
@description('Key Vault Account Name')
param keyVaultName string = '${prefix}-keyvault-${uniqueSuffix}' 

@description('Your Service Principal Object ID')
param spObjectId string //This is your Service Principal Object ID

@description('Your User Object ID')
param userObjectId string //This is your User Object ID

//----------------------------------------------------------------------

//Synapse Module Parameters
var synapseWorkspaceName = '${prefix}-synapse-${uniqueSuffix}'
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

@description('Deploy SQL Pool')
param ctrlDeploySynapseSQLPool bool = false //Controls the creation of Synapse SQL Pool
@description('Deploy Spark Pool')
param ctrlDeploySynapseSparkPool bool = false //Controls the creation of Synapse Spark Pool
@description('Deploy ADX Pool')
param ctrlDeploySynapseADXPool bool = false //Controls the creation of Synapse Spark Pool

//Synapse Workspace SQL Pool Parameters
@description('SQL Pool Name')
param synapseDedicatedSQLPoolName string = 'SQLPool'
@description('SQL Pool SKU')
param synapseSQLPoolSKU string = 'DW100c'
@description('SQL collation')
param collation string

//Synapse Workspace Spark Pool Parameters
@description('Spark Pool Name')
param synapseSparkPoolName string = 'SparkPool'
@description('Spark Node Size')
param synapseSparkPoolNodeSize string = 'Small'
@description('Spark Min Node Count')
param synapseSparkPoolMinNodeCount int = 3
@description('Spark Max Node Count')
param synapseSparkPoolMaxNodeCount int = 3


//Synapse Workspace ADX Pool Parameters
@description('ADX Pool Name')
param synapseADXPoolName string = '${prefix}-adxpool-${uniqueSuffix}'
@description('ADX Database Name')
param synapseADXDatabaseName string = 'ADXDB'
@description('ADX Pool Enable Auto-Scale')
param synapseADXPoolEnableAutoScale bool = false
@description('ADX Pool Minimum Size')
param synapseADXPoolMinSize int = 2
@description('ADX Pool Maximum Size')
param synapseADXPoolMaxSize int = 2

//----------------------------------------------------------------------

//Stream Analytics Job Parameters
@description('Azure Stream Analytics Job Name')
param streamAnalyticsJobName string =  '${prefix}-asa-${uniqueSuffix}'

@description('Azure Stream Analytics Job Sku')
param streamAnalyticsJobSku string = 'Standard'

//----------------------------------------------------------------------

//CosmosDB account parameters
@description('CosmosDB Account Name')
param cosmosDBAccountName string = '${prefix}-cosmos-${uniqueSuffix}'

@description('CosmosDB Database Name')
param cosmosDBDatabaseName string = 'CosmosDB'

//********************************************************
// Variables
//********************************************************

var deploymentScriptUAMIName = toLower('${prefix}-uami')

//********************************************************
// Deploy Core Platform Services 
//********************************************************

//1. Deploy Required VNet
//Deploy the VNet (The VNet Module needs to be expanded and will be expanded when we place Synapse Workspace within a Managed VNet that uses Private Endpoints.)
module m_vnet 'modules/deploy_1_vnet.bicep' = {
  name: 'deploy_vnet'
  params: {
    resourceLocation: resourceLocation
    networkIsolationMode: networkIsolationMode
    ctrlNewOrExistingVNet: ctrlNewOrExistingVNet
    existingVNetResourceGroupName: existingVNetResourceGroupName
    vNetIPAddressPrefixes: vNetIPAddressPrefixes
    vNetSubnetName: vNetSubnetName
    vNetName: vNetName
  }
}

//2. Deploy Required Storage Account(s)
//Deploy Storage Accounts (Create your Storage Account (ADLS Gen2 & HNS Enabled) for your Synapse Workspace)
module m_storage 'modules/deploy_2_storage.bicep' = {
  name: 'deploy_storage'
  params: {
    resourceLocation: resourceLocation
    storageAccountName: storageAccountName
    storageAccountContainer: toLower('${prefix}-synapse')
    storageAccountType: storageAccountType
  }
}

//3. Deploy Required Key Vault
module m_keyvault 'modules/deploy_3_keyvault.bicep' = {
  name: 'deploy_keyvault'
  params: {
    resourceLocation: resourceLocation
    keyVaultName: keyVaultName
    deploymentScriptUAMIName: deploymentScriptUAMIName
    spObjectId: spObjectId
    userObjectId:userObjectId
    storageAccountKey: m_storage.outputs.storageAccountKey
    storageAccountCnx: m_storage.outputs.storageAccountCnx
  }
  dependsOn: [
    m_storage
  ]
}

//4. Deploy Synapse Workspace
module m_synapse 'modules/deploy_4_synapse.bicep' = {
  name: 'deploy_synapse'
  params: {
    resourceLocation: resourceLocation
    synapseWorkspaceName: toLower(synapseWorkspaceName)
    managedResourceGroupName: synapseManagedResourceGroup

    networkIsolationMode: networkIsolationMode

    ctrlDeploySynapseSQLPool: ctrlDeploySynapseSQLPool
    ctrlDeploySynapseSparkPool: ctrlDeploySynapseSparkPool
    ctrlDeploySynapseADXPool: ctrlDeploySynapseADXPool

    defaultDataLakeStorageAccountName: storageAccountName
    defaultDataLakeStorageFileSystemName: toLower('${prefix}-synapse')
    encryption: encryption
    
    //Send in your ipAddress(s) into the synapse module to enable access to your Local IP
    startIpaddress: ipaddress
    endIpAddress: ipaddress

    //Send in your User Object ID
    userObjectId: userObjectId
    uamiPrincipalID: m_keyvault.outputs.deploymentScriptUAMIPrincipalID

    //Send in SQL Pool Parameters
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
    synapseDedicatedSQLPoolName: synapseDedicatedSQLPoolName
    synapseSQLPoolSKU: synapseSQLPoolSKU
    collation: collation

    //Send in Apache Spark Pool Parameters
    synapseSparkPoolName: synapseSparkPoolName
    synapseSparkPoolNodeSize: synapseSparkPoolNodeSize
    sparkPoolMinNodeCount: synapseSparkPoolMinNodeCount
    sparkPoolMaxNodeCount: synapseSparkPoolMaxNodeCount

    //Send in Kusto ADX Pool Parameters
    synapseADXPoolName: synapseADXPoolName
    synapseADXDatabaseName: synapseADXDatabaseName
    synapseADXPoolEnableAutoScale: synapseADXPoolEnableAutoScale
    synapseADXPoolMinSize: synapseADXPoolMinSize
    synapseADXPoolMaxSize: synapseADXPoolMaxSize
  }
  dependsOn: [
    m_storage
  ]
}

//Key Vault Access Policy for Synapse
module m_KeyVaultSynapseAccessPolicy 'modules/deploy_5_keyvaultsynapseaccesspolicy.bicep' = {
  name: 'deploy_KeyVaultSynapseAccessPolicy'
  params: {
    keyVaultName: keyVaultName
    synapseWorkspaceIdentityPrincipalID: m_synapse.outputs.synapsePrincipalId
  }
  dependsOn: [
    m_synapse
  ]
}

//********************************************************
// STREAMING SERVICES DEPLOY
//********************************************************

//Deploy Event Hub
module m_eventhub 'modules/deploy_7_eventhub.bicep' = if(ctrlDeployStreaming == true) {
  name: 'deploy_eventhub'
  params: {
    resourceLocation: resourceLocation
    eventhubname: toLower('${prefix}-eventhub-${uniqueSuffix}')   
  }
}

module m_streaminganalytics 'modules/deploy_8_streaminganalytics.bicep' = if(ctrlDeployStreaming == true) {
  name: 'deploy_streaminganalytics'
  params: {
    resourceLocation: resourceLocation
    ctrlStreamIngestionService: ctrlStreamIngestionService
    streamAnalyticsJobName: streamAnalyticsJobName
    streamAnalyticsJobSku: streamAnalyticsJobSku

  }
}

//********************************************************
// COSMOS DB DEPLOY
//********************************************************

module m_cosmosdb 'modules/deploy_9_cosmosdb.bicep' = if(ctrlDeployOperationalDB) {
  name: 'deploy_cosmosdb'
  params: {
    resourceLocation: resourceLocation
    ctrlDeployCosmosDB: ctrlDeployCosmosDB
    networkIsolationMode: networkIsolationMode
    cosmosDBAccountName: cosmosDBAccountName
    cosmosDBDatabaseName: cosmosDBDatabaseName
    synapseWorkspaceID: m_synapse.outputs.synapseWorkspaceID
  }
  dependsOn:[
    m_synapse
  ]
}

//********************************************************
// RBAC Role Assignments
//********************************************************

module m_RBACRoleAssignment 'modules/deploy_10_RBAC.bicep' = {
  name: 'deploy_RBAC'
  dependsOn:[
    m_synapse
  ]
  params: {
    ctrlDeployStreaming: ctrlDeployStreaming  
    ctrlDeployOperationalDB: ctrlDeployOperationalDB
    ctrlDeployCosmosDB: ctrlDeployCosmosDB
    dataLakeAccountName: storageAccountName
    synapseWorkspaceName: m_synapse.outputs.synapseWorkspaceName
    synapseWorkspaceIdentityPrincipalID: m_synapse.outputs.synapseWorkspaceIdentityPrincipalID
    UAMIPrincipalID: m_keyvault.outputs.deploymentScriptUAMIPrincipalID
   
  }
}
