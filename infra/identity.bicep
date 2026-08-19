@description('User-assigned managed identity (id-novatrix-web) with Storage Blob Data Contributor on the storage account.')

param location string = resourceGroup().location
param miName string = 'id-novatrix-web'
param storageAccountName string
param tags object = {}

resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: miName
  location: location
  tags: tags
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

var storageBlobDataContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountName, miName, storageBlobDataContributorRoleDefinitionId)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinitionId
    principalId: mi.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('User-assigned managed identity resource ID')
output miId string = mi.id

@description('User-assigned managed identity name')
output miName string = mi.name

@description('User-assigned managed identity principal ID')
output miPrincipalId string = mi.properties.principalId

@description('User-assigned managed identity client ID (AZURE_CLIENT_ID on the VM)')
output miClientId string = mi.properties.clientId