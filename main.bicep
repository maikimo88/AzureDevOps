targetScope = 'subscription'

param location string = 'westeurope'

// 1. Maak de Resource Group aan op abonnementsniveau
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-lab-devops-01'
  location: location
}

// 2. Implementeer het Virtual Network via een inline module gekoppeld aan de resource group
module vnetModule './vnet.bicep' = {
  name: 'vnetDeployment'
  scope: rg
}

// Hier roepen we de nieuwe Storage module aan
module storageModule './storage.bicep' = {
  name: 'storageDeployment'
  scope: rg
}

// Aanroep van de nieuwe AVD module
module avdDeployment 'avd.bicep' = {
  name: 'avdDeployment-02'
  scope: rg
  params: {
    location: location
  }
}
