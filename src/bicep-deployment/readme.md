![Synapse FastHack CI/CD](/Assets/images/synapsecicd.png)

## <img src ='https://airsblobstorage.blob.core.windows.net/airstream/bicep.png' alt="Fast Hack Bicep Deployment" width="50px" style="float: left; margin-right:10px;"> Bicep Deployment (Azure Synapse Analytics workspace)

### Preparation
1. Install az cli  
https://docs.microsoft.com/ja-jp/cli/azure/install-azure-cli
2. bicep install
https://github.com/Azure/bicep/blob/main/docs/installing.md#windows-installer
3. Install Azure Synapse Powershell Module</br>
Install-Module -Name Az.Synapse
4. Bicep install (for Powershell)</br>
[Setup your Bicep development environment](https://github.com/Azure/bicep/blob/main/docs/installing.md#manual-with-powershell)


1. Edit parameter File
- fasthackonsynapse.parameters.json</br>
  - require</br>
  xxx.xxx.xxx.xxx -> Your IP Address.</br>
  xxx(sqlAdministratorLoginPassword)(At least 12 characters (uppercase, lowercase, and numbers)) </br>
  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -> Your ObjectId of Azure AD
```
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "prefix": {
            "value": "fasthack" // This value must be provided.
        },
        "location": {
            "value": "eastus" // This value must be provided.
        },
        "synapseManagedResourceGroup": {
          "value": "A-FastHackOnSynapse-Managed-RG"
        },
        "ipaddress": {
            "value": "xxx.xxx.xxx.xxx"
        },
        "sqlAdministratorLogin": {
          "value" : "sqladminuser"
        },
        "sqlAdministratorLoginPassword": {
          "value": "Pa$$W0rd"
        },
        "storageAccountType":{
          "value": "Standard_LRS"
        },
        "sqlpoolName":{
          "value": "fhsqlpool"
        },
        "bigDataPoolName": {
          "value": "fhsparkpool"
        },
        "nodeSize":{
          "value": "Small"
        },
        "sparkPoolMinNodeCount":{
            "value": 2
        },
        "sparkPoolMaxNodeCount":{
          "value": 2
        },
        "defaultDataLakeStorageFileSystemName":{
          "value": "landingzone"
        },
        "collation":{
          "value": "SQL_Latin1_General_CP1_CI_AS"
        },
        "userObjectId":{
          "value": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        },
         "cmkUri": {
          "value": "" //i.e. https://{keyvaultname}.vault.azure.net/keys/{keyname}
        }
    }
}
```
### (Option)
#### If you use powershell(or pwsh)
1. Install Module Az or Update Module Az  (Az Version >= 5.8.0)
```
 Install-Module Az
```
or
```
Update-Module Az
```
## Usage
### STEP 1
1. Execute PowerShell Prompt
1. Set Parameter(x)

```
Write-Host "hello world"
set-variable -name TenantID "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -option constant
set-variable -name SubscriptionID "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -option constant
set-variable -name BicepFile "main.bicep" -option constant

$parameterFile = "fasthackonsynapse.parameters.json"
$rgName    = "FastHackOnSynapse-RG"
$location = "eastus"
```

2. Go to STEP2 (Azure CLI or PowerShell)
### STEP 2 (PowerShell)
1. Azure Login
```
Connect-AzAccount -Tenant ${TenantID} -Subscription ${SubscriptionID}
```
2. Create Resource Group  
```
New-AzResourceGroup -Name ${rgName} -Location ${location} -Verbose
```
3. Deployment Create  
```
New-AzResourceGroupDeployment `
  -Name devenvironment `
  -ResourceGroupName ${rgName} `
  -TemplateFile ${BicepFile} `
  -TemplateParameterFile ${parameterFile} `
  -Verbose
```

### STEP 2 (Azure CLI)
1. Azure Login
```
az login -t ${TenantID} --verbose
```
2. Set Subscription
```
az account set --subscription ${SubscriptionID} --verbose
```
3. Create Resource Group  
```
az group create --name ${rgName} --location ${location} --verbose
```
4. Deployment Create  
```
az deployment group create --resource-group ${rgName} --template-file ${BicepFile} --parameters ${parameterFile} --verbose
```
