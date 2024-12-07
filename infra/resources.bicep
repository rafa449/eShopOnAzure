@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}


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

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location)

// Monitor application with Azure Monitor
module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: '${abbrs.portalDashboards}${resourceToken}'
    location: location
    tags: tags
  }
}

// Container registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.1' = {
  name: 'registry'
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    acrAdminUserEnabled: true
    tags: tags
    publicNetworkAccess: 'Enabled'
    roleAssignments:[
      {
        principalId: basketApiIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
      {
        principalId: catalogApiIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
      {
        principalId: mobileBffShoppingIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
      {
        principalId: orderProcessorIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
      {
        principalId: orderingApiIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
      {
        principalId: paymentProcessorIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
      {
        principalId: webAppIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
      {
        principalId: webhookClientIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
      {
        principalId: webhooksApiIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
      {
        principalId: eshopApphostIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
    ]
  }
}

// Container apps environment
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.4.5' = {
  name: 'container-apps-environment'
  params: {
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    zoneRedundant: false
  }
}

module basketApiIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'basketApiidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}basketApi-${resourceToken}'
    location: location
  }
}

module basketApiFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'basketApi-fetch-image'
  params: {
    exists: basketApiExists
    name: 'basket-api'
  }
}

var basketApiAppSettingsArray = filter(array(basketApiDefinition.settings), i => i.name != '')
var basketApiSecrets = map(filter(basketApiAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var basketApiEnv = map(filter(basketApiAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module basketApi 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'basketApi'
  params: {
    name: 'basket-api'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  union([
      ],
      map(basketApiSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
    }
    containers: [
      {
        image: basketApiFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: basketApiIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        basketApiEnv,
        map(basketApiSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [basketApiIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: basketApiIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'basket-api' })
  }
}

module catalogApiIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'catalogApiidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}catalogApi-${resourceToken}'
    location: location
  }
}

module catalogApiFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'catalogApi-fetch-image'
  params: {
    exists: catalogApiExists
    name: 'catalog-api'
  }
}

var catalogApiAppSettingsArray = filter(array(catalogApiDefinition.settings), i => i.name != '')
var catalogApiSecrets = map(filter(catalogApiAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var catalogApiEnv = map(filter(catalogApiAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module catalogApi 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'catalogApi'
  params: {
    name: 'catalog-api'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  union([
      ],
      map(catalogApiSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
    }
    containers: [
      {
        image: catalogApiFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: catalogApiIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        catalogApiEnv,
        map(catalogApiSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [catalogApiIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: catalogApiIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'catalog-api' })
  }
}

module mobileBffShoppingIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'mobileBffShoppingidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}mobileBffShopping-${resourceToken}'
    location: location
  }
}

module mobileBffShoppingFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'mobileBffShopping-fetch-image'
  params: {
    exists: mobileBffShoppingExists
    name: 'mobile-bff-shopping'
  }
}

var mobileBffShoppingAppSettingsArray = filter(array(mobileBffShoppingDefinition.settings), i => i.name != '')
var mobileBffShoppingSecrets = map(filter(mobileBffShoppingAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var mobileBffShoppingEnv = map(filter(mobileBffShoppingAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module mobileBffShopping 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'mobileBffShopping'
  params: {
    name: 'mobile-bff-shopping'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  union([
      ],
      map(mobileBffShoppingSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
    }
    containers: [
      {
        image: mobileBffShoppingFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: mobileBffShoppingIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        mobileBffShoppingEnv,
        map(mobileBffShoppingSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [mobileBffShoppingIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: mobileBffShoppingIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'mobile-bff-shopping' })
  }
}

module orderProcessorIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'orderProcessoridentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}orderProcessor-${resourceToken}'
    location: location
  }
}

module orderProcessorFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'orderProcessor-fetch-image'
  params: {
    exists: orderProcessorExists
    name: 'order-processor'
  }
}

var orderProcessorAppSettingsArray = filter(array(orderProcessorDefinition.settings), i => i.name != '')
var orderProcessorSecrets = map(filter(orderProcessorAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var orderProcessorEnv = map(filter(orderProcessorAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module orderProcessor 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'orderProcessor'
  params: {
    name: 'order-processor'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  union([
      ],
      map(orderProcessorSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
    }
    containers: [
      {
        image: orderProcessorFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: orderProcessorIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        orderProcessorEnv,
        map(orderProcessorSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [orderProcessorIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: orderProcessorIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'order-processor' })
  }
}

module orderingApiIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'orderingApiidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}orderingApi-${resourceToken}'
    location: location
  }
}

module orderingApiFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'orderingApi-fetch-image'
  params: {
    exists: orderingApiExists
    name: 'ordering-api'
  }
}

var orderingApiAppSettingsArray = filter(array(orderingApiDefinition.settings), i => i.name != '')
var orderingApiSecrets = map(filter(orderingApiAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var orderingApiEnv = map(filter(orderingApiAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module orderingApi 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'orderingApi'
  params: {
    name: 'ordering-api'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  union([
      ],
      map(orderingApiSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
    }
    containers: [
      {
        image: orderingApiFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: orderingApiIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        orderingApiEnv,
        map(orderingApiSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [orderingApiIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: orderingApiIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'ordering-api' })
  }
}

module paymentProcessorIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'paymentProcessoridentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}paymentProcessor-${resourceToken}'
    location: location
  }
}

module paymentProcessorFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'paymentProcessor-fetch-image'
  params: {
    exists: paymentProcessorExists
    name: 'payment-processor'
  }
}

var paymentProcessorAppSettingsArray = filter(array(paymentProcessorDefinition.settings), i => i.name != '')
var paymentProcessorSecrets = map(filter(paymentProcessorAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var paymentProcessorEnv = map(filter(paymentProcessorAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module paymentProcessor 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'paymentProcessor'
  params: {
    name: 'payment-processor'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  union([
      ],
      map(paymentProcessorSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
    }
    containers: [
      {
        image: paymentProcessorFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: paymentProcessorIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        paymentProcessorEnv,
        map(paymentProcessorSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [paymentProcessorIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: paymentProcessorIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'payment-processor' })
  }
}

module webAppIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'webAppidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}webApp-${resourceToken}'
    location: location
  }
}

module webAppFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'webApp-fetch-image'
  params: {
    exists: webAppExists
    name: 'web-app'
  }
}

var webAppAppSettingsArray = filter(array(webAppDefinition.settings), i => i.name != '')
var webAppSecrets = map(filter(webAppAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var webAppEnv = map(filter(webAppAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module webApp 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'webApp'
  params: {
    name: 'web-app'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  union([
      ],
      map(webAppSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
    }
    containers: [
      {
        image: webAppFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: webAppIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        webAppEnv,
        map(webAppSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [webAppIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: webAppIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'web-app' })
  }
}

module webhookClientIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'webhookClientidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}webhookClient-${resourceToken}'
    location: location
  }
}

module webhookClientFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'webhookClient-fetch-image'
  params: {
    exists: webhookClientExists
    name: 'webhook-client'
  }
}

var webhookClientAppSettingsArray = filter(array(webhookClientDefinition.settings), i => i.name != '')
var webhookClientSecrets = map(filter(webhookClientAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var webhookClientEnv = map(filter(webhookClientAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module webhookClient 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'webhookClient'
  params: {
    name: 'webhook-client'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  union([
      ],
      map(webhookClientSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
    }
    containers: [
      {
        image: webhookClientFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: webhookClientIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        webhookClientEnv,
        map(webhookClientSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [webhookClientIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: webhookClientIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'webhook-client' })
  }
}

module webhooksApiIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'webhooksApiidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}webhooksApi-${resourceToken}'
    location: location
  }
}

module webhooksApiFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'webhooksApi-fetch-image'
  params: {
    exists: webhooksApiExists
    name: 'webhooks-api'
  }
}

var webhooksApiAppSettingsArray = filter(array(webhooksApiDefinition.settings), i => i.name != '')
var webhooksApiSecrets = map(filter(webhooksApiAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var webhooksApiEnv = map(filter(webhooksApiAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module webhooksApi 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'webhooksApi'
  params: {
    name: 'webhooks-api'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  union([
      ],
      map(webhooksApiSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
    }
    containers: [
      {
        image: webhooksApiFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: webhooksApiIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        webhooksApiEnv,
        map(webhooksApiSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [webhooksApiIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: webhooksApiIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'webhooks-api' })
  }
}

module eshopApphostIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'eshopApphostidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}eshopApphost-${resourceToken}'
    location: location
  }
}

module eshopApphostFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'eshopApphost-fetch-image'
  params: {
    exists: eshopApphostExists
    name: 'eshop-apphost'
  }
}

var eshopApphostAppSettingsArray = filter(array(eshopApphostDefinition.settings), i => i.name != '')
var eshopApphostSecrets = map(filter(eshopApphostAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var eshopApphostEnv = map(filter(eshopApphostAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module eshopApphost 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'eshopApphost'
  params: {
    name: 'eshop-apphost'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  union([
      ],
      map(eshopApphostSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
    }
    containers: [
      {
        image: eshopApphostFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: eshopApphostIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        eshopApphostEnv,
        map(eshopApphostSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [eshopApphostIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: eshopApphostIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'eshop-apphost' })
  }
}
// Create a keyvault to store secrets
module keyVault 'br/public:avm/res/key-vault/vault:0.6.1' = {
  name: 'keyvault'
  params: {
    name: '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    enableRbacAuthorization: false
    accessPolicies: [
      {
        objectId: principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: basketApiIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: catalogApiIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: mobileBffShoppingIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: orderProcessorIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: orderingApiIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: paymentProcessorIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: webAppIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: webhookClientIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: webhooksApiIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: eshopApphostIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
    ]
    secrets: [
    ]
  }
}
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.uri
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_RESOURCE_BASKET_API_ID string = basketApi.outputs.resourceId
output AZURE_RESOURCE_CATALOG_API_ID string = catalogApi.outputs.resourceId
output AZURE_RESOURCE_MOBILE_BFF_SHOPPING_ID string = mobileBffShopping.outputs.resourceId
output AZURE_RESOURCE_ORDER_PROCESSOR_ID string = orderProcessor.outputs.resourceId
output AZURE_RESOURCE_ORDERING_API_ID string = orderingApi.outputs.resourceId
output AZURE_RESOURCE_PAYMENT_PROCESSOR_ID string = paymentProcessor.outputs.resourceId
output AZURE_RESOURCE_WEB_APP_ID string = webApp.outputs.resourceId
output AZURE_RESOURCE_WEBHOOK_CLIENT_ID string = webhookClient.outputs.resourceId
output AZURE_RESOURCE_WEBHOOKS_API_ID string = webhooksApi.outputs.resourceId
output AZURE_RESOURCE_ESHOP_APPHOST_ID string = eshopApphost.outputs.resourceId
