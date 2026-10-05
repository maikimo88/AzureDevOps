targetScope = 'resourceGroup'

param location string = resourceGroup().location
param baseTime string = utcNow('u')

param hostPoolName string = 'avdpool-kraanlab-prod-02'
param workspaceName string = 'vdow-klant-prod-02'
param appGroupName string = 'vdag-klant-prod-desktop-02'
param vmName string = 'biceps-avd-02'

// 1. Host Pool
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: hostPoolName
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

// 2. Application Group
resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
  name: appGroupName
  location: location
  properties: {
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostPool.id
  }
}

// 3. Workspace
resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: workspaceName
  location: location
  properties: {
    applicationGroupReferences: [
      appGroup.id
    ]
  }
}

// 4. Netwerkkaart voor de VM
resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-${vmName}'
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

// 5. De Virtuele Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }
    osProfile: {
      computerName: vmName
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

// 6. Extensie: Entra ID (Azure AD) Join (Met expliciete location om LocationRequired te voorkomen)
resource entraJoin 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vm
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

// 7. Extensie: AVD Sessie Host Registratie (Optioneel / tijdelijk uitgeschakeld voor stabiele deployment)
/*
resource avdJoin 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vm
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
        HostPoolName: hostPool.name
      }
    }
  }
}
*/
