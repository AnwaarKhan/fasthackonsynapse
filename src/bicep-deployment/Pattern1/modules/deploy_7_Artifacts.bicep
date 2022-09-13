param deploymentDatetime string
param resourceLocation string
param deploymentScriptUAMIResourceId string
param synapseScriptArguments string

resource runPowerShellInline 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name:'PostDeploymentScript-${deploymentDatetime}'
  location: resourceLocation
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptUAMIResourceId}': {}
    }
  }
  properties: {
    forceUpdateTag: '1'
    azPowerShellVersion: '7.2.4' // or azCliVersion: '2.28.0'
    arguments: synapseScriptArguments
    cleanupPreference: 'OnSuccess'
    scriptContent: loadTextContent('../PowerShellScripts/SynapseDeployArtifacts.ps1')
    retentionInterval: 'P1D'
    supportingScriptUris: []
    timeout: 'PT30M'
  }
}

output result string = runPowerShellInline.properties.outputs.text
