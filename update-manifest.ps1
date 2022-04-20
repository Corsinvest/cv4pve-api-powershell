# SPDX-FileCopyrightText: 2022 Daniele Corsini <daniele.corsini@corsinvest.it>
# SPDX-FileCopyrightText: Copyright Corsinvest Srl
# SPDX-License-Identifier: GPL-3.0-only

[System.Collections.ArrayList] $functions = Get-Command -Module Corsinvest.ProxmoxVE.Api -Type Function | Select-Object -ExpandProperty Name
$functions.Remove("IsNumeric")


#$functions += 'Connect-PveCluster', 'Invoke-PveRestApi', 'Build-PveDocumentation', 'ConvertTo-PveUnixTime', 'ConvertFrom-PveUnixTime', 'Enter-PveSpice', 'Wait-PveTaskIsFinish', 'Get-PveTaskIsRunning', 'Get-PveStorage', 'Get-PveVM', 'Unlock-PveVM', 'Start-PveVM', 'Stop-PveVM', 'Suspend-PveVM', 'Resume-PveVM', 'Reset-PveVM', 'Get-PveVMSnapshots', 'New-PveVMSnapshot', 'Remove-PveVMSnapshot', 'Undo-PveVMSnapshot'
$alias = Get-Command -Module Corsinvest.ProxmoxVE.Api -Type Alias | Select-Object -ExpandProperty Name
Update-ModuleManifest -Path .\Corsinvest.ProxmoxVE.Api\Corsinvest.ProxmoxVE.Api.psd1 -FunctionsToExport $functions -AliasesToExport $alias
