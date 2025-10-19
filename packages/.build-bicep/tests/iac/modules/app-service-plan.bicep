// App Service Plan module
@description('Name of the App Service Plan')
param name string

@description('Location for the App Service Plan')
param location string

@description('App Service Plan SKU')
param sku string

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: name
  location: location
  sku: {
    name: sku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

output id string = appServicePlan.id
output name string = appServicePlan.name
