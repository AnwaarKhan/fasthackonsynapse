param prefix string = 'fasthack'
param location string = resourceGroup().location

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: '${prefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.17.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'Default'
        properties: {
          addressPrefix: '10.17.0.0/24'
        }
      }
      {
        name: 'FESubnet'
        properties: {
          addressPrefix: '10.17.1.0/24'
        }
      }
      {
        name: 'BESubnet'
        properties: {
          addressPrefix: '10.17.2.0/24'
        }
      }
    ]
  }
}
