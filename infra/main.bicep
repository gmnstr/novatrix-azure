targetScope = 'resourceGroup'

@description('Main template composing the Novatrix course environment (weeks 34-38). Azure region for all resources. Course default: swedencentral.')
param location string = 'swedencentral'

@description('Student prefix used in the storage account name (stnovatrix<prefix>01).')
param studentPrefix string = 'danlin'

@description('Local admin username for the web VM.')
param adminUsername string = 'azureuser'

@description('SSH public key for the local admin user (password auth disabled).')
param adminSshPublicKey string

@description('Deploy Azure Bastion. Credit-safe default: false.')
param deployBastion bool = false

@description('CIDR allowed to reach SSH (port 22) when Bastion is off. Default is TEST-NET-3 (not world-open). Set to your public IP /32 before deploy.')
param allowedSshCidr string = '203.0.113.0/32'

var tags = {
  Application: 'Novatrix'
  Environment: 'Course'
  ManagedBy: 'Bicep'
}

var storageAccountName = 'stnovatrix${studentPrefix}01'

// 1. Identity — MI + storage RA. dependsOn storage so the RA scope exists (first-deploy race).
module identity 'identity.bicep' = {
  name: 'identity-novatrix'
  params: {
    location: location
    miName: 'id-novatrix-web'
    storageAccountName: storageAccountName
    tags: tags
  }
  dependsOn: [
    storage
  ]
}

// 2. Network - vnet, web/data subnets, NSGs, optional Bastion
module network 'network.bicep' = {
  name: 'network-novatrix'
  params: {
    location: location
    vnetName: 'vnet-novatrix-core'
    addressSpace: '10.0.0.0/16'
    webSubnetName: 'snet-novatrix-web'
    webSubnetCidr: '10.0.1.0/24'
    dataSubnetName: 'snet-novatrix-data'
    dataSubnetCidr: '10.0.2.0/24'
    nsgWebName: 'nsg-novatrix-web'
    nsgDataName: 'nsg-novatrix-data'
    allowedSshCidr: allowedSshCidr
    deployBastion: deployBastion
    bastionName: 'bas-novatrix'
    tags: tags
  }
}

// 3. Storage - StorageV2 with private containers (tickets, files)
module storage 'storage.bicep' = {
  name: 'storage-novatrix'
  params: {
    location: location
    storageAccountName: storageAccountName
    containerNames: ['tickets', 'files']
    webSubnetId: network.outputs.webSubnetId
    dataSubnetId: network.outputs.dataSubnetId
    tags: tags
  }
}

// 4. Compute - web VM with public IP, system + user-assigned managed identity
module compute 'compute.bicep' = {
  name: 'compute-novatrix'
  params: {
    location: location
    vmName: 'vm-novatrix-web'
    vmSize: 'Standard_B2ats_v2'
    adminUsername: adminUsername
    adminSshPublicKey: adminSshPublicKey
    subnetId: network.outputs.webSubnetId
    userAssignedIdentityId: identity.outputs.miId
    storageAccountName: storageAccountName
    miClientId: identity.outputs.miClientId
    tags: tags
  }
}

@description('Web VM connection details')
output vm object = {
  id: compute.outputs.vmId
  name: compute.outputs.vmName
  privateIp: compute.outputs.privateIPAddress
  publicIp: compute.outputs.publicIPAddress
}

@description('Storage account details')
output storage object = {
  accountId: storage.outputs.storageAccountId
  accountName: storage.outputs.storageAccountName
  blobEndpoint: storage.outputs.blobEndpoint
}

@description('Managed identity details')
output identity object = {
  miId: identity.outputs.miId
  miName: identity.outputs.miName
}
