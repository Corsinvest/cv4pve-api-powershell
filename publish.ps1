# SPDX-FileCopyrightText: 2022 Daniele Corsini <daniele.corsini@corsinvest.it>
# SPDX-FileCopyrightText: Copyright Corsinvest Srl
# SPDX-License-Identifier: GPL-3.0-only

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
