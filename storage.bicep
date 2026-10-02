targetScope = 'resourceGroup'

// 1. Het Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'bicepfslogixprofiles'
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS' // Lokaal redundant, prima voor een lab
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    largeFileSharesState: 'Enabled' // Handig voor profielschijven
  }
}

// 2. De File Service binnen het Storage Account
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

// 3. De daadwerkelijke File Share voor de profielen
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileService
  name: 'fslogix-profiles'
  properties: {
    shareQuota: 100 // Limiet van 100 GB voor deze test
  }
}