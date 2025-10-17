// Main deployment file
targetScope = 'resourceGroup'

@description('The name of the application')
param appName string

@description('The Azure region for resources')
param location string = resourceGroup().location

@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string = 'dev'

@description('SQL Administrator username')
param sqlAdminUsername string

@description('SQL Administrator password')
@secure()
param sqlAdminPassword string

@description('SKU for the App Service Plan')
@allowed([
  'F1'
  'B1'
  'B2'
  'S1'
  'S2'
  'P1v2'
  'P2v2'
])
param appServicePlanSku string = 'B1'

// Variables
    var resourcePrefix = '${appName}-${environment}'
var appServicePlanName = '${resourcePrefix}-plan'
        var webAppName = '${resourcePrefix}-web'
     var sqlServerName = '${resourcePrefix}-sql'
   var sqlDatabaseName = '${appName}db'

// Deploy App Service Plan
module appServicePlan 'modules/app-service-plan.bicep' = {
  name: 'appServicePlanDeployment'
  params: {
    name: appServicePlanName
    location: location
    sku: appServicePlanSku
  }
}

// Deploy Web App
module webApp 'modules/web-app.bicep' = {
  name: 'webAppDeployment'
  params: {
    name: webAppName
    location: location
    appServicePlanId: appServicePlan.outputs.id
    sqlConnectionString: sqlServer.outputs.connectionString
  }
}

// Deploy SQL Server and Database
module sqlServer 'modules/sql-server.bicep' = {
  name: 'sqlServerDeployment'
  params: {
    serverName: sqlServerName
    databaseName: sqlDatabaseName
    location: location
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
  }
}

// Outputs
output webAppUrl string = webApp.outputs.defaultHostName
output sqlServerFqdn string = sqlServer.outputs.serverFqdn
