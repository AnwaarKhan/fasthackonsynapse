## <img src ='https://airsblobstorage.blob.core.windows.net/airstream/bicep.png' alt="FTA Analytics-in-a-Box: Bicep Deployment" width="50px" style="float: left; margin-right:10px;"> Pattern 2: Bicep Deployment (Azure Synapse Analytics workspace)

## <img src="/Assets/images/pattern2-architecture.png" alt="FTA Analytics-in-a-Box: Pattern 1 Deployment" style="float: left; margin-right:10px;" />

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
- main.parameters.json</br>
  - required</br>
  Xx$$x0xx (sqlAdministratorLoginPassword) (At least 12 characters (uppercase, lowercase, and numbers)) </br>
  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -> Your Service Principal ID from Azure AD. Make sure your Service Principal has Ownership role on the subscription.
```
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "prefix": {
          "value": "ftatoolkit" // This value must be provided.
        },
        "resourceLocation": {
          "value": "eastus" // This value must be provided.
        },
        "storageAccountType":{
          "value": "Standard_LRS"
        },
        "synapseManagedResourceGroup": {
          "value": "P2-AnalyticsFundamentals-Managed-RG"
        },
        "ipaddress": {
          "value": "xx.xxx.xxx.xx" //This is your local IP address that will allow you to see into your workspace
        },
        "sqlAdministratorLogin": {
          "value" : "sqladminuser"
        },
        "sqlAdministratorLoginPassword": {
          "value": "Xx$$x0xx"
        },
        "synapseDedicatedSQLPoolName":{
          "value": "EnterpriseDW"
        },
        "synapseSQLPoolSKU":{
          "value": "DW100c"
        },
        "collation":{
          "value": "SQL_Latin1_General_CP1_CI_AS"
        },
        "synapseSparkPoolName": {
          "value": "SparkPool"
        },
        "synapseSparkPoolNodeSize":{
          "value": "Small"
        },
        "synapseSparkPoolMinNodeCount":{
          "value": 3
        },
        "synapseSparkPoolMaxNodeCount":{
          "value": 3
        },
        "spObjectId":{
          "value": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" //Service Principal ID or your own User Object ID (Please make sure that this user has high enough Role to deploy the solution)
        }
    }
}
```
### (Option)
#### If you use powershell (or pwsh)
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

$parameterFile = "main.parameters.json"
$rgName    = "P1-AnalyticsFundamentals-RG"
$location = "eastus"
```

2. Go to STEP 2 (Azure CLI or PowerShell)
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
  -Name AnalyticsFundamentals `
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
