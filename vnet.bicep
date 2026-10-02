targetScope = 'resourceGroup'

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-lab-core-01'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.10.0.0/16']
    }
    subnets: [
      {
        name: 'snet-internal'
        properties: {
          addressPrefix: '10.10.1.0/24'
        }
      }
    ]
  }
}