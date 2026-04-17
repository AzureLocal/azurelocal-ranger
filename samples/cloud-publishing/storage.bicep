// Minimal Bicep — provision a storage account + container for Ranger cloud publishing.
// Deploy: az deployment group create -g rg-ranger -f storage.bicep

@description('Storage account name (globally unique, 3-24 lowercase alphanum)')
param storageAccountName string = 'stircompliance'

@description('Container name for Ranger run packages')
param containerName string = 'ranger-runs'

@description('Location — defaults to resource group location')
param location string = resourceGroup().location

@description('Object ID of the runner identity (MI, SP, or user) to grant Storage Blob Data Contributor')
param runnerObjectId string

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: sa
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: containerName
  properties: { publicAccess: 'None' }
}

// Storage Blob Data Contributor
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(container.id, runnerObjectId, storageBlobDataContributorRoleId)
  scope: container
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: runnerObjectId
    principalType: 'ServicePrincipal'
  }
}

output storageAccountName string = sa.name
output containerName string = container.name
output storageAccountId string = sa.id
