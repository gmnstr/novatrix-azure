// infra/function.bicep — OPTIONAL v40 compute-compare stub.
// NOT wired into main.bicep and NOT part of the default deploy.
//
// Purpose: show what a Consumption Azure Functions app for the Novatrix
// ticket pipeline would look like (v40: VM vs Container Apps/ACI vs
// Functions). Intentionally minimal: no MySQL, no Application Gateway.
//
// To try it: `bicep build infra/function.bicep` and deploy the resulting ARM
// JSON manually. scripts/deploy.sh does NOT include this file.

param location string = resourceGroup().location
param functionAppName string = 'func-novatrix-tickets'
param storageAccountName string = 'stnovatrixdanlin01'

// Consumption (dynamic) plan — pay per execution, scale to zero.
resource plan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'plan-novatrix-tickets-consumption'
  location: location
  kind: 'functionapp'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true // Linux consumption plan (required for Python runtime)
  }
}

resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: plan.id
    reserved: true
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
      ]
    }
  }
}

output functionAppId string = functionApp.id
output functionAppName string = functionApp.name