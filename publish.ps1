# This file is part of the cv4pve-api-pwsh https://github.com/Corsinvest/cv4pve-api-pwsh,
#
# This source file is available under two different licenses:
# - GNU General Public License version 3 (GPLv3)
# - Corsinvest Enterprise License (CEL)
# Full copyright and license information is available in
# LICENSE.md which is distributed with this source code.
#
# Copyright (C) 2020 Corsinvest Srl	GPLv3 and CEL

#  $p = [Environment]::GetEnvironmentVariable("PSModulePath")
#  $path = ";.\Corsinvest.ProxmoxVE.Api";
#   if (-not $p.EndsWith($path))
#   {
#       $p += $path
#       [Environment]::SetEnvironmentVariable("PSModulePath",$p)
#   }

 .\setKey.ps1

# $Profilepowershellget = "$env:userprofile\AppData\Local\Microsoft\Windows\PowerShell\PowerShellGet\"

# if(-Not(Test-Path $Profilepowershellget)){
#     New-Item $Profilepowershellget -ItemType Directory
# }

# $Url = 'https://dist.nuget.org/win-x86-commandline/v5.1.0/nuget.exe'
# $OutputFile =  "$Profilepowershellget\nuget.exe"
# $StartTime = Get-Date

# $wc = New-Object System.Net.WebClient
# $wc.DownloadFile($Url, $OutputFile)

# Write-Output "Time taken: $((Get-Date).Subtract($StartTime).Seconds) second(s)"
# Unblock-File $OutputFile

$publishModuleSplat = @{
    Path              = ".\Corsinvest.ProxmoxVE.Api"
    #Name              = "Corsinvest.ProxmoxVE.Api"
    NuGetApiKey       = $ENV:nugetapikey
    Verbose           = $true
    Debug             = $true
    Force             = $true
    Repository        = "PSGallery"
    ErrorAction       = 'Stop'
    SkipAutomaticTags = $true
}

#"Files in module output:"
#Get-ChildItem $Destination -Recurse -File |
#    Select-Object -Expand FullName

#"Publishing [$Destination] to [$PSRepository]"
Publish-Module @publishModuleSplat
