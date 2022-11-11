targetScope = 'subscription'

@description('Name of the resource group')
param resourceGroupName string = 'rg-bu0001a0008'
//param vNetResourceGroup string = 'rg-enterprise-networking-spokes'

// @description('The regional network spoke VNet Resource ID that the private endpoint will be created in')
// @minLength(79)
// param peSubnetResourceId string

@description('Web App region. This needs to be the same region as the vnet provided in these parameters.')
@allowed([
  'australiaeast'
  'canadacentral'
  'centralus'
  'eastus'
  'eastus2'
  'westus2'
  'francecentral'
  'germanywestcentral'
  'northeurope'
  'southafricanorth'
  'southcentralus'
  'uksouth'
  'westeurope'
  'japaneast'
  'southeastasia'
])
param location string

//var subRgUniqueString = uniqueString('webApp', subscription().subscriptionId, resourceGroupName, location)
//var webAppName = 'asp-${subRgUniqueString}'
//var webAppName = '${uniqueString(deployment().name)}-sites'
var webAppName = 'clive-az-wa-min-001'
var webAppPlanName = 'clive-az-asp-x-001'
//var webAppPlanName = '${uniqueString(deployment().name)}-serverfarms'
var logAnalyticsWorkspaceName = 'la-${webAppName}'
var resourceGroupNamePrivateDNSZone = 'iot-isolated'
var resourceGroupNameVnet = 'rg-network-dev-cac'
//var defaultAcrName = 'acraks${subRgUniqueString}'
//var vNetResourceGroup = split(targetVnetResourceId, '/')[4]
//var vnetName = split(targetVnetResourceId, '/')[8]
//var clusterNodesSubnetName = 'snet-clusternodes'
//var clusterIngressSubnetName = 'snet-clusteringressservices'
//var vnetNodePoolSubnetResourceId = '${targetVnetResourceId}/subnets/${clusterNodesSubnetName}'
// var vnetIngressServicesSubnetResourceId = '${targetVnetResourceId}/subnets/snet-cluster-ingressservices'
//var clusterControlPlaneIdentityName = 'mi-${webAppName}-controlplane'
//var aksIngressDomainName = 'aks-ingress.${domainName}'
//var isUsingAzureRBACasKubernetesRBAC = (subscription().tenantId == k8sControlPlaneAuthorizationTenantId)

resource rg 'Microsoft.Resources/resourceGroups@2019-05-01' existing = {
  name: resourceGroupName
}

resource privateDnsZoneWeb 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: resourceGroup(resourceGroupNamePrivateDNSZone)
  name: 'privatelink.azurewebsites.net'
}

//subscriptions/d6670526-5bdd-40db-9865-f3b1bd3e7d71/resourceGroups/rg-network-dev-cac/providers/Microsoft.Network/virtualNetworks/vnet-dev-clz-cac
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-08-01' existing = {
  scope: resourceGroup(resourceGroupNameVnet)
  name: 'vnet-dev-clz-cac'
}

resource subnetPrivateEndpoints 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' existing = {
  parent: virtualNetwork
  name: 'privateendpoints'
}

resource subnetSites 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' existing = {
  parent: virtualNetwork
  name: 'privateendpoints'
}

//resource clusterLa 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
//  scope: resourceGroup(resourceGroupName)
//  name: logAnalyticsWorkspaceName
//}

module clusterLa '../CARML/Microsoft.OperationalInsights/workspaces/deploy.bicep' = {
  name: logAnalyticsWorkspaceName
  params: {
    name: logAnalyticsWorkspaceName
    location: location
    serviceTier: 'PerGB2018'
    dataRetention: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    gallerySolutions: [
      {
        name: 'KeyVaultAnalytics'
        product: 'OMSGallery'
        publisher: 'Microsoft'
      }
    ]
  }
  scope: resourceGroup(resourceGroupName)
  dependsOn: [
    rg
  ]
}

module serverfarms '../CARML/Microsoft.Web/serverfarms/deploy.bicep' = {
  name: webAppPlanName
  params: {
    name: webAppPlanName
    location: location
    sku: {
      capacity: '1'
      family: 'S'
      name: 'S1'
      size: 'S1'
      tier: 'Standard'
    }
  }
  scope: resourceGroup(resourceGroupName)  
}

module sites '../CARML/Microsoft.Web/sites/deploy.bicep' = {
  name: webAppName
  params: {
    location: location
    kind: 'app'
    name: webAppName
    serverFarmResourceId: serverfarms.outputs.resourceId
    virtualNetworkSubnetId: subnetSites.id
    privateEndpoints:  [
      {
          // name: 'sxx-az-pe' // Optional: Name will be automatically generated if one is not provided here
          subnetResourceId: subnetPrivateEndpoints.id //'/subscriptions/<<subscriptionId>>/resourceGroups/validation-rg/providers/Microsoft.Network/virtualNetworks/sxx-az-vnet-x-001/subnets/sxx-az-subnet-x-001'
          service: 'sites'
          privateDnsZoneResourceIds: [ // Optional: No DNS record will be created if a private DNS zone Resource ID is not specified
              privateDnsZoneWeb
          ]
      }
    ]
  }
  scope: resourceGroup(resourceGroupName)
  dependsOn: [
    rg
    privateDnsZoneWeb
    subnetPrivateEndpoints
    subnetSites
  ]
}



output webAppName string = webAppName
