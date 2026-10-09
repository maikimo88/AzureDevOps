targetScope = 'resourceGroup'

param location string = resourceGroup().location
param baseTime string = utcNow('u')

@description('Local administrator password for the AVD VMs; do not commit a literal password.')
@secure()
param vmAdminPassword string

param hostPoolName string = 'avdpool-kraanlab-prod-02'
param workspaceName string = 'vdow-klant-prod-02'
param appGroupName string = 'vdag-klant-prod-desktop-02'

// Keep the existing VM and add a second host to the same pooled host pool.
var vmNames = [
  'biceps-avd-02'
  'biceps-avd-03'
]

var resourceTags = {
  environment: 'lab'
  workload: 'avd'
  managedBy: 'bicep'
}

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: hostPoolName
  location: location
  tags: resourceTags
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

resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
  name: appGroupName
  location: location
  tags: resourceTags
  properties: {
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostPool.id
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: workspaceName
  location: location
  tags: resourceTags
  properties: {
    applicationGroupReferences: [
      appGroup.id
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = [for name in vmNames: {
  name: 'nic-${name}'
  location: location
  tags: resourceTags
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
}]

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = [for (name, index) in vmNames: {
  name: name
  location: location
  tags: resourceTags
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }
    osProfile: {
      computerName: name
      adminUsername: 'azureadmin'
      adminPassword: vmAdminPassword
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
          id: nic[index].id
        }
      ]
    }
  }
}]

resource entraJoin 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for (name, index) in vmNames: {
  parent: vm[index]
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}]

// Entra join alone does not register a VM with AVD. Register the new VM
// through the host pool registration token in encrypted extension settings.
// The existing VM is intentionally not modified with a new DSC extension.
resource newHostRegistration 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vm[1]
  name: 'AVDSessionHostRegistration'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02714.342.zip'
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPool.name
        aadJoin: true
      }
    }
    protectedSettings: {
      properties: {
        registrationInfoToken: reference(hostPool.id).registrationInfo.token
      }
    }
  }
  dependsOn: [
    entraJoin[1]
  ]
}
