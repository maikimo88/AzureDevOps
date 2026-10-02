targetScope = 'resourceGroup'

param location string = resourceGroup().location
param baseTime string = utcNow('u')

// 1. Host Pool
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: 'avdpool-kraanlab-prod-01'
  location: location
  properties: {
    hostPoolType: 'Pooled'
    loadBalancerType: 'BreadthFirst'
    preferredAppGroupType: 'Desktop'
    registrationInfo: {
      expirationTime: dateTimeAdd(baseTime, 'PT2H')
      registrationTokenOperation: 'Update'
    }
  }
}

// 3. Application Group (zetten we even voor de workspace zodat we de ID kunnen gebruiken)
resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
  name: 'vdag-klant-prod-desktop'
  location: location
  properties: {
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostPool.id
  }
}

// 2. Workspace (inclusief directe referentie naar de appGroup om fouten tevoorkomen)
resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: 'vdow-klant-prod-01'
  location: location
  properties: {
    applicationGroupReferences: [
      appGroup.id
    ]
  }
}

// ==========================================
// 4. SESSION HOST: biceps-avd-01
// ==========================================

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-biceps-avd-01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', 'vnet-lab-core-01', 'snet-internal')
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'biceps-avd-01'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }
    osProfile: {
      computerName: 'biceps-avd-01'
      adminUsername: 'azureadmin'
      adminPassword: 'P@ssw0rd12345!Secure'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-23h2-avd'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource entraJoin 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vm
  name: 'AADLoginForWindows'
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

resource avdJoin 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vm
  name: 'AVDSessionHostRegistration'
  dependsOn: [
    entraJoin
  ]
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02714.342.zip'
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        HostPoolName: hostPool.name
      }
    }
    protectedSettings: {
      properties: {
        registrationInfoToken: hostPool.properties.registrationInfo.token
      }
    }
  }
}
