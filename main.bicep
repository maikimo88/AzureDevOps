targetScope = 'subscription'

// 1. Maak de Resource Group aan op abonnementsniveau
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-lab-devops-01'
  location: 'westeurope'
}

// 2. Implementeer het Virtual Network via een inline module gekoppeld aan de resource group
module vnetModule './vnet.bicep' = {
  name: 'vnetDeployment'
  scope: rg
}

// Hier roepen we de nieuwe AVD module aan
module avdModule './avd.bicep' = {
  name: 'avdDeployment'
  scope: rg
}

// Hier roepen we de nieuwe Storage module aan
module storageModule './storage.bicep' = {
  name: 'storageDeployment'
  scope: rg
}