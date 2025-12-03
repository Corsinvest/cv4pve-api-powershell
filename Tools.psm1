# SPDX-FileCopyrightText: Copyright Corsinvest Srl
# SPDX-License-Identifier: GPL-3.0-only

function Invoke-PveAction {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateSet('analyzer', 'create-doc-md', 'create-doc-mkdocs', 'build-doc-mkdocs', 'serve-doc-mkdocs', 'update-manifest', 'import', 'publish', 'build-cast')]
        [string]$Action
    )

    process {
        # Define paths
        $MkDocsOutputPath = ".\doc\mkdocs\docs"
        $MarkdownSourcePath = ".\doc\markdown"
        $modulePath = ".\Corsinvest.ProxmoxVE.Api\Corsinvest.ProxmoxVE.Api.psd1"

        if ($Action -eq 'analyzer') {
            Import-Module PSScriptAnalyzer
            Get-ChildItem -Path Corsinvest.ProxmoxVE.Api -Filter "*.psm1" -Recurse | Invoke-ScriptAnalyzer -ExcludeRule PSUseSingularNouns
        }
        elseif ($Action -eq 'create-doc-md') {
            Install-Module -Name platyPS -Force -Scope CurrentUser
            Import-Module $modulePath -Verbose -Force -GLobal

            # Clear existing markdown directory contents to ensure clean state
            if (Test-Path $MarkdownSourcePath) {
                Get-ChildItem $MarkdownSourcePath | Remove-Item -Recurse -Force
                Write-Host "🗑️  Cleared markdown directory contents" -ForegroundColor Yellow
            }

            New-MarkdownHelp -Module Corsinvest.ProxmoxVE.Api -OutputFolder $MarkdownSourcePath -Force
        }
        elseif ($Action -eq 'create-doc-mkdocs') {
            Write-Host "🚀 Starting MkDocs documentation generation..." -ForegroundColor Cyan

            # Process PlatyPS markdown files (generate index only, no copy)
            Write-Host "📚 Processing cmdlet documentation..." -ForegroundColor Cyan
            $markdownFiles = Get-ChildItem -Path $MarkdownSourcePath -Filter "*.md" | Where-Object { $_.Name -notlike "about_*" }
            $cmdletsByCategory = @{}

            foreach ($file in $markdownFiles) {
                $cmdletName = $file.BaseName

                # Determine category from cmdlet name
                $category = switch -Regex ($cmdletName) {
                    '^Connect-' { 'Connection'; break }
                    '^Get-Pve(Version|Cluster|Access)' { 'Cluster'; break }
                    '^.*Snapshot.*' { 'Snapshots'; break }
                    '^.*Nodes.*Qemu.*' { 'Virtual Machines (QEMU)'; break }
                    '^.*Nodes.*Lxc.*' { 'Containers (LXC)'; break }
                    '^.*Nodes.*Storage.*' { 'Storage'; break }
                    '^(Start|Stop|Suspend|Resume|Reset|Unlock)-PveVm' { 'VM Operations'; break }
                    '^Get-Pve.*Monitoring' { 'Monitoring'; break }
                    '^(Wait|Get)-Pve.*Task.*' { 'Task Management'; break }
                    '^ConvertFrom-PveUnixTime|ConvertTo-PveUnixTime' { 'Utilities'; break }
                    '^Invoke-Pve' { 'API Access'; break }
                    default { 'Other' }
                }

                # Add to category
                if (-not $cmdletsByCategory.ContainsKey($category)) {
                    $cmdletsByCategory[$category] = @()
                }
                $cmdletsByCategory[$category] += $cmdletName
            }

            Write-Host "✅ Analyzed $($markdownFiles.Count) cmdlet files" -ForegroundColor Green

            # Generate cmdlets index with categories (pointing to markdown source)
            Write-Host "📑 Generating cmdlets index..." -ForegroundColor Cyan
            $indexContent = @"
# Cmdlet Reference

This page provides a complete reference of all cmdlets available in the cv4pve-api-powershell module.

## Quick Links

- [PowerShell Gallery](https://www.powershellgallery.com/packages/Corsinvest.ProxmoxVE.Api/)
- [GitHub Repository](https://github.com/Corsinvest/cv4pve-api-powershell)

## Cmdlets by Category

"@

            foreach ($category in ($cmdletsByCategory.Keys | Sort-Object)) {
                $indexContent += "`n### $category`n`n"
                foreach ($cmdlet in ($cmdletsByCategory[$category] | Sort-Object)) {
                    # Point to markdown source - with docs_dir: ../ the path is relative to doc/
                    $indexContent += "- [$cmdlet](markdown/$cmdlet.md)`n"
                }
            }

            $cmdletsIndexPath = Join-Path $MkDocsOutputPath "cmdlets-index.md"
            $indexContent | Out-File $cmdletsIndexPath -Encoding utf8 -Force
            Write-Host "✅ Generated cmdlets index at $cmdletsIndexPath" -ForegroundColor Green

            # Note: mkdocs.yml navigation is static. With hundreds of cmdlets, dynamic navigation

            Write-Host "`n✅ MkDocs documentation generation complete!" -ForegroundColor Green
            Write-Host "📂 Output location: $MkDocsOutputPath" -ForegroundColor Cyan

            Write-Host "`n📖 MkDocs documentation structure created!" -ForegroundColor Green
            Write-Host "To serve locally:" -ForegroundColor Cyan
            Write-Host "  Invoke-PveAction -Action serve-doc-mkdocs " -ForegroundColor White
            Write-Host "  Open http://127.0.0.1:8000" -ForegroundColor White
        }
        elseif ($Action -eq 'build-doc-mkdocs') {
            # Build static site
            Push-Location ".\doc\mkdocs"
            try {
                Write-Host "🔨 Building MkDocs static site..." -ForegroundColor Cyan
                & mkdocs build
                Write-Host "✅ MkDocs site built successfully!" -ForegroundColor Green
                Write-Host "📁 Site location: .\doc\mkdocs\site" -ForegroundColor Cyan
            }
            finally {
                Pop-Location
            }
        }
        elseif ($Action -eq 'serve-doc-mkdocs') {
            Write-Host "🌐 Starting MkDocs server..." -ForegroundColor Cyan
            Push-Location ".\doc\mkdocs"
            try {
                Write-Host "✅ Server starting at http://127.0.0.1:8000" -ForegroundColor Green
                Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
                & mkdocs serve
            }
            finally {
                Pop-Location
            }
        }
        elseif ($Action -eq 'update-manifest') {
            [System.Collections.ArrayList] $functions = Get-Command -Module Corsinvest.ProxmoxVE.Api -Type Function | Select-Object -ExpandProperty Name
            $functions.Remove("IsNumeric")

            $alias = Get-Command -Module Corsinvest.ProxmoxVE.Api -Type Alias | Select-Object -ExpandProperty Name
            Update-ModuleManifest -Path $modulePath -FunctionsToExport $functions -AliasesToExport $alias
        }
        elseif ($Action -eq 'import') {
            Import-Module .\Corsinvest.ProxmoxVE.Api\Corsinvest.ProxmoxVE.Api.psm1 -Verbose -Force
        }
        elseif ($Action -eq 'build-cast') {
            Build-AsciinemaFromPs1 -InputFile .\doc\video-commands.ps1 -OutputFile .\doc\video.cast
        }
        elseif ($Action -eq 'publish') {
            Import-Module ..\..\..\cmds\Corsinvest.Dotnet.Develop.psm1 -Verbose -Force
           
            $env:DOTNET_CLI_UI_LANGUAGE='en-us'

            $publishModuleSplat = @{
                Path              = ".\Corsinvest.ProxmoxVE.Api"
                #Name              = "Corsinvest.ProxmoxVE.Api"
                NuGetApiKey       = $ENV:PowerShellGalleryApiKey
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