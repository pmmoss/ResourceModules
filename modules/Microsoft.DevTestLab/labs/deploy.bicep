@description('Required. The name of the lab.')
param name string

@description('Optional. Location for all Resources.')
param location string = resourceGroup().location

@allowed([
  ''
  'CanNotDelete'
  'ReadOnly'
])
@description('Optional. Specify the type of lock.')
param lock string = ''

@description('Optional. Array of role assignment objects that contain the \'roleDefinitionIdOrName\' and \'principalIds\' to define RBAC role assignments on this resource. In the roleDefinitionIdOrName attribute, you can provide either the display name of the role definition, or its fully qualified ID in the following format: \'/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11\'.')
param roleAssignments array = []

@description('Optional. Tags of the resource.')
param tags object = {}

@description('Optional. The properties of any lab announcement associated with this lab.')
param announcement object = {}

@allowed([
  'Contributor'
  'Reader'
])
@description('Optional. The access rights to be granted to the user when provisioning an environment. Default is "Reader".')
param environmentPermission string = 'Reader'

@description('Optional. Extended properties of the lab used for experimental features.')
param extendedProperties object = {}

@allowed([
  'Standard'
  'StandardSSD'
  'Premium'
])
@description('Optional. Type of storage used by the lab. It can be either Premium or Standard. Default is Premium.')
param labStorageType string = 'Premium'

@description('Optional. The ordered list of artifact resource IDs that should be applied on all Linux VM creations by default, prior to the artifacts specified by the user.')
param mandatoryArtifactsResourceIdsLinux array = []

@description('Optional. The ordered list of artifact resource IDs that should be applied on all Windows VM creations by default, prior to the artifacts specified by the user.')
param mandatoryArtifactsResourceIdsWindows array = []

@allowed([
  'Enabled'
  'Disabled'
])
@description('Optional. The setting to enable usage of premium data disks. When its value is "Enabled", creation of standard or premium data disks is allowed. When its value is "Disabled", only creation of standard data disks is allowed. Default is "Disabled".')
param premiumDataDisks string = 'Disabled'

@description('Optional. The properties of any lab support message associated with this lab.')
param support object = {}

@description('Optional. The ID(s) to assign to the resource.')
param userAssignedIdentities object = {}

@description('Optional. The ID(s) to assign to the virtual machines associated with this lab.')
param managementIdentities object = {}

@description('Optional. Virtual networks to create for the lab.')
param virtualNetworks array = []

@description('Optional. Policies to create for the lab.')
param policies array = []

@description('Optional. Schedules to create for the lab.')
param schedules array = []

@description('Conditional. Notification Channels to create for the lab. Required if the schedules property "notificationSettingsStatus" is set to "Enabled.')
param notificationChannels array = []

@description('Optional. Artifact sources to create for the lab.')
param artifactSources array = []

@description('Optional. Enable telemetry via a Globally Unique Identifier (GUID).')
param enableDefaultTelemetry bool = true

var enableReferencedModulesTelemetry = false

resource defaultTelemetry 'Microsoft.Resources/deployments@2021-04-01' = if (enableDefaultTelemetry) {
  name: 'pid-47ed15a6-730a-4827-bcb4-0fd963ffbd82-${uniqueString(deployment().name, location)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
    }
  }
}

resource lab 'Microsoft.DevTestLab/labs@2018-09-15' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: !empty(userAssignedIdentities) ? 'UserAssigned' : 'None'
    userAssignedIdentities: !empty(userAssignedIdentities) ? userAssignedIdentities : any(null)
  }
  properties: {
    announcement: announcement
    environmentPermission: environmentPermission
    extendedProperties: extendedProperties
    labStorageType: labStorageType
    mandatoryArtifactsResourceIdsLinux: mandatoryArtifactsResourceIdsLinux
    mandatoryArtifactsResourceIdsWindows: mandatoryArtifactsResourceIdsWindows
    premiumDataDisks: premiumDataDisks
    support: support
    managementIdentities: managementIdentities
  }
}

resource lab_lock 'Microsoft.Authorization/locks@2020-05-01' = if (!empty(lock)) {
  name: '${lab.name}-${lock}-lock'
  properties: {
    level: any(lock)
    notes: lock == 'CanNotDelete' ? 'Cannot delete resource or child resources.' : 'Cannot modify the resource or child resources.'
  }
  scope: lab
}

module lab_virtualNetworks 'virtualNetworks/deploy.bicep' = [for (virtualNetwork, index) in virtualNetworks: {
  name: '${uniqueString(deployment().name, location)}-Lab-VirtualNetwork-${index}'
  params: {
    labName: lab.name
    name: virtualNetwork.name
    tags: tags
    externalProviderResourceId: virtualNetwork.externalProviderResourceId
    description: contains(virtualNetwork, 'description') ? virtualNetwork.description : ''
    allowedSubnets: contains(virtualNetwork, 'allowedSubnets') ? virtualNetwork.allowedSubnets : []
    subnetOverrides: contains(virtualNetwork, 'subnetOverrides') ? virtualNetwork.subnetOverrides : []
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module lab_policies 'policySets/policies/deploy.bicep' = [for (policy, index) in policies: {
  name: '${uniqueString(deployment().name, location)}-Lab-PolicySets-Policy-${index}'
  params: {
    labName: lab.name
    name: policy.name
    tags: tags
    description: contains(policy, 'description') ? policy.description : ''
    evaluatorType: policy.evaluatorType
    factData: contains(policy, 'factData') ? policy.factData : ''
    factName: policy.factName
    status: contains(policy, 'status') ? policy.status : 'Enabled'
    threshold: policy.threshold
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module lab_schedules 'schedules/deploy.bicep' = [for (schedule, index) in schedules: {
  name: '${uniqueString(deployment().name, location)}-Lab-Schedules-${index}'
  params: {
    labName: lab.name
    name: schedule.name
    tags: tags
    taskType: schedule.taskType
    dailyRecurrence: contains(schedule, 'dailyRecurrence') ? schedule.dailyRecurrence : {}
    hourlyRecurrence: contains(schedule, 'hourlyRecurrence') ? schedule.hourlyRecurrence : {}
    weeklyRecurrence: contains(schedule, 'weeklyRecurrence') ? schedule.weeklyRecurrence : {}
    status: contains(schedule, 'status') ? schedule.status : 'Enabled'
    targetResourceId: contains(schedule, 'targetResourceId') ? schedule.targetResourceId : ''
    timeZoneId: contains(schedule, 'timeZoneId') ? schedule.timeZoneId : 'Pacific Standard time'
    notificationSettingsStatus: contains(schedule, 'notificationSettingsStatus') ? schedule.notificationSettingsStatus : 'Disabled'
    notificationSettingsTimeInMinutes: contains(schedule, 'notificationSettingsTimeInMinutes') ? schedule.notificationSettingsTimeInMinutes : 30
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module lab_notificationChannels 'notificationChannels/deploy.bicep' = [for (notificationChannel, index) in notificationChannels: {
  name: '${uniqueString(deployment().name, location)}-Lab-NotificationChannels-${index}'
  params: {
    labName: lab.name
    name: notificationChannel.name
    tags: tags
    description: contains(notificationChannel, 'description') ? notificationChannel.description : ''
    events: notificationChannel.events
    emailRecipient: contains(notificationChannel, 'emailRecipient') ? notificationChannel.emailRecipient : ''
    webhookUrl: contains(notificationChannel, 'webhookUrl') ? notificationChannel.webhookUrl : ''
    notificationLocale: contains(notificationChannel, 'notificationLocale') ? notificationChannel.notificationLocale : 'en'
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module lab_artifactSources 'artifactSources/deploy.bicep' = [for (artifactSource, index) in artifactSources: {
  name: '${uniqueString(deployment().name, location)}-Lab-ArtifactSources-${index}'
  params: {
    labName: lab.name
    name: artifactSource.name
    tags: tags
    displayName: contains(artifactSource, 'displayName') ? artifactSource.displayName : artifactSource.name
    branchRef: contains(artifactSource, 'branchRef') ? artifactSource.branchRef : ''
    folderPath: contains(artifactSource, 'folderPath') ? artifactSource.folderPath : ''
    armTemplateFolderPath: contains(artifactSource, 'armTemplateFolderPath') ? artifactSource.armTemplateFolderPath : ''
    sourceType: contains(artifactSource, 'sourceType') ? artifactSource.sourceType : ''
    status: contains(artifactSource, 'status') ? artifactSource.status : 'Enabled'
    uri: artifactSource.uri
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module lab_roleAssignments '.bicep/nested_roleAssignments.bicep' = [for (roleAssignment, index) in roleAssignments: {
  name: '${uniqueString(deployment().name, location)}-Rbac-${index}'
  params: {
    description: contains(roleAssignment, 'description') ? roleAssignment.description : ''
    principalIds: roleAssignment.principalIds
    principalType: contains(roleAssignment, 'principalType') ? roleAssignment.principalType : ''
    roleDefinitionIdOrName: roleAssignment.roleDefinitionIdOrName
    condition: contains(roleAssignment, 'condition') ? roleAssignment.condition : ''
    delegatedManagedIdentityResourceId: contains(roleAssignment, 'delegatedManagedIdentityResourceId') ? roleAssignment.delegatedManagedIdentityResourceId : ''
    resourceId: lab.id
  }
}]

@description('The unique identifier for the lab. Used to track tags that the lab applies to each resource that it creates.')
output uniqueIdentifier string = lab.properties.uniqueIdentifier

@description('The resource group the lab was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The resource ID of the lab.')
output resourceId string = lab.id

@description('The name of the lab.')
output name string = lab.name

@description('The location the resource was deployed into.')
output location string = lab.location