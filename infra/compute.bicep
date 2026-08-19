@description('Web VM: public IP + NIC + Ubuntu VM with system- and user-assigned managed identity, cloud-init bootstrap.')

param location string = resourceGroup().location
param vmName string = 'vm-novatrix-web'
param vmSize string = 'Standard_B2ats_v2'
param adminUsername string = 'azureuser'
param adminSshPublicKey string
param subnetId string
@description('Optional user-assigned managed identity id (id-novatrix-web from identity.bicep).')
param userAssignedIdentityId string = ''
@description('Storage account name injected into cloud-init (NOVATRIX_STORAGE_ACCOUNT).')
param storageAccountName string = ''
@description('User-assigned MI client id injected into cloud-init (AZURE_CLIENT_ID).')
param miClientId string = ''
param pipName string = 'pip-novatrix-web'
param nicName string = 'nic-novatrix-web'
param tags object = {}

var cloudInitRaw = loadTextContent('../web/cloud-init.yaml')
var cloudInitTemplated = replace(
  replace(cloudInitRaw, '__NOVATRIX_STORAGE_ACCOUNT__', storageAccountName),
  '__NOVATRIX_MI_CLIENT_ID__',
  miClientId
)
var cloudInit = base64(cloudInitTemplated)

resource pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: pipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  identity: empty(userAssignedIdentityId) ? {
    type: 'SystemAssigned'
  } : {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminSshPublicKey
            }
          ]
        }
      }
      customData: cloudInit
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
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
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

@description('VM resource ID')
output vmId string = vm.id

@description('VM name')
output vmName string = vm.name

@description('VM private IP address')
output privateIPAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress

@description('VM public IP address')
output publicIPAddress string = pip.properties.ipAddress

@description('Public IP resource ID')
output publicIpId string = pip.id

@description('Network interface resource ID')
output nicId string = nic.id