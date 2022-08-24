/*region Header
      Module Steps 
      1 - 
      2 - 
      3 -
*/

//Declare Parameters--------------------------------------------------------------------------------------------------------------------------

param dataLakeAccountName string
param synapseWorkspaceName string
param synapseWorkspaceIdentityPrincipalID string
param UAMIPrincipalID string

//Reference existing resources for permission assignment scope
resource r_dataLakeStorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: dataLakeAccountName
}

resource r_synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' existing = {
  name: synapseWorkspaceName
}


//https://docs.microsoft.com/en-us/azure/templates/microsoft.synapse/workspaces/integrationruntimes
//1. Create Additional Integration Runtimes
resource azureIR_1 'Microsoft.Synapse/workspaces/integrationRuntimes@2021-06-01' = {
  name: 'AzureIR1'
  parent: r_synapseWorkspace
  properties: {
    type: 'Managed'
    // For remaining properties, see IntegrationRuntime objects
    managedVirtualNetwork: {
      id: 'string'
      referenceName: 'default'
      type: 'ManagedVirtualNetworkReference'
    }

    typeProperties: {
      computeProperties: {
        location: 'East US'
        dataFlowProperties: {
          computeType: 'General'
          coreCount: 8
          timeToLive: 10
          cleanup: false
        }
        copyComputeScaleProperties: {
          dataIntegrationUnit: 256
          timeToLive: 10
        }
        pipelineExternalComputeScaleProperties: {
          timeToLive: 60
        }
      }
    }
  }
}
