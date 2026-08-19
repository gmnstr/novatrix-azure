@description('Core network for Novatrix: vnet, web (public) + data (private) subnets, NSGs, optional Bastion.')

param location string = resourceGroup().location
param vnetName string = 'vnet-novatrix-core'
param addressSpace string = '10.0.0.0/16'
param webSubnetName string = 'snet-novatrix-web'
param webSubnetCidr string = '10.0.1.0/24'
param dataSubnetName string = 'snet-novatrix-data'
param dataSubnetCidr string = '10.0.2.0/24'
param nsgWebName string = 'nsg-novatrix-web'
param nsgDataName string = 'nsg-novatrix-data'
@description('CIDR allowed to reach SSH (port 22) on the web subnet when Bastion is off. Default is TEST-NET-3 (not world-open).')
param allowedSshCidr string = '203.0.113.0/32'
@description('Deploy Azure Bastion Developer (free, Sweden Central). Credit-safe default: false.')
param deployBastion bool = false
param bastionName string = 'bas-novatrix'
param tags object = {}

var httpHttpsRules = [
  {
    name: 'AllowHTTPInbound'
    properties: {
      description: 'Allow HTTP inbound to web subnet'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '80'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 100
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowHTTPSInbound'
    properties: {
      description: 'Allow HTTPS inbound to web subnet'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 110
      direction: 'Inbound'
    }
  }
]

var sshFromHomeRule = [
  {
    name: 'AllowSSHFromHome'
    properties: {
      description: 'Allow SSH only from the configured CIDR'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '22'
      sourceAddressPrefix: allowedSshCidr
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 120
      direction: 'Inbound'
    }
  }
]

var sshFromBastionRule = [
  {
    name: 'AllowBastionSSH'
    properties: {
      description: 'Allow SSH from the VNet (Bastion Developer hop). Home SSH is off when Bastion is on.'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '22'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 120
      direction: 'Inbound'
    }
  }
]

var denyAllInboundRule = [
  {
    name: 'DenyAllInbound'
    properties: {
      description: 'Explicit deny-all rule for inbound traffic'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Deny'
      priority: 4096
      direction: 'Inbound'
    }
  }
]

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
  }
}

// Web (public) NSG: HTTP/HTTPS from Internet, SSH only from allowedSshCidr, deny-all tail
resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgWebName
  location: location
  tags: tags
  properties: {
    securityRules: concat(httpHttpsRules, deployBastion ? sshFromBastionRule : sshFromHomeRule, denyAllInboundRule)
  }
}

// Data (private) NSG: deny inbound from Internet
resource nsgData 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgDataName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'DenyInternetInbound'
        properties: {
          description: 'Deny inbound from Internet to data subnet'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource webSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: vnet
  name: webSubnetName
  properties: {
    addressPrefix: webSubnetCidr
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
    ]
    networkSecurityGroup: {
      id: nsgWeb.id
    }
  }
}

resource dataSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: vnet
  name: dataSubnetName
  properties: {
    addressPrefix: dataSubnetCidr
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
    ]
    networkSecurityGroup: {
      id: nsgData.id
    }
  }
}

// Optional Bastion Developer (free in Sweden Central; no subnet / public IP).
resource bastion 'Microsoft.Network/bastionHosts@2024-07-01' = if (deployBastion) {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: 'Developer'
  }
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
  }
}

@description('Virtual network resource ID')
output vnetId string = vnet.id

@description('Web (public) subnet resource ID')
output webSubnetId string = webSubnet.id

@description('Data (private) subnet resource ID')
output dataSubnetId string = dataSubnet.id

@description('Web NSG resource ID')
output nsgWebId string = nsgWeb.id

@description('Data NSG resource ID')
output nsgDataId string = nsgData.id

@description('Bastion name (empty when not deployed)')
output bastionName string = deployBastion ? bastion.name : ''