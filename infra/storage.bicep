@description('StorageV2 with private containers (tickets, files), no public blob access, HTTPS only, TLS 1.2.')

param location string = resourceGroup().location
param storageAccountName string
param containerNames array = ['tickets', 'files']
@description('Web subnet (VM) allowed via Microsoft.Storage service endpoint.')
param webSubnetId string
@description('Data subnet allowed via Microsoft.Storage service endpoint.')
param dataSubnetId string
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: [
        {
          id: webSubnetId
          action: 'Allow'
        }
        {
          id: dataSubnetId
          action: 'Allow'
        }
      ]
    }
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  name: 'default'
  parent: storageAccount
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [
  for name in containerNames: {
    name: name
    parent: blobServices
    properties: {
      publicAccess: 'None'
    }
  }
]

@description('Storage account resource ID')
output storageAccountId string = storageAccount.id

@description('Storage account name')
output storageAccountName string = storageAccount.name

@description('Blob service primary endpoint')
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob