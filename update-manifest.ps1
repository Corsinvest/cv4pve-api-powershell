# SPDX-FileCopyrightText: Copyright Corsinvest Srl
# SPDX-License-Identifier: GPL-3.0-only

[System.Collections.ArrayList] $functions = Get-Command -Module Corsinvest.ProxmoxVE.Api -Type Function | Select-Object -ExpandProperty Name
$functions.Remove("IsNumeric")

$alias = Get-Command -Module Corsinvest.ProxmoxVE.Api -Type Alias | Select-Object -ExpandProperty Name
Update-ModuleManifest -Path .\Corsinvest.ProxmoxVE.Api\Corsinvest.ProxmoxVE.Api.psd1 -FunctionsToExport $functions -AliasesToExport $alias
