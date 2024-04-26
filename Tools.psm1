# SPDX-FileCopyrightText: Copyright Corsinvest Srl
# SPDX-License-Identifier: GPL-3.0-only

Import-Module ..\..\..\cmds\Corsinvest.Dotnet.Develop.psm1 -Verbose -Force

function Invoke-PveAction {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateSet('analyzer', 'build-doc', 'update-manifest', 'import', 'publish', 'build-cast')]
        [string]$Action
    )

    process {
        if ($Action -eq 'analyzer') {
            Import-Module PSScriptAnalyzer
            Get-ChildItem -Path Corsinvest.ProxmoxVE.Api -Filter "*.psm1" -Recurse | Invoke-ScriptAnalyzer -ExcludeRule PSUseSingularNouns
        }
        elseif ($Action -eq 'build-doc') {
            Build-PveDocumentation -OutputFile .\doc\index.html -TemplateFile .\help-out-html.ps1
        }
        elseif ($Action -eq 'update-manifest') {
            [System.Collections.ArrayList] $functions = Get-Command -Module Corsinvest.ProxmoxVE.Api -Type Function | Select-Object -ExpandProperty Name
            $functions.Remove("IsNumeric")

            $alias = Get-Command -Module Corsinvest.ProxmoxVE.Api -Type Alias | Select-Object -ExpandProperty Name
            Update-ModuleManifest -Path .\Corsinvest.ProxmoxVE.Api\Corsinvest.ProxmoxVE.Api.psd1 -FunctionsToExport $functions -AliasesToExport $alias
        }
        elseif ($Action -eq 'import') {
            Import-Module .\Corsinvest.ProxmoxVE.Api\Corsinvest.ProxmoxVE.Api.psm1 -Verbose -Force
        }
        elseif ($Action -eq 'build-cast') {
            Build-AsciinemaFromPs1 -InputFile .\doc\video-commands.ps1 -OutputFile .\doc\video.cast
        }
        elseif ($Action -eq 'publish') {
            $publishModuleSplat = @{
                Path              = ".\Corsinvest.ProxmoxVE.Api"
                #Name              = "Corsinvest.ProxmoxVE.Api"
                NuGetApiKey       = $ENV:NugetApiKey
                Verbose           = $true
                Debug             = $true
                Force             = $true
                Repository        = "PSGallery"
                ErrorAction       = 'Stop'
                SkipAutomaticTags = $true
            }

            Publish-Module @publishModuleSplat
        }
    }
}