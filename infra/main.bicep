targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param basketApiExists bool
@secure()
param basketApiDefinition object
param catalogApiExists bool
@secure()
param catalogApiDefinition object
param mobileBffShoppingExists bool
@secure()
param mobileBffShoppingDefinition object
param orderProcessorExists bool
@secure()
param orderProcessorDefinition object
param orderingApiExists bool
@secure()
param orderingApiDefinition object
param paymentProcessorExists bool
@secure()
param paymentProcessorDefinition object
param webAppExists bool
@secure()
param webAppDefinition object
param webhookClientExists bool
@secure()
param webhookClientDefinition object
param webhooksApiExists bool
@secure()
param webhooksApiDefinition object
param eshopApphostExists bool
@secure()
param eshopApphostDefinition object

@description('Id of the user or app to assign application roles')
param principalId string

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  scope: rg
  name: 'resources'
  params: {
    location: location
    tags: tags
    principalId: principalId
    basketApiExists: basketApiExists
    basketApiDefinition: basketApiDefinition
    catalogApiExists: catalogApiExists
    catalogApiDefinition: catalogApiDefinition
    mobileBffShoppingExists: mobileBffShoppingExists
    mobileBffShoppingDefinition: mobileBffShoppingDefinition
    orderProcessorExists: orderProcessorExists
    orderProcessorDefinition: orderProcessorDefinition
    orderingApiExists: orderingApiExists
    orderingApiDefinition: orderingApiDefinition
    paymentProcessorExists: paymentProcessorExists
    paymentProcessorDefinition: paymentProcessorDefinition
    webAppExists: webAppExists
    webAppDefinition: webAppDefinition
    webhookClientExists: webhookClientExists
    webhookClientDefinition: webhookClientDefinition
    webhooksApiExists: webhooksApiExists
    webhooksApiDefinition: webhooksApiDefinition
    eshopApphostExists: eshopApphostExists
    eshopApphostDefinition: eshopApphostDefinition
  }
}
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output AZURE_KEY_VAULT_ENDPOINT string = resources.outputs.AZURE_KEY_VAULT_ENDPOINT
output AZURE_KEY_VAULT_NAME string = resources.outputs.AZURE_KEY_VAULT_NAME
output AZURE_RESOURCE_BASKET_API_ID string = resources.outputs.AZURE_RESOURCE_BASKET_API_ID
output AZURE_RESOURCE_CATALOG_API_ID string = resources.outputs.AZURE_RESOURCE_CATALOG_API_ID
output AZURE_RESOURCE_MOBILE_BFF_SHOPPING_ID string = resources.outputs.AZURE_RESOURCE_MOBILE_BFF_SHOPPING_ID
output AZURE_RESOURCE_ORDER_PROCESSOR_ID string = resources.outputs.AZURE_RESOURCE_ORDER_PROCESSOR_ID
output AZURE_RESOURCE_ORDERING_API_ID string = resources.outputs.AZURE_RESOURCE_ORDERING_API_ID
output AZURE_RESOURCE_PAYMENT_PROCESSOR_ID string = resources.outputs.AZURE_RESOURCE_PAYMENT_PROCESSOR_ID
output AZURE_RESOURCE_WEB_APP_ID string = resources.outputs.AZURE_RESOURCE_WEB_APP_ID
output AZURE_RESOURCE_WEBHOOK_CLIENT_ID string = resources.outputs.AZURE_RESOURCE_WEBHOOK_CLIENT_ID
output AZURE_RESOURCE_WEBHOOKS_API_ID string = resources.outputs.AZURE_RESOURCE_WEBHOOKS_API_ID
output AZURE_RESOURCE_ESHOP_APPHOST_ID string = resources.outputs.AZURE_RESOURCE_ESHOP_APPHOST_ID
