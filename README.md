# cv4pve-api-powershell

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/Corsinvest.ProxmoxVE.Api)](https://www.powershellgallery.com/packages/Corsinvest.ProxmoxVE.Api/)
![download](https://img.shields.io/powershellgallery/dt/Corsinvest.ProxmoxVE.Api)

[ProxmoxVE Api](https://pve.proxmox.com/pve-docs/api-viewer/)

[PowerShell Gallery](https://www.powershellgallery.com/packages/Corsinvest.ProxmoxVE.Api/)

```text
    ______                _                      __
   / ____/___  __________(_)___ _   _____  _____/ /_
  / /   / __ \/ ___/ ___/ / __ \ | / / _ \/ ___/ __/
 / /___/ /_/ / /  (__  ) / / / / |/ /  __(__  ) /_
 \____/\____/_/  /____/_/_/ /_/|___/\___/____/\__/

PowerShell for Proxmox VE         (Made in Italy)

cv4pve-api-powershell is a part of suite cv4pve.
For more information visit https://www.corsinvest.it/cv4pve
```

## 📰 Copyright

Copyright: Corsinvest Srl
For licensing details please visit [LICENSE](LICENSE)

## 🦺 Commercial Support

This software is part of a suite of tools called cv4pve. If you want commercial support, visit the [site](https://www.corsinvest.it/cv4pve)

## Introduction

The `cv4pve-api-powershell` module enables system administrators and developers to manage and automate Proxmox VE environments using PowerShell.

It provides a comprehensive set of cmdlets that wrap the Proxmox REST API, allowing operations such as VM and container management, node monitoring, backup handling, and storage inspection—all from PowerShell.

This module serves as the **PowerCLI equivalent for Proxmox VE**:
- While PowerCLI facilitates VMware vSphere automation via PowerShell,
- `cv4pve-api-powershell` offers similar capabilities for Proxmox VE environments.

![PowerShell for Proxmox VE](https://raw.githubusercontent.com/Corsinvest/cv4pve-api-powershell/master/images/powershell.png)

this is a CmdLet for PowerShell to manage Proxmox VE.

## 🚀 Main features

* Easy to learn
* Set ResponseType json, png, extjs, html, text
* Full class and method generated from documentation (about client)
* Comment any method and parameters
* Parameters indexed eg [n] is structured in array index and value
* Return data Proxmox VE
* Return result class more information PveResponse
  * Request
  * Response
  * Status
* Utility
  * ConvertFrom-PveUnixTime
  * Wait-PveTaskIsFinish
  * Get-PveTaskIsRunning
  * Build-PveDocumentation
  * Get-PveVm (from id or name)
  * Unlock-PveVm (from id or name)
  * Start-PveVm (from id or name)
  * Stop-PveVm (from id or name)
  * Suspend-PveVm (from id or name)
  * Resume-PveVm (from id or name)
  * Reset-PveVm (from id or name)
  * Get-PveNodeMonitoring (Get rrddata from Node)
  * Get-PveQemuMonitoring (Get rrddata from Qemu)
  * Get-PveLxcMonitoring (Get rrddata from Lxc)
  * And More
* Method direct access using Invoke-PveRestApi return PveResponse
* Connect-PveCluster accept multiple hosts for HA
* Completely written in PowerShell
* Use native api REST Proxmox VE
* Independent os (Windows, Linux, Macosx)
* Installation from PowerShellGallery or download file
* Not require installation in Proxmox VE
* Execute out side Proxmox VE
* Open Source
* Form Proxmox VE 6.2 support Api Token for user
* Invoke-PveSpice enter Spice VM
* Login with One-time password for Two-factor authentication

## 📙 Documentation

[Documentation HTML](https://raw.githack.com/Corsinvest/cv4pve-api-powershell/master/doc/index.html)

[Documentation Markdown](https://github.com/Corsinvest/cv4pve-api-powershell/blob/master/doc/markdown/about_cv4pve-api-powershell.md)

## Tutorial

[Tutorial interactive in VSCode notebook](https://tinyurl.com/cv4pve-api-pwsh-learn)

## Video
<a href="https://asciinema.org/a/656606" target="_blank"><img src="https://asciinema.org/a/656606.svg" /></a>

## Requirement

Minimum version requirement for Powershell is 6.0

## Installation

Install [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell) in your system.

### From PowerShell Gallery

Open PowerShell and install module form [gallery](https://www.powershellgallery.com/)

```ps
PS /home/frank> Install-Module -Name Corsinvest.ProxmoxVE.Api
```

### Manual

Download folder Corsinvest.ProxmoxVE.Api and copy in path module

```ps
# show path module
PS /home/frank> [Environment]::GetEnvironmentVariable("PSModulePath")
```

## Api token

From version 6.2 of Proxmox VE is possible to use [Api token](https://pve.proxmox.com/pve-docs/pveum-plain.html).
This feature permit execute Api without using user and password.
If using **Privilege Separation** when create api token remember specify in permission.
Format USER@REALM!TOKENID=UUID

## Connect to cluster

For connection use the function Connect-PveCluster. This function generate a Ticket object that refer a PveTicket class.
The first connection saved ticket data in the variable $Global:PveTicketLast. In the various functions, the -PveTicket parameter is the connection reference ticket. If not specified will be used $Global:PveTicketLast.

## PveTicket Class

This class contain data after connection and login Connect-PveCluster

```ps
class PveTicket {
    [string] $HostName = ''
    [int] $Port = 8006
    [bool] $SkipCertificateCheck = $true
    [string] $Ticket = ''
    [string] $CSRFPreventionToken = ''
    [string] $ApiToken = ''
}
```

## PveResponse Class

This class contain data after execution any command

```ps
class PveResponse {
    #Contain real response of Proxmox VE
    #Is converted in object Json response
    [PSCustomObject] $Response
    [int] $StatusCode = 200
    [string] $ReasonPhrase
    [bool] $IsSuccessStatusCode = $true
    [string] $RequestResource
    [hashtable] $Parameters
    [string] $Method
    [string] $ResponseType

    [bool] ResponseInError() { return $null -ne $this.Response.error }
    [PSCustomObject] ToTable() { return $this.Response.data | Format-Table -Property * }
    [PSCustomObject] ToData() { return $this.Response.data }
    [void] ToCsv([string] $filename) { $this.Response.data | Export-Csv $filename }
    [void] ToGridView() { $this.Response.data | Out-GridView -Title "View Result Data" }
}
```

## Usage

Example Connect and get version

```ps
#Connection to cluster user and password
PS /home/frank> Connect-PveCluster -HostsAndPorts 192.168.190.191:8006,192.168.190.192 -SkipCertificateCheck
PowerShell credential request
Proxmox VE Username and password, username formatted as user@pam, user@pve, user@yourdomain or user (default domain pam).
User: test
Password for user test: ****

#return Ticket, default set $Global:PveTicketLast
#this is useful when connections to multiple clusters are needed use parameter -SkipRefreshPveTicketLast
HostName             : 192.168.190.191
Port                 : 8006
SkipCertificateCheck : True
Ticket               : PVE:test@pam:5EFF3CCA::iXhSNb5NTgNUYznf93mBOhj8pqYvAXoecKBHCXa3coYwBWjsWO/x8TO1gIDX0yz9nfHuvY3alJ0+Ew5AouOTZlZl3NODO9Cp4Hl87qnzhsz4wvoYEzvS1NUOTBekt+yAa68jdbhP
                        OzhOd8ozEEQIK7Fw2lOSa0qBFUTZRoMtnCnlsjk/Nn3kNEnZrkHXRGm46fA+asprvr0nslLxJgPGh94Xxd6jpNDj+xJnp9u6W3PxiAojM9g7IRurbp7ZCJvAgHbA9FqxibpgjaVm4NCd8LdkLDgCROxgYCjI3eR
                        gjkDvu1P7lLjK9JxSzqnCWWD739DT3P3bW+Ac3SyVqTf8sw==
CSRFPreventionToken  : 5EFF3CCA:Cu0NuFiL6CkhFdha2V+HHigMQPk

#Connection to cluster using Api Token
PS /home/frank> Connect-PveCluster -HostsAndPorts 192.168.190.191:8006,192.168.190.192 -SkipCertificateCheck -ApiToken root@pam!qqqqqq=8a8c1cd4-d373-43f1-b366-05ce4cb8061f
HostName             : 192.168.190.191
Port                 : 8006
SkipCertificateCheck : True
Ticket               :
CSRFPreventionToken  :
ApiToken             : root@pam!qqqqqq=8a8c1cd4-d373-43f1-b366-05ce4cb8061f

#For disable output call Connect-PveCluster > $null

#Get version
PS /home/frank> $ret = Get-PveVersion

#$ret return a class PveResponse

#Show data
PS /home/frank> $ret.Response.data
repoid   release keyboard version
------   ------- -------- -------
d0ec33c6 15      it       5.4

#Show data 2
PS /home/frank> $ret.ToTable()
repoid   release keyboard version
------   ------- -------- -------
d0ec33c6 15      it       5.4
```

Get snapshots of vm

```ps
PS /home/frank> (Get-PveNodesQemuSnapshot -Node pve1 -Vmid 100).ToTable()

vmstate name                         parent                       description       snaptime
------- ----                         ------                       -----------       --------
      0 autowin10service200221183059 autowin10service200220183012 cv4pve-autosnap 1582306261
      0 autowin10service200220183012 autowin10service200219183012 cv4pve-autosnap 1582219813
      0 autowin10service200224183012 autowin10service200223183014 cv4pve-autosnap 1582565413
      0 autowin10service200223183014 autowin10service200222183019 cv4pve-autosnap 1582479015
      0 autowin10service200215183012 autowin10service200214183012 cv4pve-autosnap 1581787814
      0 autowin10service200216183017 autowin10service200215183012 cv4pve-autosnap 1581874219
      0 autowin10service200218183010 autowin10service200216183017 cv4pve-autosnap 1582047011
      0 autowin10service200219183012 autowin10service200218183010 cv4pve-autosnap 1582133413
      0 autowin10service200214183012                              cv4pve-autosnap 1581701413
      0 autowin10service200222183019 autowin10service200221183059 cv4pve-autosnap 1582392621
        current                      autowin10service200224183012 You are here!
```

Other method

```ps
(Get-PveVm -VmIdOrName 100 | Get-PveNodesQemuSnapshot).ToTable()
vmstate name                         parent                       description       snaptime
------- ----                         ------                       -----------       --------
      0 autowin10service200221183059 autowin10service200220183012 cv4pve-autosnap 1582306261
      0 autowin10service200220183012 autowin10service200219183012 cv4pve-autosnap 1582219813
      0 autowin10service200224183012 autowin10service200223183014 cv4pve-autosnap 1582565413
      0 autowin10service200223183014 autowin10service200222183019 cv4pve-autosnap 1582479015
      0 autowin10service200215183012 autowin10service200214183012 cv4pve-autosnap 1581787814
      0 autowin10service200216183017 autowin10service200215183012 cv4pve-autosnap 1581874219
      0 autowin10service200218183010 autowin10service200216183017 cv4pve-autosnap 1582047011
      0 autowin10service200219183012 autowin10service200218183010 cv4pve-autosnap 1582133413
      0 autowin10service200214183012                              cv4pve-autosnap 1581701413
      0 autowin10service200222183019 autowin10service200221183059 cv4pve-autosnap 1582392621
        current                      autowin10service200224183012 You are here!
```

## Indexed data parameter

if you need to pass indexed parameters e.g. (-ScsiN, -IdeN, -NetN) you must use the following way:

```powershell
#create variabile
$networkConfig = @{ 1 = [uri]::EscapeDataString("model=virtio,bridge=vmbr0") }
$storageConfig = @{ 1 = 'ssdpool:32' }
$bootableIso = @{ 1 = 'local:iso/ubuntu.iso' }

#use variable
New-PveNodesQemu -Node $node -Vmid 105 -Memory 2048 -ScsiN $storageConfig -IdeN $bootableIso -NetN $networkConfig
```

The **[uri]::EscapeDataString** escape value to pass.

## Build documentation

For build documentation use command **Build-PveDocumentation**

This command accept **TemplateFile** parameter is a template for generate documentation.
The default [file](https://raw.githubusercontent.com/corsinvest/cv4pve-api-powershell/master/help-out-html.ps1).
