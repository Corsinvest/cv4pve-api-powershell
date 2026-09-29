# SPDX-FileCopyrightText: Copyright Corsinvest Srl
# SPDX-License-Identifier: MIT

function Invoke-PveAction {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateSet('analyzer', 'create-doc', 'update-manifest', 'import')]
        [string]$Action
    )

    process {
        # Define paths
        $modulePath = ".\Corsinvest.ProxmoxVE.Api\Corsinvest.ProxmoxVE.Api.psd1"
        $rootModulePath = ".\Corsinvest.ProxmoxVE.Api\Corsinvest.ProxmoxVE.Api.psm1"

        if ($Action -eq 'analyzer') {
            Import-Module PSScriptAnalyzer
            Get-ChildItem -Path Corsinvest.ProxmoxVE.Api -Filter "*.psm1" -Recurse | Invoke-ScriptAnalyzer -ExcludeRule PSUseSingularNouns
        }
        elseif ($Action -eq 'create-doc') {
            # Cmdlet reference of the documentation site (docs/), generated from the module source
            & .\docs\scripts\Update-CmdletReference.ps1
        }
        elseif ($Action -eq 'update-manifest') {
            # Import the .psm1 directly (not the .psd1): the manifest's FunctionsToExport
            # would otherwise filter out any newly generated function, leaving the list stale.
            Remove-Module Corsinvest.ProxmoxVE.Api -Force -ErrorAction SilentlyContinue
            Import-Module $rootModulePath -Force

            [System.Collections.ArrayList] $functions = Get-Command -Module Corsinvest.ProxmoxVE.Api -Type Function | Select-Object -ExpandProperty Name
            $functions.Remove("IsNumeric")

            $alias = Get-Command -Module Corsinvest.ProxmoxVE.Api -Type Alias | Select-Object -ExpandProperty Name
            Update-ModuleManifest -Path $modulePath -FunctionsToExport $functions -AliasesToExport $alias
        }
        elseif ($Action -eq 'import') {
            Remove-Module Corsinvest.ProxmoxVE.Api -Force -ErrorAction SilentlyContinue
            Import-Module $modulePath -Verbose -Force
        }
    }
}