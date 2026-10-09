targetScope = 'subscription'

param location string = 'westeurope'

@description('Local administrator password for the AVD VMs; supply from a secret pipeline variable.')
@secure()
param vmAdminPassword string

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-lab-devops-01'
  location: location
}

module vnetModule './vnet.bicep' = {
  name: 'vnetDeployment'
  scope: rg
}

module storageModule './storage.bicep' = {
  name: 'storageDeployment'
  scope: rg
}

module avdDeployment './avd.bicep' = {
  name: 'avdDeployment-02'
  scope: rg
  params: {
    location: location
    vmAdminPassword: vmAdminPassword
  }
  dependsOn: [
    vnetModule
  ]
}
