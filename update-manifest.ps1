# This file is part of the cv4pve-api-pwsh https://github.com/Corsinvest/cv4pve-api-pwsh,
#
# This source file is available under two different licenses:
# - GNU General Public License version 3 (GPLv3)
# - Corsinvest Enterprise License (CEL)
# Full copyright and license information is available in
# LICENSE.md which is distributed with this source code.
#
# Copyright (C) 2020 Corsinvest Srl	GPLv3 and CEL

$functions = Get-Command -Module Corsinvest.ProxmoxVE.Api -Type Function | Select-Object -ExpandProperty Name
$alias = Get-Command -Module Corsinvest.ProxmoxVE.Api -Type Alias | Select-Object -ExpandProperty Name
Update-ModuleManifest -Path .\Corsinvest.ProxmoxVE.Api\Corsinvest.ProxmoxVE.Api.psd1 -FunctionsToExport $functions -AliasesToExport $alias
