#
# Module manifest for module 'Corsinvest.ProxmoxVE.Api'
#
# Generated by: Daniele Corsini
#
# Generated on: 06/12/2021
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'Corsinvest.ProxmoxVE.Api.psm1'

# Version number of this module.
ModuleVersion = '7.1.2.0'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '1ea166c7-0303-42c6-ac8f-0718c03d39e2'

# Author of this module
Author = 'Daniele Corsini'

# Company or vendor of this module
CompanyName = 'Corsinvest Srl'

# Copyright statement for this module
Copyright = '(c) 2020 Corsinvest Srl. All rights reserved.'

# Description of the functionality provided by this module
Description = 'PowerShell for Proxmox VE'

# Minimum version of the PowerShell engine required by this module
# PowerShellVersion = ''

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'Build-PveDocumentation', 'Connect-PveCluster',
               'ConvertFrom-PveUnixTime', 'ConvertTo-PveUnixTime', 'Enter-PveSpice',
               'Get-PveAccess', 'Get-PveAccessAcl', 'Get-PveAccessDomains',
               'Get-PveAccessDomainsIdx', 'Get-PveAccessGroups',
               'Get-PveAccessGroupsIdx', 'Get-PveAccessOpenid',
               'Get-PveAccessPermissions', 'Get-PveAccessRoles',
               'Get-PveAccessRolesIdx', 'Get-PveAccessTfa', 'Get-PveAccessTfaIdx',
               'Get-PveAccessTicket', 'Get-PveAccessUsers', 'Get-PveAccessUsersIdx',
               'Get-PveAccessUsersTfa', 'Get-PveAccessUsersToken',
               'Get-PveAccessUsersTokenIdx', 'Get-PveCluster', 'Get-PveClusterAcme',
               'Get-PveClusterAcmeAccount', 'Get-PveClusterAcmeAccountIdx',
               'Get-PveClusterAcmeChallengeSchema',
               'Get-PveClusterAcmeDirectories', 'Get-PveClusterAcmePlugins',
               'Get-PveClusterAcmePluginsIdx', 'Get-PveClusterAcmeTos',
               'Get-PveClusterBackup', 'Get-PveClusterBackupIdx',
               'Get-PveClusterBackupIncludedVolumes', 'Get-PveClusterBackupInfo',
               'Get-PveClusterBackupInfoNotBackedUp', 'Get-PveClusterCeph',
               'Get-PveClusterCephFlags', 'Get-PveClusterCephFlagsIdx',
               'Get-PveClusterCephMetadata', 'Get-PveClusterCephStatus',
               'Get-PveClusterConfig', 'Get-PveClusterConfigApiversion',
               'Get-PveClusterConfigJoin', 'Get-PveClusterConfigNodes',
               'Get-PveClusterConfigQdevice', 'Get-PveClusterConfigTotem',
               'Get-PveClusterFirewall', 'Get-PveClusterFirewallAliases',
               'Get-PveClusterFirewallAliasesIdx', 'Get-PveClusterFirewallGroups',
               'Get-PveClusterFirewallGroupsIdx', 'Get-PveClusterFirewallIpset',
               'Get-PveClusterFirewallIpsetIdx', 'Get-PveClusterFirewallMacros',
               'Get-PveClusterFirewallOptions', 'Get-PveClusterFirewallRefs',
               'Get-PveClusterFirewallRules', 'Get-PveClusterFirewallRulesIdx',
               'Get-PveClusterHa', 'Get-PveClusterHaGroups',
               'Get-PveClusterHaGroupsIdx', 'Get-PveClusterHaResources',
               'Get-PveClusterHaResourcesIdx', 'Get-PveClusterHaStatus',
               'Get-PveClusterHaStatusCurrent',
               'Get-PveClusterHaStatusManagerStatus', 'Get-PveClusterJobs',
               'Get-PveClusterJobsScheduleAnalyze', 'Get-PveClusterLog',
               'Get-PveClusterMetrics', 'Get-PveClusterMetricsServer',
               'Get-PveClusterMetricsServerIdx', 'Get-PveClusterNextid',
               'Get-PveClusterOptions', 'Get-PveClusterReplication',
               'Get-PveClusterReplicationIdx', 'Get-PveClusterResources',
               'Get-PveClusterSdn', 'Get-PveClusterSdnControllers',
               'Get-PveClusterSdnControllersIdx', 'Get-PveClusterSdnDns',
               'Get-PveClusterSdnDnsIdx', 'Get-PveClusterSdnIpams',
               'Get-PveClusterSdnIpamsIdx', 'Get-PveClusterSdnVnets',
               'Get-PveClusterSdnVnetsIdx', 'Get-PveClusterSdnVnetsSubnets',
               'Get-PveClusterSdnVnetsSubnetsIdx', 'Get-PveClusterSdnZones',
               'Get-PveClusterSdnZonesIdx', 'Get-PveClusterStatus',
               'Get-PveClusterTasks', 'Get-PveNode', 'Get-PveNodes',
               'Get-PveNodesAplinfo', 'Get-PveNodesApt', 'Get-PveNodesAptChangelog',
               'Get-PveNodesAptRepositories', 'Get-PveNodesAptUpdate',
               'Get-PveNodesAptVersions', 'Get-PveNodesCapabilities',
               'Get-PveNodesCapabilitiesQemu', 'Get-PveNodesCapabilitiesQemuCpu',
               'Get-PveNodesCapabilitiesQemuMachines', 'Get-PveNodesCeph',
               'Get-PveNodesCephConfig', 'Get-PveNodesCephConfigdb',
               'Get-PveNodesCephCrush', 'Get-PveNodesCephFs', 'Get-PveNodesCephLog',
               'Get-PveNodesCephMds', 'Get-PveNodesCephMgr', 'Get-PveNodesCephMon',
               'Get-PveNodesCephOsd', 'Get-PveNodesCephPools',
               'Get-PveNodesCephPoolsIdx', 'Get-PveNodesCephRules',
               'Get-PveNodesCephStatus', 'Get-PveNodesCertificates',
               'Get-PveNodesCertificatesAcme', 'Get-PveNodesCertificatesInfo',
               'Get-PveNodesConfig', 'Get-PveNodesDisks',
               'Get-PveNodesDisksDirectory', 'Get-PveNodesDisksList',
               'Get-PveNodesDisksLvm', 'Get-PveNodesDisksLvmthin',
               'Get-PveNodesDisksSmart', 'Get-PveNodesDisksZfs',
               'Get-PveNodesDisksZfsIdx', 'Get-PveNodesDns', 'Get-PveNodesFirewall',
               'Get-PveNodesFirewallLog', 'Get-PveNodesFirewallOptions',
               'Get-PveNodesFirewallRules', 'Get-PveNodesFirewallRulesIdx',
               'Get-PveNodesHardware', 'Get-PveNodesHardwarePci',
               'Get-PveNodesHardwarePciIdx', 'Get-PveNodesHardwarePciMdev',
               'Get-PveNodesHardwareUsb', 'Get-PveNodesHosts', 'Get-PveNodesIdx',
               'Get-PveNodesJournal', 'Get-PveNodesLxc', 'Get-PveNodesLxcConfig',
               'Get-PveNodesLxcFeature', 'Get-PveNodesLxcFirewall',
               'Get-PveNodesLxcFirewallAliases',
               'Get-PveNodesLxcFirewallAliasesIdx', 'Get-PveNodesLxcFirewallIpset',
               'Get-PveNodesLxcFirewallIpsetIdx', 'Get-PveNodesLxcFirewallLog',
               'Get-PveNodesLxcFirewallOptions', 'Get-PveNodesLxcFirewallRefs',
               'Get-PveNodesLxcFirewallRules', 'Get-PveNodesLxcFirewallRulesIdx',
               'Get-PveNodesLxcIdx', 'Get-PveNodesLxcPending', 'Get-PveNodesLxcRrd',
               'Get-PveNodesLxcRrddata', 'Get-PveNodesLxcSnapshot',
               'Get-PveNodesLxcSnapshotConfig', 'Get-PveNodesLxcSnapshotIdx',
               'Get-PveNodesLxcStatus', 'Get-PveNodesLxcStatusCurrent',
               'Get-PveNodesLxcVncwebsocket', 'Get-PveNodesNetstat',
               'Get-PveNodesNetwork', 'Get-PveNodesNetworkIdx', 'Get-PveNodesQemu',
               'Get-PveNodesQemuAgent', 'Get-PveNodesQemuAgentExecStatus',
               'Get-PveNodesQemuAgentFileRead', 'Get-PveNodesQemuAgentGetFsinfo',
               'Get-PveNodesQemuAgentGetHostName',
               'Get-PveNodesQemuAgentGetMemoryBlockInfo',
               'Get-PveNodesQemuAgentGetMemoryBlocks',
               'Get-PveNodesQemuAgentGetOsinfo', 'Get-PveNodesQemuAgentGetTime',
               'Get-PveNodesQemuAgentGetTimezone', 'Get-PveNodesQemuAgentGetUsers',
               'Get-PveNodesQemuAgentGetVcpus', 'Get-PveNodesQemuAgentInfo',
               'Get-PveNodesQemuAgentNetworkGetInterfaces',
               'Get-PveNodesQemuConfig', 'Get-PveNodesQemuFeature',
               'Get-PveNodesQemuFirewall', 'Get-PveNodesQemuFirewallAliases',
               'Get-PveNodesQemuFirewallAliasesIdx',
               'Get-PveNodesQemuFirewallIpset', 'Get-PveNodesQemuFirewallIpsetIdx',
               'Get-PveNodesQemuFirewallLog', 'Get-PveNodesQemuFirewallOptions',
               'Get-PveNodesQemuFirewallRefs', 'Get-PveNodesQemuFirewallRules',
               'Get-PveNodesQemuFirewallRulesIdx', 'Get-PveNodesQemuIdx',
               'Get-PveNodesQemuMigrate', 'Get-PveNodesQemuPending',
               'Get-PveNodesQemuRrd', 'Get-PveNodesQemuRrddata',
               'Get-PveNodesQemuSnapshot', 'Get-PveNodesQemuSnapshotConfig',
               'Get-PveNodesQemuSnapshotIdx', 'Get-PveNodesQemuStatus',
               'Get-PveNodesQemuStatusCurrent', 'Get-PveNodesQemuVncwebsocket',
               'Get-PveNodesQueryUrlMetadata', 'Get-PveNodesReplication',
               'Get-PveNodesReplicationIdx', 'Get-PveNodesReplicationLog',
               'Get-PveNodesReplicationStatus', 'Get-PveNodesReport',
               'Get-PveNodesRrd', 'Get-PveNodesRrddata', 'Get-PveNodesScan',
               'Get-PveNodesScanCifs', 'Get-PveNodesScanGlusterfs',
               'Get-PveNodesScanIscsi', 'Get-PveNodesScanLvm',
               'Get-PveNodesScanLvmthin', 'Get-PveNodesScanNfs',
               'Get-PveNodesScanPbs', 'Get-PveNodesScanZfs', 'Get-PveNodesSdn',
               'Get-PveNodesSdnZones', 'Get-PveNodesSdnZonesContent',
               'Get-PveNodesSdnZonesIdx', 'Get-PveNodesServices',
               'Get-PveNodesServicesIdx', 'Get-PveNodesServicesState',
               'Get-PveNodesStatus', 'Get-PveNodesStorage',
               'Get-PveNodesStorageContent', 'Get-PveNodesStorageContentIdx',
               'Get-PveNodesStorageIdx', 'Get-PveNodesStoragePrunebackups',
               'Get-PveNodesStorageRrd', 'Get-PveNodesStorageRrddata',
               'Get-PveNodesStorageStatus', 'Get-PveNodesSubscription',
               'Get-PveNodesSyslog', 'Get-PveNodesTasks', 'Get-PveNodesTasksIdx',
               'Get-PveNodesTasksLog', 'Get-PveNodesTasksStatus', 'Get-PveNodesTime',
               'Get-PveNodesVersion', 'Get-PveNodesVncwebsocket',
               'Get-PveNodesVzdumpDefaults', 'Get-PveNodesVzdumpExtractconfig',
               'Get-PvePools', 'Get-PvePoolsIdx', 'Get-PveStorage',
               'Get-PveStorageIdx', 'Get-PveTaskIsRunning', 'Get-PveVersion',
               'Get-PveVM', 'Get-PveVMSnapshots', 'Invoke-PveRestApi', 'IsNumeric',
               'New-PveAccessDomains', 'New-PveAccessDomainsSync',
               'New-PveAccessGroups', 'New-PveAccessOpenidAuthUrl',
               'New-PveAccessOpenidLogin', 'New-PveAccessRoles', 'New-PveAccessTfa',
               'New-PveAccessTfaIdx', 'New-PveAccessTicket', 'New-PveAccessUsers',
               'New-PveAccessUsersToken', 'New-PveClusterAcmeAccount',
               'New-PveClusterAcmePlugins', 'New-PveClusterBackup',
               'New-PveClusterConfig', 'New-PveClusterConfigJoin',
               'New-PveClusterConfigNodes', 'New-PveClusterFirewallAliases',
               'New-PveClusterFirewallGroups', 'New-PveClusterFirewallGroupsIdx',
               'New-PveClusterFirewallIpset', 'New-PveClusterFirewallIpsetIdx',
               'New-PveClusterFirewallRules', 'New-PveClusterHaGroups',
               'New-PveClusterHaResources', 'New-PveClusterHaResourcesMigrate',
               'New-PveClusterHaResourcesRelocate', 'New-PveClusterMetricsServer',
               'New-PveClusterReplication', 'New-PveClusterSdnControllers',
               'New-PveClusterSdnDns', 'New-PveClusterSdnIpams',
               'New-PveClusterSdnVnets', 'New-PveClusterSdnVnetsSubnets',
               'New-PveClusterSdnZones', 'New-PveNodesAplinfo',
               'New-PveNodesAptRepositories', 'New-PveNodesAptUpdate',
               'New-PveNodesCephFs', 'New-PveNodesCephInit', 'New-PveNodesCephMds',
               'New-PveNodesCephMgr', 'New-PveNodesCephMon', 'New-PveNodesCephOsd',
               'New-PveNodesCephOsdIn', 'New-PveNodesCephOsdOut',
               'New-PveNodesCephOsdScrub', 'New-PveNodesCephPools',
               'New-PveNodesCephRestart', 'New-PveNodesCephStart',
               'New-PveNodesCephStop', 'New-PveNodesCertificatesAcmeCertificate',
               'New-PveNodesCertificatesCustom', 'New-PveNodesDisksDirectory',
               'New-PveNodesDisksInitgpt', 'New-PveNodesDisksLvm',
               'New-PveNodesDisksLvmthin', 'New-PveNodesDisksZfs',
               'New-PveNodesExecute', 'New-PveNodesFirewallRules',
               'New-PveNodesHosts', 'New-PveNodesLxc', 'New-PveNodesLxcClone',
               'New-PveNodesLxcFirewallAliases', 'New-PveNodesLxcFirewallIpset',
               'New-PveNodesLxcFirewallIpsetIdx', 'New-PveNodesLxcFirewallRules',
               'New-PveNodesLxcMigrate', 'New-PveNodesLxcMoveVolume',
               'New-PveNodesLxcSnapshot', 'New-PveNodesLxcSnapshotRollback',
               'New-PveNodesLxcSpiceproxy', 'New-PveNodesLxcStatusReboot',
               'New-PveNodesLxcStatusResume', 'New-PveNodesLxcStatusShutdown',
               'New-PveNodesLxcStatusStart', 'New-PveNodesLxcStatusStop',
               'New-PveNodesLxcStatusSuspend', 'New-PveNodesLxcTemplate',
               'New-PveNodesLxcTermproxy', 'New-PveNodesLxcVncproxy',
               'New-PveNodesMigrateall', 'New-PveNodesNetwork', 'New-PveNodesQemu',
               'New-PveNodesQemuAgent', 'New-PveNodesQemuAgentExec',
               'New-PveNodesQemuAgentFileWrite',
               'New-PveNodesQemuAgentFsfreezeFreeze',
               'New-PveNodesQemuAgentFsfreezeStatus',
               'New-PveNodesQemuAgentFsfreezeThaw', 'New-PveNodesQemuAgentFstrim',
               'New-PveNodesQemuAgentPing', 'New-PveNodesQemuAgentSetUserPassword',
               'New-PveNodesQemuAgentShutdown', 'New-PveNodesQemuAgentSuspendDisk',
               'New-PveNodesQemuAgentSuspendHybrid',
               'New-PveNodesQemuAgentSuspendRam', 'New-PveNodesQemuClone',
               'New-PveNodesQemuConfig', 'New-PveNodesQemuFirewallAliases',
               'New-PveNodesQemuFirewallIpset', 'New-PveNodesQemuFirewallIpsetIdx',
               'New-PveNodesQemuFirewallRules', 'New-PveNodesQemuMigrate',
               'New-PveNodesQemuMonitor', 'New-PveNodesQemuMoveDisk',
               'New-PveNodesQemuSnapshot', 'New-PveNodesQemuSnapshotRollback',
               'New-PveNodesQemuSpiceproxy', 'New-PveNodesQemuStatusReboot',
               'New-PveNodesQemuStatusReset', 'New-PveNodesQemuStatusResume',
               'New-PveNodesQemuStatusShutdown', 'New-PveNodesQemuStatusStart',
               'New-PveNodesQemuStatusStop', 'New-PveNodesQemuStatusSuspend',
               'New-PveNodesQemuTemplate', 'New-PveNodesQemuTermproxy',
               'New-PveNodesQemuVncproxy', 'New-PveNodesReplicationScheduleNow',
               'New-PveNodesServicesReload', 'New-PveNodesServicesRestart',
               'New-PveNodesServicesStart', 'New-PveNodesServicesStop',
               'New-PveNodesSpiceshell', 'New-PveNodesStartall',
               'New-PveNodesStatus', 'New-PveNodesStopall',
               'New-PveNodesStorageContent', 'New-PveNodesStorageContentIdx',
               'New-PveNodesStorageDownloadUrl', 'New-PveNodesStorageUpload',
               'New-PveNodesSubscription', 'New-PveNodesTermproxy',
               'New-PveNodesVncshell', 'New-PveNodesVzdump', 'New-PveNodesWakeonlan',
               'New-PvePools', 'New-PveStorage', 'New-PveVMSnapshot',
               'Remove-PveAccessDomains', 'Remove-PveAccessGroups',
               'Remove-PveAccessRoles', 'Remove-PveAccessTfa',
               'Remove-PveAccessUsers', 'Remove-PveAccessUsersToken',
               'Remove-PveClusterAcmeAccount', 'Remove-PveClusterAcmePlugins',
               'Remove-PveClusterBackup', 'Remove-PveClusterConfigNodes',
               'Remove-PveClusterFirewallAliases',
               'Remove-PveClusterFirewallGroups',
               'Remove-PveClusterFirewallGroupsIdx',
               'Remove-PveClusterFirewallIpset',
               'Remove-PveClusterFirewallIpsetIdx',
               'Remove-PveClusterFirewallRules', 'Remove-PveClusterHaGroups',
               'Remove-PveClusterHaResources', 'Remove-PveClusterMetricsServer',
               'Remove-PveClusterReplication', 'Remove-PveClusterSdnControllers',
               'Remove-PveClusterSdnDns', 'Remove-PveClusterSdnIpams',
               'Remove-PveClusterSdnVnets', 'Remove-PveClusterSdnVnetsSubnets',
               'Remove-PveClusterSdnZones', 'Remove-PveNodesCephMds',
               'Remove-PveNodesCephMgr', 'Remove-PveNodesCephMon',
               'Remove-PveNodesCephOsd', 'Remove-PveNodesCephPools',
               'Remove-PveNodesCertificatesAcmeCertificate',
               'Remove-PveNodesCertificatesCustom',
               'Remove-PveNodesDisksDirectory', 'Remove-PveNodesDisksLvm',
               'Remove-PveNodesDisksLvmthin', 'Remove-PveNodesDisksZfs',
               'Remove-PveNodesFirewallRules', 'Remove-PveNodesLxc',
               'Remove-PveNodesLxcFirewallAliases',
               'Remove-PveNodesLxcFirewallIpset',
               'Remove-PveNodesLxcFirewallIpsetIdx',
               'Remove-PveNodesLxcFirewallRules', 'Remove-PveNodesLxcSnapshot',
               'Remove-PveNodesNetwork', 'Remove-PveNodesNetworkIdx',
               'Remove-PveNodesQemu', 'Remove-PveNodesQemuFirewallAliases',
               'Remove-PveNodesQemuFirewallIpset',
               'Remove-PveNodesQemuFirewallIpsetIdx',
               'Remove-PveNodesQemuFirewallRules', 'Remove-PveNodesQemuSnapshot',
               'Remove-PveNodesStorageContent',
               'Remove-PveNodesStoragePrunebackups', 'Remove-PveNodesSubscription',
               'Remove-PveNodesTasks', 'Remove-PvePools', 'Remove-PveStorage',
               'Remove-PveVMSnapshot', 'Reset-PveVM', 'Resume-PveVM',
               'Set-PveAccessAcl', 'Set-PveAccessDomains', 'Set-PveAccessGroups',
               'Set-PveAccessPassword', 'Set-PveAccessRoles', 'Set-PveAccessTfa',
               'Set-PveAccessUsers', 'Set-PveAccessUsersToken',
               'Set-PveClusterAcmeAccount', 'Set-PveClusterAcmePlugins',
               'Set-PveClusterBackup', 'Set-PveClusterCephFlags',
               'Set-PveClusterCephFlagsIdx', 'Set-PveClusterFirewallAliases',
               'Set-PveClusterFirewallGroups', 'Set-PveClusterFirewallIpset',
               'Set-PveClusterFirewallOptions', 'Set-PveClusterFirewallRules',
               'Set-PveClusterHaGroups', 'Set-PveClusterHaResources',
               'Set-PveClusterMetricsServer', 'Set-PveClusterOptions',
               'Set-PveClusterReplication', 'Set-PveClusterSdn',
               'Set-PveClusterSdnControllers', 'Set-PveClusterSdnDns',
               'Set-PveClusterSdnIpams', 'Set-PveClusterSdnVnets',
               'Set-PveClusterSdnVnetsSubnets', 'Set-PveClusterSdnZones',
               'Set-PveNodesAptRepositories', 'Set-PveNodesCephPools',
               'Set-PveNodesCertificatesAcmeCertificate', 'Set-PveNodesConfig',
               'Set-PveNodesDisksWipedisk', 'Set-PveNodesDns',
               'Set-PveNodesFirewallOptions', 'Set-PveNodesFirewallRules',
               'Set-PveNodesLxcConfig', 'Set-PveNodesLxcFirewallAliases',
               'Set-PveNodesLxcFirewallIpset', 'Set-PveNodesLxcFirewallOptions',
               'Set-PveNodesLxcFirewallRules', 'Set-PveNodesLxcResize',
               'Set-PveNodesLxcSnapshotConfig', 'Set-PveNodesNetwork',
               'Set-PveNodesNetworkIdx', 'Set-PveNodesQemuConfig',
               'Set-PveNodesQemuFirewallAliases', 'Set-PveNodesQemuFirewallIpset',
               'Set-PveNodesQemuFirewallOptions', 'Set-PveNodesQemuFirewallRules',
               'Set-PveNodesQemuResize', 'Set-PveNodesQemuSendkey',
               'Set-PveNodesQemuSnapshotConfig', 'Set-PveNodesQemuUnlink',
               'Set-PveNodesStorageContent', 'Set-PveNodesSubscription',
               'Set-PveNodesTime', 'Set-PvePools', 'Set-PveStorage', 'Start-PveVM',
               'Stop-PveVM', 'Suspend-PveVM', 'Undo-PveVMSnapshot', 'Unlock-PveVM',
               'VmCheckIdOrName', 'Wait-PveTaskIsFinish'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = 'Backup-PveVzdump', 'Copy-PveLxc', 'Copy-PveQemu', 'Get-PveTasksStatus',
               'Move-PveLxc', 'Move-PveQemu', 'New-PveQemu', 'Reset-PveQemu',
               'Resume-PveLxc', 'Resume-PveQemu', 'Start-PveLxc', 'Start-PveQemu',
               'Stop-PveLxc', 'Stop-PveQemu', 'Suspend-PveLxc', 'Suspend-PveQemu',
               'Update-PveNode'

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'Proxmox','ProxmoxVE','Api','Clueser','Virtualization','PVE'

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/Corsinvest/cv4pve-api-powershell'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

 } # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

