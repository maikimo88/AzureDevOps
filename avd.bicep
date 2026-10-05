targetScope = 'resourceGroup'

param location string = resourceGroup().location
param baseTime string = utcNow('u')

// Unieke nieuwe namen voor lab / productie
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

// 3. Workspace (inclusief directe referentie naar de appGroup)
resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: workspaceName
  location: location
  properties: {
    applicationGroupReferences: [
      appGroup.id
    ]
  }
}

// ==========================================
// 4. SESSION HOST & CONFIGURATIE
// ==========================================

// Netwerkkaart voor de VM (koppelt aan bestaand VNet / Subnet)
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

// De Windows 11 AVD Virtuele Machine
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

// Extensie 1: Entra ID (Azure AD) Join voor de Session Host
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

// Extensie 2: AVD Sessie Host Registratie (Voegt VM toe aan de Host Pool)
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

// ==========================================
// 5. RBAC: IAM RECHTEN VOOR AANMELDEN
// ==========================================

// Definieer de ingebouwde rol "Virtual Machine User Login" (ID: fb879df8-f326-4884-b1cf-06f3adec6be5)
var vmUserLoginRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'fb879df8-f326-4884-b1cf-06f3adec6be5')

// Wijs de rol toe aan mkn@wilroffreitsma.nl op de virtuele machine (of op resourcegroep-niveau)
resource rbMknLogin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vm.id, 'mkn-wilroffreitsma-login')
  scope: vm
  properties: {
    roleDefinitionId: vmUserLoginRoleDefinitionId
    // Let op: Dit is de object ID (GUID) van mkn@wilroffreitsma.nl in Entra ID. 
    // Als de deployment klaagt over een onbekend object, kun je dit later eventueel via een prinicipalId / user object ID koppelen.
    principalId: 'VOER_HIER_DE_OBJECT_ID_VAN_MKN_IN' 
    principalType: 'User'
  }
}
