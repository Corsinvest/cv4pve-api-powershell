# This file is part of the cv4pve-api-pwsh https://github.com/Corsinvest/cv4pve-api-pwsh,
#
# This source file is available under two different licenses:
# - GNU General Public License version 3 (GPLv3)
# - Corsinvest Enterprise License (CEL)
# Full copyright and license information is available in
# LICENSE.md which is distributed with this source code.
#
# Copyright (C) 2020 Corsinvest Srl	GPLv3 and CEL

class PveValidVmId : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        return (Get-PveClusterResources -Type vm).Response.data | Select-Object -ExpandProperty vmid
    }
}

class PveValidVmName : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        return (Get-PveClusterResources -Type vm).Response.data | Where-Object {$_.status -ne 'unknown' } | Select-Object -ExpandProperty name
    }
}

class PveValidNode : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        return (Get-PveClusterResources -Type node).Response.data | Select-Object -ExpandProperty node
    }
}

class PveTicket {
    [string] $HostName = ''
    [int] $Port = 8006
    [bool] $SkipCertificateCheck = $true
    [string] $Ticket = ''
    [string] $CSRFPreventionToken = ''
    [string] $ApiToken = ''
}

class PveResponse {
    [PSCustomObject] $Response
    [int] $StatusCode = 200
    [string] $ReasonPhrase
    [bool] $IsSuccessStatusCode = $true
    [string] $RequestResource
    [hashtable] $Parameters
    [string] $Method
    [string] $ResponseType

    [bool] ResponseInError() { return $null -ne $this.Response.error }

    [PSCustomObject] ToTable() { return $this.Response.data | Format-Table }

    [PSCustomObject] GetData() { return $this.Response.data }

    [void] ToCsv([string] $filename) { $this.Response.data | Export-Csv $filename }
}

$Global:PveTicketLast = $null

##########
## CORE ##
##########
#region Core
function Connect-PveCluster {
    <#
.DESCRIPTION
Connect to Proxmox VE Cluster.
.PARAMETER HostsAndPorts
Host and ports
Format 10.1.1.90:8006,10.1.1.91:8006,10.1.1.92:8006.
.PARAMETER SkipCertificateCheck
Skips certificate validation checks.
.PARAMETER Credentials
Username and password, username formatted as user@pam, user@pve, user@yourdomain or user (default domain pam).
.PARAMETER SkipRefreshPveTicketLast
Skip refresh PveTicket Last global variable
.EXAMPLE
$PveTicket = Connect-PveCluster -HostsAndPorts 192.168.128.115 -Credentials (Get-Credential -Username 'root').
.OUTPUTS
PveTicket. Return ticket connection.
#>
    [CmdletBinding()]
    [OutputType([PveTicket])]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$HostsAndPorts,

        [pscredential]$Credentials,

        [string]$ApiToken,

        [switch]$SkipCertificateCheck,

        [switch]$SkipRefreshPveTicketLast
    )

    process {
        $hostName = '';
        $port = 0;

        #find host and port
        foreach ($hostAndPort in $HostsAndPorts) {
            $data = $hostAndPort.Split(':');
            $hostTmp = $data[0];
            $portTmp = 8006;

            if ($data.Length -eq 2 ) { [int32]::TryParse($data[1] , [ref]$portTmp) | Out-Null }

            if (Test-Connection -Ping $hostTmp -BufferSize 16 -Count 1 -ea 0 -quiet) {
                $hostName = $hostTmp;
                $port = $portTmp;
                break;
            }
        }

        if ([string]::IsNullOrWhiteSpace($hostName)) { throw 'Host not valid' }
        if ($port -le 0) { throw 'Port not valid' }

        $pveTicket = [PveTicket]::new()
        $pveTicket.HostName = $hostName
        $pveTicket.Port = $port
        $pveTicket.SkipCertificateCheck = $SkipCertificateCheck
        $pveTicket.ApiToken = $ApiToken

        if (-not $ApiToken)
        {
            if (-not $Credentials) {
                $Credentials = Get-Credential -Message 'Proxmox VE Username and password, username formated as user@pam, user@pve, user@yourdomain or user (default domain pam).'
            }

            #not exists domain set default pam
            $userName = $Credentials.UserName
            if ($userName.IndexOf('@') -lt 0) { $userName += '@pam' }

            $parameters = @{
                username = $userName
                password = $Credentials.GetNetworkCredential().Password
            }

            $response = Invoke-PveRestApi -PveTicket $pveTicket -Method Create -Resource '/access/ticket' -Parameters $parameters

            #erro response
            if (!$response.IsSuccessStatusCode -or $response.StatusCode -le 0) {
                throw $response.ReasonPhrase
            }

            $pveTicket.Ticket = $response.Response.data.ticket
            $pveTicket.CSRFPreventionToken = $response.Response.data.CSRFPreventionToken
        }

        #last ticket connection
        if ($null -eq $Global:PveTicketLast -or (-not $SkipRefreshPveTicketLast)) {
            $Global:PveTicketLast = $pveTicket
        }

        return $pveTicket
    }
}

function Invoke-PveRestApi {
    <#
.DESCRIPTION
Invoke Proxmox VE Rest API
.PARAMETER PveTicket
Ticket data
.PARAMETER Resource
Resource Request
.PARAMETER Method
Method request
.PARAMETER ResponseType
Type request
.PARAMETER Parameters
Parameters request
.EXAMPLE
$PveTicket = Connect-PveCluster -HostsAndPorts '192.168.128.115' -Credentials (Get-Credential -Username 'root').
(Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource '/version').data

data
----
@{version=5.4; release=15; repoid=d0ec33c6; keyboard=it}
.NOTES
This must be used before any other cmdlets are used
.OUTPUTS
Return object request
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory)]
        [string]$Resource,

        [ValidateNotNullOrEmpty()]
        [ValidateSet('Get', 'Set', 'Create', 'Delete')]
        [string]$Method = 'Get',

        [Parameter()]
        [ValidateSet('Json', 'Png')]
        [string]$ResponseType = 'Json',

        [ValidateNotNullOrEmpty()]
        [string]$ApiBase = '/api2/json',

        [hashtable]$Parameters
    )

    process {
        #use last ticket
        if ($null -eq $PveTicket) { $PveTicket = $Global:PveTicketLast }

        #web method
        $restMethod = @{
            Get    = 'Get'
            Set    = 'Put'
            Create = 'Post'
            Delete = 'Delete'
        }[$Method]

        $cookie = New-Object System.Net.Cookie -Property @{
            Name   = 'PVEAuthCookie'
            Path   = '/'
            Domain = $PveTicket.HostName
            Value  = $PveTicket.Ticket
        }

        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $session.cookies.add($cookie)

        $query = ''
        if ($Parameters -and $Parameters.Count -gt 0) {
            Write-Debug 'Parameters:'
            $Parameters.keys | ForEach-Object { Write-Debug "$_ => $($Parameters[$_])" }

            #fix switch parameter from bool to 1/0
            $Parameters.keys | ForEach-Object {
                if ($Parameters[$_] -is [switch]) {
                    $Parameters[$_] = $Parameters[$_] ? 1 : 0
                }
            }

            $query = '?' + (($Parameters.Keys | ForEach-Object { "$_=$($Parameters[$_])" }) -join '&')
        }

        $response = New-Object PveResponse -Property @{
            Method          = $restMethod
            Parameters      = $Parameters
            ResponseType    = $ResponseType
            RequestResource = $Resource
        }

        $headers = @{ CSRFPreventionToken = $PveTicket.CSRFPreventionToken  }
        if($PveTicket.ApiToken -ne '') { $headers.Authorization = 'PVEAPIToken ' + $PveTicket.ApiToken }

        $params = @{
            Uri                  = "https://$($PveTicket.HostName):$($PveTicket.Port)$ApiBase$Resource$query"
            Method               = $restMethod
            WebSession           = $session
            SkipCertificateCheck = $PveTicket.SkipCertificateCheck
            Headers              = $headers
        }

        Write-Debug ($params | Format-List | Out-String)

        #body parameters
        if ($Parameters -and $Parameters.Count -gt 0 -and $('Post', 'Put').IndexOf($restMethod) -ge 0) {
            $params['body'] = $Parameters
        }

        try {
            Write-Debug "PveRestApi Method: $($params.Method) - Uri: $($params.Uri)"
            $response.Response = Invoke-RestMethod @params
        }
        catch {
            $response.StatusCode = $_.Exception.Response.StatusCode
            $response.ReasonPhrase = $_.Exception.Response.ReasonPhrase
            $response.IsSuccessStatusCode = $_.Exception.Response.IsSuccessStatusCode
            if ($response.StatusCode -eq 0) {
                $response.ReasonPhrase = $_.Exception.Message
                $response.StatusCode = -1
            }
        }

        Write-Debug "PveRestApi Response: $($response.Response | Format-Table | Out-String)"
        Write-Debug "PveRestApi IsSuccessStatusCode: $($response.IsSuccessStatusCode)"
        Write-Debug "PveRestApi StatusCode: $($response.StatusCode)"
        Write-Debug "PveRestApi ReasonPhrase: $($response.ReasonPhrase)"

        return $response
    }
}
#endregion

#############
## UTILITY ##
#############

#region Utility
Function Build-PveDocumentation {
    <#
.DESCRIPTION
Build documentation
.PARAMETER TemplateFile
Template file for generation documentation
.PARAMETER OutputFile
Output file
#>
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter()]
        [string] $TemplateFile = 'https://raw.githubusercontent.com/corsinvest/cv4pve-api-pwsh/master/cv4pve-api-pwsh-help-out-html.ps1',

        [Parameter(Mandatory)]
        [string] $OutputFile
    )

    process {
        $progress = 0
        $commands = (Get-Command -module 'Corsinvest.ProxmoxVE.Api' -CommandType Function) | Sort-Object #| Select-Object -first 10
        $totProgress = $commands.Length
        $data = [System.Collections.ArrayList]::new()
        foreach ($item in $commands) {
            $progress++
            Write-Progress -Activity "Elaborate command $($item.Name)" `
                            -CurrentOperation "Completed $($progress) of $totProgress." `
                            -PercentComplete $(($progress / $totProgress) * 100)

            #help
            $help = Get-Help $item.Name -Full

            #alias
            $alias = Get-Alias -definition $item.Name -ErrorAction SilentlyContinue
            if ($alias) { $help | Add-Member Alias $alias }

            # related links and assign them to a links hashtable.
            if (($help.relatedLinks | Out-String).Trim().Length -gt 0) {
                $links = $help.relatedLinks.navigationLink | ForEach-Object {
                    if ($_.uri) { @{name = $_.uri; link = $_.uri; target = '_blank' } }
                    if ($_.linkText) { @{name = $_.linkText; link = "#$($_.linkText)"; cssClass = 'psLink'; target = '_top' } }
                }
                $help | Add-Member Links $links
            }

            #parameter aliases to the object.
            foreach ($parameter in $help.parameters.parameter ) {
                $paramAliases = ($cmdHelp.parameters.values | Where-Object name -like $parameter.name | Select-Object aliases).Aliases
                if ($paramAliases) { $parameter | Add-Member Aliases "$($paramAliases -join ', ')" -Force }
            }

            $data.Add($help) > $null
        }

        $data = $data | Where-Object { $_.Name }
        $totProgress = $data.Count

        #template
        $content = (($TemplateFile -as [System.Uri]).Scheme -match '[http|https]') ?
                    (Invoke-WebRequest $TemplateFile).Content :
                    (Get-Content $TemplateFile -Raw -Force)

        #generate help
        Invoke-Expression $content > $OutputFile
    }
}

#region COnvert Time Windows/Unix
function ConvertTo-PveUnixTime {
<#
.SYNOPSIS
Convert datetime objects to UNIX time.
.DESCRIPTION
Convert System.DateTime objects to UNIX time.
.PARAMETER Date
Date time
.OUTPUTS
[Int32]. Return Unix Time.
#>
    [CmdletBinding()]
    [OutputType([Int32])]
    param (
        [Parameter(Mandatory,Position = 0,ValueFromPipeline )]
        [DateTime]$Date
    )

    process {
        [Int32] ($Date.ToUniversalTime() - (Get-Date '1/1/1970').ToUniversalTime()).TotalSeconds
    }
}

Function ConvertFrom-PveUnixTime {
    <#
.DESCRIPTION
Convert Unix Time in DateTime
.PARAMETER Time
Unix Time
.OUTPUTS
DateTime. Return DateTime from Unix Time.
#>
    [CmdletBinding()]
    [OutputType([DateTime])]
    param (
        [Parameter(Position = 0, Mandatory)]
        [long] $Time
    )

    return (New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0).ToLocalTime().AddSeconds($Time)
}
#endregion

Function Enter-PveSpice {
    <#
.DESCRIPTION
Enter Spice VM.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER VmIdOrName
The (unique) ID or Name of the VM.
.PARAMETER Proxy
Proxy host.
.PARAMETER RemoteViewer
Path of Spice remove viewer.
* Linux /usr/bin/remote-viewer
* Windows C:\Program Files\VirtViewer v?.?-???\bin\remote-viewer.exe
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VmIdOrName,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$RemoteViewer
    )

    process {
        $vm = Find-PveVM -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') {
            $node = $vm.node
            $vmid = $vm.vmid

            $parameters = @{ proxy = $null -eq $PveTicket ? $PveTicketLast.HostName : $PveTicket.HostName }

            $ret = Invoke-PveRestApi -PveTicket $PveTicket -Method Create -ApiBase "/api2" -Resource "/spiceconfig/nodes/$node/qemu/$vmid/spiceproxy" -Parameters $parameters

            Write-Debug "======================================="
            Write-Debug "SPICE Proxy Configuration"
            Write-Debug "======================================="
            Write-Debug $ret
            Write-Debug "======================================="

            $tmp = New-TemporaryFile
            $ret.Response | Out-File $tmp.FullName

            Start-Process -FilePath $RemoteViewer -Args $tmp.FullName
        }
    }
}

#region Task
function Wait-PveTaskIsFinish {
    <#
.DESCRIPTION
Get task is running.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Upid
Upid task e.g UPID:pve1:00004A1A:0964214C:5EECEF11:vzdump:134:root@pam:
.PARAMETER Wait
Millisecond wait next check
.PARAMETER Timeout
Millisecond timeout
.OUTPUTS
Bool. Return tas is running.
#>
    [OutputType([bool])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Upid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Wait = 500,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Timeout = 10000
    )

    process {
        $isRunning = $true;
        if ($wait -le 0) { $wait = 500; }
        if ($timeOut -lt $wait) { $timeOut = $wait + 5000; }
        $timeStart = [DateTime]::Now
        $waitTime = $timeStart

        while ($isRunning -and ($timeStart - [DateTime]::Now).Milliseconds -lt $timeOut) {
            $now = [DateTime]::Now
            if (($now - $waitTime).TotalMilliseconds -ge $wait) {
                $waitTime = $now;
                $isRunning = Get-PveTaskIsRunning -PveTicket $PveTicket -Upid $Upid
            }
        }

        #check timeout
        return ($timeStart - [DateTime]::Now).Milliseconds -lt $timeOut
    }
}

function Get-PveTaskIsRunning {
    <#
.DESCRIPTION
Get task is running.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Upid
Upid task e.g UPID:pve1:00004A1A:0964214C:5EECEF11:vzdump:134:root@pam:
.OUTPUTS
Bool. Return tas is running.
#>
    [OutputType([bool])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Upid
    )

    process {
        return (Get-PveNodesTasks -PveTicket $PveTicket -Node $Upid.Split(':')[1] -Upid $Upid).Response.data -eq 'running'
    }
}
#endregion

function Find-PveVM {
    <#
.DESCRIPTION
Find VM/CT from id or name.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER VmIdOrName
The (unique) ID or Name of the VM.
.OUTPUTS
PSCustomObject. Return Vm Data.
#>
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VmIdOrName
    )

    process {
        return (Get-PveClusterResources -PveTicket $PveTicket -Type vm).Response.data |
        Where-Object { $_.vmid -eq $VmIdOrName -or $_.name -eq $VmIdOrName }
    }
}

function Unlock-PveVM {
    <#
.DESCRIPTION
Unlock VM.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER VmIdOrName
The (unique) ID or Name of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VmIdOrName
    )

    process {
        $vm = Find-PveVM -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | Set-PveNodesQemuConfig -PveTicket $PveTicket -Delete 'lock' -Skiplock }
        ElseIf (vm.type -eq 'lxc') { return $vm | Set-PveNodesLxcConfig -PveTicket $PveTicket -Delete 'lock' }
    }
}

#region VM status
function Start-PveVM {
    <#
.DESCRIPTION
Start VM.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER VmIdOrName
The (unique) ID or Name of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VmIdOrName
    )

    process {
        $vm = Find-PveVM -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | New-PveNodesQemuStatusStart -PveTicket $PveTicket }
        ElseIf (vm.type -eq 'lxc') { return $vm | New-PveNodesLxcStatusStart -PveTicket $PveTicket }
    }
}

function Stop-PveVM {
    <#
.DESCRIPTION
Stop VM.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER VmIdOrName
The (unique) ID or Name of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VmIdOrName
    )

    process {
        $vm = Find-PveVM -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | New-PveNodesQemuStatusStop -PveTicket $PveTicket }
        ElseIf (vm.type -eq 'lxc') { return $vm | New-PveNodesLxcStatusStop -PveTicket $PveTicket }
    }
}

function Suspend-PveVM {
    <#
.DESCRIPTION
Suspend VM.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER VmIdOrName
The (unique) ID or Name of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VmIdOrName
    )

    process {
        $vm = Find-PveVM -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | New-PveNodesQemuStatusSuspend -PveTicket $PveTicket }
        ElseIf (vm.type -eq 'lxc') { return $vm | New-PveNodesLxcStatusSuspend -PveTicket $PveTicket }
    }
}

function Resume-PveVM {
    <#
.DESCRIPTION
Resume VM.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER VmIdOrName
The (unique) ID or Name of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VmIdOrName
    )

    process {
        $vm = Find-PveVM -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | New-PveNodesQemuStatusResume -PveTicket $PveTicket }
        ElseIf (vm.type -eq 'lxc') { return $vm | New-PveNodesLxcStatusResume -PveTicket $PveTicket }
    }
}

function Reset-PveVM {
    <#
.DESCRIPTION
Reset VM.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER VmIdOrName
The (unique) ID or Name of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VmIdOrName
    )

    process {
        $vm = Find-PveVM -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | New-PveNodesQemuStatusReset -PveTicket $PveTicket }
        ElseIf (vm.type -eq 'lxc') { throw "Lxc not implement reset!" }
    }
}
#endregion

#region Snapshot
function Get-PveVMSnapshots {
    <#
.DESCRIPTION
Get snapshots VM.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER VmIdOrName
The (unique) ID or Name of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VmIdOrName
    )

    process {
        $vm = Find-PveVM -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | Get-PveNodesQemuSnapshot -PveTicket $PveTicket }
        ElseIf (vm.type -eq 'lxc') { return $vm | Get-PveNodesLxcSnapshot -PveTicket $PveTicket }
    }
}

function New-PveVMSnapshot {
    <#
.DESCRIPTION
Create snapshot VM.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER VmIdOrName
The (unique) ID or Name of the VM.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Description
A textual description or comment.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VmIdOrName,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname
    )

    process {
        $vm = Find-PveVM -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | New-PveNodesQemuSnapshot -PveTicket $PveTicket -Snapname $Snapname -Description $Description }
        ElseIf (vm.type -eq 'lxc') { return $vm | New-PveNodesLxcSnapshot -PveTicket $PveTicket -Snapname $Snapname -Description $Description }
    }
}

function Remove-PveVMSnapshot {
    <#
.DESCRIPTION
Delete a VM snapshot.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER VmIdOrName
The (unique) ID or Name of the VM.
.PARAMETER Snapname
The name of the snapshot.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VmIdOrName,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname
    )

    process {
        $vm = Find-PveVM -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | Remove-PveNodesQemuSnapshot -PveTicket $PveTicket -Snapname $Snapname }
        ElseIf (vm.type -eq 'lxc') { return $vm | Remove-PveNodesLxcSnapshot -PveTicket $PveTicket -Snapname $Snapname }
    }
}

function Undo-PveVMSnapshot {
    <#
.DESCRIPTION
Rollback VM state to specified snapshot.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER VmIdOrName
The (unique) ID or Name of the VM.
.PARAMETER Snapname
The name of the snapshot.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VmIdOrName,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname
    )

    process {
        $vm = Find-PveVM -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | New-PveNodesQemuSnapshotRollback -PveTicket $PveTicket -Snapname $Snapname }
        ElseIf (vm.type -eq 'lxc') { return $vm | New-PveNodesLxcSnapshotRollback -PveTicket $PveTicket -Snapname $Snapname }
    }
}


#endregion
#endregion

###########
## ALIAS ##
###########

Set-Alias -Name Get-PveTasksStatus -Value Get-PveNodesTasksStatus

#QEMU
Set-Alias -Name Start-PveQemu -Value New-PveNodesQemuStatusStart
Set-Alias -Name Stop-PveQemu -Value New-PveNodesQemuStatusStop
Set-Alias -Name Suspend-PveQemu -Value New-PveNodesQemuStatusSuspend
Set-Alias -Name Resume-PveQemu -Value New-PveNodesQemuStatusResume
Set-Alias -Name Reset-PveQemu -Value New-PveNodesQemuStatusReset
#Set-Alias -Name Reboot-PveQemu -Value New-PveNodesQemuStatusReboot
#Set-Alias -Name Shutdown-PveQemu -Value New-PveNodesQemuStatusShutdown
Set-Alias -Name Move-PveQemu -Value New-PveNodesQemuMigrate
Set-Alias -Name New-PveQemu -Value New-PveNodesQemu
Set-Alias -Name Copy-PveQemu -Value New-PveNodesQemuClone

#LXC
Set-Alias -Name Start-PveLxc -Value New-PveNodesLxcStatusStart
Set-Alias -Name Stop-PveLxc -Value New-PveNodesLxcStatusStop
Set-Alias -Name Suspend-PveLxc -Value New-PveNodesLxcStatusSuspend
Set-Alias -Name Resume-PveLxc -Value New-PveNodesLxcStatusResume
#Set-Alias -Name Start-PveLxc -Value New-PveNodesLxcStatusReboot
#Set-Alias -Name Start-PveLxc -Value New-PveNodesLxcStatusShutdown
Set-Alias -Name Move-PveLxc -Value New-PveNodesLxcMigrate
Set-Alias -Name Copy-PveLxc -Value New-PveNodesLxcClone



#NODE
Set-Alias -Name Update-PveNode -Value New-PveNodesAptUpdate
Set-Alias -Name Backup-PveVzdump -Value New-PveNodesVzdump

#MISC
Set-Alias -Name Get-PveTop -Value Get-PveClusterResources


#########
## API ##
#########


function Get-PveCluster
{
<#
.DESCRIPTION
Cluster index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster"
    }
}

function Get-PveClusterReplication
{
<#
.DESCRIPTION
List replication jobs.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/replication"
    }
}

function New-PveClusterReplication
{
<#
.DESCRIPTION
Create a new replication job
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
Description.
.PARAMETER Disable
Flag to disable/deactivate the entry.
.PARAMETER Id
Replication Job ID. The ID is composed of a Guest ID and a job number, separated by a hyphen, i.e. '<GUEST>-<JOBNUM>'.
.PARAMETER Rate
Rate limit in mbps (megabytes per second) as floating point number.
.PARAMETER RemoveJob
Mark the replication job for removal. The job will remove all local replication snapshots. When set to 'full', it also tries to remove replicated volumes on the target. The job then removes itself from the configuration file.
.PARAMETER Schedule
Storage replication schedule. The format is a subset of `systemd` calendar events.
.PARAMETER Source
Source of the replication.
.PARAMETER Target
Target node.
.PARAMETER Type
Section type.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Disable,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Rate,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('local','full')]
        [string]$RemoveJob,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Schedule,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Source,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Target,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('local')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Disable']) { $parameters['disable'] = $Disable }
        if($PSBoundParameters['Id']) { $parameters['id'] = $Id }
        if($PSBoundParameters['Rate']) { $parameters['rate'] = $Rate }
        if($PSBoundParameters['RemoveJob']) { $parameters['remove_job'] = $RemoveJob }
        if($PSBoundParameters['Schedule']) { $parameters['schedule'] = $Schedule }
        if($PSBoundParameters['Source']) { $parameters['source'] = $Source }
        if($PSBoundParameters['Target']) { $parameters['target'] = $Target }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/replication" -Parameters $parameters
    }
}

function Remove-PveClusterReplication
{
<#
.DESCRIPTION
Mark replication job for removal.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Force
Will remove the jobconfig entry, but will not cleanup.
.PARAMETER Id
Replication Job ID. The ID is composed of a Guest ID and a job number, separated by a hyphen, i.e. '<GUEST>-<JOBNUM>'.
.PARAMETER Keep
Keep replicated data at target (do not remove).
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Keep
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }
        if($PSBoundParameters['Keep']) { $parameters['keep'] = $Keep }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/replication/$Id" -Parameters $parameters
    }
}

function Get-PveClusterReplicationIdx
{
<#
.DESCRIPTION
Read replication job configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Id
Replication Job ID. The ID is composed of a Guest ID and a job number, separated by a hyphen, i.e. '<GUEST>-<JOBNUM>'.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/replication/$Id"
    }
}

function Set-PveClusterReplication
{
<#
.DESCRIPTION
Update replication job configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
Description.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Disable
Flag to disable/deactivate the entry.
.PARAMETER Id
Replication Job ID. The ID is composed of a Guest ID and a job number, separated by a hyphen, i.e. '<GUEST>-<JOBNUM>'.
.PARAMETER Rate
Rate limit in mbps (megabytes per second) as floating point number.
.PARAMETER RemoveJob
Mark the replication job for removal. The job will remove all local replication snapshots. When set to 'full', it also tries to remove replicated volumes on the target. The job then removes itself from the configuration file.
.PARAMETER Schedule
Storage replication schedule. The format is a subset of `systemd` calendar events.
.PARAMETER Source
Source of the replication.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Disable,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Rate,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('local','full')]
        [string]$RemoveJob,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Schedule,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Source
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Disable']) { $parameters['disable'] = $Disable }
        if($PSBoundParameters['Rate']) { $parameters['rate'] = $Rate }
        if($PSBoundParameters['RemoveJob']) { $parameters['remove_job'] = $RemoveJob }
        if($PSBoundParameters['Schedule']) { $parameters['schedule'] = $Schedule }
        if($PSBoundParameters['Source']) { $parameters['source'] = $Source }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/replication/$Id" -Parameters $parameters
    }
}

function Get-PveClusterConfig
{
<#
.DESCRIPTION
Directory index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/config"
    }
}

function New-PveClusterConfig
{
<#
.DESCRIPTION
Generate new cluster configuration. If no links given, default to local IP address as link0.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Clustername
The name of the cluster.
.PARAMETER LinkN
Address and priority information of a single corosync link. (up to 8 links supported; link0..link7)
.PARAMETER Nodeid
Node id for this node.
.PARAMETER Votes
Number of votes for this node.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Clustername,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$LinkN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Nodeid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Votes
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Clustername']) { $parameters['clustername'] = $Clustername }
        if($PSBoundParameters['Nodeid']) { $parameters['nodeid'] = $Nodeid }
        if($PSBoundParameters['Votes']) { $parameters['votes'] = $Votes }

        if($PSBoundParameters['LinkN']) { $LinkN.keys | ForEach-Object { $parameters['link' + $_] = $LinkN[$_] } }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/config" -Parameters $parameters
    }
}

function Get-PveClusterConfigApiversion
{
<#
.DESCRIPTION
Return the version of the cluster join API available on this node.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/config/apiversion"
    }
}

function Get-PveClusterConfigNodes
{
<#
.DESCRIPTION
Corosync node list.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/config/nodes"
    }
}

function Remove-PveClusterConfigNodes
{
<#
.DESCRIPTION
Removes a node from the cluster configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/config/nodes/$Node"
    }
}

function New-PveClusterConfigNodes
{
<#
.DESCRIPTION
Adds a node to the cluster configuration. This call is for internal use.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Apiversion
The JOIN_API_VERSION of the new node.
.PARAMETER Force
Do not throw error if node already exists.
.PARAMETER LinkN
Address and priority information of a single corosync link. (up to 8 links supported; link0..link7)
.PARAMETER NewNodeIp
IP Address of node to add. Used as fallback if no links are given.
.PARAMETER Node
The cluster node name.
.PARAMETER Nodeid
Node id for this node.
.PARAMETER Votes
Number of votes for this node
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Apiversion,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$LinkN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$NewNodeIp,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Nodeid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Votes
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Apiversion']) { $parameters['apiversion'] = $Apiversion }
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }
        if($PSBoundParameters['NewNodeIp']) { $parameters['new_node_ip'] = $NewNodeIp }
        if($PSBoundParameters['Nodeid']) { $parameters['nodeid'] = $Nodeid }
        if($PSBoundParameters['Votes']) { $parameters['votes'] = $Votes }

        if($PSBoundParameters['LinkN']) { $LinkN.keys | ForEach-Object { $parameters['link' + $_] = $LinkN[$_] } }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/config/nodes/$Node" -Parameters $parameters
    }
}

function Get-PveClusterConfigJoin
{
<#
.DESCRIPTION
Get information needed to join this cluster over the connected node.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The node for which the joinee gets the nodeinfo.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Node']) { $parameters['node'] = $Node }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/config/join" -Parameters $parameters
    }
}

function New-PveClusterConfigJoin
{
<#
.DESCRIPTION
Joins this node into an existing cluster. If no links are given, default to IP resolved by node's hostname on single link (fallback fails for clusters with multiple links).
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Fingerprint
Certificate SHA 256 fingerprint.
.PARAMETER Force
Do not throw error if node already exists.
.PARAMETER Hostname
Hostname (or IP) of an existing cluster member.
.PARAMETER LinkN
Address and priority information of a single corosync link. (up to 8 links supported; link0..link7)
.PARAMETER Nodeid
Node id for this node.
.PARAMETER Password
Superuser (root) password of peer node.
.PARAMETER Votes
Number of votes for this node
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Fingerprint,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hostname,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$LinkN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Nodeid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Password,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Votes
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Fingerprint']) { $parameters['fingerprint'] = $Fingerprint }
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }
        if($PSBoundParameters['Hostname']) { $parameters['hostname'] = $Hostname }
        if($PSBoundParameters['Nodeid']) { $parameters['nodeid'] = $Nodeid }
        if($PSBoundParameters['Password']) { $parameters['password'] = (ConvertFrom-SecureString -SecureString $Password -AsPlainText) }
        if($PSBoundParameters['Votes']) { $parameters['votes'] = $Votes }

        if($PSBoundParameters['LinkN']) { $LinkN.keys | ForEach-Object { $parameters['link' + $_] = $LinkN[$_] } }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/config/join" -Parameters $parameters
    }
}

function Get-PveClusterConfigTotem
{
<#
.DESCRIPTION
Get corosync totem protocol settings.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/config/totem"
    }
}

function Get-PveClusterConfigQdevice
{
<#
.DESCRIPTION
Get QDevice status
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/config/qdevice"
    }
}

function Get-PveClusterFirewall
{
<#
.DESCRIPTION
Directory index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/firewall"
    }
}

function Get-PveClusterFirewallGroups
{
<#
.DESCRIPTION
List security groups.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/firewall/groups"
    }
}

function New-PveClusterFirewallGroups
{
<#
.DESCRIPTION
Create new security group.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
--
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Group
Security Group name.
.PARAMETER Rename
Rename/update an existing security group. You can set 'rename' to the same value as 'name' to update the 'comment' of an existing group.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Group,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Rename
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Group']) { $parameters['group'] = $Group }
        if($PSBoundParameters['Rename']) { $parameters['rename'] = $Rename }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/firewall/groups" -Parameters $parameters
    }
}

function Remove-PveClusterFirewallGroups
{
<#
.DESCRIPTION
Delete security group.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Group
Security Group name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Group
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/firewall/groups/$Group"
    }
}

function Get-PveClusterFirewallGroupsIdx
{
<#
.DESCRIPTION
List rules.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Group
Security Group name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Group
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/firewall/groups/$Group"
    }
}

function New-PveClusterFirewallGroupsIdx
{
<#
.DESCRIPTION
Create new rule.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Action
Rule action ('ACCEPT', 'DROP', 'REJECT') or security group name.
.PARAMETER Comment
Descriptive comment.
.PARAMETER Dest
Restrict packet destination address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Dport
Restrict TCP/UDP destination port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Enable
Flag to enable/disable a rule.
.PARAMETER Group
Security Group name.
.PARAMETER Iface
Network interface name. You have to use network configuration key names for VMs and containers ('net\d+'). Host related rules can use arbitrary strings.
.PARAMETER Log
Log level for firewall rule.
.PARAMETER Macro
Use predefined standard macro.
.PARAMETER Pos
Update rule at position <pos>.
.PARAMETER Proto
IP protocol. You can use protocol names ('tcp'/'udp') or simple numbers, as defined in '/etc/protocols'.
.PARAMETER Source
Restrict packet source address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Sport
Restrict TCP/UDP source port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Type
Rule type.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Action,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Enable,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Group,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iface,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$Log,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Macro,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Proto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Source,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sport,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('in','out','group')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Action']) { $parameters['action'] = $Action }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Dest']) { $parameters['dest'] = $Dest }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Dport']) { $parameters['dport'] = $Dport }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['Iface']) { $parameters['iface'] = $Iface }
        if($PSBoundParameters['Log']) { $parameters['log'] = $Log }
        if($PSBoundParameters['Macro']) { $parameters['macro'] = $Macro }
        if($PSBoundParameters['Pos']) { $parameters['pos'] = $Pos }
        if($PSBoundParameters['Proto']) { $parameters['proto'] = $Proto }
        if($PSBoundParameters['Source']) { $parameters['source'] = $Source }
        if($PSBoundParameters['Sport']) { $parameters['sport'] = $Sport }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/firewall/groups/$Group" -Parameters $parameters
    }
}

function Remove-PveClusterFirewallGroupsIdx
{
<#
.DESCRIPTION
Delete rule.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Group
Security Group name.
.PARAMETER Pos
Update rule at position <pos>.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Group,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/firewall/groups/$Group/$Pos" -Parameters $parameters
    }
}

function Get-PveClusterFirewallGroupsIdx
{
<#
.DESCRIPTION
Get single rule data.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Group
Security Group name.
.PARAMETER Pos
Update rule at position <pos>.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Group,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/firewall/groups/$Group/$Pos"
    }
}

function Set-PveClusterFirewallGroups
{
<#
.DESCRIPTION
Modify rule data.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Action
Rule action ('ACCEPT', 'DROP', 'REJECT') or security group name.
.PARAMETER Comment
Descriptive comment.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Dest
Restrict packet destination address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Dport
Restrict TCP/UDP destination port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Enable
Flag to enable/disable a rule.
.PARAMETER Group
Security Group name.
.PARAMETER Iface
Network interface name. You have to use network configuration key names for VMs and containers ('net\d+'). Host related rules can use arbitrary strings.
.PARAMETER Log
Log level for firewall rule.
.PARAMETER Macro
Use predefined standard macro.
.PARAMETER Moveto
Move rule to new position <moveto>. Other arguments are ignored.
.PARAMETER Pos
Update rule at position <pos>.
.PARAMETER Proto
IP protocol. You can use protocol names ('tcp'/'udp') or simple numbers, as defined in '/etc/protocols'.
.PARAMETER Source
Restrict packet source address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Sport
Restrict TCP/UDP source port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Type
Rule type.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Action,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Enable,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Group,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iface,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$Log,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Macro,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Moveto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Proto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Source,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('in','out','group')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Action']) { $parameters['action'] = $Action }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Dest']) { $parameters['dest'] = $Dest }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Dport']) { $parameters['dport'] = $Dport }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['Iface']) { $parameters['iface'] = $Iface }
        if($PSBoundParameters['Log']) { $parameters['log'] = $Log }
        if($PSBoundParameters['Macro']) { $parameters['macro'] = $Macro }
        if($PSBoundParameters['Moveto']) { $parameters['moveto'] = $Moveto }
        if($PSBoundParameters['Proto']) { $parameters['proto'] = $Proto }
        if($PSBoundParameters['Source']) { $parameters['source'] = $Source }
        if($PSBoundParameters['Sport']) { $parameters['sport'] = $Sport }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/firewall/groups/$Group/$Pos" -Parameters $parameters
    }
}

function Get-PveClusterFirewallRules
{
<#
.DESCRIPTION
List rules.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/firewall/rules"
    }
}

function New-PveClusterFirewallRules
{
<#
.DESCRIPTION
Create new rule.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Action
Rule action ('ACCEPT', 'DROP', 'REJECT') or security group name.
.PARAMETER Comment
Descriptive comment.
.PARAMETER Dest
Restrict packet destination address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Dport
Restrict TCP/UDP destination port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Enable
Flag to enable/disable a rule.
.PARAMETER Iface
Network interface name. You have to use network configuration key names for VMs and containers ('net\d+'). Host related rules can use arbitrary strings.
.PARAMETER Log
Log level for firewall rule.
.PARAMETER Macro
Use predefined standard macro.
.PARAMETER Pos
Update rule at position <pos>.
.PARAMETER Proto
IP protocol. You can use protocol names ('tcp'/'udp') or simple numbers, as defined in '/etc/protocols'.
.PARAMETER Source
Restrict packet source address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Sport
Restrict TCP/UDP source port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Type
Rule type.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Action,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Enable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iface,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$Log,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Macro,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Proto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Source,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sport,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('in','out','group')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Action']) { $parameters['action'] = $Action }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Dest']) { $parameters['dest'] = $Dest }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Dport']) { $parameters['dport'] = $Dport }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['Iface']) { $parameters['iface'] = $Iface }
        if($PSBoundParameters['Log']) { $parameters['log'] = $Log }
        if($PSBoundParameters['Macro']) { $parameters['macro'] = $Macro }
        if($PSBoundParameters['Pos']) { $parameters['pos'] = $Pos }
        if($PSBoundParameters['Proto']) { $parameters['proto'] = $Proto }
        if($PSBoundParameters['Source']) { $parameters['source'] = $Source }
        if($PSBoundParameters['Sport']) { $parameters['sport'] = $Sport }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/firewall/rules" -Parameters $parameters
    }
}

function Remove-PveClusterFirewallRules
{
<#
.DESCRIPTION
Delete rule.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Pos
Update rule at position <pos>.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/firewall/rules/$Pos" -Parameters $parameters
    }
}

function Get-PveClusterFirewallRulesIdx
{
<#
.DESCRIPTION
Get single rule data.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Pos
Update rule at position <pos>.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/firewall/rules/$Pos"
    }
}

function Set-PveClusterFirewallRules
{
<#
.DESCRIPTION
Modify rule data.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Action
Rule action ('ACCEPT', 'DROP', 'REJECT') or security group name.
.PARAMETER Comment
Descriptive comment.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Dest
Restrict packet destination address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Dport
Restrict TCP/UDP destination port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Enable
Flag to enable/disable a rule.
.PARAMETER Iface
Network interface name. You have to use network configuration key names for VMs and containers ('net\d+'). Host related rules can use arbitrary strings.
.PARAMETER Log
Log level for firewall rule.
.PARAMETER Macro
Use predefined standard macro.
.PARAMETER Moveto
Move rule to new position <moveto>. Other arguments are ignored.
.PARAMETER Pos
Update rule at position <pos>.
.PARAMETER Proto
IP protocol. You can use protocol names ('tcp'/'udp') or simple numbers, as defined in '/etc/protocols'.
.PARAMETER Source
Restrict packet source address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Sport
Restrict TCP/UDP source port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Type
Rule type.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Action,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Enable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iface,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$Log,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Macro,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Moveto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Proto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Source,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('in','out','group')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Action']) { $parameters['action'] = $Action }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Dest']) { $parameters['dest'] = $Dest }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Dport']) { $parameters['dport'] = $Dport }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['Iface']) { $parameters['iface'] = $Iface }
        if($PSBoundParameters['Log']) { $parameters['log'] = $Log }
        if($PSBoundParameters['Macro']) { $parameters['macro'] = $Macro }
        if($PSBoundParameters['Moveto']) { $parameters['moveto'] = $Moveto }
        if($PSBoundParameters['Proto']) { $parameters['proto'] = $Proto }
        if($PSBoundParameters['Source']) { $parameters['source'] = $Source }
        if($PSBoundParameters['Sport']) { $parameters['sport'] = $Sport }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/firewall/rules/$Pos" -Parameters $parameters
    }
}

function Get-PveClusterFirewallIpset
{
<#
.DESCRIPTION
List IPSets
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/firewall/ipset"
    }
}

function New-PveClusterFirewallIpset
{
<#
.DESCRIPTION
Create new IPSet
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
--
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
IP set name.
.PARAMETER Rename
Rename an existing IPSet. You can set 'rename' to the same value as 'name' to update the 'comment' of an existing IPSet.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Rename
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }
        if($PSBoundParameters['Rename']) { $parameters['rename'] = $Rename }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/firewall/ipset" -Parameters $parameters
    }
}

function Remove-PveClusterFirewallIpset
{
<#
.DESCRIPTION
Delete IPSet
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Name
IP set name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/firewall/ipset/$Name"
    }
}

function Get-PveClusterFirewallIpsetIdx
{
<#
.DESCRIPTION
List IPSet content
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Name
IP set name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/firewall/ipset/$Name"
    }
}

function New-PveClusterFirewallIpsetIdx
{
<#
.DESCRIPTION
Add IP or Network to IPSet.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Comment
--
.PARAMETER Name
IP set name.
.PARAMETER Nomatch
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Nomatch
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cidr']) { $parameters['cidr'] = $Cidr }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Nomatch']) { $parameters['nomatch'] = $Nomatch }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/firewall/ipset/$Name" -Parameters $parameters
    }
}

function Remove-PveClusterFirewallIpsetIdx
{
<#
.DESCRIPTION
Remove IP or Network from IPSet.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
IP set name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/firewall/ipset/$Name/$Cidr" -Parameters $parameters
    }
}

function Get-PveClusterFirewallIpsetIdx
{
<#
.DESCRIPTION
Read IP or Network settings from IPSet.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Name
IP set name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/firewall/ipset/$Name/$Cidr"
    }
}

function Set-PveClusterFirewallIpset
{
<#
.DESCRIPTION
Update IP or Network settings
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Comment
--
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
IP set name.
.PARAMETER Nomatch
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Nomatch
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Nomatch']) { $parameters['nomatch'] = $Nomatch }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/firewall/ipset/$Name/$Cidr" -Parameters $parameters
    }
}

function Get-PveClusterFirewallAliases
{
<#
.DESCRIPTION
List aliases
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/firewall/aliases"
    }
}

function New-PveClusterFirewallAliases
{
<#
.DESCRIPTION
Create IP or Network Alias.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Comment
--
.PARAMETER Name
Alias name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cidr']) { $parameters['cidr'] = $Cidr }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/firewall/aliases" -Parameters $parameters
    }
}

function Remove-PveClusterFirewallAliases
{
<#
.DESCRIPTION
Remove IP or Network alias.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
Alias name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/firewall/aliases/$Name" -Parameters $parameters
    }
}

function Get-PveClusterFirewallAliasesIdx
{
<#
.DESCRIPTION
Read alias.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Name
Alias name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/firewall/aliases/$Name"
    }
}

function Set-PveClusterFirewallAliases
{
<#
.DESCRIPTION
Update IP or Network alias.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Comment
--
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
Alias name.
.PARAMETER Rename
Rename an existing alias.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Rename
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cidr']) { $parameters['cidr'] = $Cidr }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Rename']) { $parameters['rename'] = $Rename }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/firewall/aliases/$Name" -Parameters $parameters
    }
}

function Get-PveClusterFirewallOptions
{
<#
.DESCRIPTION
Get Firewall options.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/firewall/options"
    }
}

function Set-PveClusterFirewallOptions
{
<#
.DESCRIPTION
Set Firewall options.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Ebtables
Enable ebtables rules cluster wide.
.PARAMETER Enable
Enable or disable the firewall cluster wide.
.PARAMETER LogRatelimit
Log ratelimiting settings
.PARAMETER PolicyIn
Input policy.
.PARAMETER PolicyOut
Output policy.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Ebtables,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Enable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$LogRatelimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('ACCEPT','REJECT','DROP')]
        [string]$PolicyIn,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('ACCEPT','REJECT','DROP')]
        [string]$PolicyOut
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Ebtables']) { $parameters['ebtables'] = $Ebtables }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['LogRatelimit']) { $parameters['log_ratelimit'] = $LogRatelimit }
        if($PSBoundParameters['PolicyIn']) { $parameters['policy_in'] = $PolicyIn }
        if($PSBoundParameters['PolicyOut']) { $parameters['policy_out'] = $PolicyOut }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/firewall/options" -Parameters $parameters
    }
}

function Get-PveClusterFirewallMacros
{
<#
.DESCRIPTION
List available macros
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/firewall/macros"
    }
}

function Get-PveClusterFirewallRefs
{
<#
.DESCRIPTION
Lists possible IPSet/Alias reference which are allowed in source/dest properties.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Type
Only list references of specified type.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('alias','ipset')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/firewall/refs" -Parameters $parameters
    }
}

function Get-PveClusterBackup
{
<#
.DESCRIPTION
List vzdump backup schedule.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/backup"
    }
}

function New-PveClusterBackup
{
<#
.DESCRIPTION
Create new vzdump backup job.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER All
Backup all known guest systems on this host.
.PARAMETER Bwlimit
Limit I/O bandwidth (KBytes per second).
.PARAMETER Compress
Compress dump file.
.PARAMETER Dow
Day of week selection.
.PARAMETER Dumpdir
Store resulting files to specified directory.
.PARAMETER Enabled
Enable or disable the job.
.PARAMETER Exclude
Exclude specified guest systems (assumes --all)
.PARAMETER ExcludePath
Exclude certain files/directories (shell globs).
.PARAMETER Ionice
Set CFQ ionice priority.
.PARAMETER Lockwait
Maximal time to wait for the global lock (minutes).
.PARAMETER Mailnotification
Specify when to send an email
.PARAMETER Mailto
Comma-separated list of email addresses that should receive email notifications.
.PARAMETER Maxfiles
Maximal number of backup files per guest system.
.PARAMETER Mode
Backup mode.
.PARAMETER Node
Only run if executed on this node.
.PARAMETER Pigz
Use pigz instead of gzip when N>0. N=1 uses half of cores, N>1 uses N as thread count.
.PARAMETER Pool
Backup all known guest systems included in the specified pool.
.PARAMETER PruneBackups
Use these retention options instead of those from the storage configuration.
.PARAMETER Quiet
Be quiet.
.PARAMETER Remove
Remove old backup files if there are more than 'maxfiles' backup files.
.PARAMETER Script
Use specified hook script.
.PARAMETER Size
Unused, will be removed in a future release.
.PARAMETER Starttime
Job Start time.
.PARAMETER Stdexcludes
Exclude temporary files and logs.
.PARAMETER Stop
Stop running backup jobs on this host.
.PARAMETER Stopwait
Maximal time to wait until a guest system is stopped (minutes).
.PARAMETER Storage
Store resulting file to this storage.
.PARAMETER Tmpdir
Store temporary files to specified directory.
.PARAMETER Vmid
The ID of the guest system you want to backup.
.PARAMETER Zstd
Zstd threads. N=0 uses half of the available cores, N>0 uses N as thread count.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$All,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Bwlimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('0','1','gzip','lzo','zstd')]
        [string]$Compress,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dow,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dumpdir,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Enabled,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Exclude,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ExcludePath,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Ionice,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Lockwait,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('always','failure')]
        [string]$Mailnotification,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Mailto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Maxfiles,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('snapshot','suspend','stop')]
        [string]$Mode,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pigz,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Pool,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$PruneBackups,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Quiet,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Remove,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Script,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Size,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Starttime,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Stdexcludes,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Stop,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Stopwait,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tmpdir,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vmid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Zstd
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['All']) { $parameters['all'] = $All }
        if($PSBoundParameters['Bwlimit']) { $parameters['bwlimit'] = $Bwlimit }
        if($PSBoundParameters['Compress']) { $parameters['compress'] = $Compress }
        if($PSBoundParameters['Dow']) { $parameters['dow'] = $Dow }
        if($PSBoundParameters['Dumpdir']) { $parameters['dumpdir'] = $Dumpdir }
        if($PSBoundParameters['Enabled']) { $parameters['enabled'] = $Enabled }
        if($PSBoundParameters['Exclude']) { $parameters['exclude'] = $Exclude }
        if($PSBoundParameters['ExcludePath']) { $parameters['exclude-path'] = $ExcludePath }
        if($PSBoundParameters['Ionice']) { $parameters['ionice'] = $Ionice }
        if($PSBoundParameters['Lockwait']) { $parameters['lockwait'] = $Lockwait }
        if($PSBoundParameters['Mailnotification']) { $parameters['mailnotification'] = $Mailnotification }
        if($PSBoundParameters['Mailto']) { $parameters['mailto'] = $Mailto }
        if($PSBoundParameters['Maxfiles']) { $parameters['maxfiles'] = $Maxfiles }
        if($PSBoundParameters['Mode']) { $parameters['mode'] = $Mode }
        if($PSBoundParameters['Node']) { $parameters['node'] = $Node }
        if($PSBoundParameters['Pigz']) { $parameters['pigz'] = $Pigz }
        if($PSBoundParameters['Pool']) { $parameters['pool'] = $Pool }
        if($PSBoundParameters['PruneBackups']) { $parameters['prune-backups'] = $PruneBackups }
        if($PSBoundParameters['Quiet']) { $parameters['quiet'] = $Quiet }
        if($PSBoundParameters['Remove']) { $parameters['remove'] = $Remove }
        if($PSBoundParameters['Script']) { $parameters['script'] = $Script }
        if($PSBoundParameters['Size']) { $parameters['size'] = $Size }
        if($PSBoundParameters['Starttime']) { $parameters['starttime'] = $Starttime }
        if($PSBoundParameters['Stdexcludes']) { $parameters['stdexcludes'] = $Stdexcludes }
        if($PSBoundParameters['Stop']) { $parameters['stop'] = $Stop }
        if($PSBoundParameters['Stopwait']) { $parameters['stopwait'] = $Stopwait }
        if($PSBoundParameters['Storage']) { $parameters['storage'] = $Storage }
        if($PSBoundParameters['Tmpdir']) { $parameters['tmpdir'] = $Tmpdir }
        if($PSBoundParameters['Vmid']) { $parameters['vmid'] = $Vmid }
        if($PSBoundParameters['Zstd']) { $parameters['zstd'] = $Zstd }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/backup" -Parameters $parameters
    }
}

function Remove-PveClusterBackup
{
<#
.DESCRIPTION
Delete vzdump backup job definition.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Id
The job ID.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/backup/$Id"
    }
}

function Get-PveClusterBackupIdx
{
<#
.DESCRIPTION
Read vzdump backup job definition.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Id
The job ID.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/backup/$Id"
    }
}

function Set-PveClusterBackup
{
<#
.DESCRIPTION
Update vzdump backup job definition.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER All
Backup all known guest systems on this host.
.PARAMETER Bwlimit
Limit I/O bandwidth (KBytes per second).
.PARAMETER Compress
Compress dump file.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Dow
Day of week selection.
.PARAMETER Dumpdir
Store resulting files to specified directory.
.PARAMETER Enabled
Enable or disable the job.
.PARAMETER Exclude
Exclude specified guest systems (assumes --all)
.PARAMETER ExcludePath
Exclude certain files/directories (shell globs).
.PARAMETER Id
The job ID.
.PARAMETER Ionice
Set CFQ ionice priority.
.PARAMETER Lockwait
Maximal time to wait for the global lock (minutes).
.PARAMETER Mailnotification
Specify when to send an email
.PARAMETER Mailto
Comma-separated list of email addresses that should receive email notifications.
.PARAMETER Maxfiles
Maximal number of backup files per guest system.
.PARAMETER Mode
Backup mode.
.PARAMETER Node
Only run if executed on this node.
.PARAMETER Pigz
Use pigz instead of gzip when N>0. N=1 uses half of cores, N>1 uses N as thread count.
.PARAMETER Pool
Backup all known guest systems included in the specified pool.
.PARAMETER PruneBackups
Use these retention options instead of those from the storage configuration.
.PARAMETER Quiet
Be quiet.
.PARAMETER Remove
Remove old backup files if there are more than 'maxfiles' backup files.
.PARAMETER Script
Use specified hook script.
.PARAMETER Size
Unused, will be removed in a future release.
.PARAMETER Starttime
Job Start time.
.PARAMETER Stdexcludes
Exclude temporary files and logs.
.PARAMETER Stop
Stop running backup jobs on this host.
.PARAMETER Stopwait
Maximal time to wait until a guest system is stopped (minutes).
.PARAMETER Storage
Store resulting file to this storage.
.PARAMETER Tmpdir
Store temporary files to specified directory.
.PARAMETER Vmid
The ID of the guest system you want to backup.
.PARAMETER Zstd
Zstd threads. N=0 uses half of the available cores, N>0 uses N as thread count.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$All,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Bwlimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('0','1','gzip','lzo','zstd')]
        [string]$Compress,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dow,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dumpdir,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Enabled,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Exclude,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ExcludePath,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Ionice,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Lockwait,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('always','failure')]
        [string]$Mailnotification,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Mailto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Maxfiles,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('snapshot','suspend','stop')]
        [string]$Mode,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pigz,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Pool,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$PruneBackups,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Quiet,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Remove,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Script,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Size,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Starttime,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Stdexcludes,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Stop,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Stopwait,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tmpdir,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vmid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Zstd
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['All']) { $parameters['all'] = $All }
        if($PSBoundParameters['Bwlimit']) { $parameters['bwlimit'] = $Bwlimit }
        if($PSBoundParameters['Compress']) { $parameters['compress'] = $Compress }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Dow']) { $parameters['dow'] = $Dow }
        if($PSBoundParameters['Dumpdir']) { $parameters['dumpdir'] = $Dumpdir }
        if($PSBoundParameters['Enabled']) { $parameters['enabled'] = $Enabled }
        if($PSBoundParameters['Exclude']) { $parameters['exclude'] = $Exclude }
        if($PSBoundParameters['ExcludePath']) { $parameters['exclude-path'] = $ExcludePath }
        if($PSBoundParameters['Ionice']) { $parameters['ionice'] = $Ionice }
        if($PSBoundParameters['Lockwait']) { $parameters['lockwait'] = $Lockwait }
        if($PSBoundParameters['Mailnotification']) { $parameters['mailnotification'] = $Mailnotification }
        if($PSBoundParameters['Mailto']) { $parameters['mailto'] = $Mailto }
        if($PSBoundParameters['Maxfiles']) { $parameters['maxfiles'] = $Maxfiles }
        if($PSBoundParameters['Mode']) { $parameters['mode'] = $Mode }
        if($PSBoundParameters['Node']) { $parameters['node'] = $Node }
        if($PSBoundParameters['Pigz']) { $parameters['pigz'] = $Pigz }
        if($PSBoundParameters['Pool']) { $parameters['pool'] = $Pool }
        if($PSBoundParameters['PruneBackups']) { $parameters['prune-backups'] = $PruneBackups }
        if($PSBoundParameters['Quiet']) { $parameters['quiet'] = $Quiet }
        if($PSBoundParameters['Remove']) { $parameters['remove'] = $Remove }
        if($PSBoundParameters['Script']) { $parameters['script'] = $Script }
        if($PSBoundParameters['Size']) { $parameters['size'] = $Size }
        if($PSBoundParameters['Starttime']) { $parameters['starttime'] = $Starttime }
        if($PSBoundParameters['Stdexcludes']) { $parameters['stdexcludes'] = $Stdexcludes }
        if($PSBoundParameters['Stop']) { $parameters['stop'] = $Stop }
        if($PSBoundParameters['Stopwait']) { $parameters['stopwait'] = $Stopwait }
        if($PSBoundParameters['Storage']) { $parameters['storage'] = $Storage }
        if($PSBoundParameters['Tmpdir']) { $parameters['tmpdir'] = $Tmpdir }
        if($PSBoundParameters['Vmid']) { $parameters['vmid'] = $Vmid }
        if($PSBoundParameters['Zstd']) { $parameters['zstd'] = $Zstd }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/backup/$Id" -Parameters $parameters
    }
}

function Get-PveClusterBackupIncludedVolumes
{
<#
.DESCRIPTION
Returns included guests and the backup status of their disks. Optimized to be used in ExtJS tree views.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Id
The job ID.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/backup/$Id/included_volumes"
    }
}

function Get-PveClusterBackupinfo
{
<#
.DESCRIPTION
Stub, waits for future use.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/backupinfo"
    }
}

function Get-PveClusterBackupinfoNotBackedUp
{
<#
.DESCRIPTION
Shows all guests which are not covered by any backup job.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/backupinfo/not_backed_up"
    }
}

function Get-PveClusterHa
{
<#
.DESCRIPTION
Directory index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/ha"
    }
}

function Get-PveClusterHaResources
{
<#
.DESCRIPTION
List HA resources.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Type
Only list resources of specific type
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('ct','vm')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/ha/resources" -Parameters $parameters
    }
}

function New-PveClusterHaResources
{
<#
.DESCRIPTION
Create a new HA resource.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
Description.
.PARAMETER Group
The HA group identifier.
.PARAMETER MaxRelocate
Maximal number of service relocate tries when a service failes to start.
.PARAMETER MaxRestart
Maximal number of tries to restart the service on a node after its start failed.
.PARAMETER Sid
HA resource ID. This consists of a resource type followed by a resource specific name, separated with colon (example':' vm':'100 / ct':'100). For virtual machines and containers, you can simply use the VM or CT id as a shortcut (example':' 100).
.PARAMETER State
Requested resource state.
.PARAMETER Type
Resource type.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Group,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$MaxRelocate,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$MaxRestart,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('started','stopped','enabled','disabled','ignored')]
        [string]$State,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('ct','vm')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Group']) { $parameters['group'] = $Group }
        if($PSBoundParameters['MaxRelocate']) { $parameters['max_relocate'] = $MaxRelocate }
        if($PSBoundParameters['MaxRestart']) { $parameters['max_restart'] = $MaxRestart }
        if($PSBoundParameters['Sid']) { $parameters['sid'] = $Sid }
        if($PSBoundParameters['State']) { $parameters['state'] = $State }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/ha/resources" -Parameters $parameters
    }
}

function Remove-PveClusterHaResources
{
<#
.DESCRIPTION
Delete resource configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Sid
HA resource ID. This consists of a resource type followed by a resource specific name, separated with colon (example':' vm':'100 / ct':'100). For virtual machines and containers, you can simply use the VM or CT id as a shortcut (example':' 100).
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/ha/resources/$Sid"
    }
}

function Get-PveClusterHaResourcesIdx
{
<#
.DESCRIPTION
Read resource configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Sid
HA resource ID. This consists of a resource type followed by a resource specific name, separated with colon (example':' vm':'100 / ct':'100). For virtual machines and containers, you can simply use the VM or CT id as a shortcut (example':' 100).
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/ha/resources/$Sid"
    }
}

function Set-PveClusterHaResources
{
<#
.DESCRIPTION
Update resource configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
Description.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Group
The HA group identifier.
.PARAMETER MaxRelocate
Maximal number of service relocate tries when a service failes to start.
.PARAMETER MaxRestart
Maximal number of tries to restart the service on a node after its start failed.
.PARAMETER Sid
HA resource ID. This consists of a resource type followed by a resource specific name, separated with colon (example':' vm':'100 / ct':'100). For virtual machines and containers, you can simply use the VM or CT id as a shortcut (example':' 100).
.PARAMETER State
Requested resource state.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Group,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$MaxRelocate,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$MaxRestart,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('started','stopped','enabled','disabled','ignored')]
        [string]$State
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Group']) { $parameters['group'] = $Group }
        if($PSBoundParameters['MaxRelocate']) { $parameters['max_relocate'] = $MaxRelocate }
        if($PSBoundParameters['MaxRestart']) { $parameters['max_restart'] = $MaxRestart }
        if($PSBoundParameters['State']) { $parameters['state'] = $State }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/ha/resources/$Sid" -Parameters $parameters
    }
}

function New-PveClusterHaResourcesMigrate
{
<#
.DESCRIPTION
Request resource migration (online) to another node.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
Target node.
.PARAMETER Sid
HA resource ID. This consists of a resource type followed by a resource specific name, separated with colon (example':' vm':'100 / ct':'100). For virtual machines and containers, you can simply use the VM or CT id as a shortcut (example':' 100).
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Node']) { $parameters['node'] = $Node }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/ha/resources/$Sid/migrate" -Parameters $parameters
    }
}

function New-PveClusterHaResourcesRelocate
{
<#
.DESCRIPTION
Request resource relocatzion to another node. This stops the service on the old node, and restarts it on the target node.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
Target node.
.PARAMETER Sid
HA resource ID. This consists of a resource type followed by a resource specific name, separated with colon (example':' vm':'100 / ct':'100). For virtual machines and containers, you can simply use the VM or CT id as a shortcut (example':' 100).
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Node']) { $parameters['node'] = $Node }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/ha/resources/$Sid/relocate" -Parameters $parameters
    }
}

function Get-PveClusterHaGroups
{
<#
.DESCRIPTION
Get HA groups.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/ha/groups"
    }
}

function New-PveClusterHaGroups
{
<#
.DESCRIPTION
Create a new HA group.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
Description.
.PARAMETER Group
The HA group identifier.
.PARAMETER Nodes
List of cluster node names with optional priority.
.PARAMETER Nofailback
The CRM tries to run services on the node with the highest priority. If a node with higher priority comes online, the CRM migrates the service to that node. Enabling nofailback prevents that behavior.
.PARAMETER Restricted
Resources bound to restricted groups may only run on nodes defined by the group.
.PARAMETER Type
Group type.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Group,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Nodes,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Nofailback,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Restricted,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('group')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Group']) { $parameters['group'] = $Group }
        if($PSBoundParameters['Nodes']) { $parameters['nodes'] = $Nodes }
        if($PSBoundParameters['Nofailback']) { $parameters['nofailback'] = $Nofailback }
        if($PSBoundParameters['Restricted']) { $parameters['restricted'] = $Restricted }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/ha/groups" -Parameters $parameters
    }
}

function Remove-PveClusterHaGroups
{
<#
.DESCRIPTION
Delete ha group configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Group
The HA group identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Group
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/ha/groups/$Group"
    }
}

function Get-PveClusterHaGroupsIdx
{
<#
.DESCRIPTION
Read ha group configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Group
The HA group identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Group
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/ha/groups/$Group"
    }
}

function Set-PveClusterHaGroups
{
<#
.DESCRIPTION
Update ha group configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
Description.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Group
The HA group identifier.
.PARAMETER Nodes
List of cluster node names with optional priority.
.PARAMETER Nofailback
The CRM tries to run services on the node with the highest priority. If a node with higher priority comes online, the CRM migrates the service to that node. Enabling nofailback prevents that behavior.
.PARAMETER Restricted
Resources bound to restricted groups may only run on nodes defined by the group.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Group,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Nodes,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Nofailback,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Restricted
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Nodes']) { $parameters['nodes'] = $Nodes }
        if($PSBoundParameters['Nofailback']) { $parameters['nofailback'] = $Nofailback }
        if($PSBoundParameters['Restricted']) { $parameters['restricted'] = $Restricted }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/ha/groups/$Group" -Parameters $parameters
    }
}

function Get-PveClusterHaStatus
{
<#
.DESCRIPTION
Directory index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/ha/status"
    }
}

function Get-PveClusterHaStatusCurrent
{
<#
.DESCRIPTION
Get HA manger status.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/ha/status/current"
    }
}

function Get-PveClusterHaStatusManagerStatus
{
<#
.DESCRIPTION
Get full HA manger status, including LRM status.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/ha/status/manager_status"
    }
}

function Get-PveClusterAcme
{
<#
.DESCRIPTION
ACMEAccount index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/acme"
    }
}

function Get-PveClusterAcmePlugins
{
<#
.DESCRIPTION
ACME plugin index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Type
Only list ACME plugins of a specific type
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('dns','standalone')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/acme/plugins" -Parameters $parameters
    }
}

function New-PveClusterAcmePlugins
{
<#
.DESCRIPTION
Add ACME plugin configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Api
API plugin name
.PARAMETER Data
DNS plugin data. (base64 encoded)
.PARAMETER Disable
Flag to disable the config.
.PARAMETER Id
ACME Plugin ID name
.PARAMETER Nodes
List of cluster node names.
.PARAMETER Type
ACME challenge type.
.PARAMETER ValidationDelay
Extra delay in seconds to wait before requesting validation. Allows to cope with a long TTL of DNS records.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('acmedns','acmeproxy','active24','ad','ali','autodns','aws','azure','cf','clouddns','cloudns','cn','conoha','constellix','cx','cyon','da','ddnss','desec','df','dgon','dnsimple','do','doapi','domeneshop','dp','dpi','dreamhost','duckdns','durabledns','dyn','dynu','dynv6','easydns','euserv','exoscale','freedns','gandi_livedns','gcloud','gd','gdnsdk','he','hexonet','hostingde','infoblox','internetbs','inwx','ispconfig','jd','kas','kinghost','knot','leaseweb','lexicon','linode','linode_v4','loopia','lua','maradns','me','miab','misaka','myapi','mydevil','mydnsjp','namecheap','namecom','namesilo','nederhost','neodigit','netcup','nic','nsd','nsone','nsupdate','nw','one','online','openprovider','opnsense','ovh','pdns','pleskxml','pointhq','rackspace','rcode0','regru','schlundtech','selectel','servercow','tele3','ultra','unoeuro','variomedia','vscale','vultr','yandex','zilore','zone','zonomi')]
        [string]$Api,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Data,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Disable,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Nodes,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('dns','standalone')]
        [string]$Type,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$ValidationDelay
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Api']) { $parameters['api'] = $Api }
        if($PSBoundParameters['Data']) { $parameters['data'] = $Data }
        if($PSBoundParameters['Disable']) { $parameters['disable'] = $Disable }
        if($PSBoundParameters['Id']) { $parameters['id'] = $Id }
        if($PSBoundParameters['Nodes']) { $parameters['nodes'] = $Nodes }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }
        if($PSBoundParameters['ValidationDelay']) { $parameters['validation-delay'] = $ValidationDelay }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/acme/plugins" -Parameters $parameters
    }
}

function Remove-PveClusterAcmePlugins
{
<#
.DESCRIPTION
Delete ACME plugin configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Id
Unique identifier for ACME plugin instance.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/acme/plugins/$Id"
    }
}

function Get-PveClusterAcmePluginsIdx
{
<#
.DESCRIPTION
Get ACME plugin configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Id
Unique identifier for ACME plugin instance.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/acme/plugins/$Id"
    }
}

function Set-PveClusterAcmePlugins
{
<#
.DESCRIPTION
Update ACME plugin configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Api
API plugin name
.PARAMETER Data
DNS plugin data. (base64 encoded)
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Disable
Flag to disable the config.
.PARAMETER Id
ACME Plugin ID name
.PARAMETER Nodes
List of cluster node names.
.PARAMETER ValidationDelay
Extra delay in seconds to wait before requesting validation. Allows to cope with a long TTL of DNS records.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('acmedns','acmeproxy','active24','ad','ali','autodns','aws','azure','cf','clouddns','cloudns','cn','conoha','constellix','cx','cyon','da','ddnss','desec','df','dgon','dnsimple','do','doapi','domeneshop','dp','dpi','dreamhost','duckdns','durabledns','dyn','dynu','dynv6','easydns','euserv','exoscale','freedns','gandi_livedns','gcloud','gd','gdnsdk','he','hexonet','hostingde','infoblox','internetbs','inwx','ispconfig','jd','kas','kinghost','knot','leaseweb','lexicon','linode','linode_v4','loopia','lua','maradns','me','miab','misaka','myapi','mydevil','mydnsjp','namecheap','namecom','namesilo','nederhost','neodigit','netcup','nic','nsd','nsone','nsupdate','nw','one','online','openprovider','opnsense','ovh','pdns','pleskxml','pointhq','rackspace','rcode0','regru','schlundtech','selectel','servercow','tele3','ultra','unoeuro','variomedia','vscale','vultr','yandex','zilore','zone','zonomi')]
        [string]$Api,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Data,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Disable,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Nodes,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$ValidationDelay
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Api']) { $parameters['api'] = $Api }
        if($PSBoundParameters['Data']) { $parameters['data'] = $Data }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Disable']) { $parameters['disable'] = $Disable }
        if($PSBoundParameters['Nodes']) { $parameters['nodes'] = $Nodes }
        if($PSBoundParameters['ValidationDelay']) { $parameters['validation-delay'] = $ValidationDelay }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/acme/plugins/$Id" -Parameters $parameters
    }
}

function Get-PveClusterAcmeAccount
{
<#
.DESCRIPTION
ACMEAccount index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/acme/account"
    }
}

function New-PveClusterAcmeAccount
{
<#
.DESCRIPTION
Register a new ACME account with CA.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Contact
Contact email addresses.
.PARAMETER Directory
URL of ACME CA directory endpoint.
.PARAMETER Name
ACME account config file name.
.PARAMETER TosUrl
URL of CA TermsOfService - setting this indicates agreement.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Contact,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Directory,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$TosUrl
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Contact']) { $parameters['contact'] = $Contact }
        if($PSBoundParameters['Directory']) { $parameters['directory'] = $Directory }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }
        if($PSBoundParameters['TosUrl']) { $parameters['tos_url'] = $TosUrl }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/acme/account" -Parameters $parameters
    }
}

function Remove-PveClusterAcmeAccount
{
<#
.DESCRIPTION
Deactivate existing ACME account at CA.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Name
ACME account config file name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/acme/account/$Name"
    }
}

function Get-PveClusterAcmeAccountIdx
{
<#
.DESCRIPTION
Return existing ACME account information.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Name
ACME account config file name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/acme/account/$Name"
    }
}

function Set-PveClusterAcmeAccount
{
<#
.DESCRIPTION
Update existing ACME account information with CA. Note':' not specifying any new account information triggers a refresh.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Contact
Contact email addresses.
.PARAMETER Name
ACME account config file name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Contact,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Contact']) { $parameters['contact'] = $Contact }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/acme/account/$Name" -Parameters $parameters
    }
}

function Get-PveClusterAcmeTos
{
<#
.DESCRIPTION
Retrieve ACME TermsOfService URL from CA.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Directory
URL of ACME CA directory endpoint.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Directory
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Directory']) { $parameters['directory'] = $Directory }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/acme/tos" -Parameters $parameters
    }
}

function Get-PveClusterAcmeDirectories
{
<#
.DESCRIPTION
Get named known ACME directory endpoints.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/acme/directories"
    }
}

function Get-PveClusterAcmeChallengeSchema
{
<#
.DESCRIPTION
Get schema of ACME challenge types.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/acme/challenge-schema"
    }
}

function Get-PveClusterCeph
{
<#
.DESCRIPTION
Cluster ceph index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/ceph"
    }
}

function Get-PveClusterCephMetadata
{
<#
.DESCRIPTION
Get ceph metadata.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Scope
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('all','versions')]
        [string]$Scope
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Scope']) { $parameters['scope'] = $Scope }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/ceph/metadata" -Parameters $parameters
    }
}

function Get-PveClusterCephStatus
{
<#
.DESCRIPTION
Get ceph status.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/ceph/status"
    }
}

function Get-PveClusterCephFlags
{
<#
.DESCRIPTION
get the status of all ceph flags
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/ceph/flags"
    }
}

function Set-PveClusterCephFlags
{
<#
.DESCRIPTION
Set/Unset multiple ceph flags at once.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Nobackfill
Backfilling of PGs is suspended.
.PARAMETER NodeepScrub
Deep Scrubbing is disabled.
.PARAMETER Nodown
OSD failure reports are being ignored, such that the monitors will not mark OSDs down.
.PARAMETER Noin
OSDs that were previously marked out will not be marked back in when they start.
.PARAMETER Noout
OSDs will not automatically be marked out after the configured interval.
.PARAMETER Norebalance
Rebalancing of PGs is suspended.
.PARAMETER Norecover
Recovery of PGs is suspended.
.PARAMETER Noscrub
Scrubbing is disabled.
.PARAMETER Notieragent
Cache tiering activity is suspended.
.PARAMETER Noup
OSDs are not allowed to start.
.PARAMETER Pause
Pauses read and writes.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Nobackfill,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$NodeepScrub,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Nodown,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Noin,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Noout,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Norebalance,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Norecover,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Noscrub,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Notieragent,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Noup,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Pause
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Nobackfill']) { $parameters['nobackfill'] = $Nobackfill }
        if($PSBoundParameters['NodeepScrub']) { $parameters['nodeep-scrub'] = $NodeepScrub }
        if($PSBoundParameters['Nodown']) { $parameters['nodown'] = $Nodown }
        if($PSBoundParameters['Noin']) { $parameters['noin'] = $Noin }
        if($PSBoundParameters['Noout']) { $parameters['noout'] = $Noout }
        if($PSBoundParameters['Norebalance']) { $parameters['norebalance'] = $Norebalance }
        if($PSBoundParameters['Norecover']) { $parameters['norecover'] = $Norecover }
        if($PSBoundParameters['Noscrub']) { $parameters['noscrub'] = $Noscrub }
        if($PSBoundParameters['Notieragent']) { $parameters['notieragent'] = $Notieragent }
        if($PSBoundParameters['Noup']) { $parameters['noup'] = $Noup }
        if($PSBoundParameters['Pause']) { $parameters['pause'] = $Pause }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/ceph/flags" -Parameters $parameters
    }
}

function Get-PveClusterCephFlagsIdx
{
<#
.DESCRIPTION
Get the status of a specific ceph flag.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Flag
The name of the flag name to get.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('nobackfill','nodeep-scrub','nodown','noin','noout','norebalance','norecover','noscrub','notieragent','noup','pause')]
        [string]$Flag
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/ceph/flags/$Flag"
    }
}

function Set-PveClusterCephFlagsIdx
{
<#
.DESCRIPTION
Set or clear (unset) a specific ceph flag
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Flag
The ceph flag to update
.PARAMETER Value
The new value of the flag
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('nobackfill','nodeep-scrub','nodown','noin','noout','norebalance','norecover','noscrub','notieragent','noup','pause')]
        [string]$Flag,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Value
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Value']) { $parameters['value'] = $Value }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/ceph/flags/$Flag" -Parameters $parameters
    }
}

function Get-PveClusterSdn
{
<#
.DESCRIPTION
Directory index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/sdn"
    }
}

function Set-PveClusterSdn
{
<#
.DESCRIPTION
Apply sdn controller changes && reload.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/sdn"
    }
}

function Get-PveClusterSdnVnets
{
<#
.DESCRIPTION
SDN vnets index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/sdn/vnets"
    }
}

function New-PveClusterSdnVnets
{
<#
.DESCRIPTION
Create a new sdn vnet object.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Alias
alias name of the vnet
.PARAMETER Ipv4
Anycast router ipv4 address.
.PARAMETER Ipv6
Anycast router ipv6 address.
.PARAMETER Mac
Anycast router mac address
.PARAMETER Tag
vlan or vxlan id
.PARAMETER Type
Type
.PARAMETER Vlanaware
Allow vm VLANs to pass through this vnet.
.PARAMETER Vnet
The SDN vnet object identifier.
.PARAMETER Zone
zone id
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Alias,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ipv4,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ipv6,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Mac,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Tag,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('vnet')]
        [string]$Type,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Vlanaware,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vnet,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Zone
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Alias']) { $parameters['alias'] = $Alias }
        if($PSBoundParameters['Ipv4']) { $parameters['ipv4'] = $Ipv4 }
        if($PSBoundParameters['Ipv6']) { $parameters['ipv6'] = $Ipv6 }
        if($PSBoundParameters['Mac']) { $parameters['mac'] = $Mac }
        if($PSBoundParameters['Tag']) { $parameters['tag'] = $Tag }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }
        if($PSBoundParameters['Vlanaware']) { $parameters['vlanaware'] = $Vlanaware }
        if($PSBoundParameters['Vnet']) { $parameters['vnet'] = $Vnet }
        if($PSBoundParameters['Zone']) { $parameters['zone'] = $Zone }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/sdn/vnets" -Parameters $parameters
    }
}

function Remove-PveClusterSdnVnets
{
<#
.DESCRIPTION
Delete sdn vnet object configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Vnet
The SDN vnet object identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vnet
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/sdn/vnets/$Vnet"
    }
}

function Get-PveClusterSdnVnetsIdx
{
<#
.DESCRIPTION
Read sdn vnet configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Vnet
The SDN vnet object identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vnet
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/sdn/vnets/$Vnet"
    }
}

function Set-PveClusterSdnVnets
{
<#
.DESCRIPTION
Update sdn vnet object configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Alias
alias name of the vnet
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Ipv4
Anycast router ipv4 address.
.PARAMETER Ipv6
Anycast router ipv6 address.
.PARAMETER Mac
Anycast router mac address
.PARAMETER Tag
vlan or vxlan id
.PARAMETER Vlanaware
Allow vm VLANs to pass through this vnet.
.PARAMETER Vnet
The SDN vnet object identifier.
.PARAMETER Zone
zone id
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Alias,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ipv4,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ipv6,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Mac,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Tag,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Vlanaware,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vnet,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Zone
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Alias']) { $parameters['alias'] = $Alias }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Ipv4']) { $parameters['ipv4'] = $Ipv4 }
        if($PSBoundParameters['Ipv6']) { $parameters['ipv6'] = $Ipv6 }
        if($PSBoundParameters['Mac']) { $parameters['mac'] = $Mac }
        if($PSBoundParameters['Tag']) { $parameters['tag'] = $Tag }
        if($PSBoundParameters['Vlanaware']) { $parameters['vlanaware'] = $Vlanaware }
        if($PSBoundParameters['Zone']) { $parameters['zone'] = $Zone }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/sdn/vnets/$Vnet" -Parameters $parameters
    }
}

function Get-PveClusterSdnZones
{
<#
.DESCRIPTION
SDN zones index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Type
Only list sdn zones of specific type
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('evpn','faucet','qinq','simple','vlan','vxlan')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/sdn/zones" -Parameters $parameters
    }
}

function New-PveClusterSdnZones
{
<#
.DESCRIPTION
Create a new sdn zone object.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Bridge
--
.PARAMETER Controller
Frr router name
.PARAMETER DpId
Faucet dataplane id
.PARAMETER Mtu
MTU
.PARAMETER Nodes
List of cluster node names.
.PARAMETER Peers
peers address list.
.PARAMETER Tag
Service-VLAN Tag
.PARAMETER Type
Plugin type.
.PARAMETER VlanProtocol
--
.PARAMETER VrfVxlan
l3vni.
.PARAMETER Zone
The SDN zone object identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Bridge,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Controller,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$DpId,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Mtu,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Nodes,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Peers,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Tag,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('evpn','faucet','qinq','simple','vlan','vxlan')]
        [string]$Type,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('802.1q','802.1ad')]
        [string]$VlanProtocol,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$VrfVxlan,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Zone
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Bridge']) { $parameters['bridge'] = $Bridge }
        if($PSBoundParameters['Controller']) { $parameters['controller'] = $Controller }
        if($PSBoundParameters['DpId']) { $parameters['dp-id'] = $DpId }
        if($PSBoundParameters['Mtu']) { $parameters['mtu'] = $Mtu }
        if($PSBoundParameters['Nodes']) { $parameters['nodes'] = $Nodes }
        if($PSBoundParameters['Peers']) { $parameters['peers'] = $Peers }
        if($PSBoundParameters['Tag']) { $parameters['tag'] = $Tag }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }
        if($PSBoundParameters['VlanProtocol']) { $parameters['vlan-protocol'] = $VlanProtocol }
        if($PSBoundParameters['VrfVxlan']) { $parameters['vrf-vxlan'] = $VrfVxlan }
        if($PSBoundParameters['Zone']) { $parameters['zone'] = $Zone }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/sdn/zones" -Parameters $parameters
    }
}

function Remove-PveClusterSdnZones
{
<#
.DESCRIPTION
Delete sdn zone object configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Zone
The SDN zone object identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Zone
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/sdn/zones/$Zone"
    }
}

function Get-PveClusterSdnZonesIdx
{
<#
.DESCRIPTION
Read sdn zone configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Zone
The SDN zone object identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Zone
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/sdn/zones/$Zone"
    }
}

function Set-PveClusterSdnZones
{
<#
.DESCRIPTION
Update sdn zone object configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Bridge
--
.PARAMETER Controller
Frr router name
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER DpId
Faucet dataplane id
.PARAMETER Mtu
MTU
.PARAMETER Nodes
List of cluster node names.
.PARAMETER Peers
peers address list.
.PARAMETER Tag
Service-VLAN Tag
.PARAMETER VlanProtocol
--
.PARAMETER VrfVxlan
l3vni.
.PARAMETER Zone
The SDN zone object identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Bridge,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Controller,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$DpId,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Mtu,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Nodes,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Peers,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Tag,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('802.1q','802.1ad')]
        [string]$VlanProtocol,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$VrfVxlan,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Zone
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Bridge']) { $parameters['bridge'] = $Bridge }
        if($PSBoundParameters['Controller']) { $parameters['controller'] = $Controller }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['DpId']) { $parameters['dp-id'] = $DpId }
        if($PSBoundParameters['Mtu']) { $parameters['mtu'] = $Mtu }
        if($PSBoundParameters['Nodes']) { $parameters['nodes'] = $Nodes }
        if($PSBoundParameters['Peers']) { $parameters['peers'] = $Peers }
        if($PSBoundParameters['Tag']) { $parameters['tag'] = $Tag }
        if($PSBoundParameters['VlanProtocol']) { $parameters['vlan-protocol'] = $VlanProtocol }
        if($PSBoundParameters['VrfVxlan']) { $parameters['vrf-vxlan'] = $VrfVxlan }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/sdn/zones/$Zone" -Parameters $parameters
    }
}

function Get-PveClusterSdnControllers
{
<#
.DESCRIPTION
SDN controllers index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Type
Only list sdn controllers of specific type
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('evpn','faucet')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/sdn/controllers" -Parameters $parameters
    }
}

function New-PveClusterSdnControllers
{
<#
.DESCRIPTION
Create a new sdn controller object.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Asn
autonomous system number
.PARAMETER Controller
The SDN controller object identifier.
.PARAMETER GatewayExternalPeers
upstream bgp peers address list.
.PARAMETER GatewayNodes
List of cluster node names.
.PARAMETER Peers
peers address list.
.PARAMETER Type
Plugin type.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Asn,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Controller,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GatewayExternalPeers,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GatewayNodes,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Peers,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('evpn','faucet')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Asn']) { $parameters['asn'] = $Asn }
        if($PSBoundParameters['Controller']) { $parameters['controller'] = $Controller }
        if($PSBoundParameters['GatewayExternalPeers']) { $parameters['gateway-external-peers'] = $GatewayExternalPeers }
        if($PSBoundParameters['GatewayNodes']) { $parameters['gateway-nodes'] = $GatewayNodes }
        if($PSBoundParameters['Peers']) { $parameters['peers'] = $Peers }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/cluster/sdn/controllers" -Parameters $parameters
    }
}

function Remove-PveClusterSdnControllers
{
<#
.DESCRIPTION
Delete sdn controller object configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Controller
The SDN controller object identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Controller
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/cluster/sdn/controllers/$Controller"
    }
}

function Get-PveClusterSdnControllersIdx
{
<#
.DESCRIPTION
Read sdn controller configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Controller
The SDN controller object identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Controller
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/sdn/controllers/$Controller"
    }
}

function Set-PveClusterSdnControllers
{
<#
.DESCRIPTION
Update sdn controller object configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Asn
autonomous system number
.PARAMETER Controller
The SDN controller object identifier.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER GatewayExternalPeers
upstream bgp peers address list.
.PARAMETER GatewayNodes
List of cluster node names.
.PARAMETER Peers
peers address list.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Asn,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Controller,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GatewayExternalPeers,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GatewayNodes,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Peers
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Asn']) { $parameters['asn'] = $Asn }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['GatewayExternalPeers']) { $parameters['gateway-external-peers'] = $GatewayExternalPeers }
        if($PSBoundParameters['GatewayNodes']) { $parameters['gateway-nodes'] = $GatewayNodes }
        if($PSBoundParameters['Peers']) { $parameters['peers'] = $Peers }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/sdn/controllers/$Controller" -Parameters $parameters
    }
}

function Get-PveClusterLog
{
<#
.DESCRIPTION
Read cluster log
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Max
Maximum number of entries.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Max
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Max']) { $parameters['max'] = $Max }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/log" -Parameters $parameters
    }
}

function Get-PveClusterResources
{
<#
.DESCRIPTION
Resources index (cluster wide).
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Type
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('vm','storage','node','sdn')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/resources" -Parameters $parameters
    }
}

function Get-PveClusterTasks
{
<#
.DESCRIPTION
List recent tasks (cluster wide).
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/tasks"
    }
}

function Get-PveClusterOptions
{
<#
.DESCRIPTION
Get datacenter options.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/options"
    }
}

function Set-PveClusterOptions
{
<#
.DESCRIPTION
Set datacenter options.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Bwlimit
Set bandwidth/io limits various operations.
.PARAMETER Console
Select the default Console viewer. You can either use the builtin java applet (VNC; deprecated and maps to html5), an external virt-viewer comtatible application (SPICE), an HTML5 based vnc viewer (noVNC), or an HTML5 based console client (xtermjs). If the selected viewer is not available (e.g. SPICE not activated for the VM), the fallback is noVNC.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER EmailFrom
Specify email address to send notification from (default is root@$hostname)
.PARAMETER Fencing
Set the fencing mode of the HA cluster. Hardware mode needs a valid configuration of fence devices in /etc/pve/ha/fence.cfg. With both all two modes are used.WARNING':' 'hardware' and 'both' are EXPERIMENTAL & WIP
.PARAMETER Ha
Cluster wide HA settings.
.PARAMETER HttpProxy
Specify external http proxy which is used for downloads (example':' 'http':'//username':'password@host':'port/')
.PARAMETER Keyboard
Default keybord layout for vnc server.
.PARAMETER Language
Default GUI language.
.PARAMETER MacPrefix
Prefix for autogenerated MAC addresses.
.PARAMETER MaxWorkers
Defines how many workers (per node) are maximal started  on actions like 'stopall VMs' or task from the ha-manager.
.PARAMETER Migration
For cluster wide migration settings.
.PARAMETER MigrationUnsecure
Migration is secure using SSH tunnel by default. For secure private networks you can disable it to speed up migration. Deprecated, use the 'migration' property instead!
.PARAMETER U2f
u2f
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Bwlimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('applet','vv','html5','xtermjs')]
        [string]$Console,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$EmailFrom,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('watchdog','hardware','both')]
        [string]$Fencing,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ha,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$HttpProxy,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('de','de-ch','da','en-gb','en-us','es','fi','fr','fr-be','fr-ca','fr-ch','hu','is','it','ja','lt','mk','nl','no','pl','pt','pt-br','sv','sl','tr')]
        [string]$Keyboard,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('ca','da','de','en','es','eu','fa','fr','he','it','ja','nb','nn','pl','pt_BR','ru','sl','sv','tr','zh_CN','zh_TW')]
        [string]$Language,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$MacPrefix,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$MaxWorkers,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Migration,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$MigrationUnsecure,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$U2f
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Bwlimit']) { $parameters['bwlimit'] = $Bwlimit }
        if($PSBoundParameters['Console']) { $parameters['console'] = $Console }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['EmailFrom']) { $parameters['email_from'] = $EmailFrom }
        if($PSBoundParameters['Fencing']) { $parameters['fencing'] = $Fencing }
        if($PSBoundParameters['Ha']) { $parameters['ha'] = $Ha }
        if($PSBoundParameters['HttpProxy']) { $parameters['http_proxy'] = $HttpProxy }
        if($PSBoundParameters['Keyboard']) { $parameters['keyboard'] = $Keyboard }
        if($PSBoundParameters['Language']) { $parameters['language'] = $Language }
        if($PSBoundParameters['MacPrefix']) { $parameters['mac_prefix'] = $MacPrefix }
        if($PSBoundParameters['MaxWorkers']) { $parameters['max_workers'] = $MaxWorkers }
        if($PSBoundParameters['Migration']) { $parameters['migration'] = $Migration }
        if($PSBoundParameters['MigrationUnsecure']) { $parameters['migration_unsecure'] = $MigrationUnsecure }
        if($PSBoundParameters['U2f']) { $parameters['u2f'] = $U2f }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/cluster/options" -Parameters $parameters
    }
}

function Get-PveClusterStatus
{
<#
.DESCRIPTION
Get cluster status information.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/status"
    }
}

function Get-PveClusterNextid
{
<#
.DESCRIPTION
Get next free VMID. If you pass an VMID it will raise an error if the ID is already used.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Vmid']) { $parameters['vmid'] = $Vmid }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/cluster/nextid" -Parameters $parameters
    }
}

function Get-PveNodes
{
<#
.DESCRIPTION
Cluster node index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes"
    }
}

function Get-PveNodesIdx
{
<#
.DESCRIPTION
Node index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node"
    }
}

function Get-PveNodesQemu
{
<#
.DESCRIPTION
Virtual machine index (per node).
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Full
Determine the full status of active VMs.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Full,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Full']) { $parameters['full'] = $Full }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu" -Parameters $parameters
    }
}

function New-PveNodesQemu
{
<#
.DESCRIPTION
Create or restore a virtual machine.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Acpi
Enable/disable ACPI.
.PARAMETER Agent
Enable/disable Qemu GuestAgent and its properties.
.PARAMETER Arch
Virtual processor architecture. Defaults to the host.
.PARAMETER Archive
The backup archive. Either the file system path to a .tar or .vma file (use '-' to pipe data from stdin) or a proxmox storage backup volume identifier.
.PARAMETER Args_
Arbitrary arguments passed to kvm.
.PARAMETER Audio0
Configure a audio device, useful in combination with QXL/Spice.
.PARAMETER Autostart
Automatic restart after crash (currently ignored).
.PARAMETER Balloon
Amount of target RAM for the VM in MB. Using zero disables the ballon driver.
.PARAMETER Bios
Select BIOS implementation.
.PARAMETER Boot
Boot on floppy (a), hard disk (c), CD-ROM (d), or network (n).
.PARAMETER Bootdisk
Enable booting from specified disk.
.PARAMETER Bwlimit
Override I/O bandwidth limit (in KiB/s).
.PARAMETER Cdrom
This is an alias for option -ide2
.PARAMETER Cicustom
cloud-init':' Specify custom files to replace the automatically generated ones at start.
.PARAMETER Cipassword
cloud-init':' Password to assign the user. Using this is generally not recommended. Use ssh keys instead. Also note that older cloud-init versions do not support hashed passwords.
.PARAMETER Citype
Specifies the cloud-init configuration format. The default depends on the configured operating system type (`ostype`. We use the `nocloud` format for Linux, and `configdrive2` for windows.
.PARAMETER Ciuser
cloud-init':' User name to change ssh keys and password for instead of the image's configured default user.
.PARAMETER Cores
The number of cores per socket.
.PARAMETER Cpu
Emulated CPU type.
.PARAMETER Cpulimit
Limit of CPU usage.
.PARAMETER Cpuunits
CPU weight for a VM.
.PARAMETER Description
Description for the VM. Only used on the configuration web interface. This is saved as comment inside the configuration file.
.PARAMETER Efidisk0
Configure a Disk for storing EFI vars
.PARAMETER Force
Allow to overwrite existing VM.
.PARAMETER Freeze
Freeze CPU at startup (use 'c' monitor command to start execution).
.PARAMETER Hookscript
Script that will be executed during various steps in the vms lifetime.
.PARAMETER HostpciN
Map host PCI devices into guest.
.PARAMETER Hotplug
Selectively enable hotplug features. This is a comma separated list of hotplug features':' 'network', 'disk', 'cpu', 'memory' and 'usb'. Use '0' to disable hotplug completely. Value '1' is an alias for the default 'network,disk,usb'.
.PARAMETER Hugepages
Enable/disable hugepages memory.
.PARAMETER IdeN
Use volume as IDE hard disk or CD-ROM (n is 0 to 3).
.PARAMETER IpconfigN
cloud-init':' Specify IP addresses and gateways for the corresponding interface.IP addresses use CIDR notation, gateways are optional but need an IP of the same type specified.The special string 'dhcp' can be used for IP addresses to use DHCP, in which case no explicit gateway should be provided.For IPv6 the special string 'auto' can be used to use stateless autoconfiguration.If cloud-init is enabled and neither an IPv4 nor an IPv6 address is specified, it defaults to using dhcp on IPv4.
.PARAMETER Ivshmem
Inter-VM shared memory. Useful for direct communication between VMs, or to the host.
.PARAMETER Keyboard
Keybord layout for vnc server. Default is read from the '/etc/pve/datacenter.cfg' configuration file.It should not be necessary to set it.
.PARAMETER Kvm
Enable/disable KVM hardware virtualization.
.PARAMETER Localtime
Set the real time clock to local time. This is enabled by default if ostype indicates a Microsoft OS.
.PARAMETER Lock
Lock/unlock the VM.
.PARAMETER Machine
Specifies the Qemu machine type.
.PARAMETER Memory
Amount of RAM for the VM in MB. This is the maximum available memory when you use the balloon device.
.PARAMETER MigrateDowntime
Set maximum tolerated downtime (in seconds) for migrations.
.PARAMETER MigrateSpeed
Set maximum speed (in MB/s) for migrations. Value 0 is no limit.
.PARAMETER Name
Set a name for the VM. Only used on the configuration web interface.
.PARAMETER Nameserver
cloud-init':' Sets DNS server IP address for a container. Create will automatically use the setting from the host if neither searchdomain nor nameserver are set.
.PARAMETER NetN
Specify network devices.
.PARAMETER Node
The cluster node name.
.PARAMETER Numa
Enable/disable NUMA.
.PARAMETER NumaN
NUMA topology.
.PARAMETER Onboot
Specifies whether a VM will be started during system bootup.
.PARAMETER Ostype
Specify guest operating system.
.PARAMETER ParallelN
Map host parallel devices (n is 0 to 2).
.PARAMETER Pool
Add the VM to the specified pool.
.PARAMETER Protection
Sets the protection flag of the VM. This will disable the remove VM and remove disk operations.
.PARAMETER Reboot
Allow reboot. If set to '0' the VM exit on reboot.
.PARAMETER Rng0
Configure a VirtIO-based Random Number Generator.
.PARAMETER SataN
Use volume as SATA hard disk or CD-ROM (n is 0 to 5).
.PARAMETER ScsiN
Use volume as SCSI hard disk or CD-ROM (n is 0 to 30).
.PARAMETER Scsihw
SCSI controller model
.PARAMETER Searchdomain
cloud-init':' Sets DNS search domains for a container. Create will automatically use the setting from the host if neither searchdomain nor nameserver are set.
.PARAMETER SerialN
Create a serial device inside the VM (n is 0 to 3)
.PARAMETER Shares
Amount of memory shares for auto-ballooning. The larger the number is, the more memory this VM gets. Number is relative to weights of all other running VMs. Using zero disables auto-ballooning. Auto-ballooning is done by pvestatd.
.PARAMETER Smbios1
Specify SMBIOS type 1 fields.
.PARAMETER Smp
The number of CPUs. Please use option -sockets instead.
.PARAMETER Sockets
The number of CPU sockets.
.PARAMETER SpiceEnhancements
Configure additional enhancements for SPICE.
.PARAMETER Sshkeys
cloud-init':' Setup public SSH keys (one key per line, OpenSSH format).
.PARAMETER Start
Start VM after it was created successfully.
.PARAMETER Startdate
Set the initial date of the real time clock. Valid format for date are':' 'now' or '2006-06-17T16':'01':'21' or '2006-06-17'.
.PARAMETER Startup
Startup and shutdown behavior. Order is a non-negative number defining the general startup order. Shutdown in done with reverse ordering. Additionally you can set the 'up' or 'down' delay in seconds, which specifies a delay to wait before the next VM is started or stopped.
.PARAMETER Storage
Default storage.
.PARAMETER Tablet
Enable/disable the USB tablet device.
.PARAMETER Tags
Tags of the VM. This is only meta information.
.PARAMETER Tdf
Enable/disable time drift fix.
.PARAMETER Template
Enable/disable Template.
.PARAMETER Unique
Assign a unique random ethernet address.
.PARAMETER UnusedN
Reference to unused volumes. This is used internally, and should not be modified manually.
.PARAMETER UsbN
Configure an USB device (n is 0 to 4).
.PARAMETER Vcpus
Number of hotplugged vcpus.
.PARAMETER Vga
Configure the VGA hardware.
.PARAMETER VirtioN
Use volume as VIRTIO hard disk (n is 0 to 15).
.PARAMETER Vmgenid
Set VM Generation ID. Use '1' to autogenerate on create or update, pass '0' to disable explicitly.
.PARAMETER Vmid
The (unique) ID of the VM.
.PARAMETER Vmstatestorage
Default storage for VM state volumes/files.
.PARAMETER Watchdog
Create a virtual hardware watchdog device.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Acpi,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Agent,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('x86_64','aarch64')]
        [string]$Arch,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Archive,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Args_,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Audio0,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Autostart,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Balloon,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('seabios','ovmf')]
        [string]$Bios,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Boot,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Bootdisk,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Bwlimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cdrom,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cicustom,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Cipassword,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('configdrive2','nocloud')]
        [string]$Citype,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ciuser,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cores,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cpu,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cpulimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cpuunits,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Efidisk0,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Freeze,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hookscript,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$HostpciN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hotplug,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('any','2','1024')]
        [string]$Hugepages,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$IdeN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$IpconfigN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ivshmem,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('de','de-ch','da','en-gb','en-us','es','fi','fr','fr-be','fr-ca','fr-ch','hu','is','it','ja','lt','mk','nl','no','pl','pt','pt-br','sv','sl','tr')]
        [string]$Keyboard,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Kvm,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Localtime,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('backup','clone','create','migrate','rollback','snapshot','snapshot-delete','suspending','suspended')]
        [string]$Lock,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Machine,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Memory,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$MigrateDowntime,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$MigrateSpeed,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Nameserver,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$NetN,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Numa,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$NumaN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Onboot,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('other','wxp','w2k','w2k3','w2k8','wvista','win7','win8','win10','l24','l26','solaris')]
        [string]$Ostype,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$ParallelN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Pool,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Protection,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Reboot,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Rng0,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$SataN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$ScsiN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('lsi','lsi53c810','virtio-scsi-pci','virtio-scsi-single','megasas','pvscsi')]
        [string]$Scsihw,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Searchdomain,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$SerialN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Shares,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Smbios1,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Smp,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Sockets,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$SpiceEnhancements,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sshkeys,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Start,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Startdate,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Startup,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Tablet,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tags,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Tdf,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Template,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Unique,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$UnusedN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$UsbN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vcpus,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vga,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$VirtioN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vmgenid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vmstatestorage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Watchdog
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Acpi']) { $parameters['acpi'] = $Acpi }
        if($PSBoundParameters['Agent']) { $parameters['agent'] = $Agent }
        if($PSBoundParameters['Arch']) { $parameters['arch'] = $Arch }
        if($PSBoundParameters['Archive']) { $parameters['archive'] = $Archive }
        if($PSBoundParameters['Args_']) { $parameters['args'] = $Args_ }
        if($PSBoundParameters['Audio0']) { $parameters['audio0'] = $Audio0 }
        if($PSBoundParameters['Autostart']) { $parameters['autostart'] = $Autostart }
        if($PSBoundParameters['Balloon']) { $parameters['balloon'] = $Balloon }
        if($PSBoundParameters['Bios']) { $parameters['bios'] = $Bios }
        if($PSBoundParameters['Boot']) { $parameters['boot'] = $Boot }
        if($PSBoundParameters['Bootdisk']) { $parameters['bootdisk'] = $Bootdisk }
        if($PSBoundParameters['Bwlimit']) { $parameters['bwlimit'] = $Bwlimit }
        if($PSBoundParameters['Cdrom']) { $parameters['cdrom'] = $Cdrom }
        if($PSBoundParameters['Cicustom']) { $parameters['cicustom'] = $Cicustom }
        if($PSBoundParameters['Cipassword']) { $parameters['cipassword'] = (ConvertFrom-SecureString -SecureString $Cipassword -AsPlainText) }
        if($PSBoundParameters['Citype']) { $parameters['citype'] = $Citype }
        if($PSBoundParameters['Ciuser']) { $parameters['ciuser'] = $Ciuser }
        if($PSBoundParameters['Cores']) { $parameters['cores'] = $Cores }
        if($PSBoundParameters['Cpu']) { $parameters['cpu'] = $Cpu }
        if($PSBoundParameters['Cpulimit']) { $parameters['cpulimit'] = $Cpulimit }
        if($PSBoundParameters['Cpuunits']) { $parameters['cpuunits'] = $Cpuunits }
        if($PSBoundParameters['Description']) { $parameters['description'] = $Description }
        if($PSBoundParameters['Efidisk0']) { $parameters['efidisk0'] = $Efidisk0 }
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }
        if($PSBoundParameters['Freeze']) { $parameters['freeze'] = $Freeze }
        if($PSBoundParameters['Hookscript']) { $parameters['hookscript'] = $Hookscript }
        if($PSBoundParameters['Hotplug']) { $parameters['hotplug'] = $Hotplug }
        if($PSBoundParameters['Hugepages']) { $parameters['hugepages'] = $Hugepages }
        if($PSBoundParameters['Ivshmem']) { $parameters['ivshmem'] = $Ivshmem }
        if($PSBoundParameters['Keyboard']) { $parameters['keyboard'] = $Keyboard }
        if($PSBoundParameters['Kvm']) { $parameters['kvm'] = $Kvm }
        if($PSBoundParameters['Localtime']) { $parameters['localtime'] = $Localtime }
        if($PSBoundParameters['Lock']) { $parameters['lock'] = $Lock }
        if($PSBoundParameters['Machine']) { $parameters['machine'] = $Machine }
        if($PSBoundParameters['Memory']) { $parameters['memory'] = $Memory }
        if($PSBoundParameters['MigrateDowntime']) { $parameters['migrate_downtime'] = $MigrateDowntime }
        if($PSBoundParameters['MigrateSpeed']) { $parameters['migrate_speed'] = $MigrateSpeed }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }
        if($PSBoundParameters['Nameserver']) { $parameters['nameserver'] = $Nameserver }
        if($PSBoundParameters['Numa']) { $parameters['numa'] = $Numa }
        if($PSBoundParameters['Onboot']) { $parameters['onboot'] = $Onboot }
        if($PSBoundParameters['Ostype']) { $parameters['ostype'] = $Ostype }
        if($PSBoundParameters['Pool']) { $parameters['pool'] = $Pool }
        if($PSBoundParameters['Protection']) { $parameters['protection'] = $Protection }
        if($PSBoundParameters['Reboot']) { $parameters['reboot'] = $Reboot }
        if($PSBoundParameters['Rng0']) { $parameters['rng0'] = $Rng0 }
        if($PSBoundParameters['Scsihw']) { $parameters['scsihw'] = $Scsihw }
        if($PSBoundParameters['Searchdomain']) { $parameters['searchdomain'] = $Searchdomain }
        if($PSBoundParameters['Shares']) { $parameters['shares'] = $Shares }
        if($PSBoundParameters['Smbios1']) { $parameters['smbios1'] = $Smbios1 }
        if($PSBoundParameters['Smp']) { $parameters['smp'] = $Smp }
        if($PSBoundParameters['Sockets']) { $parameters['sockets'] = $Sockets }
        if($PSBoundParameters['SpiceEnhancements']) { $parameters['spice_enhancements'] = $SpiceEnhancements }
        if($PSBoundParameters['Sshkeys']) { $parameters['sshkeys'] = $Sshkeys }
        if($PSBoundParameters['Start']) { $parameters['start'] = $Start }
        if($PSBoundParameters['Startdate']) { $parameters['startdate'] = $Startdate }
        if($PSBoundParameters['Startup']) { $parameters['startup'] = $Startup }
        if($PSBoundParameters['Storage']) { $parameters['storage'] = $Storage }
        if($PSBoundParameters['Tablet']) { $parameters['tablet'] = $Tablet }
        if($PSBoundParameters['Tags']) { $parameters['tags'] = $Tags }
        if($PSBoundParameters['Tdf']) { $parameters['tdf'] = $Tdf }
        if($PSBoundParameters['Template']) { $parameters['template'] = $Template }
        if($PSBoundParameters['Unique']) { $parameters['unique'] = $Unique }
        if($PSBoundParameters['Vcpus']) { $parameters['vcpus'] = $Vcpus }
        if($PSBoundParameters['Vga']) { $parameters['vga'] = $Vga }
        if($PSBoundParameters['Vmgenid']) { $parameters['vmgenid'] = $Vmgenid }
        if($PSBoundParameters['Vmid']) { $parameters['vmid'] = $Vmid }
        if($PSBoundParameters['Vmstatestorage']) { $parameters['vmstatestorage'] = $Vmstatestorage }
        if($PSBoundParameters['Watchdog']) { $parameters['watchdog'] = $Watchdog }

        if($PSBoundParameters['HostpciN']) { $HostpciN.keys | ForEach-Object { $parameters['hostpci' + $_] = $HostpciN[$_] } }
        if($PSBoundParameters['IdeN']) { $IdeN.keys | ForEach-Object { $parameters['ide' + $_] = $IdeN[$_] } }
        if($PSBoundParameters['IpconfigN']) { $IpconfigN.keys | ForEach-Object { $parameters['ipconfig' + $_] = $IpconfigN[$_] } }
        if($PSBoundParameters['NetN']) { $NetN.keys | ForEach-Object { $parameters['net' + $_] = $NetN[$_] } }
        if($PSBoundParameters['NumaN']) { $NumaN.keys | ForEach-Object { $parameters['numa' + $_] = $NumaN[$_] } }
        if($PSBoundParameters['ParallelN']) { $ParallelN.keys | ForEach-Object { $parameters['parallel' + $_] = $ParallelN[$_] } }
        if($PSBoundParameters['SataN']) { $SataN.keys | ForEach-Object { $parameters['sata' + $_] = $SataN[$_] } }
        if($PSBoundParameters['ScsiN']) { $ScsiN.keys | ForEach-Object { $parameters['scsi' + $_] = $ScsiN[$_] } }
        if($PSBoundParameters['SerialN']) { $SerialN.keys | ForEach-Object { $parameters['serial' + $_] = $SerialN[$_] } }
        if($PSBoundParameters['UnusedN']) { $UnusedN.keys | ForEach-Object { $parameters['unused' + $_] = $UnusedN[$_] } }
        if($PSBoundParameters['UsbN']) { $UsbN.keys | ForEach-Object { $parameters['usb' + $_] = $UsbN[$_] } }
        if($PSBoundParameters['VirtioN']) { $VirtioN.keys | ForEach-Object { $parameters['virtio' + $_] = $VirtioN[$_] } }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu" -Parameters $parameters
    }
}

function Remove-PveNodesQemu
{
<#
.DESCRIPTION
Destroy the vm (also delete all used/owned volumes).
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Purge
Remove vmid from backup cron jobs.
.PARAMETER Skiplock
Ignore locks - only root is allowed to use this option.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Purge,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Skiplock,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Purge']) { $parameters['purge'] = $Purge }
        if($PSBoundParameters['Skiplock']) { $parameters['skiplock'] = $Skiplock }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/qemu/$Vmid" -Parameters $parameters
    }
}

function Get-PveNodesQemuIdx
{
<#
.DESCRIPTION
Directory index
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid"
    }
}

function Get-PveNodesQemuFirewall
{
<#
.DESCRIPTION
Directory index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/firewall"
    }
}

function Get-PveNodesQemuFirewallRules
{
<#
.DESCRIPTION
List rules.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/firewall/rules"
    }
}

function New-PveNodesQemuFirewallRules
{
<#
.DESCRIPTION
Create new rule.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Action
Rule action ('ACCEPT', 'DROP', 'REJECT') or security group name.
.PARAMETER Comment
Descriptive comment.
.PARAMETER Dest
Restrict packet destination address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Dport
Restrict TCP/UDP destination port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Enable
Flag to enable/disable a rule.
.PARAMETER Iface
Network interface name. You have to use network configuration key names for VMs and containers ('net\d+'). Host related rules can use arbitrary strings.
.PARAMETER Log
Log level for firewall rule.
.PARAMETER Macro
Use predefined standard macro.
.PARAMETER Node
The cluster node name.
.PARAMETER Pos
Update rule at position <pos>.
.PARAMETER Proto
IP protocol. You can use protocol names ('tcp'/'udp') or simple numbers, as defined in '/etc/protocols'.
.PARAMETER Source
Restrict packet source address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Sport
Restrict TCP/UDP source port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Type
Rule type.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Action,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Enable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iface,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$Log,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Macro,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Proto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Source,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sport,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('in','out','group')]
        [string]$Type,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Action']) { $parameters['action'] = $Action }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Dest']) { $parameters['dest'] = $Dest }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Dport']) { $parameters['dport'] = $Dport }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['Iface']) { $parameters['iface'] = $Iface }
        if($PSBoundParameters['Log']) { $parameters['log'] = $Log }
        if($PSBoundParameters['Macro']) { $parameters['macro'] = $Macro }
        if($PSBoundParameters['Pos']) { $parameters['pos'] = $Pos }
        if($PSBoundParameters['Proto']) { $parameters['proto'] = $Proto }
        if($PSBoundParameters['Source']) { $parameters['source'] = $Source }
        if($PSBoundParameters['Sport']) { $parameters['sport'] = $Sport }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/firewall/rules" -Parameters $parameters
    }
}

function Remove-PveNodesQemuFirewallRules
{
<#
.DESCRIPTION
Delete rule.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Node
The cluster node name.
.PARAMETER Pos
Update rule at position <pos>.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/qemu/$Vmid/firewall/rules/$Pos" -Parameters $parameters
    }
}

function Get-PveNodesQemuFirewallRulesIdx
{
<#
.DESCRIPTION
Get single rule data.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Pos
Update rule at position <pos>.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/firewall/rules/$Pos"
    }
}

function Set-PveNodesQemuFirewallRules
{
<#
.DESCRIPTION
Modify rule data.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Action
Rule action ('ACCEPT', 'DROP', 'REJECT') or security group name.
.PARAMETER Comment
Descriptive comment.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Dest
Restrict packet destination address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Dport
Restrict TCP/UDP destination port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Enable
Flag to enable/disable a rule.
.PARAMETER Iface
Network interface name. You have to use network configuration key names for VMs and containers ('net\d+'). Host related rules can use arbitrary strings.
.PARAMETER Log
Log level for firewall rule.
.PARAMETER Macro
Use predefined standard macro.
.PARAMETER Moveto
Move rule to new position <moveto>. Other arguments are ignored.
.PARAMETER Node
The cluster node name.
.PARAMETER Pos
Update rule at position <pos>.
.PARAMETER Proto
IP protocol. You can use protocol names ('tcp'/'udp') or simple numbers, as defined in '/etc/protocols'.
.PARAMETER Source
Restrict packet source address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Sport
Restrict TCP/UDP source port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Type
Rule type.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Action,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Enable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iface,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$Log,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Macro,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Moveto,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Proto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Source,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('in','out','group')]
        [string]$Type,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Action']) { $parameters['action'] = $Action }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Dest']) { $parameters['dest'] = $Dest }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Dport']) { $parameters['dport'] = $Dport }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['Iface']) { $parameters['iface'] = $Iface }
        if($PSBoundParameters['Log']) { $parameters['log'] = $Log }
        if($PSBoundParameters['Macro']) { $parameters['macro'] = $Macro }
        if($PSBoundParameters['Moveto']) { $parameters['moveto'] = $Moveto }
        if($PSBoundParameters['Proto']) { $parameters['proto'] = $Proto }
        if($PSBoundParameters['Source']) { $parameters['source'] = $Source }
        if($PSBoundParameters['Sport']) { $parameters['sport'] = $Sport }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/qemu/$Vmid/firewall/rules/$Pos" -Parameters $parameters
    }
}

function Get-PveNodesQemuFirewallAliases
{
<#
.DESCRIPTION
List aliases
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/firewall/aliases"
    }
}

function New-PveNodesQemuFirewallAliases
{
<#
.DESCRIPTION
Create IP or Network Alias.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Comment
--
.PARAMETER Name
Alias name.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cidr']) { $parameters['cidr'] = $Cidr }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/firewall/aliases" -Parameters $parameters
    }
}

function Remove-PveNodesQemuFirewallAliases
{
<#
.DESCRIPTION
Remove IP or Network alias.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
Alias name.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/qemu/$Vmid/firewall/aliases/$Name" -Parameters $parameters
    }
}

function Get-PveNodesQemuFirewallAliasesIdx
{
<#
.DESCRIPTION
Read alias.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Name
Alias name.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/firewall/aliases/$Name"
    }
}

function Set-PveNodesQemuFirewallAliases
{
<#
.DESCRIPTION
Update IP or Network alias.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Comment
--
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
Alias name.
.PARAMETER Node
The cluster node name.
.PARAMETER Rename
Rename an existing alias.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Rename,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cidr']) { $parameters['cidr'] = $Cidr }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Rename']) { $parameters['rename'] = $Rename }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/qemu/$Vmid/firewall/aliases/$Name" -Parameters $parameters
    }
}

function Get-PveNodesQemuFirewallIpset
{
<#
.DESCRIPTION
List IPSets
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/firewall/ipset"
    }
}

function New-PveNodesQemuFirewallIpset
{
<#
.DESCRIPTION
Create new IPSet
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
--
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
IP set name.
.PARAMETER Node
The cluster node name.
.PARAMETER Rename
Rename an existing IPSet. You can set 'rename' to the same value as 'name' to update the 'comment' of an existing IPSet.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Rename,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }
        if($PSBoundParameters['Rename']) { $parameters['rename'] = $Rename }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/firewall/ipset" -Parameters $parameters
    }
}

function Remove-PveNodesQemuFirewallIpset
{
<#
.DESCRIPTION
Delete IPSet
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Name
IP set name.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/qemu/$Vmid/firewall/ipset/$Name"
    }
}

function Get-PveNodesQemuFirewallIpsetIdx
{
<#
.DESCRIPTION
List IPSet content
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Name
IP set name.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/firewall/ipset/$Name"
    }
}

function New-PveNodesQemuFirewallIpsetIdx
{
<#
.DESCRIPTION
Add IP or Network to IPSet.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Comment
--
.PARAMETER Name
IP set name.
.PARAMETER Node
The cluster node name.
.PARAMETER Nomatch
--
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Nomatch,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cidr']) { $parameters['cidr'] = $Cidr }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Nomatch']) { $parameters['nomatch'] = $Nomatch }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/firewall/ipset/$Name" -Parameters $parameters
    }
}

function Remove-PveNodesQemuFirewallIpsetIdx
{
<#
.DESCRIPTION
Remove IP or Network from IPSet.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
IP set name.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/qemu/$Vmid/firewall/ipset/$Name/$Cidr" -Parameters $parameters
    }
}

function Get-PveNodesQemuFirewallIpsetIdx
{
<#
.DESCRIPTION
Read IP or Network settings from IPSet.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Name
IP set name.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/firewall/ipset/$Name/$Cidr"
    }
}

function Set-PveNodesQemuFirewallIpset
{
<#
.DESCRIPTION
Update IP or Network settings
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Comment
--
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
IP set name.
.PARAMETER Node
The cluster node name.
.PARAMETER Nomatch
--
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Nomatch,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Nomatch']) { $parameters['nomatch'] = $Nomatch }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/qemu/$Vmid/firewall/ipset/$Name/$Cidr" -Parameters $parameters
    }
}

function Get-PveNodesQemuFirewallOptions
{
<#
.DESCRIPTION
Get VM firewall options.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/firewall/options"
    }
}

function Set-PveNodesQemuFirewallOptions
{
<#
.DESCRIPTION
Set Firewall options.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Dhcp
Enable DHCP.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Enable
Enable/disable firewall rules.
.PARAMETER Ipfilter
Enable default IP filters. This is equivalent to adding an empty ipfilter-net<id> ipset for every interface. Such ipsets implicitly contain sane default restrictions such as restricting IPv6 link local addresses to the one derived from the interface's MAC address. For containers the configured IP addresses will be implicitly added.
.PARAMETER LogLevelIn
Log level for incoming traffic.
.PARAMETER LogLevelOut
Log level for outgoing traffic.
.PARAMETER Macfilter
Enable/disable MAC address filter.
.PARAMETER Ndp
Enable NDP (Neighbor Discovery Protocol).
.PARAMETER Node
The cluster node name.
.PARAMETER PolicyIn
Input policy.
.PARAMETER PolicyOut
Output policy.
.PARAMETER Radv
Allow sending Router Advertisement.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Dhcp,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Enable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Ipfilter,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$LogLevelIn,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$LogLevelOut,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Macfilter,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Ndp,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('ACCEPT','REJECT','DROP')]
        [string]$PolicyIn,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('ACCEPT','REJECT','DROP')]
        [string]$PolicyOut,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Radv,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Dhcp']) { $parameters['dhcp'] = $Dhcp }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['Ipfilter']) { $parameters['ipfilter'] = $Ipfilter }
        if($PSBoundParameters['LogLevelIn']) { $parameters['log_level_in'] = $LogLevelIn }
        if($PSBoundParameters['LogLevelOut']) { $parameters['log_level_out'] = $LogLevelOut }
        if($PSBoundParameters['Macfilter']) { $parameters['macfilter'] = $Macfilter }
        if($PSBoundParameters['Ndp']) { $parameters['ndp'] = $Ndp }
        if($PSBoundParameters['PolicyIn']) { $parameters['policy_in'] = $PolicyIn }
        if($PSBoundParameters['PolicyOut']) { $parameters['policy_out'] = $PolicyOut }
        if($PSBoundParameters['Radv']) { $parameters['radv'] = $Radv }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/qemu/$Vmid/firewall/options" -Parameters $parameters
    }
}

function Get-PveNodesQemuFirewallLog
{
<#
.DESCRIPTION
Read firewall log
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Limit
--
.PARAMETER Node
The cluster node name.
.PARAMETER Start
--
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Limit,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Start,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Limit']) { $parameters['limit'] = $Limit }
        if($PSBoundParameters['Start']) { $parameters['start'] = $Start }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/firewall/log" -Parameters $parameters
    }
}

function Get-PveNodesQemuFirewallRefs
{
<#
.DESCRIPTION
Lists possible IPSet/Alias reference which are allowed in source/dest properties.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Type
Only list references of specified type.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('alias','ipset')]
        [string]$Type,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/firewall/refs" -Parameters $parameters
    }
}

function Get-PveNodesQemuAgent
{
<#
.DESCRIPTION
Qemu Agent command index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/agent"
    }
}

function New-PveNodesQemuAgent
{
<#
.DESCRIPTION
Execute Qemu Guest Agent commands.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Command
The QGA command.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('fsfreeze-freeze','fsfreeze-status','fsfreeze-thaw','fstrim','get-fsinfo','get-host-name','get-memory-block-info','get-memory-blocks','get-osinfo','get-time','get-timezone','get-users','get-vcpus','info','network-get-interfaces','ping','shutdown','suspend-disk','suspend-hybrid','suspend-ram')]
        [string]$Command,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Command']) { $parameters['command'] = $Command }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/agent" -Parameters $parameters
    }
}

function New-PveNodesQemuAgentFsfreezeFreeze
{
<#
.DESCRIPTION
Execute fsfreeze-freeze.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/agent/fsfreeze-freeze"
    }
}

function New-PveNodesQemuAgentFsfreezeStatus
{
<#
.DESCRIPTION
Execute fsfreeze-status.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/agent/fsfreeze-status"
    }
}

function New-PveNodesQemuAgentFsfreezeThaw
{
<#
.DESCRIPTION
Execute fsfreeze-thaw.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/agent/fsfreeze-thaw"
    }
}

function New-PveNodesQemuAgentFstrim
{
<#
.DESCRIPTION
Execute fstrim.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/agent/fstrim"
    }
}

function Get-PveNodesQemuAgentGetFsinfo
{
<#
.DESCRIPTION
Execute get-fsinfo.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/agent/get-fsinfo"
    }
}

function Get-PveNodesQemuAgentGetHostName
{
<#
.DESCRIPTION
Execute get-host-name.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/agent/get-host-name"
    }
}

function Get-PveNodesQemuAgentGetMemoryBlockInfo
{
<#
.DESCRIPTION
Execute get-memory-block-info.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/agent/get-memory-block-info"
    }
}

function Get-PveNodesQemuAgentGetMemoryBlocks
{
<#
.DESCRIPTION
Execute get-memory-blocks.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/agent/get-memory-blocks"
    }
}

function Get-PveNodesQemuAgentGetOsinfo
{
<#
.DESCRIPTION
Execute get-osinfo.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/agent/get-osinfo"
    }
}

function Get-PveNodesQemuAgentGetTime
{
<#
.DESCRIPTION
Execute get-time.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/agent/get-time"
    }
}

function Get-PveNodesQemuAgentGetTimezone
{
<#
.DESCRIPTION
Execute get-timezone.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/agent/get-timezone"
    }
}

function Get-PveNodesQemuAgentGetUsers
{
<#
.DESCRIPTION
Execute get-users.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/agent/get-users"
    }
}

function Get-PveNodesQemuAgentGetVcpus
{
<#
.DESCRIPTION
Execute get-vcpus.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/agent/get-vcpus"
    }
}

function Get-PveNodesQemuAgentInfo
{
<#
.DESCRIPTION
Execute info.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/agent/info"
    }
}

function Get-PveNodesQemuAgentNetworkGetInterfaces
{
<#
.DESCRIPTION
Execute network-get-interfaces.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/agent/network-get-interfaces"
    }
}

function New-PveNodesQemuAgentPing
{
<#
.DESCRIPTION
Execute ping.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/agent/ping"
    }
}

function New-PveNodesQemuAgentShutdown
{
<#
.DESCRIPTION
Execute shutdown.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/agent/shutdown"
    }
}

function New-PveNodesQemuAgentSuspendDisk
{
<#
.DESCRIPTION
Execute suspend-disk.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/agent/suspend-disk"
    }
}

function New-PveNodesQemuAgentSuspendHybrid
{
<#
.DESCRIPTION
Execute suspend-hybrid.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/agent/suspend-hybrid"
    }
}

function New-PveNodesQemuAgentSuspendRam
{
<#
.DESCRIPTION
Execute suspend-ram.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/agent/suspend-ram"
    }
}

function New-PveNodesQemuAgentSetUserPassword
{
<#
.DESCRIPTION
Sets the password for the given user to the given password
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Crypted
set to 1 if the password has already been passed through crypt()
.PARAMETER Node
The cluster node name.
.PARAMETER Password
The new password.
.PARAMETER Username
The user to set the password for.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Crypted,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Password,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Username,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Crypted']) { $parameters['crypted'] = $Crypted }
        if($PSBoundParameters['Password']) { $parameters['password'] = (ConvertFrom-SecureString -SecureString $Password -AsPlainText) }
        if($PSBoundParameters['Username']) { $parameters['username'] = $Username }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/agent/set-user-password" -Parameters $parameters
    }
}

function New-PveNodesQemuAgentExec
{
<#
.DESCRIPTION
Executes the given command in the vm via the guest-agent and returns an object with the pid.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Command
The command as a list of program + arguments
.PARAMETER InputData
Data to pass as 'input-data' to the guest. Usually treated as STDIN to 'command'.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Command,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$InputData,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Command']) { $parameters['command'] = $Command }
        if($PSBoundParameters['InputData']) { $parameters['input-data'] = $InputData }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/agent/exec" -Parameters $parameters
    }
}

function Get-PveNodesQemuAgentExecStatus
{
<#
.DESCRIPTION
Gets the status of the given pid started by the guest-agent
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Pid_
The PID to query
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pid_,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Pid_']) { $parameters['pid'] = $Pid_ }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/agent/exec-status" -Parameters $parameters
    }
}

function Get-PveNodesQemuAgentFileRead
{
<#
.DESCRIPTION
Reads the given file via guest agent. Is limited to 16777216 bytes.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER File
The path to the file
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$File,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['File']) { $parameters['file'] = $File }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/agent/file-read" -Parameters $parameters
    }
}

function New-PveNodesQemuAgentFileWrite
{
<#
.DESCRIPTION
Writes the given file via guest agent.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Content
The content to write into the file.
.PARAMETER File
The path to the file.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Content,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$File,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Content']) { $parameters['content'] = $Content }
        if($PSBoundParameters['File']) { $parameters['file'] = $File }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/agent/file-write" -Parameters $parameters
    }
}

function Get-PveNodesQemuRrd
{
<#
.DESCRIPTION
Read VM RRD statistics (returns PNG)
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cf
The RRD consolidation function
.PARAMETER Ds
The list of datasources you want to display.
.PARAMETER Node
The cluster node name.
.PARAMETER Timeframe
Specify the time frame you are interested in.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('AVERAGE','MAX')]
        [string]$Cf,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ds,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('hour','day','week','month','year')]
        [string]$Timeframe,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cf']) { $parameters['cf'] = $Cf }
        if($PSBoundParameters['Ds']) { $parameters['ds'] = $Ds }
        if($PSBoundParameters['Timeframe']) { $parameters['timeframe'] = $Timeframe }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/rrd" -Parameters $parameters
    }
}

function Get-PveNodesQemuRrddata
{
<#
.DESCRIPTION
Read VM RRD statistics
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cf
The RRD consolidation function
.PARAMETER Node
The cluster node name.
.PARAMETER Timeframe
Specify the time frame you are interested in.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('AVERAGE','MAX')]
        [string]$Cf,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('hour','day','week','month','year')]
        [string]$Timeframe,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cf']) { $parameters['cf'] = $Cf }
        if($PSBoundParameters['Timeframe']) { $parameters['timeframe'] = $Timeframe }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/rrddata" -Parameters $parameters
    }
}

function Get-PveNodesQemuConfig
{
<#
.DESCRIPTION
Get the virtual machine configuration with pending configuration changes applied. Set the 'current' parameter to get the current configuration instead.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Current
Get current values (instead of pending values).
.PARAMETER Node
The cluster node name.
.PARAMETER Snapshot
Fetch config values from given snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Current,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapshot,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Current']) { $parameters['current'] = $Current }
        if($PSBoundParameters['Snapshot']) { $parameters['snapshot'] = $Snapshot }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/config" -Parameters $parameters
    }
}

function New-PveNodesQemuConfig
{
<#
.DESCRIPTION
Set virtual machine options (asynchrounous API).
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Acpi
Enable/disable ACPI.
.PARAMETER Agent
Enable/disable Qemu GuestAgent and its properties.
.PARAMETER Arch
Virtual processor architecture. Defaults to the host.
.PARAMETER Args_
Arbitrary arguments passed to kvm.
.PARAMETER Audio0
Configure a audio device, useful in combination with QXL/Spice.
.PARAMETER Autostart
Automatic restart after crash (currently ignored).
.PARAMETER BackgroundDelay
Time to wait for the task to finish. We return 'null' if the task finish within that time.
.PARAMETER Balloon
Amount of target RAM for the VM in MB. Using zero disables the ballon driver.
.PARAMETER Bios
Select BIOS implementation.
.PARAMETER Boot
Boot on floppy (a), hard disk (c), CD-ROM (d), or network (n).
.PARAMETER Bootdisk
Enable booting from specified disk.
.PARAMETER Cdrom
This is an alias for option -ide2
.PARAMETER Cicustom
cloud-init':' Specify custom files to replace the automatically generated ones at start.
.PARAMETER Cipassword
cloud-init':' Password to assign the user. Using this is generally not recommended. Use ssh keys instead. Also note that older cloud-init versions do not support hashed passwords.
.PARAMETER Citype
Specifies the cloud-init configuration format. The default depends on the configured operating system type (`ostype`. We use the `nocloud` format for Linux, and `configdrive2` for windows.
.PARAMETER Ciuser
cloud-init':' User name to change ssh keys and password for instead of the image's configured default user.
.PARAMETER Cores
The number of cores per socket.
.PARAMETER Cpu
Emulated CPU type.
.PARAMETER Cpulimit
Limit of CPU usage.
.PARAMETER Cpuunits
CPU weight for a VM.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Description
Description for the VM. Only used on the configuration web interface. This is saved as comment inside the configuration file.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Efidisk0
Configure a Disk for storing EFI vars
.PARAMETER Force
Force physical removal. Without this, we simple remove the disk from the config file and create an additional configuration entry called 'unused\[n]', which contains the volume ID. Unlink of unused\[n] always cause physical removal.
.PARAMETER Freeze
Freeze CPU at startup (use 'c' monitor command to start execution).
.PARAMETER Hookscript
Script that will be executed during various steps in the vms lifetime.
.PARAMETER HostpciN
Map host PCI devices into guest.
.PARAMETER Hotplug
Selectively enable hotplug features. This is a comma separated list of hotplug features':' 'network', 'disk', 'cpu', 'memory' and 'usb'. Use '0' to disable hotplug completely. Value '1' is an alias for the default 'network,disk,usb'.
.PARAMETER Hugepages
Enable/disable hugepages memory.
.PARAMETER IdeN
Use volume as IDE hard disk or CD-ROM (n is 0 to 3).
.PARAMETER IpconfigN
cloud-init':' Specify IP addresses and gateways for the corresponding interface.IP addresses use CIDR notation, gateways are optional but need an IP of the same type specified.The special string 'dhcp' can be used for IP addresses to use DHCP, in which case no explicit gateway should be provided.For IPv6 the special string 'auto' can be used to use stateless autoconfiguration.If cloud-init is enabled and neither an IPv4 nor an IPv6 address is specified, it defaults to using dhcp on IPv4.
.PARAMETER Ivshmem
Inter-VM shared memory. Useful for direct communication between VMs, or to the host.
.PARAMETER Keyboard
Keybord layout for vnc server. Default is read from the '/etc/pve/datacenter.cfg' configuration file.It should not be necessary to set it.
.PARAMETER Kvm
Enable/disable KVM hardware virtualization.
.PARAMETER Localtime
Set the real time clock to local time. This is enabled by default if ostype indicates a Microsoft OS.
.PARAMETER Lock
Lock/unlock the VM.
.PARAMETER Machine
Specifies the Qemu machine type.
.PARAMETER Memory
Amount of RAM for the VM in MB. This is the maximum available memory when you use the balloon device.
.PARAMETER MigrateDowntime
Set maximum tolerated downtime (in seconds) for migrations.
.PARAMETER MigrateSpeed
Set maximum speed (in MB/s) for migrations. Value 0 is no limit.
.PARAMETER Name
Set a name for the VM. Only used on the configuration web interface.
.PARAMETER Nameserver
cloud-init':' Sets DNS server IP address for a container. Create will automatically use the setting from the host if neither searchdomain nor nameserver are set.
.PARAMETER NetN
Specify network devices.
.PARAMETER Node
The cluster node name.
.PARAMETER Numa
Enable/disable NUMA.
.PARAMETER NumaN
NUMA topology.
.PARAMETER Onboot
Specifies whether a VM will be started during system bootup.
.PARAMETER Ostype
Specify guest operating system.
.PARAMETER ParallelN
Map host parallel devices (n is 0 to 2).
.PARAMETER Protection
Sets the protection flag of the VM. This will disable the remove VM and remove disk operations.
.PARAMETER Reboot
Allow reboot. If set to '0' the VM exit on reboot.
.PARAMETER Revert
Revert a pending change.
.PARAMETER Rng0
Configure a VirtIO-based Random Number Generator.
.PARAMETER SataN
Use volume as SATA hard disk or CD-ROM (n is 0 to 5).
.PARAMETER ScsiN
Use volume as SCSI hard disk or CD-ROM (n is 0 to 30).
.PARAMETER Scsihw
SCSI controller model
.PARAMETER Searchdomain
cloud-init':' Sets DNS search domains for a container. Create will automatically use the setting from the host if neither searchdomain nor nameserver are set.
.PARAMETER SerialN
Create a serial device inside the VM (n is 0 to 3)
.PARAMETER Shares
Amount of memory shares for auto-ballooning. The larger the number is, the more memory this VM gets. Number is relative to weights of all other running VMs. Using zero disables auto-ballooning. Auto-ballooning is done by pvestatd.
.PARAMETER Skiplock
Ignore locks - only root is allowed to use this option.
.PARAMETER Smbios1
Specify SMBIOS type 1 fields.
.PARAMETER Smp
The number of CPUs. Please use option -sockets instead.
.PARAMETER Sockets
The number of CPU sockets.
.PARAMETER SpiceEnhancements
Configure additional enhancements for SPICE.
.PARAMETER Sshkeys
cloud-init':' Setup public SSH keys (one key per line, OpenSSH format).
.PARAMETER Startdate
Set the initial date of the real time clock. Valid format for date are':' 'now' or '2006-06-17T16':'01':'21' or '2006-06-17'.
.PARAMETER Startup
Startup and shutdown behavior. Order is a non-negative number defining the general startup order. Shutdown in done with reverse ordering. Additionally you can set the 'up' or 'down' delay in seconds, which specifies a delay to wait before the next VM is started or stopped.
.PARAMETER Tablet
Enable/disable the USB tablet device.
.PARAMETER Tags
Tags of the VM. This is only meta information.
.PARAMETER Tdf
Enable/disable time drift fix.
.PARAMETER Template
Enable/disable Template.
.PARAMETER UnusedN
Reference to unused volumes. This is used internally, and should not be modified manually.
.PARAMETER UsbN
Configure an USB device (n is 0 to 4).
.PARAMETER Vcpus
Number of hotplugged vcpus.
.PARAMETER Vga
Configure the VGA hardware.
.PARAMETER VirtioN
Use volume as VIRTIO hard disk (n is 0 to 15).
.PARAMETER Vmgenid
Set VM Generation ID. Use '1' to autogenerate on create or update, pass '0' to disable explicitly.
.PARAMETER Vmid
The (unique) ID of the VM.
.PARAMETER Vmstatestorage
Default storage for VM state volumes/files.
.PARAMETER Watchdog
Create a virtual hardware watchdog device.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Acpi,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Agent,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('x86_64','aarch64')]
        [string]$Arch,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Args_,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Audio0,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Autostart,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$BackgroundDelay,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Balloon,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('seabios','ovmf')]
        [string]$Bios,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Boot,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Bootdisk,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cdrom,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cicustom,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Cipassword,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('configdrive2','nocloud')]
        [string]$Citype,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ciuser,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cores,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cpu,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cpulimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cpuunits,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Efidisk0,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Freeze,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hookscript,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$HostpciN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hotplug,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('any','2','1024')]
        [string]$Hugepages,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$IdeN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$IpconfigN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ivshmem,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('de','de-ch','da','en-gb','en-us','es','fi','fr','fr-be','fr-ca','fr-ch','hu','is','it','ja','lt','mk','nl','no','pl','pt','pt-br','sv','sl','tr')]
        [string]$Keyboard,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Kvm,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Localtime,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('backup','clone','create','migrate','rollback','snapshot','snapshot-delete','suspending','suspended')]
        [string]$Lock,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Machine,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Memory,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$MigrateDowntime,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$MigrateSpeed,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Nameserver,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$NetN,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Numa,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$NumaN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Onboot,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('other','wxp','w2k','w2k3','w2k8','wvista','win7','win8','win10','l24','l26','solaris')]
        [string]$Ostype,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$ParallelN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Protection,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Reboot,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Revert,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Rng0,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$SataN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$ScsiN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('lsi','lsi53c810','virtio-scsi-pci','virtio-scsi-single','megasas','pvscsi')]
        [string]$Scsihw,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Searchdomain,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$SerialN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Shares,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Skiplock,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Smbios1,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Smp,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Sockets,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$SpiceEnhancements,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sshkeys,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Startdate,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Startup,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Tablet,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tags,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Tdf,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Template,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$UnusedN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$UsbN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vcpus,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vga,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$VirtioN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vmgenid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vmstatestorage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Watchdog
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Acpi']) { $parameters['acpi'] = $Acpi }
        if($PSBoundParameters['Agent']) { $parameters['agent'] = $Agent }
        if($PSBoundParameters['Arch']) { $parameters['arch'] = $Arch }
        if($PSBoundParameters['Args_']) { $parameters['args'] = $Args_ }
        if($PSBoundParameters['Audio0']) { $parameters['audio0'] = $Audio0 }
        if($PSBoundParameters['Autostart']) { $parameters['autostart'] = $Autostart }
        if($PSBoundParameters['BackgroundDelay']) { $parameters['background_delay'] = $BackgroundDelay }
        if($PSBoundParameters['Balloon']) { $parameters['balloon'] = $Balloon }
        if($PSBoundParameters['Bios']) { $parameters['bios'] = $Bios }
        if($PSBoundParameters['Boot']) { $parameters['boot'] = $Boot }
        if($PSBoundParameters['Bootdisk']) { $parameters['bootdisk'] = $Bootdisk }
        if($PSBoundParameters['Cdrom']) { $parameters['cdrom'] = $Cdrom }
        if($PSBoundParameters['Cicustom']) { $parameters['cicustom'] = $Cicustom }
        if($PSBoundParameters['Cipassword']) { $parameters['cipassword'] = (ConvertFrom-SecureString -SecureString $Cipassword -AsPlainText) }
        if($PSBoundParameters['Citype']) { $parameters['citype'] = $Citype }
        if($PSBoundParameters['Ciuser']) { $parameters['ciuser'] = $Ciuser }
        if($PSBoundParameters['Cores']) { $parameters['cores'] = $Cores }
        if($PSBoundParameters['Cpu']) { $parameters['cpu'] = $Cpu }
        if($PSBoundParameters['Cpulimit']) { $parameters['cpulimit'] = $Cpulimit }
        if($PSBoundParameters['Cpuunits']) { $parameters['cpuunits'] = $Cpuunits }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Description']) { $parameters['description'] = $Description }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Efidisk0']) { $parameters['efidisk0'] = $Efidisk0 }
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }
        if($PSBoundParameters['Freeze']) { $parameters['freeze'] = $Freeze }
        if($PSBoundParameters['Hookscript']) { $parameters['hookscript'] = $Hookscript }
        if($PSBoundParameters['Hotplug']) { $parameters['hotplug'] = $Hotplug }
        if($PSBoundParameters['Hugepages']) { $parameters['hugepages'] = $Hugepages }
        if($PSBoundParameters['Ivshmem']) { $parameters['ivshmem'] = $Ivshmem }
        if($PSBoundParameters['Keyboard']) { $parameters['keyboard'] = $Keyboard }
        if($PSBoundParameters['Kvm']) { $parameters['kvm'] = $Kvm }
        if($PSBoundParameters['Localtime']) { $parameters['localtime'] = $Localtime }
        if($PSBoundParameters['Lock']) { $parameters['lock'] = $Lock }
        if($PSBoundParameters['Machine']) { $parameters['machine'] = $Machine }
        if($PSBoundParameters['Memory']) { $parameters['memory'] = $Memory }
        if($PSBoundParameters['MigrateDowntime']) { $parameters['migrate_downtime'] = $MigrateDowntime }
        if($PSBoundParameters['MigrateSpeed']) { $parameters['migrate_speed'] = $MigrateSpeed }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }
        if($PSBoundParameters['Nameserver']) { $parameters['nameserver'] = $Nameserver }
        if($PSBoundParameters['Numa']) { $parameters['numa'] = $Numa }
        if($PSBoundParameters['Onboot']) { $parameters['onboot'] = $Onboot }
        if($PSBoundParameters['Ostype']) { $parameters['ostype'] = $Ostype }
        if($PSBoundParameters['Protection']) { $parameters['protection'] = $Protection }
        if($PSBoundParameters['Reboot']) { $parameters['reboot'] = $Reboot }
        if($PSBoundParameters['Revert']) { $parameters['revert'] = $Revert }
        if($PSBoundParameters['Rng0']) { $parameters['rng0'] = $Rng0 }
        if($PSBoundParameters['Scsihw']) { $parameters['scsihw'] = $Scsihw }
        if($PSBoundParameters['Searchdomain']) { $parameters['searchdomain'] = $Searchdomain }
        if($PSBoundParameters['Shares']) { $parameters['shares'] = $Shares }
        if($PSBoundParameters['Skiplock']) { $parameters['skiplock'] = $Skiplock }
        if($PSBoundParameters['Smbios1']) { $parameters['smbios1'] = $Smbios1 }
        if($PSBoundParameters['Smp']) { $parameters['smp'] = $Smp }
        if($PSBoundParameters['Sockets']) { $parameters['sockets'] = $Sockets }
        if($PSBoundParameters['SpiceEnhancements']) { $parameters['spice_enhancements'] = $SpiceEnhancements }
        if($PSBoundParameters['Sshkeys']) { $parameters['sshkeys'] = $Sshkeys }
        if($PSBoundParameters['Startdate']) { $parameters['startdate'] = $Startdate }
        if($PSBoundParameters['Startup']) { $parameters['startup'] = $Startup }
        if($PSBoundParameters['Tablet']) { $parameters['tablet'] = $Tablet }
        if($PSBoundParameters['Tags']) { $parameters['tags'] = $Tags }
        if($PSBoundParameters['Tdf']) { $parameters['tdf'] = $Tdf }
        if($PSBoundParameters['Template']) { $parameters['template'] = $Template }
        if($PSBoundParameters['Vcpus']) { $parameters['vcpus'] = $Vcpus }
        if($PSBoundParameters['Vga']) { $parameters['vga'] = $Vga }
        if($PSBoundParameters['Vmgenid']) { $parameters['vmgenid'] = $Vmgenid }
        if($PSBoundParameters['Vmstatestorage']) { $parameters['vmstatestorage'] = $Vmstatestorage }
        if($PSBoundParameters['Watchdog']) { $parameters['watchdog'] = $Watchdog }

        if($PSBoundParameters['HostpciN']) { $HostpciN.keys | ForEach-Object { $parameters['hostpci' + $_] = $HostpciN[$_] } }
        if($PSBoundParameters['IdeN']) { $IdeN.keys | ForEach-Object { $parameters['ide' + $_] = $IdeN[$_] } }
        if($PSBoundParameters['IpconfigN']) { $IpconfigN.keys | ForEach-Object { $parameters['ipconfig' + $_] = $IpconfigN[$_] } }
        if($PSBoundParameters['NetN']) { $NetN.keys | ForEach-Object { $parameters['net' + $_] = $NetN[$_] } }
        if($PSBoundParameters['NumaN']) { $NumaN.keys | ForEach-Object { $parameters['numa' + $_] = $NumaN[$_] } }
        if($PSBoundParameters['ParallelN']) { $ParallelN.keys | ForEach-Object { $parameters['parallel' + $_] = $ParallelN[$_] } }
        if($PSBoundParameters['SataN']) { $SataN.keys | ForEach-Object { $parameters['sata' + $_] = $SataN[$_] } }
        if($PSBoundParameters['ScsiN']) { $ScsiN.keys | ForEach-Object { $parameters['scsi' + $_] = $ScsiN[$_] } }
        if($PSBoundParameters['SerialN']) { $SerialN.keys | ForEach-Object { $parameters['serial' + $_] = $SerialN[$_] } }
        if($PSBoundParameters['UnusedN']) { $UnusedN.keys | ForEach-Object { $parameters['unused' + $_] = $UnusedN[$_] } }
        if($PSBoundParameters['UsbN']) { $UsbN.keys | ForEach-Object { $parameters['usb' + $_] = $UsbN[$_] } }
        if($PSBoundParameters['VirtioN']) { $VirtioN.keys | ForEach-Object { $parameters['virtio' + $_] = $VirtioN[$_] } }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/config" -Parameters $parameters
    }
}

function Set-PveNodesQemuConfig
{
<#
.DESCRIPTION
Set virtual machine options (synchrounous API) - You should consider using the POST method instead for any actions involving hotplug or storage allocation.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Acpi
Enable/disable ACPI.
.PARAMETER Agent
Enable/disable Qemu GuestAgent and its properties.
.PARAMETER Arch
Virtual processor architecture. Defaults to the host.
.PARAMETER Args_
Arbitrary arguments passed to kvm.
.PARAMETER Audio0
Configure a audio device, useful in combination with QXL/Spice.
.PARAMETER Autostart
Automatic restart after crash (currently ignored).
.PARAMETER Balloon
Amount of target RAM for the VM in MB. Using zero disables the ballon driver.
.PARAMETER Bios
Select BIOS implementation.
.PARAMETER Boot
Boot on floppy (a), hard disk (c), CD-ROM (d), or network (n).
.PARAMETER Bootdisk
Enable booting from specified disk.
.PARAMETER Cdrom
This is an alias for option -ide2
.PARAMETER Cicustom
cloud-init':' Specify custom files to replace the automatically generated ones at start.
.PARAMETER Cipassword
cloud-init':' Password to assign the user. Using this is generally not recommended. Use ssh keys instead. Also note that older cloud-init versions do not support hashed passwords.
.PARAMETER Citype
Specifies the cloud-init configuration format. The default depends on the configured operating system type (`ostype`. We use the `nocloud` format for Linux, and `configdrive2` for windows.
.PARAMETER Ciuser
cloud-init':' User name to change ssh keys and password for instead of the image's configured default user.
.PARAMETER Cores
The number of cores per socket.
.PARAMETER Cpu
Emulated CPU type.
.PARAMETER Cpulimit
Limit of CPU usage.
.PARAMETER Cpuunits
CPU weight for a VM.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Description
Description for the VM. Only used on the configuration web interface. This is saved as comment inside the configuration file.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Efidisk0
Configure a Disk for storing EFI vars
.PARAMETER Force
Force physical removal. Without this, we simple remove the disk from the config file and create an additional configuration entry called 'unused\[n]', which contains the volume ID. Unlink of unused\[n] always cause physical removal.
.PARAMETER Freeze
Freeze CPU at startup (use 'c' monitor command to start execution).
.PARAMETER Hookscript
Script that will be executed during various steps in the vms lifetime.
.PARAMETER HostpciN
Map host PCI devices into guest.
.PARAMETER Hotplug
Selectively enable hotplug features. This is a comma separated list of hotplug features':' 'network', 'disk', 'cpu', 'memory' and 'usb'. Use '0' to disable hotplug completely. Value '1' is an alias for the default 'network,disk,usb'.
.PARAMETER Hugepages
Enable/disable hugepages memory.
.PARAMETER IdeN
Use volume as IDE hard disk or CD-ROM (n is 0 to 3).
.PARAMETER IpconfigN
cloud-init':' Specify IP addresses and gateways for the corresponding interface.IP addresses use CIDR notation, gateways are optional but need an IP of the same type specified.The special string 'dhcp' can be used for IP addresses to use DHCP, in which case no explicit gateway should be provided.For IPv6 the special string 'auto' can be used to use stateless autoconfiguration.If cloud-init is enabled and neither an IPv4 nor an IPv6 address is specified, it defaults to using dhcp on IPv4.
.PARAMETER Ivshmem
Inter-VM shared memory. Useful for direct communication between VMs, or to the host.
.PARAMETER Keyboard
Keybord layout for vnc server. Default is read from the '/etc/pve/datacenter.cfg' configuration file.It should not be necessary to set it.
.PARAMETER Kvm
Enable/disable KVM hardware virtualization.
.PARAMETER Localtime
Set the real time clock to local time. This is enabled by default if ostype indicates a Microsoft OS.
.PARAMETER Lock
Lock/unlock the VM.
.PARAMETER Machine
Specifies the Qemu machine type.
.PARAMETER Memory
Amount of RAM for the VM in MB. This is the maximum available memory when you use the balloon device.
.PARAMETER MigrateDowntime
Set maximum tolerated downtime (in seconds) for migrations.
.PARAMETER MigrateSpeed
Set maximum speed (in MB/s) for migrations. Value 0 is no limit.
.PARAMETER Name
Set a name for the VM. Only used on the configuration web interface.
.PARAMETER Nameserver
cloud-init':' Sets DNS server IP address for a container. Create will automatically use the setting from the host if neither searchdomain nor nameserver are set.
.PARAMETER NetN
Specify network devices.
.PARAMETER Node
The cluster node name.
.PARAMETER Numa
Enable/disable NUMA.
.PARAMETER NumaN
NUMA topology.
.PARAMETER Onboot
Specifies whether a VM will be started during system bootup.
.PARAMETER Ostype
Specify guest operating system.
.PARAMETER ParallelN
Map host parallel devices (n is 0 to 2).
.PARAMETER Protection
Sets the protection flag of the VM. This will disable the remove VM and remove disk operations.
.PARAMETER Reboot
Allow reboot. If set to '0' the VM exit on reboot.
.PARAMETER Revert
Revert a pending change.
.PARAMETER Rng0
Configure a VirtIO-based Random Number Generator.
.PARAMETER SataN
Use volume as SATA hard disk or CD-ROM (n is 0 to 5).
.PARAMETER ScsiN
Use volume as SCSI hard disk or CD-ROM (n is 0 to 30).
.PARAMETER Scsihw
SCSI controller model
.PARAMETER Searchdomain
cloud-init':' Sets DNS search domains for a container. Create will automatically use the setting from the host if neither searchdomain nor nameserver are set.
.PARAMETER SerialN
Create a serial device inside the VM (n is 0 to 3)
.PARAMETER Shares
Amount of memory shares for auto-ballooning. The larger the number is, the more memory this VM gets. Number is relative to weights of all other running VMs. Using zero disables auto-ballooning. Auto-ballooning is done by pvestatd.
.PARAMETER Skiplock
Ignore locks - only root is allowed to use this option.
.PARAMETER Smbios1
Specify SMBIOS type 1 fields.
.PARAMETER Smp
The number of CPUs. Please use option -sockets instead.
.PARAMETER Sockets
The number of CPU sockets.
.PARAMETER SpiceEnhancements
Configure additional enhancements for SPICE.
.PARAMETER Sshkeys
cloud-init':' Setup public SSH keys (one key per line, OpenSSH format).
.PARAMETER Startdate
Set the initial date of the real time clock. Valid format for date are':' 'now' or '2006-06-17T16':'01':'21' or '2006-06-17'.
.PARAMETER Startup
Startup and shutdown behavior. Order is a non-negative number defining the general startup order. Shutdown in done with reverse ordering. Additionally you can set the 'up' or 'down' delay in seconds, which specifies a delay to wait before the next VM is started or stopped.
.PARAMETER Tablet
Enable/disable the USB tablet device.
.PARAMETER Tags
Tags of the VM. This is only meta information.
.PARAMETER Tdf
Enable/disable time drift fix.
.PARAMETER Template
Enable/disable Template.
.PARAMETER UnusedN
Reference to unused volumes. This is used internally, and should not be modified manually.
.PARAMETER UsbN
Configure an USB device (n is 0 to 4).
.PARAMETER Vcpus
Number of hotplugged vcpus.
.PARAMETER Vga
Configure the VGA hardware.
.PARAMETER VirtioN
Use volume as VIRTIO hard disk (n is 0 to 15).
.PARAMETER Vmgenid
Set VM Generation ID. Use '1' to autogenerate on create or update, pass '0' to disable explicitly.
.PARAMETER Vmid
The (unique) ID of the VM.
.PARAMETER Vmstatestorage
Default storage for VM state volumes/files.
.PARAMETER Watchdog
Create a virtual hardware watchdog device.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Acpi,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Agent,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('x86_64','aarch64')]
        [string]$Arch,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Args_,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Audio0,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Autostart,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Balloon,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('seabios','ovmf')]
        [string]$Bios,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Boot,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Bootdisk,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cdrom,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cicustom,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Cipassword,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('configdrive2','nocloud')]
        [string]$Citype,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ciuser,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cores,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cpu,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cpulimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cpuunits,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Efidisk0,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Freeze,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hookscript,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$HostpciN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hotplug,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('any','2','1024')]
        [string]$Hugepages,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$IdeN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$IpconfigN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ivshmem,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('de','de-ch','da','en-gb','en-us','es','fi','fr','fr-be','fr-ca','fr-ch','hu','is','it','ja','lt','mk','nl','no','pl','pt','pt-br','sv','sl','tr')]
        [string]$Keyboard,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Kvm,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Localtime,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('backup','clone','create','migrate','rollback','snapshot','snapshot-delete','suspending','suspended')]
        [string]$Lock,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Machine,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Memory,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$MigrateDowntime,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$MigrateSpeed,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Nameserver,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$NetN,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Numa,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$NumaN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Onboot,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('other','wxp','w2k','w2k3','w2k8','wvista','win7','win8','win10','l24','l26','solaris')]
        [string]$Ostype,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$ParallelN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Protection,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Reboot,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Revert,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Rng0,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$SataN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$ScsiN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('lsi','lsi53c810','virtio-scsi-pci','virtio-scsi-single','megasas','pvscsi')]
        [string]$Scsihw,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Searchdomain,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$SerialN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Shares,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Skiplock,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Smbios1,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Smp,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Sockets,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$SpiceEnhancements,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sshkeys,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Startdate,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Startup,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Tablet,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tags,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Tdf,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Template,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$UnusedN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$UsbN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vcpus,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vga,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$VirtioN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vmgenid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vmstatestorage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Watchdog
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Acpi']) { $parameters['acpi'] = $Acpi }
        if($PSBoundParameters['Agent']) { $parameters['agent'] = $Agent }
        if($PSBoundParameters['Arch']) { $parameters['arch'] = $Arch }
        if($PSBoundParameters['Args_']) { $parameters['args'] = $Args_ }
        if($PSBoundParameters['Audio0']) { $parameters['audio0'] = $Audio0 }
        if($PSBoundParameters['Autostart']) { $parameters['autostart'] = $Autostart }
        if($PSBoundParameters['Balloon']) { $parameters['balloon'] = $Balloon }
        if($PSBoundParameters['Bios']) { $parameters['bios'] = $Bios }
        if($PSBoundParameters['Boot']) { $parameters['boot'] = $Boot }
        if($PSBoundParameters['Bootdisk']) { $parameters['bootdisk'] = $Bootdisk }
        if($PSBoundParameters['Cdrom']) { $parameters['cdrom'] = $Cdrom }
        if($PSBoundParameters['Cicustom']) { $parameters['cicustom'] = $Cicustom }
        if($PSBoundParameters['Cipassword']) { $parameters['cipassword'] = (ConvertFrom-SecureString -SecureString $Cipassword -AsPlainText) }
        if($PSBoundParameters['Citype']) { $parameters['citype'] = $Citype }
        if($PSBoundParameters['Ciuser']) { $parameters['ciuser'] = $Ciuser }
        if($PSBoundParameters['Cores']) { $parameters['cores'] = $Cores }
        if($PSBoundParameters['Cpu']) { $parameters['cpu'] = $Cpu }
        if($PSBoundParameters['Cpulimit']) { $parameters['cpulimit'] = $Cpulimit }
        if($PSBoundParameters['Cpuunits']) { $parameters['cpuunits'] = $Cpuunits }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Description']) { $parameters['description'] = $Description }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Efidisk0']) { $parameters['efidisk0'] = $Efidisk0 }
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }
        if($PSBoundParameters['Freeze']) { $parameters['freeze'] = $Freeze }
        if($PSBoundParameters['Hookscript']) { $parameters['hookscript'] = $Hookscript }
        if($PSBoundParameters['Hotplug']) { $parameters['hotplug'] = $Hotplug }
        if($PSBoundParameters['Hugepages']) { $parameters['hugepages'] = $Hugepages }
        if($PSBoundParameters['Ivshmem']) { $parameters['ivshmem'] = $Ivshmem }
        if($PSBoundParameters['Keyboard']) { $parameters['keyboard'] = $Keyboard }
        if($PSBoundParameters['Kvm']) { $parameters['kvm'] = $Kvm }
        if($PSBoundParameters['Localtime']) { $parameters['localtime'] = $Localtime }
        if($PSBoundParameters['Lock']) { $parameters['lock'] = $Lock }
        if($PSBoundParameters['Machine']) { $parameters['machine'] = $Machine }
        if($PSBoundParameters['Memory']) { $parameters['memory'] = $Memory }
        if($PSBoundParameters['MigrateDowntime']) { $parameters['migrate_downtime'] = $MigrateDowntime }
        if($PSBoundParameters['MigrateSpeed']) { $parameters['migrate_speed'] = $MigrateSpeed }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }
        if($PSBoundParameters['Nameserver']) { $parameters['nameserver'] = $Nameserver }
        if($PSBoundParameters['Numa']) { $parameters['numa'] = $Numa }
        if($PSBoundParameters['Onboot']) { $parameters['onboot'] = $Onboot }
        if($PSBoundParameters['Ostype']) { $parameters['ostype'] = $Ostype }
        if($PSBoundParameters['Protection']) { $parameters['protection'] = $Protection }
        if($PSBoundParameters['Reboot']) { $parameters['reboot'] = $Reboot }
        if($PSBoundParameters['Revert']) { $parameters['revert'] = $Revert }
        if($PSBoundParameters['Rng0']) { $parameters['rng0'] = $Rng0 }
        if($PSBoundParameters['Scsihw']) { $parameters['scsihw'] = $Scsihw }
        if($PSBoundParameters['Searchdomain']) { $parameters['searchdomain'] = $Searchdomain }
        if($PSBoundParameters['Shares']) { $parameters['shares'] = $Shares }
        if($PSBoundParameters['Skiplock']) { $parameters['skiplock'] = $Skiplock }
        if($PSBoundParameters['Smbios1']) { $parameters['smbios1'] = $Smbios1 }
        if($PSBoundParameters['Smp']) { $parameters['smp'] = $Smp }
        if($PSBoundParameters['Sockets']) { $parameters['sockets'] = $Sockets }
        if($PSBoundParameters['SpiceEnhancements']) { $parameters['spice_enhancements'] = $SpiceEnhancements }
        if($PSBoundParameters['Sshkeys']) { $parameters['sshkeys'] = $Sshkeys }
        if($PSBoundParameters['Startdate']) { $parameters['startdate'] = $Startdate }
        if($PSBoundParameters['Startup']) { $parameters['startup'] = $Startup }
        if($PSBoundParameters['Tablet']) { $parameters['tablet'] = $Tablet }
        if($PSBoundParameters['Tags']) { $parameters['tags'] = $Tags }
        if($PSBoundParameters['Tdf']) { $parameters['tdf'] = $Tdf }
        if($PSBoundParameters['Template']) { $parameters['template'] = $Template }
        if($PSBoundParameters['Vcpus']) { $parameters['vcpus'] = $Vcpus }
        if($PSBoundParameters['Vga']) { $parameters['vga'] = $Vga }
        if($PSBoundParameters['Vmgenid']) { $parameters['vmgenid'] = $Vmgenid }
        if($PSBoundParameters['Vmstatestorage']) { $parameters['vmstatestorage'] = $Vmstatestorage }
        if($PSBoundParameters['Watchdog']) { $parameters['watchdog'] = $Watchdog }

        if($PSBoundParameters['HostpciN']) { $HostpciN.keys | ForEach-Object { $parameters['hostpci' + $_] = $HostpciN[$_] } }
        if($PSBoundParameters['IdeN']) { $IdeN.keys | ForEach-Object { $parameters['ide' + $_] = $IdeN[$_] } }
        if($PSBoundParameters['IpconfigN']) { $IpconfigN.keys | ForEach-Object { $parameters['ipconfig' + $_] = $IpconfigN[$_] } }
        if($PSBoundParameters['NetN']) { $NetN.keys | ForEach-Object { $parameters['net' + $_] = $NetN[$_] } }
        if($PSBoundParameters['NumaN']) { $NumaN.keys | ForEach-Object { $parameters['numa' + $_] = $NumaN[$_] } }
        if($PSBoundParameters['ParallelN']) { $ParallelN.keys | ForEach-Object { $parameters['parallel' + $_] = $ParallelN[$_] } }
        if($PSBoundParameters['SataN']) { $SataN.keys | ForEach-Object { $parameters['sata' + $_] = $SataN[$_] } }
        if($PSBoundParameters['ScsiN']) { $ScsiN.keys | ForEach-Object { $parameters['scsi' + $_] = $ScsiN[$_] } }
        if($PSBoundParameters['SerialN']) { $SerialN.keys | ForEach-Object { $parameters['serial' + $_] = $SerialN[$_] } }
        if($PSBoundParameters['UnusedN']) { $UnusedN.keys | ForEach-Object { $parameters['unused' + $_] = $UnusedN[$_] } }
        if($PSBoundParameters['UsbN']) { $UsbN.keys | ForEach-Object { $parameters['usb' + $_] = $UsbN[$_] } }
        if($PSBoundParameters['VirtioN']) { $VirtioN.keys | ForEach-Object { $parameters['virtio' + $_] = $VirtioN[$_] } }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/qemu/$Vmid/config" -Parameters $parameters
    }
}

function Get-PveNodesQemuPending
{
<#
.DESCRIPTION
Get the virtual machine configuration with both current and pending values.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/pending"
    }
}

function Set-PveNodesQemuUnlink
{
<#
.DESCRIPTION
Unlink/delete disk images.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Force
Force physical removal. Without this, we simple remove the disk from the config file and create an additional configuration entry called 'unused\[n]', which contains the volume ID. Unlink of unused\[n] always cause physical removal.
.PARAMETER Idlist
A list of disk IDs you want to delete.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Idlist,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }
        if($PSBoundParameters['Idlist']) { $parameters['idlist'] = $Idlist }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/qemu/$Vmid/unlink" -Parameters $parameters
    }
}

function New-PveNodesQemuVncproxy
{
<#
.DESCRIPTION
Creates a TCP VNC proxy connections.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER GeneratePassword
Generates a random password to be used as ticket instead of the API ticket.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.PARAMETER Websocket
starts websockify instead of vncproxy
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$GeneratePassword,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Websocket
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['GeneratePassword']) { $parameters['generate-password'] = $GeneratePassword }
        if($PSBoundParameters['Websocket']) { $parameters['websocket'] = $Websocket }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/vncproxy" -Parameters $parameters
    }
}

function New-PveNodesQemuTermproxy
{
<#
.DESCRIPTION
Creates a TCP proxy connections.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Serial
opens a serial terminal (defaults to display)
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('serial0','serial1','serial2','serial3')]
        [string]$Serial,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Serial']) { $parameters['serial'] = $Serial }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/termproxy" -Parameters $parameters
    }
}

function Get-PveNodesQemuVncwebsocket
{
<#
.DESCRIPTION
Opens a weksocket for VNC traffic.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Port
Port number returned by previous vncproxy call.
.PARAMETER Vmid
The (unique) ID of the VM.
.PARAMETER Vncticket
Ticket from previous call to vncproxy.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Port,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vncticket
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Port']) { $parameters['port'] = $Port }
        if($PSBoundParameters['Vncticket']) { $parameters['vncticket'] = $Vncticket }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/vncwebsocket" -Parameters $parameters
    }
}

function New-PveNodesQemuSpiceproxy
{
<#
.DESCRIPTION
Returns a SPICE configuration to connect to the VM.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Proxy
SPICE proxy server. This can be used by the client to specify the proxy server. All nodes in a cluster runs 'spiceproxy', so it is up to the client to choose one. By default, we return the node where the VM is currently running. As reasonable setting is to use same node you use to connect to the API (This is window.location.hostname for the JS GUI).
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Proxy,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Proxy']) { $parameters['proxy'] = $Proxy }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/spiceproxy" -Parameters $parameters
    }
}

function Get-PveNodesQemuStatus
{
<#
.DESCRIPTION
Directory index
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/status"
    }
}

function Get-PveNodesQemuStatusCurrent
{
<#
.DESCRIPTION
Get virtual machine status.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/status/current"
    }
}

function New-PveNodesQemuStatusStart
{
<#
.DESCRIPTION
Start virtual machine.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER ForceCpu
Override QEMU's -cpu argument with the given string.
.PARAMETER Machine
Specifies the Qemu machine type.
.PARAMETER Migratedfrom
The cluster node name.
.PARAMETER MigrationNetwork
CIDR of the (sub) network that is used for migration.
.PARAMETER MigrationType
Migration traffic is encrypted using an SSH tunnel by default. On secure, completely private networks this can be disabled to increase performance.
.PARAMETER Node
The cluster node name.
.PARAMETER Skiplock
Ignore locks - only root is allowed to use this option.
.PARAMETER Stateuri
Some command save/restore state from this location.
.PARAMETER Targetstorage
Mapping from source to target storages. Providing only a single storage ID maps all source storages to that storage. Providing the special value '1' will map each source storage to itself.
.PARAMETER Timeout
Wait maximal timeout seconds.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ForceCpu,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Machine,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Migratedfrom,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$MigrationNetwork,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('secure','insecure')]
        [string]$MigrationType,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Skiplock,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Stateuri,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Targetstorage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Timeout,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['ForceCpu']) { $parameters['force-cpu'] = $ForceCpu }
        if($PSBoundParameters['Machine']) { $parameters['machine'] = $Machine }
        if($PSBoundParameters['Migratedfrom']) { $parameters['migratedfrom'] = $Migratedfrom }
        if($PSBoundParameters['MigrationNetwork']) { $parameters['migration_network'] = $MigrationNetwork }
        if($PSBoundParameters['MigrationType']) { $parameters['migration_type'] = $MigrationType }
        if($PSBoundParameters['Skiplock']) { $parameters['skiplock'] = $Skiplock }
        if($PSBoundParameters['Stateuri']) { $parameters['stateuri'] = $Stateuri }
        if($PSBoundParameters['Targetstorage']) { $parameters['targetstorage'] = $Targetstorage }
        if($PSBoundParameters['Timeout']) { $parameters['timeout'] = $Timeout }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/status/start" -Parameters $parameters
    }
}

function New-PveNodesQemuStatusStop
{
<#
.DESCRIPTION
Stop virtual machine. The qemu process will exit immediately. Thisis akin to pulling the power plug of a running computer and may damage the VM data
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Keepactive
Do not deactivate storage volumes.
.PARAMETER Migratedfrom
The cluster node name.
.PARAMETER Node
The cluster node name.
.PARAMETER Skiplock
Ignore locks - only root is allowed to use this option.
.PARAMETER Timeout
Wait maximal timeout seconds.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Keepactive,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Migratedfrom,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Skiplock,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Timeout,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Keepactive']) { $parameters['keepActive'] = $Keepactive }
        if($PSBoundParameters['Migratedfrom']) { $parameters['migratedfrom'] = $Migratedfrom }
        if($PSBoundParameters['Skiplock']) { $parameters['skiplock'] = $Skiplock }
        if($PSBoundParameters['Timeout']) { $parameters['timeout'] = $Timeout }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/status/stop" -Parameters $parameters
    }
}

function New-PveNodesQemuStatusReset
{
<#
.DESCRIPTION
Reset virtual machine.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Skiplock
Ignore locks - only root is allowed to use this option.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Skiplock,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Skiplock']) { $parameters['skiplock'] = $Skiplock }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/status/reset" -Parameters $parameters
    }
}

function New-PveNodesQemuStatusShutdown
{
<#
.DESCRIPTION
Shutdown virtual machine. This is similar to pressing the power button on a physical machine.This will send an ACPI event for the guest OS, which should then proceed to a clean shutdown.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Forcestop
Make sure the VM stops.
.PARAMETER Keepactive
Do not deactivate storage volumes.
.PARAMETER Node
The cluster node name.
.PARAMETER Skiplock
Ignore locks - only root is allowed to use this option.
.PARAMETER Timeout
Wait maximal timeout seconds.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Forcestop,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Keepactive,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Skiplock,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Timeout,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Forcestop']) { $parameters['forceStop'] = $Forcestop }
        if($PSBoundParameters['Keepactive']) { $parameters['keepActive'] = $Keepactive }
        if($PSBoundParameters['Skiplock']) { $parameters['skiplock'] = $Skiplock }
        if($PSBoundParameters['Timeout']) { $parameters['timeout'] = $Timeout }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/status/shutdown" -Parameters $parameters
    }
}

function New-PveNodesQemuStatusReboot
{
<#
.DESCRIPTION
Reboot the VM by shutting it down, and starting it again. Applies pending changes.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Timeout
Wait maximal timeout seconds for the shutdown.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Timeout,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Timeout']) { $parameters['timeout'] = $Timeout }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/status/reboot" -Parameters $parameters
    }
}

function New-PveNodesQemuStatusSuspend
{
<#
.DESCRIPTION
Suspend virtual machine.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Skiplock
Ignore locks - only root is allowed to use this option.
.PARAMETER Statestorage
The storage for the VM state
.PARAMETER Todisk
If set, suspends the VM to disk. Will be resumed on next VM start.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Skiplock,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Statestorage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Todisk,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Skiplock']) { $parameters['skiplock'] = $Skiplock }
        if($PSBoundParameters['Statestorage']) { $parameters['statestorage'] = $Statestorage }
        if($PSBoundParameters['Todisk']) { $parameters['todisk'] = $Todisk }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/status/suspend" -Parameters $parameters
    }
}

function New-PveNodesQemuStatusResume
{
<#
.DESCRIPTION
Resume virtual machine.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Nocheck
--
.PARAMETER Node
The cluster node name.
.PARAMETER Skiplock
Ignore locks - only root is allowed to use this option.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Nocheck,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Skiplock,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Nocheck']) { $parameters['nocheck'] = $Nocheck }
        if($PSBoundParameters['Skiplock']) { $parameters['skiplock'] = $Skiplock }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/status/resume" -Parameters $parameters
    }
}

function Set-PveNodesQemuSendkey
{
<#
.DESCRIPTION
Send key event to virtual machine.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Key
The key (qemu monitor encoding).
.PARAMETER Node
The cluster node name.
.PARAMETER Skiplock
Ignore locks - only root is allowed to use this option.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Key,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Skiplock,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Key']) { $parameters['key'] = $Key }
        if($PSBoundParameters['Skiplock']) { $parameters['skiplock'] = $Skiplock }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/qemu/$Vmid/sendkey" -Parameters $parameters
    }
}

function Get-PveNodesQemuFeature
{
<#
.DESCRIPTION
Check if feature for virtual machine is available.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Feature
Feature to check.
.PARAMETER Node
The cluster node name.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('snapshot','clone','copy')]
        [string]$Feature,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Feature']) { $parameters['feature'] = $Feature }
        if($PSBoundParameters['Snapname']) { $parameters['snapname'] = $Snapname }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/feature" -Parameters $parameters
    }
}

function New-PveNodesQemuClone
{
<#
.DESCRIPTION
Create a copy of virtual machine/template.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Bwlimit
Override I/O bandwidth limit (in KiB/s).
.PARAMETER Description
Description for the new VM.
.PARAMETER Format
Target format for file storage. Only valid for full clone.
.PARAMETER Full
Create a full copy of all disks. This is always done when you clone a normal VM. For VM templates, we try to create a linked clone by default.
.PARAMETER Name
Set a name for the new VM.
.PARAMETER Newid
VMID for the clone.
.PARAMETER Node
The cluster node name.
.PARAMETER Pool
Add the new VM to the specified pool.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Storage
Target storage for full clone.
.PARAMETER Target
Target node. Only allowed if the original VM is on shared storage.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Bwlimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('raw','qcow2','vmdk')]
        [string]$Format,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Full,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Newid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Pool,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Target,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Bwlimit']) { $parameters['bwlimit'] = $Bwlimit }
        if($PSBoundParameters['Description']) { $parameters['description'] = $Description }
        if($PSBoundParameters['Format']) { $parameters['format'] = $Format }
        if($PSBoundParameters['Full']) { $parameters['full'] = $Full }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }
        if($PSBoundParameters['Newid']) { $parameters['newid'] = $Newid }
        if($PSBoundParameters['Pool']) { $parameters['pool'] = $Pool }
        if($PSBoundParameters['Snapname']) { $parameters['snapname'] = $Snapname }
        if($PSBoundParameters['Storage']) { $parameters['storage'] = $Storage }
        if($PSBoundParameters['Target']) { $parameters['target'] = $Target }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/clone" -Parameters $parameters
    }
}

function New-PveNodesQemuMoveDisk
{
<#
.DESCRIPTION
Move volume to different storage.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Bwlimit
Override I/O bandwidth limit (in KiB/s).
.PARAMETER Delete
Delete the original disk after successful copy. By default the original disk is kept as unused disk.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Disk
The disk you want to move.
.PARAMETER Format
Target Format.
.PARAMETER Node
The cluster node name.
.PARAMETER Storage
Target storage.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Bwlimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('ide0','ide1','ide2','ide3','scsi0','scsi1','scsi2','scsi3','scsi4','scsi5','scsi6','scsi7','scsi8','scsi9','scsi10','scsi11','scsi12','scsi13','scsi14','scsi15','scsi16','scsi17','scsi18','scsi19','scsi20','scsi21','scsi22','scsi23','scsi24','scsi25','scsi26','scsi27','scsi28','scsi29','scsi30','virtio0','virtio1','virtio2','virtio3','virtio4','virtio5','virtio6','virtio7','virtio8','virtio9','virtio10','virtio11','virtio12','virtio13','virtio14','virtio15','sata0','sata1','sata2','sata3','sata4','sata5','efidisk0')]
        [string]$Disk,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('raw','qcow2','vmdk')]
        [string]$Format,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Bwlimit']) { $parameters['bwlimit'] = $Bwlimit }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Disk']) { $parameters['disk'] = $Disk }
        if($PSBoundParameters['Format']) { $parameters['format'] = $Format }
        if($PSBoundParameters['Storage']) { $parameters['storage'] = $Storage }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/move_disk" -Parameters $parameters
    }
}

function Get-PveNodesQemuMigrate
{
<#
.DESCRIPTION
Get preconditions for migration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Target
Target node.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Target,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Target']) { $parameters['target'] = $Target }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/migrate" -Parameters $parameters
    }
}

function New-PveNodesQemuMigrate
{
<#
.DESCRIPTION
Migrate virtual machine. Creates a new migration task.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Bwlimit
Override I/O bandwidth limit (in KiB/s).
.PARAMETER Force
Allow to migrate VMs which use local devices. Only root may use this option.
.PARAMETER MigrationNetwork
CIDR of the (sub) network that is used for migration.
.PARAMETER MigrationType
Migration traffic is encrypted using an SSH tunnel by default. On secure, completely private networks this can be disabled to increase performance.
.PARAMETER Node
The cluster node name.
.PARAMETER Online
Use online/live migration if VM is running. Ignored if VM is stopped.
.PARAMETER Target
Target node.
.PARAMETER Targetstorage
Mapping from source to target storages. Providing only a single storage ID maps all source storages to that storage. Providing the special value '1' will map each source storage to itself.
.PARAMETER Vmid
The (unique) ID of the VM.
.PARAMETER WithLocalDisks
Enable live storage migration for local disk
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Bwlimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$MigrationNetwork,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('secure','insecure')]
        [string]$MigrationType,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Online,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Target,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Targetstorage,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$WithLocalDisks
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Bwlimit']) { $parameters['bwlimit'] = $Bwlimit }
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }
        if($PSBoundParameters['MigrationNetwork']) { $parameters['migration_network'] = $MigrationNetwork }
        if($PSBoundParameters['MigrationType']) { $parameters['migration_type'] = $MigrationType }
        if($PSBoundParameters['Online']) { $parameters['online'] = $Online }
        if($PSBoundParameters['Target']) { $parameters['target'] = $Target }
        if($PSBoundParameters['Targetstorage']) { $parameters['targetstorage'] = $Targetstorage }
        if($PSBoundParameters['WithLocalDisks']) { $parameters['with-local-disks'] = $WithLocalDisks }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/migrate" -Parameters $parameters
    }
}

function New-PveNodesQemuMonitor
{
<#
.DESCRIPTION
Execute Qemu monitor commands.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Command
The monitor command.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Command,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Command']) { $parameters['command'] = $Command }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/monitor" -Parameters $parameters
    }
}

function Set-PveNodesQemuResize
{
<#
.DESCRIPTION
Extend volume size.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Disk
The disk you want to resize.
.PARAMETER Node
The cluster node name.
.PARAMETER Size
The new size. With the `+` sign the value is added to the actual size of the volume and without it, the value is taken as an absolute one. Shrinking disk size is not supported.
.PARAMETER Skiplock
Ignore locks - only root is allowed to use this option.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('ide0','ide1','ide2','ide3','scsi0','scsi1','scsi2','scsi3','scsi4','scsi5','scsi6','scsi7','scsi8','scsi9','scsi10','scsi11','scsi12','scsi13','scsi14','scsi15','scsi16','scsi17','scsi18','scsi19','scsi20','scsi21','scsi22','scsi23','scsi24','scsi25','scsi26','scsi27','scsi28','scsi29','scsi30','virtio0','virtio1','virtio2','virtio3','virtio4','virtio5','virtio6','virtio7','virtio8','virtio9','virtio10','virtio11','virtio12','virtio13','virtio14','virtio15','sata0','sata1','sata2','sata3','sata4','sata5','efidisk0')]
        [string]$Disk,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Size,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Skiplock,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Disk']) { $parameters['disk'] = $Disk }
        if($PSBoundParameters['Size']) { $parameters['size'] = $Size }
        if($PSBoundParameters['Skiplock']) { $parameters['skiplock'] = $Skiplock }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/qemu/$Vmid/resize" -Parameters $parameters
    }
}

function Get-PveNodesQemuSnapshot
{
<#
.DESCRIPTION
List all snapshots.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/snapshot"
    }
}

function New-PveNodesQemuSnapshot
{
<#
.DESCRIPTION
Snapshot a VM.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Description
A textual description or comment.
.PARAMETER Node
The cluster node name.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.PARAMETER Vmstate
Save the vmstate
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Vmstate
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Description']) { $parameters['description'] = $Description }
        if($PSBoundParameters['Snapname']) { $parameters['snapname'] = $Snapname }
        if($PSBoundParameters['Vmstate']) { $parameters['vmstate'] = $Vmstate }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/snapshot" -Parameters $parameters
    }
}

function Remove-PveNodesQemuSnapshot
{
<#
.DESCRIPTION
Delete a VM snapshot.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Force
For removal from config file, even if removing disk snapshots fails.
.PARAMETER Node
The cluster node name.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/qemu/$Vmid/snapshot/$Snapname" -Parameters $parameters
    }
}

function Get-PveNodesQemuSnapshotIdx
{
<#
.DESCRIPTION
--
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/snapshot/$Snapname"
    }
}

function Get-PveNodesQemuSnapshotConfig
{
<#
.DESCRIPTION
Get snapshot configuration
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/qemu/$Vmid/snapshot/$Snapname/config"
    }
}

function Set-PveNodesQemuSnapshotConfig
{
<#
.DESCRIPTION
Update snapshot metadata.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Description
A textual description or comment.
.PARAMETER Node
The cluster node name.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Description']) { $parameters['description'] = $Description }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/qemu/$Vmid/snapshot/$Snapname/config" -Parameters $parameters
    }
}

function New-PveNodesQemuSnapshotRollback
{
<#
.DESCRIPTION
Rollback VM state to specified snapshot.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/snapshot/$Snapname/rollback"
    }
}

function New-PveNodesQemuTemplate
{
<#
.DESCRIPTION
Create a Template.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Disk
If you want to convert only 1 disk to base image.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('ide0','ide1','ide2','ide3','scsi0','scsi1','scsi2','scsi3','scsi4','scsi5','scsi6','scsi7','scsi8','scsi9','scsi10','scsi11','scsi12','scsi13','scsi14','scsi15','scsi16','scsi17','scsi18','scsi19','scsi20','scsi21','scsi22','scsi23','scsi24','scsi25','scsi26','scsi27','scsi28','scsi29','scsi30','virtio0','virtio1','virtio2','virtio3','virtio4','virtio5','virtio6','virtio7','virtio8','virtio9','virtio10','virtio11','virtio12','virtio13','virtio14','virtio15','sata0','sata1','sata2','sata3','sata4','sata5','efidisk0')]
        [string]$Disk,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Disk']) { $parameters['disk'] = $Disk }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/qemu/$Vmid/template" -Parameters $parameters
    }
}

function Get-PveNodesCpu
{
<#
.DESCRIPTION
List all custom and default CPU models.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/cpu"
    }
}

function Get-PveNodesLxc
{
<#
.DESCRIPTION
LXC container index (per node).
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc"
    }
}

function New-PveNodesLxc
{
<#
.DESCRIPTION
Create or restore a container.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Arch
OS architecture type.
.PARAMETER Bwlimit
Override I/O bandwidth limit (in KiB/s).
.PARAMETER Cmode
Console mode. By default, the console command tries to open a connection to one of the available tty devices. By setting cmode to 'console' it tries to attach to /dev/console instead. If you set cmode to 'shell', it simply invokes a shell inside the container (no login).
.PARAMETER Console
Attach a console device (/dev/console) to the container.
.PARAMETER Cores
The number of cores assigned to the container. A container can use all available cores by default.
.PARAMETER Cpulimit
Limit of CPU usage.NOTE':' If the computer has 2 CPUs, it has a total of '2' CPU time. Value '0' indicates no CPU limit.
.PARAMETER Cpuunits
CPU weight for a VM. Argument is used in the kernel fair scheduler. The larger the number is, the more CPU time this VM gets. Number is relative to the weights of all the other running VMs.NOTE':' You can disable fair-scheduler configuration by setting this to 0.
.PARAMETER Debug
Try to be more verbose. For now this only enables debug log-level on start.
.PARAMETER Description
Container description. Only used on the configuration web interface.
.PARAMETER Features
Allow containers access to advanced features.
.PARAMETER Force
Allow to overwrite existing container.
.PARAMETER Hookscript
Script that will be exectued during various steps in the containers lifetime.
.PARAMETER Hostname
Set a host name for the container.
.PARAMETER IgnoreUnpackErrors
Ignore errors when extracting the template.
.PARAMETER Lock
Lock/unlock the VM.
.PARAMETER Memory
Amount of RAM for the VM in MB.
.PARAMETER MpN
Use volume as container mount point.
.PARAMETER Nameserver
Sets DNS server IP address for a container. Create will automatically use the setting from the host if you neither set searchdomain nor nameserver.
.PARAMETER NetN
Specifies network interfaces for the container.
.PARAMETER Node
The cluster node name.
.PARAMETER Onboot
Specifies whether a VM will be started during system bootup.
.PARAMETER Ostemplate
The OS template or backup file.
.PARAMETER Ostype
OS type. This is used to setup configuration inside the container, and corresponds to lxc setup scripts in /usr/share/lxc/config/<ostype>.common.conf. Value 'unmanaged' can be used to skip and OS specific setup.
.PARAMETER Password
Sets root password inside container.
.PARAMETER Pool
Add the VM to the specified pool.
.PARAMETER Protection
Sets the protection flag of the container. This will prevent the CT or CT's disk remove/update operation.
.PARAMETER Restore
Mark this as restore task.
.PARAMETER Rootfs
Use volume as container root.
.PARAMETER Searchdomain
Sets DNS search domains for a container. Create will automatically use the setting from the host if you neither set searchdomain nor nameserver.
.PARAMETER SshPublicKeys
Setup public SSH keys (one key per line, OpenSSH format).
.PARAMETER Start
Start the CT after its creation finished successfully.
.PARAMETER Startup
Startup and shutdown behavior. Order is a non-negative number defining the general startup order. Shutdown in done with reverse ordering. Additionally you can set the 'up' or 'down' delay in seconds, which specifies a delay to wait before the next VM is started or stopped.
.PARAMETER Storage
Default Storage.
.PARAMETER Swap
Amount of SWAP for the VM in MB.
.PARAMETER Tags
Tags of the Container. This is only meta information.
.PARAMETER Template
Enable/disable Template.
.PARAMETER Timezone
Time zone to use in the container. If option isn't set, then nothing will be done. Can be set to 'host' to match the host time zone, or an arbitrary time zone option from /usr/share/zoneinfo/zone.tab
.PARAMETER Tty
Specify the number of tty available to the container
.PARAMETER Unique
Assign a unique random ethernet address.
.PARAMETER Unprivileged
Makes the container run as unprivileged user. (Should not be modified manually.)
.PARAMETER UnusedN
Reference to unused volumes. This is used internally, and should not be modified manually.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('amd64','i386','arm64','armhf')]
        [string]$Arch,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Bwlimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('shell','console','tty')]
        [string]$Cmode,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Console,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cores,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cpulimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cpuunits,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Debug,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Features,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hookscript,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hostname,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$IgnoreUnpackErrors,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('backup','create','destroyed','disk','fstrim','migrate','mounted','rollback','snapshot','snapshot-delete')]
        [string]$Lock,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Memory,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$MpN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Nameserver,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$NetN,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Onboot,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ostemplate,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('debian','ubuntu','centos','fedora','opensuse','archlinux','alpine','gentoo','unmanaged')]
        [string]$Ostype,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Password,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Pool,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Protection,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Restore,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Rootfs,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Searchdomain,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$SshPublicKeys,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Start,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Startup,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Swap,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tags,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Template,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Timezone,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Tty,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Unique,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Unprivileged,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$UnusedN,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Arch']) { $parameters['arch'] = $Arch }
        if($PSBoundParameters['Bwlimit']) { $parameters['bwlimit'] = $Bwlimit }
        if($PSBoundParameters['Cmode']) { $parameters['cmode'] = $Cmode }
        if($PSBoundParameters['Console']) { $parameters['console'] = $Console }
        if($PSBoundParameters['Cores']) { $parameters['cores'] = $Cores }
        if($PSBoundParameters['Cpulimit']) { $parameters['cpulimit'] = $Cpulimit }
        if($PSBoundParameters['Cpuunits']) { $parameters['cpuunits'] = $Cpuunits }
        if($PSBoundParameters['Debug']) { $parameters['debug'] = $Debug }
        if($PSBoundParameters['Description']) { $parameters['description'] = $Description }
        if($PSBoundParameters['Features']) { $parameters['features'] = $Features }
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }
        if($PSBoundParameters['Hookscript']) { $parameters['hookscript'] = $Hookscript }
        if($PSBoundParameters['Hostname']) { $parameters['hostname'] = $Hostname }
        if($PSBoundParameters['IgnoreUnpackErrors']) { $parameters['ignore-unpack-errors'] = $IgnoreUnpackErrors }
        if($PSBoundParameters['Lock']) { $parameters['lock'] = $Lock }
        if($PSBoundParameters['Memory']) { $parameters['memory'] = $Memory }
        if($PSBoundParameters['Nameserver']) { $parameters['nameserver'] = $Nameserver }
        if($PSBoundParameters['Onboot']) { $parameters['onboot'] = $Onboot }
        if($PSBoundParameters['Ostemplate']) { $parameters['ostemplate'] = $Ostemplate }
        if($PSBoundParameters['Ostype']) { $parameters['ostype'] = $Ostype }
        if($PSBoundParameters['Password']) { $parameters['password'] = (ConvertFrom-SecureString -SecureString $Password -AsPlainText) }
        if($PSBoundParameters['Pool']) { $parameters['pool'] = $Pool }
        if($PSBoundParameters['Protection']) { $parameters['protection'] = $Protection }
        if($PSBoundParameters['Restore']) { $parameters['restore'] = $Restore }
        if($PSBoundParameters['Rootfs']) { $parameters['rootfs'] = $Rootfs }
        if($PSBoundParameters['Searchdomain']) { $parameters['searchdomain'] = $Searchdomain }
        if($PSBoundParameters['SshPublicKeys']) { $parameters['ssh-public-keys'] = $SshPublicKeys }
        if($PSBoundParameters['Start']) { $parameters['start'] = $Start }
        if($PSBoundParameters['Startup']) { $parameters['startup'] = $Startup }
        if($PSBoundParameters['Storage']) { $parameters['storage'] = $Storage }
        if($PSBoundParameters['Swap']) { $parameters['swap'] = $Swap }
        if($PSBoundParameters['Tags']) { $parameters['tags'] = $Tags }
        if($PSBoundParameters['Template']) { $parameters['template'] = $Template }
        if($PSBoundParameters['Timezone']) { $parameters['timezone'] = $Timezone }
        if($PSBoundParameters['Tty']) { $parameters['tty'] = $Tty }
        if($PSBoundParameters['Unique']) { $parameters['unique'] = $Unique }
        if($PSBoundParameters['Unprivileged']) { $parameters['unprivileged'] = $Unprivileged }
        if($PSBoundParameters['Vmid']) { $parameters['vmid'] = $Vmid }

        if($PSBoundParameters['MpN']) { $MpN.keys | ForEach-Object { $parameters['mp' + $_] = $MpN[$_] } }
        if($PSBoundParameters['NetN']) { $NetN.keys | ForEach-Object { $parameters['net' + $_] = $NetN[$_] } }
        if($PSBoundParameters['UnusedN']) { $UnusedN.keys | ForEach-Object { $parameters['unused' + $_] = $UnusedN[$_] } }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc" -Parameters $parameters
    }
}

function Remove-PveNodesLxc
{
<#
.DESCRIPTION
Destroy the container (also delete all uses files).
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Force
Force destroy, even if running.
.PARAMETER Node
The cluster node name.
.PARAMETER Purge
Remove container from all related configurations. For example, backup jobs, replication jobs or HA. Related ACLs and Firewall entries will *always* be removed.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Purge,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }
        if($PSBoundParameters['Purge']) { $parameters['purge'] = $Purge }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/lxc/$Vmid" -Parameters $parameters
    }
}

function Get-PveNodesLxcIdx
{
<#
.DESCRIPTION
Directory index
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid"
    }
}

function Get-PveNodesLxcConfig
{
<#
.DESCRIPTION
Get container configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Current
Get current values (instead of pending values).
.PARAMETER Node
The cluster node name.
.PARAMETER Snapshot
Fetch config values from given snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Current,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapshot,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Current']) { $parameters['current'] = $Current }
        if($PSBoundParameters['Snapshot']) { $parameters['snapshot'] = $Snapshot }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/config" -Parameters $parameters
    }
}

function Set-PveNodesLxcConfig
{
<#
.DESCRIPTION
Set container options.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Arch
OS architecture type.
.PARAMETER Cmode
Console mode. By default, the console command tries to open a connection to one of the available tty devices. By setting cmode to 'console' it tries to attach to /dev/console instead. If you set cmode to 'shell', it simply invokes a shell inside the container (no login).
.PARAMETER Console
Attach a console device (/dev/console) to the container.
.PARAMETER Cores
The number of cores assigned to the container. A container can use all available cores by default.
.PARAMETER Cpulimit
Limit of CPU usage.NOTE':' If the computer has 2 CPUs, it has a total of '2' CPU time. Value '0' indicates no CPU limit.
.PARAMETER Cpuunits
CPU weight for a VM. Argument is used in the kernel fair scheduler. The larger the number is, the more CPU time this VM gets. Number is relative to the weights of all the other running VMs.NOTE':' You can disable fair-scheduler configuration by setting this to 0.
.PARAMETER Debug
Try to be more verbose. For now this only enables debug log-level on start.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Description
Container description. Only used on the configuration web interface.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Features
Allow containers access to advanced features.
.PARAMETER Hookscript
Script that will be exectued during various steps in the containers lifetime.
.PARAMETER Hostname
Set a host name for the container.
.PARAMETER Lock
Lock/unlock the VM.
.PARAMETER Memory
Amount of RAM for the VM in MB.
.PARAMETER MpN
Use volume as container mount point.
.PARAMETER Nameserver
Sets DNS server IP address for a container. Create will automatically use the setting from the host if you neither set searchdomain nor nameserver.
.PARAMETER NetN
Specifies network interfaces for the container.
.PARAMETER Node
The cluster node name.
.PARAMETER Onboot
Specifies whether a VM will be started during system bootup.
.PARAMETER Ostype
OS type. This is used to setup configuration inside the container, and corresponds to lxc setup scripts in /usr/share/lxc/config/<ostype>.common.conf. Value 'unmanaged' can be used to skip and OS specific setup.
.PARAMETER Protection
Sets the protection flag of the container. This will prevent the CT or CT's disk remove/update operation.
.PARAMETER Revert
Revert a pending change.
.PARAMETER Rootfs
Use volume as container root.
.PARAMETER Searchdomain
Sets DNS search domains for a container. Create will automatically use the setting from the host if you neither set searchdomain nor nameserver.
.PARAMETER Startup
Startup and shutdown behavior. Order is a non-negative number defining the general startup order. Shutdown in done with reverse ordering. Additionally you can set the 'up' or 'down' delay in seconds, which specifies a delay to wait before the next VM is started or stopped.
.PARAMETER Swap
Amount of SWAP for the VM in MB.
.PARAMETER Tags
Tags of the Container. This is only meta information.
.PARAMETER Template
Enable/disable Template.
.PARAMETER Timezone
Time zone to use in the container. If option isn't set, then nothing will be done. Can be set to 'host' to match the host time zone, or an arbitrary time zone option from /usr/share/zoneinfo/zone.tab
.PARAMETER Tty
Specify the number of tty available to the container
.PARAMETER Unprivileged
Makes the container run as unprivileged user. (Should not be modified manually.)
.PARAMETER UnusedN
Reference to unused volumes. This is used internally, and should not be modified manually.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('amd64','i386','arm64','armhf')]
        [string]$Arch,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('shell','console','tty')]
        [string]$Cmode,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Console,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cores,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cpulimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Cpuunits,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Debug,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Features,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hookscript,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hostname,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('backup','create','destroyed','disk','fstrim','migrate','mounted','rollback','snapshot','snapshot-delete')]
        [string]$Lock,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Memory,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$MpN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Nameserver,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$NetN,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Onboot,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('debian','ubuntu','centos','fedora','opensuse','archlinux','alpine','gentoo','unmanaged')]
        [string]$Ostype,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Protection,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Revert,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Rootfs,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Searchdomain,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Startup,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Swap,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tags,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Template,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Timezone,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Tty,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Unprivileged,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$UnusedN,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Arch']) { $parameters['arch'] = $Arch }
        if($PSBoundParameters['Cmode']) { $parameters['cmode'] = $Cmode }
        if($PSBoundParameters['Console']) { $parameters['console'] = $Console }
        if($PSBoundParameters['Cores']) { $parameters['cores'] = $Cores }
        if($PSBoundParameters['Cpulimit']) { $parameters['cpulimit'] = $Cpulimit }
        if($PSBoundParameters['Cpuunits']) { $parameters['cpuunits'] = $Cpuunits }
        if($PSBoundParameters['Debug']) { $parameters['debug'] = $Debug }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Description']) { $parameters['description'] = $Description }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Features']) { $parameters['features'] = $Features }
        if($PSBoundParameters['Hookscript']) { $parameters['hookscript'] = $Hookscript }
        if($PSBoundParameters['Hostname']) { $parameters['hostname'] = $Hostname }
        if($PSBoundParameters['Lock']) { $parameters['lock'] = $Lock }
        if($PSBoundParameters['Memory']) { $parameters['memory'] = $Memory }
        if($PSBoundParameters['Nameserver']) { $parameters['nameserver'] = $Nameserver }
        if($PSBoundParameters['Onboot']) { $parameters['onboot'] = $Onboot }
        if($PSBoundParameters['Ostype']) { $parameters['ostype'] = $Ostype }
        if($PSBoundParameters['Protection']) { $parameters['protection'] = $Protection }
        if($PSBoundParameters['Revert']) { $parameters['revert'] = $Revert }
        if($PSBoundParameters['Rootfs']) { $parameters['rootfs'] = $Rootfs }
        if($PSBoundParameters['Searchdomain']) { $parameters['searchdomain'] = $Searchdomain }
        if($PSBoundParameters['Startup']) { $parameters['startup'] = $Startup }
        if($PSBoundParameters['Swap']) { $parameters['swap'] = $Swap }
        if($PSBoundParameters['Tags']) { $parameters['tags'] = $Tags }
        if($PSBoundParameters['Template']) { $parameters['template'] = $Template }
        if($PSBoundParameters['Timezone']) { $parameters['timezone'] = $Timezone }
        if($PSBoundParameters['Tty']) { $parameters['tty'] = $Tty }
        if($PSBoundParameters['Unprivileged']) { $parameters['unprivileged'] = $Unprivileged }

        if($PSBoundParameters['MpN']) { $MpN.keys | ForEach-Object { $parameters['mp' + $_] = $MpN[$_] } }
        if($PSBoundParameters['NetN']) { $NetN.keys | ForEach-Object { $parameters['net' + $_] = $NetN[$_] } }
        if($PSBoundParameters['UnusedN']) { $UnusedN.keys | ForEach-Object { $parameters['unused' + $_] = $UnusedN[$_] } }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/lxc/$Vmid/config" -Parameters $parameters
    }
}

function Get-PveNodesLxcStatus
{
<#
.DESCRIPTION
Directory index
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/status"
    }
}

function Get-PveNodesLxcStatusCurrent
{
<#
.DESCRIPTION
Get virtual machine status.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/status/current"
    }
}

function New-PveNodesLxcStatusStart
{
<#
.DESCRIPTION
Start the container.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Debug
If set, enables very verbose debug log-level on start.
.PARAMETER Node
The cluster node name.
.PARAMETER Skiplock
Ignore locks - only root is allowed to use this option.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Debug,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Skiplock,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Debug']) { $parameters['debug'] = $Debug }
        if($PSBoundParameters['Skiplock']) { $parameters['skiplock'] = $Skiplock }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/status/start" -Parameters $parameters
    }
}

function New-PveNodesLxcStatusStop
{
<#
.DESCRIPTION
Stop the container. This will abruptly stop all processes running in the container.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Skiplock
Ignore locks - only root is allowed to use this option.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Skiplock,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Skiplock']) { $parameters['skiplock'] = $Skiplock }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/status/stop" -Parameters $parameters
    }
}

function New-PveNodesLxcStatusShutdown
{
<#
.DESCRIPTION
Shutdown the container. This will trigger a clean shutdown of the container, see lxc-stop(1) for details.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Forcestop
Make sure the Container stops.
.PARAMETER Node
The cluster node name.
.PARAMETER Timeout
Wait maximal timeout seconds.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Forcestop,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Timeout,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Forcestop']) { $parameters['forceStop'] = $Forcestop }
        if($PSBoundParameters['Timeout']) { $parameters['timeout'] = $Timeout }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/status/shutdown" -Parameters $parameters
    }
}

function New-PveNodesLxcStatusSuspend
{
<#
.DESCRIPTION
Suspend the container.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/status/suspend"
    }
}

function New-PveNodesLxcStatusResume
{
<#
.DESCRIPTION
Resume the container.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/status/resume"
    }
}

function New-PveNodesLxcStatusReboot
{
<#
.DESCRIPTION
Reboot the container by shutting it down, and starting it again. Applies pending changes.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Timeout
Wait maximal timeout seconds for the shutdown.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Timeout,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Timeout']) { $parameters['timeout'] = $Timeout }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/status/reboot" -Parameters $parameters
    }
}

function Get-PveNodesLxcSnapshot
{
<#
.DESCRIPTION
List all snapshots.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/snapshot"
    }
}

function New-PveNodesLxcSnapshot
{
<#
.DESCRIPTION
Snapshot a container.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Description
A textual description or comment.
.PARAMETER Node
The cluster node name.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Description']) { $parameters['description'] = $Description }
        if($PSBoundParameters['Snapname']) { $parameters['snapname'] = $Snapname }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/snapshot" -Parameters $parameters
    }
}

function Remove-PveNodesLxcSnapshot
{
<#
.DESCRIPTION
Delete a LXC snapshot.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Force
For removal from config file, even if removing disk snapshots fails.
.PARAMETER Node
The cluster node name.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/lxc/$Vmid/snapshot/$Snapname" -Parameters $parameters
    }
}

function Get-PveNodesLxcSnapshotIdx
{
<#
.DESCRIPTION
--
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/snapshot/$Snapname"
    }
}

function New-PveNodesLxcSnapshotRollback
{
<#
.DESCRIPTION
Rollback LXC state to specified snapshot.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/snapshot/$Snapname/rollback"
    }
}

function Get-PveNodesLxcSnapshotConfig
{
<#
.DESCRIPTION
Get snapshot configuration
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/snapshot/$Snapname/config"
    }
}

function Set-PveNodesLxcSnapshotConfig
{
<#
.DESCRIPTION
Update snapshot metadata.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Description
A textual description or comment.
.PARAMETER Node
The cluster node name.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Description']) { $parameters['description'] = $Description }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/lxc/$Vmid/snapshot/$Snapname/config" -Parameters $parameters
    }
}

function Get-PveNodesLxcFirewall
{
<#
.DESCRIPTION
Directory index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/firewall"
    }
}

function Get-PveNodesLxcFirewallRules
{
<#
.DESCRIPTION
List rules.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/firewall/rules"
    }
}

function New-PveNodesLxcFirewallRules
{
<#
.DESCRIPTION
Create new rule.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Action
Rule action ('ACCEPT', 'DROP', 'REJECT') or security group name.
.PARAMETER Comment
Descriptive comment.
.PARAMETER Dest
Restrict packet destination address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Dport
Restrict TCP/UDP destination port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Enable
Flag to enable/disable a rule.
.PARAMETER Iface
Network interface name. You have to use network configuration key names for VMs and containers ('net\d+'). Host related rules can use arbitrary strings.
.PARAMETER Log
Log level for firewall rule.
.PARAMETER Macro
Use predefined standard macro.
.PARAMETER Node
The cluster node name.
.PARAMETER Pos
Update rule at position <pos>.
.PARAMETER Proto
IP protocol. You can use protocol names ('tcp'/'udp') or simple numbers, as defined in '/etc/protocols'.
.PARAMETER Source
Restrict packet source address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Sport
Restrict TCP/UDP source port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Type
Rule type.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Action,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Enable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iface,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$Log,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Macro,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Proto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Source,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sport,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('in','out','group')]
        [string]$Type,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Action']) { $parameters['action'] = $Action }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Dest']) { $parameters['dest'] = $Dest }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Dport']) { $parameters['dport'] = $Dport }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['Iface']) { $parameters['iface'] = $Iface }
        if($PSBoundParameters['Log']) { $parameters['log'] = $Log }
        if($PSBoundParameters['Macro']) { $parameters['macro'] = $Macro }
        if($PSBoundParameters['Pos']) { $parameters['pos'] = $Pos }
        if($PSBoundParameters['Proto']) { $parameters['proto'] = $Proto }
        if($PSBoundParameters['Source']) { $parameters['source'] = $Source }
        if($PSBoundParameters['Sport']) { $parameters['sport'] = $Sport }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/firewall/rules" -Parameters $parameters
    }
}

function Remove-PveNodesLxcFirewallRules
{
<#
.DESCRIPTION
Delete rule.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Node
The cluster node name.
.PARAMETER Pos
Update rule at position <pos>.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/lxc/$Vmid/firewall/rules/$Pos" -Parameters $parameters
    }
}

function Get-PveNodesLxcFirewallRulesIdx
{
<#
.DESCRIPTION
Get single rule data.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Pos
Update rule at position <pos>.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/firewall/rules/$Pos"
    }
}

function Set-PveNodesLxcFirewallRules
{
<#
.DESCRIPTION
Modify rule data.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Action
Rule action ('ACCEPT', 'DROP', 'REJECT') or security group name.
.PARAMETER Comment
Descriptive comment.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Dest
Restrict packet destination address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Dport
Restrict TCP/UDP destination port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Enable
Flag to enable/disable a rule.
.PARAMETER Iface
Network interface name. You have to use network configuration key names for VMs and containers ('net\d+'). Host related rules can use arbitrary strings.
.PARAMETER Log
Log level for firewall rule.
.PARAMETER Macro
Use predefined standard macro.
.PARAMETER Moveto
Move rule to new position <moveto>. Other arguments are ignored.
.PARAMETER Node
The cluster node name.
.PARAMETER Pos
Update rule at position <pos>.
.PARAMETER Proto
IP protocol. You can use protocol names ('tcp'/'udp') or simple numbers, as defined in '/etc/protocols'.
.PARAMETER Source
Restrict packet source address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Sport
Restrict TCP/UDP source port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Type
Rule type.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Action,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Enable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iface,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$Log,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Macro,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Moveto,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Proto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Source,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('in','out','group')]
        [string]$Type,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Action']) { $parameters['action'] = $Action }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Dest']) { $parameters['dest'] = $Dest }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Dport']) { $parameters['dport'] = $Dport }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['Iface']) { $parameters['iface'] = $Iface }
        if($PSBoundParameters['Log']) { $parameters['log'] = $Log }
        if($PSBoundParameters['Macro']) { $parameters['macro'] = $Macro }
        if($PSBoundParameters['Moveto']) { $parameters['moveto'] = $Moveto }
        if($PSBoundParameters['Proto']) { $parameters['proto'] = $Proto }
        if($PSBoundParameters['Source']) { $parameters['source'] = $Source }
        if($PSBoundParameters['Sport']) { $parameters['sport'] = $Sport }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/lxc/$Vmid/firewall/rules/$Pos" -Parameters $parameters
    }
}

function Get-PveNodesLxcFirewallAliases
{
<#
.DESCRIPTION
List aliases
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/firewall/aliases"
    }
}

function New-PveNodesLxcFirewallAliases
{
<#
.DESCRIPTION
Create IP or Network Alias.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Comment
--
.PARAMETER Name
Alias name.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cidr']) { $parameters['cidr'] = $Cidr }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/firewall/aliases" -Parameters $parameters
    }
}

function Remove-PveNodesLxcFirewallAliases
{
<#
.DESCRIPTION
Remove IP or Network alias.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
Alias name.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/lxc/$Vmid/firewall/aliases/$Name" -Parameters $parameters
    }
}

function Get-PveNodesLxcFirewallAliasesIdx
{
<#
.DESCRIPTION
Read alias.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Name
Alias name.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/firewall/aliases/$Name"
    }
}

function Set-PveNodesLxcFirewallAliases
{
<#
.DESCRIPTION
Update IP or Network alias.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Comment
--
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
Alias name.
.PARAMETER Node
The cluster node name.
.PARAMETER Rename
Rename an existing alias.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Rename,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cidr']) { $parameters['cidr'] = $Cidr }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Rename']) { $parameters['rename'] = $Rename }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/lxc/$Vmid/firewall/aliases/$Name" -Parameters $parameters
    }
}

function Get-PveNodesLxcFirewallIpset
{
<#
.DESCRIPTION
List IPSets
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/firewall/ipset"
    }
}

function New-PveNodesLxcFirewallIpset
{
<#
.DESCRIPTION
Create new IPSet
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
--
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
IP set name.
.PARAMETER Node
The cluster node name.
.PARAMETER Rename
Rename an existing IPSet. You can set 'rename' to the same value as 'name' to update the 'comment' of an existing IPSet.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Rename,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }
        if($PSBoundParameters['Rename']) { $parameters['rename'] = $Rename }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/firewall/ipset" -Parameters $parameters
    }
}

function Remove-PveNodesLxcFirewallIpset
{
<#
.DESCRIPTION
Delete IPSet
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Name
IP set name.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/lxc/$Vmid/firewall/ipset/$Name"
    }
}

function Get-PveNodesLxcFirewallIpsetIdx
{
<#
.DESCRIPTION
List IPSet content
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Name
IP set name.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/firewall/ipset/$Name"
    }
}

function New-PveNodesLxcFirewallIpsetIdx
{
<#
.DESCRIPTION
Add IP or Network to IPSet.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Comment
--
.PARAMETER Name
IP set name.
.PARAMETER Node
The cluster node name.
.PARAMETER Nomatch
--
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Nomatch,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cidr']) { $parameters['cidr'] = $Cidr }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Nomatch']) { $parameters['nomatch'] = $Nomatch }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/firewall/ipset/$Name" -Parameters $parameters
    }
}

function Remove-PveNodesLxcFirewallIpsetIdx
{
<#
.DESCRIPTION
Remove IP or Network from IPSet.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
IP set name.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/lxc/$Vmid/firewall/ipset/$Name/$Cidr" -Parameters $parameters
    }
}

function Get-PveNodesLxcFirewallIpsetIdx
{
<#
.DESCRIPTION
Read IP or Network settings from IPSet.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Name
IP set name.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/firewall/ipset/$Name/$Cidr"
    }
}

function Set-PveNodesLxcFirewallIpset
{
<#
.DESCRIPTION
Update IP or Network settings
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cidr
Network/IP specification in CIDR format.
.PARAMETER Comment
--
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Name
IP set name.
.PARAMETER Node
The cluster node name.
.PARAMETER Nomatch
--
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Nomatch,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Nomatch']) { $parameters['nomatch'] = $Nomatch }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/lxc/$Vmid/firewall/ipset/$Name/$Cidr" -Parameters $parameters
    }
}

function Get-PveNodesLxcFirewallOptions
{
<#
.DESCRIPTION
Get VM firewall options.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/firewall/options"
    }
}

function Set-PveNodesLxcFirewallOptions
{
<#
.DESCRIPTION
Set Firewall options.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Dhcp
Enable DHCP.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Enable
Enable/disable firewall rules.
.PARAMETER Ipfilter
Enable default IP filters. This is equivalent to adding an empty ipfilter-net<id> ipset for every interface. Such ipsets implicitly contain sane default restrictions such as restricting IPv6 link local addresses to the one derived from the interface's MAC address. For containers the configured IP addresses will be implicitly added.
.PARAMETER LogLevelIn
Log level for incoming traffic.
.PARAMETER LogLevelOut
Log level for outgoing traffic.
.PARAMETER Macfilter
Enable/disable MAC address filter.
.PARAMETER Ndp
Enable NDP (Neighbor Discovery Protocol).
.PARAMETER Node
The cluster node name.
.PARAMETER PolicyIn
Input policy.
.PARAMETER PolicyOut
Output policy.
.PARAMETER Radv
Allow sending Router Advertisement.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Dhcp,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Enable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Ipfilter,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$LogLevelIn,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$LogLevelOut,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Macfilter,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Ndp,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('ACCEPT','REJECT','DROP')]
        [string]$PolicyIn,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('ACCEPT','REJECT','DROP')]
        [string]$PolicyOut,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Radv,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Dhcp']) { $parameters['dhcp'] = $Dhcp }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['Ipfilter']) { $parameters['ipfilter'] = $Ipfilter }
        if($PSBoundParameters['LogLevelIn']) { $parameters['log_level_in'] = $LogLevelIn }
        if($PSBoundParameters['LogLevelOut']) { $parameters['log_level_out'] = $LogLevelOut }
        if($PSBoundParameters['Macfilter']) { $parameters['macfilter'] = $Macfilter }
        if($PSBoundParameters['Ndp']) { $parameters['ndp'] = $Ndp }
        if($PSBoundParameters['PolicyIn']) { $parameters['policy_in'] = $PolicyIn }
        if($PSBoundParameters['PolicyOut']) { $parameters['policy_out'] = $PolicyOut }
        if($PSBoundParameters['Radv']) { $parameters['radv'] = $Radv }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/lxc/$Vmid/firewall/options" -Parameters $parameters
    }
}

function Get-PveNodesLxcFirewallLog
{
<#
.DESCRIPTION
Read firewall log
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Limit
--
.PARAMETER Node
The cluster node name.
.PARAMETER Start
--
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Limit,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Start,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Limit']) { $parameters['limit'] = $Limit }
        if($PSBoundParameters['Start']) { $parameters['start'] = $Start }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/firewall/log" -Parameters $parameters
    }
}

function Get-PveNodesLxcFirewallRefs
{
<#
.DESCRIPTION
Lists possible IPSet/Alias reference which are allowed in source/dest properties.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Type
Only list references of specified type.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('alias','ipset')]
        [string]$Type,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/firewall/refs" -Parameters $parameters
    }
}

function Get-PveNodesLxcRrd
{
<#
.DESCRIPTION
Read VM RRD statistics (returns PNG)
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cf
The RRD consolidation function
.PARAMETER Ds
The list of datasources you want to display.
.PARAMETER Node
The cluster node name.
.PARAMETER Timeframe
Specify the time frame you are interested in.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('AVERAGE','MAX')]
        [string]$Cf,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ds,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('hour','day','week','month','year')]
        [string]$Timeframe,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cf']) { $parameters['cf'] = $Cf }
        if($PSBoundParameters['Ds']) { $parameters['ds'] = $Ds }
        if($PSBoundParameters['Timeframe']) { $parameters['timeframe'] = $Timeframe }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/rrd" -Parameters $parameters
    }
}

function Get-PveNodesLxcRrddata
{
<#
.DESCRIPTION
Read VM RRD statistics
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cf
The RRD consolidation function
.PARAMETER Node
The cluster node name.
.PARAMETER Timeframe
Specify the time frame you are interested in.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('AVERAGE','MAX')]
        [string]$Cf,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('hour','day','week','month','year')]
        [string]$Timeframe,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cf']) { $parameters['cf'] = $Cf }
        if($PSBoundParameters['Timeframe']) { $parameters['timeframe'] = $Timeframe }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/rrddata" -Parameters $parameters
    }
}

function New-PveNodesLxcVncproxy
{
<#
.DESCRIPTION
Creates a TCP VNC proxy connections.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Height
sets the height of the console in pixels.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.PARAMETER Websocket
use websocket instead of standard VNC.
.PARAMETER Width
sets the width of the console in pixels.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Height,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Websocket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Width
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Height']) { $parameters['height'] = $Height }
        if($PSBoundParameters['Websocket']) { $parameters['websocket'] = $Websocket }
        if($PSBoundParameters['Width']) { $parameters['width'] = $Width }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/vncproxy" -Parameters $parameters
    }
}

function New-PveNodesLxcTermproxy
{
<#
.DESCRIPTION
Creates a TCP proxy connection.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/termproxy"
    }
}

function Get-PveNodesLxcVncwebsocket
{
<#
.DESCRIPTION
Opens a weksocket for VNC traffic.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Port
Port number returned by previous vncproxy call.
.PARAMETER Vmid
The (unique) ID of the VM.
.PARAMETER Vncticket
Ticket from previous call to vncproxy.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Port,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vncticket
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Port']) { $parameters['port'] = $Port }
        if($PSBoundParameters['Vncticket']) { $parameters['vncticket'] = $Vncticket }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/vncwebsocket" -Parameters $parameters
    }
}

function New-PveNodesLxcSpiceproxy
{
<#
.DESCRIPTION
Returns a SPICE configuration to connect to the CT.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Proxy
SPICE proxy server. This can be used by the client to specify the proxy server. All nodes in a cluster runs 'spiceproxy', so it is up to the client to choose one. By default, we return the node where the VM is currently running. As reasonable setting is to use same node you use to connect to the API (This is window.location.hostname for the JS GUI).
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Proxy,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Proxy']) { $parameters['proxy'] = $Proxy }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/spiceproxy" -Parameters $parameters
    }
}

function New-PveNodesLxcMigrate
{
<#
.DESCRIPTION
Migrate the container to another node. Creates a new migration task.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Bwlimit
Override I/O bandwidth limit (in KiB/s).
.PARAMETER Force
Force migration despite local bind / device mounts. NOTE':' deprecated, use 'shared' property of mount point instead.
.PARAMETER Node
The cluster node name.
.PARAMETER Online
Use online/live migration.
.PARAMETER Restart
Use restart migration
.PARAMETER Target
Target node.
.PARAMETER Timeout
Timeout in seconds for shutdown for restart migration
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Bwlimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Online,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Restart,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Target,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Timeout,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Bwlimit']) { $parameters['bwlimit'] = $Bwlimit }
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }
        if($PSBoundParameters['Online']) { $parameters['online'] = $Online }
        if($PSBoundParameters['Restart']) { $parameters['restart'] = $Restart }
        if($PSBoundParameters['Target']) { $parameters['target'] = $Target }
        if($PSBoundParameters['Timeout']) { $parameters['timeout'] = $Timeout }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/migrate" -Parameters $parameters
    }
}

function Get-PveNodesLxcFeature
{
<#
.DESCRIPTION
Check if feature for virtual machine is available.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Feature
Feature to check.
.PARAMETER Node
The cluster node name.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('snapshot','clone','copy')]
        [string]$Feature,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Feature']) { $parameters['feature'] = $Feature }
        if($PSBoundParameters['Snapname']) { $parameters['snapname'] = $Snapname }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/feature" -Parameters $parameters
    }
}

function New-PveNodesLxcTemplate
{
<#
.DESCRIPTION
Create a Template.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/template"
    }
}

function New-PveNodesLxcClone
{
<#
.DESCRIPTION
Create a container clone/copy
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Bwlimit
Override I/O bandwidth limit (in KiB/s).
.PARAMETER Description
Description for the new CT.
.PARAMETER Full
Create a full copy of all disks. This is always done when you clone a normal CT. For CT templates, we try to create a linked clone by default.
.PARAMETER Hostname
Set a hostname for the new CT.
.PARAMETER Newid
VMID for the clone.
.PARAMETER Node
The cluster node name.
.PARAMETER Pool
Add the new CT to the specified pool.
.PARAMETER Snapname
The name of the snapshot.
.PARAMETER Storage
Target storage for full clone.
.PARAMETER Target
Target node. Only allowed if the original VM is on shared storage.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Bwlimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Full,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hostname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Newid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Pool,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Snapname,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Target,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Bwlimit']) { $parameters['bwlimit'] = $Bwlimit }
        if($PSBoundParameters['Description']) { $parameters['description'] = $Description }
        if($PSBoundParameters['Full']) { $parameters['full'] = $Full }
        if($PSBoundParameters['Hostname']) { $parameters['hostname'] = $Hostname }
        if($PSBoundParameters['Newid']) { $parameters['newid'] = $Newid }
        if($PSBoundParameters['Pool']) { $parameters['pool'] = $Pool }
        if($PSBoundParameters['Snapname']) { $parameters['snapname'] = $Snapname }
        if($PSBoundParameters['Storage']) { $parameters['storage'] = $Storage }
        if($PSBoundParameters['Target']) { $parameters['target'] = $Target }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/clone" -Parameters $parameters
    }
}

function Set-PveNodesLxcResize
{
<#
.DESCRIPTION
Resize a container mount point.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Disk
The disk you want to resize.
.PARAMETER Node
The cluster node name.
.PARAMETER Size
The new size. With the '+' sign the value is added to the actual size of the volume and without it, the value is taken as an absolute one. Shrinking disk size is not supported.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('rootfs','mp0','mp1','mp2','mp3','mp4','mp5','mp6','mp7','mp8','mp9','mp10','mp11','mp12','mp13','mp14','mp15','mp16','mp17','mp18','mp19','mp20','mp21','mp22','mp23','mp24','mp25','mp26','mp27','mp28','mp29','mp30','mp31','mp32','mp33','mp34','mp35','mp36','mp37','mp38','mp39','mp40','mp41','mp42','mp43','mp44','mp45','mp46','mp47','mp48','mp49','mp50','mp51','mp52','mp53','mp54','mp55','mp56','mp57','mp58','mp59','mp60','mp61','mp62','mp63','mp64','mp65','mp66','mp67','mp68','mp69','mp70','mp71','mp72','mp73','mp74','mp75','mp76','mp77','mp78','mp79','mp80','mp81','mp82','mp83','mp84','mp85','mp86','mp87','mp88','mp89','mp90','mp91','mp92','mp93','mp94','mp95','mp96','mp97','mp98','mp99','mp100','mp101','mp102','mp103','mp104','mp105','mp106','mp107','mp108','mp109','mp110','mp111','mp112','mp113','mp114','mp115','mp116','mp117','mp118','mp119','mp120','mp121','mp122','mp123','mp124','mp125','mp126','mp127','mp128','mp129','mp130','mp131','mp132','mp133','mp134','mp135','mp136','mp137','mp138','mp139','mp140','mp141','mp142','mp143','mp144','mp145','mp146','mp147','mp148','mp149','mp150','mp151','mp152','mp153','mp154','mp155','mp156','mp157','mp158','mp159','mp160','mp161','mp162','mp163','mp164','mp165','mp166','mp167','mp168','mp169','mp170','mp171','mp172','mp173','mp174','mp175','mp176','mp177','mp178','mp179','mp180','mp181','mp182','mp183','mp184','mp185','mp186','mp187','mp188','mp189','mp190','mp191','mp192','mp193','mp194','mp195','mp196','mp197','mp198','mp199','mp200','mp201','mp202','mp203','mp204','mp205','mp206','mp207','mp208','mp209','mp210','mp211','mp212','mp213','mp214','mp215','mp216','mp217','mp218','mp219','mp220','mp221','mp222','mp223','mp224','mp225','mp226','mp227','mp228','mp229','mp230','mp231','mp232','mp233','mp234','mp235','mp236','mp237','mp238','mp239','mp240','mp241','mp242','mp243','mp244','mp245','mp246','mp247','mp248','mp249','mp250','mp251','mp252','mp253','mp254','mp255')]
        [string]$Disk,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Size,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Disk']) { $parameters['disk'] = $Disk }
        if($PSBoundParameters['Size']) { $parameters['size'] = $Size }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/lxc/$Vmid/resize" -Parameters $parameters
    }
}

function New-PveNodesLxcMoveVolume
{
<#
.DESCRIPTION
Move a rootfs-/mp-volume to a different storage
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Bwlimit
Override I/O bandwidth limit (in KiB/s).
.PARAMETER Delete
Delete the original volume after successful copy. By default the original is kept as an unused volume entry.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Node
The cluster node name.
.PARAMETER Storage
Target Storage.
.PARAMETER Vmid
The (unique) ID of the VM.
.PARAMETER Volume
Volume which will be moved.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Bwlimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('rootfs','mp0','mp1','mp2','mp3','mp4','mp5','mp6','mp7','mp8','mp9','mp10','mp11','mp12','mp13','mp14','mp15','mp16','mp17','mp18','mp19','mp20','mp21','mp22','mp23','mp24','mp25','mp26','mp27','mp28','mp29','mp30','mp31','mp32','mp33','mp34','mp35','mp36','mp37','mp38','mp39','mp40','mp41','mp42','mp43','mp44','mp45','mp46','mp47','mp48','mp49','mp50','mp51','mp52','mp53','mp54','mp55','mp56','mp57','mp58','mp59','mp60','mp61','mp62','mp63','mp64','mp65','mp66','mp67','mp68','mp69','mp70','mp71','mp72','mp73','mp74','mp75','mp76','mp77','mp78','mp79','mp80','mp81','mp82','mp83','mp84','mp85','mp86','mp87','mp88','mp89','mp90','mp91','mp92','mp93','mp94','mp95','mp96','mp97','mp98','mp99','mp100','mp101','mp102','mp103','mp104','mp105','mp106','mp107','mp108','mp109','mp110','mp111','mp112','mp113','mp114','mp115','mp116','mp117','mp118','mp119','mp120','mp121','mp122','mp123','mp124','mp125','mp126','mp127','mp128','mp129','mp130','mp131','mp132','mp133','mp134','mp135','mp136','mp137','mp138','mp139','mp140','mp141','mp142','mp143','mp144','mp145','mp146','mp147','mp148','mp149','mp150','mp151','mp152','mp153','mp154','mp155','mp156','mp157','mp158','mp159','mp160','mp161','mp162','mp163','mp164','mp165','mp166','mp167','mp168','mp169','mp170','mp171','mp172','mp173','mp174','mp175','mp176','mp177','mp178','mp179','mp180','mp181','mp182','mp183','mp184','mp185','mp186','mp187','mp188','mp189','mp190','mp191','mp192','mp193','mp194','mp195','mp196','mp197','mp198','mp199','mp200','mp201','mp202','mp203','mp204','mp205','mp206','mp207','mp208','mp209','mp210','mp211','mp212','mp213','mp214','mp215','mp216','mp217','mp218','mp219','mp220','mp221','mp222','mp223','mp224','mp225','mp226','mp227','mp228','mp229','mp230','mp231','mp232','mp233','mp234','mp235','mp236','mp237','mp238','mp239','mp240','mp241','mp242','mp243','mp244','mp245','mp246','mp247','mp248','mp249','mp250','mp251','mp252','mp253','mp254','mp255')]
        [string]$Volume
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Bwlimit']) { $parameters['bwlimit'] = $Bwlimit }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Storage']) { $parameters['storage'] = $Storage }
        if($PSBoundParameters['Volume']) { $parameters['volume'] = $Volume }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/lxc/$Vmid/move_volume" -Parameters $parameters
    }
}

function Get-PveNodesLxcPending
{
<#
.DESCRIPTION
Get container configuration, including pending changes.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vmid
The (unique) ID of the VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/lxc/$Vmid/pending"
    }
}

function Get-PveNodesCeph
{
<#
.DESCRIPTION
Directory index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph"
    }
}

function Get-PveNodesCephOsd
{
<#
.DESCRIPTION
Get Ceph osd list/tree.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph/osd"
    }
}

function New-PveNodesCephOsd
{
<#
.DESCRIPTION
Create OSD
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER CrushDeviceClass
Set the device class of the OSD in crush.
.PARAMETER DbDev
Block device name for block.db.
.PARAMETER DbSize
Size in GiB for block.db.
.PARAMETER Dev
Block device name.
.PARAMETER Encrypted
Enables encryption of the OSD.
.PARAMETER Node
The cluster node name.
.PARAMETER WalDev
Block device name for block.wal.
.PARAMETER WalSize
Size in GiB for block.wal.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$CrushDeviceClass,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$DbDev,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$DbSize,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dev,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Encrypted,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$WalDev,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$WalSize
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['CrushDeviceClass']) { $parameters['crush-device-class'] = $CrushDeviceClass }
        if($PSBoundParameters['DbDev']) { $parameters['db_dev'] = $DbDev }
        if($PSBoundParameters['DbSize']) { $parameters['db_size'] = $DbSize }
        if($PSBoundParameters['Dev']) { $parameters['dev'] = $Dev }
        if($PSBoundParameters['Encrypted']) { $parameters['encrypted'] = $Encrypted }
        if($PSBoundParameters['WalDev']) { $parameters['wal_dev'] = $WalDev }
        if($PSBoundParameters['WalSize']) { $parameters['wal_size'] = $WalSize }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/ceph/osd" -Parameters $parameters
    }
}

function Remove-PveNodesCephOsd
{
<#
.DESCRIPTION
Destroy OSD
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cleanup
If set, we remove partition table entries.
.PARAMETER Node
The cluster node name.
.PARAMETER Osdid
OSD ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Cleanup,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Osdid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cleanup']) { $parameters['cleanup'] = $Cleanup }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/ceph/osd/$Osdid" -Parameters $parameters
    }
}

function New-PveNodesCephOsdIn
{
<#
.DESCRIPTION
ceph osd in
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Osdid
OSD ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Osdid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/ceph/osd/$Osdid/in"
    }
}

function New-PveNodesCephOsdOut
{
<#
.DESCRIPTION
ceph osd out
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Osdid
OSD ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Osdid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/ceph/osd/$Osdid/out"
    }
}

function New-PveNodesCephOsdScrub
{
<#
.DESCRIPTION
Instruct the OSD to scrub.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Deep
If set, instructs a deep scrub instead of a normal one.
.PARAMETER Node
The cluster node name.
.PARAMETER Osdid
OSD ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Deep,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Osdid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Deep']) { $parameters['deep'] = $Deep }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/ceph/osd/$Osdid/scrub" -Parameters $parameters
    }
}

function Get-PveNodesCephMds
{
<#
.DESCRIPTION
MDS directory index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph/mds"
    }
}

function Remove-PveNodesCephMds
{
<#
.DESCRIPTION
Destroy Ceph Metadata Server
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Name
The name (ID) of the mds
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/ceph/mds/$Name"
    }
}

function New-PveNodesCephMds
{
<#
.DESCRIPTION
Create Ceph Metadata Server (MDS)
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Hotstandby
Determines whether a ceph-mds daemon should poll and replay the log of an active MDS. Faster switch on MDS failure, but needs more idle resources.
.PARAMETER Name
The ID for the mds, when omitted the same as the nodename
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Hotstandby,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Hotstandby']) { $parameters['hotstandby'] = $Hotstandby }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/ceph/mds/$Name" -Parameters $parameters
    }
}

function Get-PveNodesCephMgr
{
<#
.DESCRIPTION
MGR directory index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph/mgr"
    }
}

function Remove-PveNodesCephMgr
{
<#
.DESCRIPTION
Destroy Ceph Manager.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Id
The ID of the manager
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/ceph/mgr/$Id"
    }
}

function New-PveNodesCephMgr
{
<#
.DESCRIPTION
Create Ceph Manager
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Id
The ID for the manager, when omitted the same as the nodename
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/ceph/mgr/$Id"
    }
}

function Get-PveNodesCephMon
{
<#
.DESCRIPTION
Get Ceph monitor list.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph/mon"
    }
}

function Remove-PveNodesCephMon
{
<#
.DESCRIPTION
Destroy Ceph Monitor and Manager.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Monid
Monitor ID
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Monid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/ceph/mon/$Monid"
    }
}

function New-PveNodesCephMon
{
<#
.DESCRIPTION
Create Ceph Monitor and Manager
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER MonAddress
Overwrites autodetected monitor IP address. Must be in the public network of ceph.
.PARAMETER Monid
The ID for the monitor, when omitted the same as the nodename
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$MonAddress,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Monid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['MonAddress']) { $parameters['mon-address'] = $MonAddress }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/ceph/mon/$Monid" -Parameters $parameters
    }
}

function Get-PveNodesCephFs
{
<#
.DESCRIPTION
Directory index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph/fs"
    }
}

function New-PveNodesCephFs
{
<#
.DESCRIPTION
Create a Ceph filesystem
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER AddStorage
Configure the created CephFS as storage for this cluster.
.PARAMETER Name
The ceph filesystem name.
.PARAMETER Node
The cluster node name.
.PARAMETER PgNum
Number of placement groups for the backing data pool. The metadata pool will use a quarter of this.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$AddStorage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$PgNum
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['AddStorage']) { $parameters['add-storage'] = $AddStorage }
        if($PSBoundParameters['PgNum']) { $parameters['pg_num'] = $PgNum }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/ceph/fs/$Name" -Parameters $parameters
    }
}

function Get-PveNodesCephDisks
{
<#
.DESCRIPTION
List local disks.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Type
Only list specific types of disks.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('unused','journal_disks')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph/disks" -Parameters $parameters
    }
}

function Get-PveNodesCephConfig
{
<#
.DESCRIPTION
Get Ceph configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph/config"
    }
}

function Get-PveNodesCephConfigdb
{
<#
.DESCRIPTION
Get Ceph configuration database.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph/configdb"
    }
}

function New-PveNodesCephInit
{
<#
.DESCRIPTION
Create initial ceph default configuration and setup symlinks.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER ClusterNetwork
Declare a separate cluster network, OSDs will routeheartbeat, object replication and recovery traffic over it
.PARAMETER DisableCephx
Disable cephx authentication.WARNING':' cephx is a security feature protecting against man-in-the-middle attacks. Only consider disabling cephx if your network is private!
.PARAMETER MinSize
Minimum number of available replicas per object to allow I/O
.PARAMETER Network
Use specific network for all ceph related traffic
.PARAMETER Node
The cluster node name.
.PARAMETER PgBits
Placement group bits, used to specify the default number of placement groups.NOTE':' 'osd pool default pg num' does not work for default pools.
.PARAMETER Size
Targeted number of replicas per object
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ClusterNetwork,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$DisableCephx,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$MinSize,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Network,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$PgBits,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Size
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['ClusterNetwork']) { $parameters['cluster-network'] = $ClusterNetwork }
        if($PSBoundParameters['DisableCephx']) { $parameters['disable_cephx'] = $DisableCephx }
        if($PSBoundParameters['MinSize']) { $parameters['min_size'] = $MinSize }
        if($PSBoundParameters['Network']) { $parameters['network'] = $Network }
        if($PSBoundParameters['PgBits']) { $parameters['pg_bits'] = $PgBits }
        if($PSBoundParameters['Size']) { $parameters['size'] = $Size }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/ceph/init" -Parameters $parameters
    }
}

function New-PveNodesCephStop
{
<#
.DESCRIPTION
Stop ceph services.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Service
Ceph service name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Service
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Service']) { $parameters['service'] = $Service }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/ceph/stop" -Parameters $parameters
    }
}

function New-PveNodesCephStart
{
<#
.DESCRIPTION
Start ceph services.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Service
Ceph service name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Service
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Service']) { $parameters['service'] = $Service }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/ceph/start" -Parameters $parameters
    }
}

function New-PveNodesCephRestart
{
<#
.DESCRIPTION
Restart ceph services.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Service
Ceph service name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Service
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Service']) { $parameters['service'] = $Service }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/ceph/restart" -Parameters $parameters
    }
}

function Get-PveNodesCephStatus
{
<#
.DESCRIPTION
Get ceph status.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph/status"
    }
}

function Get-PveNodesCephPools
{
<#
.DESCRIPTION
List all pools.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph/pools"
    }
}

function New-PveNodesCephPools
{
<#
.DESCRIPTION
Create POOL
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER AddStorages
Configure VM and CT storage using the new pool.
.PARAMETER Application
The application of the pool, 'rbd' by default.
.PARAMETER CrushRule
The rule to use for mapping object placement in the cluster.
.PARAMETER MinSize
Minimum number of replicas per object
.PARAMETER Name
The name of the pool. It must be unique.
.PARAMETER Node
The cluster node name.
.PARAMETER PgNum
Number of placement groups.
.PARAMETER Size
Number of replicas per object
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$AddStorages,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('rbd','cephfs','rgw')]
        [string]$Application,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$CrushRule,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$MinSize,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$PgNum,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Size
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['AddStorages']) { $parameters['add_storages'] = $AddStorages }
        if($PSBoundParameters['Application']) { $parameters['application'] = $Application }
        if($PSBoundParameters['CrushRule']) { $parameters['crush_rule'] = $CrushRule }
        if($PSBoundParameters['MinSize']) { $parameters['min_size'] = $MinSize }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }
        if($PSBoundParameters['PgNum']) { $parameters['pg_num'] = $PgNum }
        if($PSBoundParameters['Size']) { $parameters['size'] = $Size }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/ceph/pools" -Parameters $parameters
    }
}

function Remove-PveNodesCephPools
{
<#
.DESCRIPTION
Destroy pool
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Force
If true, destroys pool even if in use
.PARAMETER Name
The name of the pool. It must be unique.
.PARAMETER Node
The cluster node name.
.PARAMETER RemoveStorages
Remove all pveceph-managed storages configured for this pool
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$RemoveStorages
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }
        if($PSBoundParameters['RemoveStorages']) { $parameters['remove_storages'] = $RemoveStorages }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/ceph/pools/$Name" -Parameters $parameters
    }
}

function Get-PveNodesCephFlags
{
<#
.DESCRIPTION
get all set ceph flags
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph/flags"
    }
}

function Remove-PveNodesCephFlags
{
<#
.DESCRIPTION
Unset a ceph flag
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Flag
The ceph flag to unset
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('nobackfill','nodeep-scrub','nodown','noin','noout','norebalance','norecover','noscrub','notieragent','noup','pause')]
        [string]$Flag,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/ceph/flags/$Flag"
    }
}

function New-PveNodesCephFlags
{
<#
.DESCRIPTION
Set a specific ceph flag
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Flag
The ceph flag to set
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('nobackfill','nodeep-scrub','nodown','noin','noout','norebalance','norecover','noscrub','notieragent','noup','pause')]
        [string]$Flag,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/ceph/flags/$Flag"
    }
}

function Get-PveNodesCephCrush
{
<#
.DESCRIPTION
Get OSD crush map
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph/crush"
    }
}

function Get-PveNodesCephLog
{
<#
.DESCRIPTION
Read ceph log
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Limit
--
.PARAMETER Node
The cluster node name.
.PARAMETER Start
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Limit,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Start
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Limit']) { $parameters['limit'] = $Limit }
        if($PSBoundParameters['Start']) { $parameters['start'] = $Start }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph/log" -Parameters $parameters
    }
}

function Get-PveNodesCephRules
{
<#
.DESCRIPTION
List ceph rules.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/ceph/rules"
    }
}

function New-PveNodesVzdump
{
<#
.DESCRIPTION
Create backup.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER All
Backup all known guest systems on this host.
.PARAMETER Bwlimit
Limit I/O bandwidth (KBytes per second).
.PARAMETER Compress
Compress dump file.
.PARAMETER Dumpdir
Store resulting files to specified directory.
.PARAMETER Exclude
Exclude specified guest systems (assumes --all)
.PARAMETER ExcludePath
Exclude certain files/directories (shell globs).
.PARAMETER Ionice
Set CFQ ionice priority.
.PARAMETER Lockwait
Maximal time to wait for the global lock (minutes).
.PARAMETER Mailnotification
Specify when to send an email
.PARAMETER Mailto
Comma-separated list of email addresses that should receive email notifications.
.PARAMETER Maxfiles
Maximal number of backup files per guest system.
.PARAMETER Mode
Backup mode.
.PARAMETER Node
Only run if executed on this node.
.PARAMETER Pigz
Use pigz instead of gzip when N>0. N=1 uses half of cores, N>1 uses N as thread count.
.PARAMETER Pool
Backup all known guest systems included in the specified pool.
.PARAMETER PruneBackups
Use these retention options instead of those from the storage configuration.
.PARAMETER Quiet
Be quiet.
.PARAMETER Remove
Remove old backup files if there are more than 'maxfiles' backup files.
.PARAMETER Script
Use specified hook script.
.PARAMETER Size
Unused, will be removed in a future release.
.PARAMETER Stdexcludes
Exclude temporary files and logs.
.PARAMETER Stdout
Write tar to stdout, not to a file.
.PARAMETER Stop
Stop running backup jobs on this host.
.PARAMETER Stopwait
Maximal time to wait until a guest system is stopped (minutes).
.PARAMETER Storage
Store resulting file to this storage.
.PARAMETER Tmpdir
Store temporary files to specified directory.
.PARAMETER Vmid
The ID of the guest system you want to backup.
.PARAMETER Zstd
Zstd threads. N=0 uses half of the available cores, N>0 uses N as thread count.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$All,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Bwlimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('0','1','gzip','lzo','zstd')]
        [string]$Compress,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dumpdir,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Exclude,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ExcludePath,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Ionice,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Lockwait,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('always','failure')]
        [string]$Mailnotification,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Mailto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Maxfiles,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('snapshot','suspend','stop')]
        [string]$Mode,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pigz,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Pool,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$PruneBackups,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Quiet,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Remove,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Script,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Size,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Stdexcludes,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Stdout,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Stop,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Stopwait,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tmpdir,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vmid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Zstd
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['All']) { $parameters['all'] = $All }
        if($PSBoundParameters['Bwlimit']) { $parameters['bwlimit'] = $Bwlimit }
        if($PSBoundParameters['Compress']) { $parameters['compress'] = $Compress }
        if($PSBoundParameters['Dumpdir']) { $parameters['dumpdir'] = $Dumpdir }
        if($PSBoundParameters['Exclude']) { $parameters['exclude'] = $Exclude }
        if($PSBoundParameters['ExcludePath']) { $parameters['exclude-path'] = $ExcludePath }
        if($PSBoundParameters['Ionice']) { $parameters['ionice'] = $Ionice }
        if($PSBoundParameters['Lockwait']) { $parameters['lockwait'] = $Lockwait }
        if($PSBoundParameters['Mailnotification']) { $parameters['mailnotification'] = $Mailnotification }
        if($PSBoundParameters['Mailto']) { $parameters['mailto'] = $Mailto }
        if($PSBoundParameters['Maxfiles']) { $parameters['maxfiles'] = $Maxfiles }
        if($PSBoundParameters['Mode']) { $parameters['mode'] = $Mode }
        if($PSBoundParameters['Pigz']) { $parameters['pigz'] = $Pigz }
        if($PSBoundParameters['Pool']) { $parameters['pool'] = $Pool }
        if($PSBoundParameters['PruneBackups']) { $parameters['prune-backups'] = $PruneBackups }
        if($PSBoundParameters['Quiet']) { $parameters['quiet'] = $Quiet }
        if($PSBoundParameters['Remove']) { $parameters['remove'] = $Remove }
        if($PSBoundParameters['Script']) { $parameters['script'] = $Script }
        if($PSBoundParameters['Size']) { $parameters['size'] = $Size }
        if($PSBoundParameters['Stdexcludes']) { $parameters['stdexcludes'] = $Stdexcludes }
        if($PSBoundParameters['Stdout']) { $parameters['stdout'] = $Stdout }
        if($PSBoundParameters['Stop']) { $parameters['stop'] = $Stop }
        if($PSBoundParameters['Stopwait']) { $parameters['stopwait'] = $Stopwait }
        if($PSBoundParameters['Storage']) { $parameters['storage'] = $Storage }
        if($PSBoundParameters['Tmpdir']) { $parameters['tmpdir'] = $Tmpdir }
        if($PSBoundParameters['Vmid']) { $parameters['vmid'] = $Vmid }
        if($PSBoundParameters['Zstd']) { $parameters['zstd'] = $Zstd }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/vzdump" -Parameters $parameters
    }
}

function Get-PveNodesVzdumpExtractconfig
{
<#
.DESCRIPTION
Extract configuration from vzdump backup archive.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Volume
Volume identifier
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Volume
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Volume']) { $parameters['volume'] = $Volume }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/vzdump/extractconfig" -Parameters $parameters
    }
}

function Get-PveNodesServices
{
<#
.DESCRIPTION
Service list.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/services"
    }
}

function Get-PveNodesServicesIdx
{
<#
.DESCRIPTION
Directory index
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Service
Service ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('pveproxy','pvedaemon','spiceproxy','pvestatd','pve-cluster','corosync','pve-firewall','pvefw-logger','pve-ha-crm','pve-ha-lrm','sshd','syslog','cron','postfix','ksmtuned','systemd-timesyncd')]
        [string]$Service
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/services/$Service"
    }
}

function Get-PveNodesServicesState
{
<#
.DESCRIPTION
Read service properties
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Service
Service ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('pveproxy','pvedaemon','spiceproxy','pvestatd','pve-cluster','corosync','pve-firewall','pvefw-logger','pve-ha-crm','pve-ha-lrm','sshd','syslog','cron','postfix','ksmtuned','systemd-timesyncd')]
        [string]$Service
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/services/$Service/state"
    }
}

function New-PveNodesServicesStart
{
<#
.DESCRIPTION
Start service.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Service
Service ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('pveproxy','pvedaemon','spiceproxy','pvestatd','pve-cluster','corosync','pve-firewall','pvefw-logger','pve-ha-crm','pve-ha-lrm','sshd','syslog','cron','postfix','ksmtuned','systemd-timesyncd')]
        [string]$Service
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/services/$Service/start"
    }
}

function New-PveNodesServicesStop
{
<#
.DESCRIPTION
Stop service.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Service
Service ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('pveproxy','pvedaemon','spiceproxy','pvestatd','pve-cluster','corosync','pve-firewall','pvefw-logger','pve-ha-crm','pve-ha-lrm','sshd','syslog','cron','postfix','ksmtuned','systemd-timesyncd')]
        [string]$Service
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/services/$Service/stop"
    }
}

function New-PveNodesServicesRestart
{
<#
.DESCRIPTION
Hard restart service. Use reload if you want to reduce interruptions.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Service
Service ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('pveproxy','pvedaemon','spiceproxy','pvestatd','pve-cluster','corosync','pve-firewall','pvefw-logger','pve-ha-crm','pve-ha-lrm','sshd','syslog','cron','postfix','ksmtuned','systemd-timesyncd')]
        [string]$Service
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/services/$Service/restart"
    }
}

function New-PveNodesServicesReload
{
<#
.DESCRIPTION
Reload service. Falls back to restart if service cannot be reloaded.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Service
Service ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('pveproxy','pvedaemon','spiceproxy','pvestatd','pve-cluster','corosync','pve-firewall','pvefw-logger','pve-ha-crm','pve-ha-lrm','sshd','syslog','cron','postfix','ksmtuned','systemd-timesyncd')]
        [string]$Service
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/services/$Service/reload"
    }
}

function Remove-PveNodesSubscription
{
<#
.DESCRIPTION
Delete subscription key of this node.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/subscription"
    }
}

function Get-PveNodesSubscription
{
<#
.DESCRIPTION
Read subscription info.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/subscription"
    }
}

function New-PveNodesSubscription
{
<#
.DESCRIPTION
Update subscription info.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Force
Always connect to server, even if we have up to date info inside local cache.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/subscription" -Parameters $parameters
    }
}

function Set-PveNodesSubscription
{
<#
.DESCRIPTION
Set subscription key.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Key
Proxmox VE subscription key
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Key,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Key']) { $parameters['key'] = $Key }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/subscription" -Parameters $parameters
    }
}

function Remove-PveNodesNetwork
{
<#
.DESCRIPTION
Revert network configuration changes.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/network"
    }
}

function Get-PveNodesNetwork
{
<#
.DESCRIPTION
List available networks
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Type
Only list specific interface types.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('bridge','bond','eth','alias','vlan','OVSBridge','OVSBond','OVSPort','OVSIntPort','any_bridge')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/network" -Parameters $parameters
    }
}

function New-PveNodesNetwork
{
<#
.DESCRIPTION
Create network device configuration
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Address
IP address.
.PARAMETER Address6
IP address.
.PARAMETER Autostart
Automatically start interface on boot.
.PARAMETER BondPrimary
Specify the primary interface for active-backup bond.
.PARAMETER BondMode
Bonding mode.
.PARAMETER BondXmitHashPolicy
Selects the transmit hash policy to use for slave selection in balance-xor and 802.3ad modes.
.PARAMETER BridgePorts
Specify the interfaces you want to add to your bridge.
.PARAMETER BridgeVlanAware
Enable bridge vlan support.
.PARAMETER Cidr
IPv4 CIDR.
.PARAMETER Cidr6
IPv6 CIDR.
.PARAMETER Comments
Comments
.PARAMETER Comments6
Comments
.PARAMETER Gateway
Default gateway address.
.PARAMETER Gateway6
Default ipv6 gateway address.
.PARAMETER Iface
Network interface name.
.PARAMETER Mtu
MTU.
.PARAMETER Netmask
Network mask.
.PARAMETER Netmask6
Network mask.
.PARAMETER Node
The cluster node name.
.PARAMETER OvsBonds
Specify the interfaces used by the bonding device.
.PARAMETER OvsBridge
The OVS bridge associated with a OVS port. This is required when you create an OVS port.
.PARAMETER OvsOptions
OVS interface options.
.PARAMETER OvsPorts
Specify the interfaces you want to add to your bridge.
.PARAMETER OvsTag
Specify a VLan tag (used by OVSPort, OVSIntPort, OVSBond)
.PARAMETER Slaves
Specify the interfaces used by the bonding device.
.PARAMETER Type
Network interface type
.PARAMETER VlanId
vlan-id for a custom named vlan interface (ifupdown2 only).
.PARAMETER VlanRawDevice
Specify the raw interface for the vlan interface.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Address,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Address6,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Autostart,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$BondPrimary,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('balance-rr','active-backup','balance-xor','broadcast','802.3ad','balance-tlb','balance-alb','balance-slb','lacp-balance-slb','lacp-balance-tcp')]
        [string]$BondMode,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('layer2','layer2+3','layer3+4')]
        [string]$BondXmitHashPolicy,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$BridgePorts,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$BridgeVlanAware,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr6,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comments,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comments6,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Gateway,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Gateway6,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iface,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Mtu,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Netmask,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Netmask6,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$OvsBonds,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$OvsBridge,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$OvsOptions,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$OvsPorts,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$OvsTag,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Slaves,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('bridge','bond','eth','alias','vlan','OVSBridge','OVSBond','OVSPort','OVSIntPort','unknown')]
        [string]$Type,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$VlanId,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VlanRawDevice
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Address']) { $parameters['address'] = $Address }
        if($PSBoundParameters['Address6']) { $parameters['address6'] = $Address6 }
        if($PSBoundParameters['Autostart']) { $parameters['autostart'] = $Autostart }
        if($PSBoundParameters['BondPrimary']) { $parameters['bond-primary'] = $BondPrimary }
        if($PSBoundParameters['BondMode']) { $parameters['bond_mode'] = $BondMode }
        if($PSBoundParameters['BondXmitHashPolicy']) { $parameters['bond_xmit_hash_policy'] = $BondXmitHashPolicy }
        if($PSBoundParameters['BridgePorts']) { $parameters['bridge_ports'] = $BridgePorts }
        if($PSBoundParameters['BridgeVlanAware']) { $parameters['bridge_vlan_aware'] = $BridgeVlanAware }
        if($PSBoundParameters['Cidr']) { $parameters['cidr'] = $Cidr }
        if($PSBoundParameters['Cidr6']) { $parameters['cidr6'] = $Cidr6 }
        if($PSBoundParameters['Comments']) { $parameters['comments'] = $Comments }
        if($PSBoundParameters['Comments6']) { $parameters['comments6'] = $Comments6 }
        if($PSBoundParameters['Gateway']) { $parameters['gateway'] = $Gateway }
        if($PSBoundParameters['Gateway6']) { $parameters['gateway6'] = $Gateway6 }
        if($PSBoundParameters['Iface']) { $parameters['iface'] = $Iface }
        if($PSBoundParameters['Mtu']) { $parameters['mtu'] = $Mtu }
        if($PSBoundParameters['Netmask']) { $parameters['netmask'] = $Netmask }
        if($PSBoundParameters['Netmask6']) { $parameters['netmask6'] = $Netmask6 }
        if($PSBoundParameters['OvsBonds']) { $parameters['ovs_bonds'] = $OvsBonds }
        if($PSBoundParameters['OvsBridge']) { $parameters['ovs_bridge'] = $OvsBridge }
        if($PSBoundParameters['OvsOptions']) { $parameters['ovs_options'] = $OvsOptions }
        if($PSBoundParameters['OvsPorts']) { $parameters['ovs_ports'] = $OvsPorts }
        if($PSBoundParameters['OvsTag']) { $parameters['ovs_tag'] = $OvsTag }
        if($PSBoundParameters['Slaves']) { $parameters['slaves'] = $Slaves }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }
        if($PSBoundParameters['VlanId']) { $parameters['vlan-id'] = $VlanId }
        if($PSBoundParameters['VlanRawDevice']) { $parameters['vlan-raw-device'] = $VlanRawDevice }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/network" -Parameters $parameters
    }
}

function Set-PveNodesNetwork
{
<#
.DESCRIPTION
Reload network configuration
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/network"
    }
}

function Remove-PveNodesNetworkIdx
{
<#
.DESCRIPTION
Delete network device configuration
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Iface
Network interface name.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iface,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/network/$Iface"
    }
}

function Get-PveNodesNetworkIdx
{
<#
.DESCRIPTION
Read network device configuration
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Iface
Network interface name.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iface,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/network/$Iface"
    }
}

function Set-PveNodesNetworkIdx
{
<#
.DESCRIPTION
Update network device configuration
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Address
IP address.
.PARAMETER Address6
IP address.
.PARAMETER Autostart
Automatically start interface on boot.
.PARAMETER BondPrimary
Specify the primary interface for active-backup bond.
.PARAMETER BondMode
Bonding mode.
.PARAMETER BondXmitHashPolicy
Selects the transmit hash policy to use for slave selection in balance-xor and 802.3ad modes.
.PARAMETER BridgePorts
Specify the interfaces you want to add to your bridge.
.PARAMETER BridgeVlanAware
Enable bridge vlan support.
.PARAMETER Cidr
IPv4 CIDR.
.PARAMETER Cidr6
IPv6 CIDR.
.PARAMETER Comments
Comments
.PARAMETER Comments6
Comments
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Gateway
Default gateway address.
.PARAMETER Gateway6
Default ipv6 gateway address.
.PARAMETER Iface
Network interface name.
.PARAMETER Mtu
MTU.
.PARAMETER Netmask
Network mask.
.PARAMETER Netmask6
Network mask.
.PARAMETER Node
The cluster node name.
.PARAMETER OvsBonds
Specify the interfaces used by the bonding device.
.PARAMETER OvsBridge
The OVS bridge associated with a OVS port. This is required when you create an OVS port.
.PARAMETER OvsOptions
OVS interface options.
.PARAMETER OvsPorts
Specify the interfaces you want to add to your bridge.
.PARAMETER OvsTag
Specify a VLan tag (used by OVSPort, OVSIntPort, OVSBond)
.PARAMETER Slaves
Specify the interfaces used by the bonding device.
.PARAMETER Type
Network interface type
.PARAMETER VlanId
vlan-id for a custom named vlan interface (ifupdown2 only).
.PARAMETER VlanRawDevice
Specify the raw interface for the vlan interface.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Address,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Address6,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Autostart,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$BondPrimary,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('balance-rr','active-backup','balance-xor','broadcast','802.3ad','balance-tlb','balance-alb','balance-slb','lacp-balance-slb','lacp-balance-tcp')]
        [string]$BondMode,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('layer2','layer2+3','layer3+4')]
        [string]$BondXmitHashPolicy,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$BridgePorts,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$BridgeVlanAware,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cidr6,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comments,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comments6,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Gateway,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Gateway6,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iface,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Mtu,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Netmask,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Netmask6,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$OvsBonds,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$OvsBridge,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$OvsOptions,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$OvsPorts,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$OvsTag,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Slaves,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('bridge','bond','eth','alias','vlan','OVSBridge','OVSBond','OVSPort','OVSIntPort','unknown')]
        [string]$Type,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$VlanId,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VlanRawDevice
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Address']) { $parameters['address'] = $Address }
        if($PSBoundParameters['Address6']) { $parameters['address6'] = $Address6 }
        if($PSBoundParameters['Autostart']) { $parameters['autostart'] = $Autostart }
        if($PSBoundParameters['BondPrimary']) { $parameters['bond-primary'] = $BondPrimary }
        if($PSBoundParameters['BondMode']) { $parameters['bond_mode'] = $BondMode }
        if($PSBoundParameters['BondXmitHashPolicy']) { $parameters['bond_xmit_hash_policy'] = $BondXmitHashPolicy }
        if($PSBoundParameters['BridgePorts']) { $parameters['bridge_ports'] = $BridgePorts }
        if($PSBoundParameters['BridgeVlanAware']) { $parameters['bridge_vlan_aware'] = $BridgeVlanAware }
        if($PSBoundParameters['Cidr']) { $parameters['cidr'] = $Cidr }
        if($PSBoundParameters['Cidr6']) { $parameters['cidr6'] = $Cidr6 }
        if($PSBoundParameters['Comments']) { $parameters['comments'] = $Comments }
        if($PSBoundParameters['Comments6']) { $parameters['comments6'] = $Comments6 }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Gateway']) { $parameters['gateway'] = $Gateway }
        if($PSBoundParameters['Gateway6']) { $parameters['gateway6'] = $Gateway6 }
        if($PSBoundParameters['Mtu']) { $parameters['mtu'] = $Mtu }
        if($PSBoundParameters['Netmask']) { $parameters['netmask'] = $Netmask }
        if($PSBoundParameters['Netmask6']) { $parameters['netmask6'] = $Netmask6 }
        if($PSBoundParameters['OvsBonds']) { $parameters['ovs_bonds'] = $OvsBonds }
        if($PSBoundParameters['OvsBridge']) { $parameters['ovs_bridge'] = $OvsBridge }
        if($PSBoundParameters['OvsOptions']) { $parameters['ovs_options'] = $OvsOptions }
        if($PSBoundParameters['OvsPorts']) { $parameters['ovs_ports'] = $OvsPorts }
        if($PSBoundParameters['OvsTag']) { $parameters['ovs_tag'] = $OvsTag }
        if($PSBoundParameters['Slaves']) { $parameters['slaves'] = $Slaves }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }
        if($PSBoundParameters['VlanId']) { $parameters['vlan-id'] = $VlanId }
        if($PSBoundParameters['VlanRawDevice']) { $parameters['vlan-raw-device'] = $VlanRawDevice }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/network/$Iface" -Parameters $parameters
    }
}

function Get-PveNodesTasks
{
<#
.DESCRIPTION
Read task list for one node (finished tasks).
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Errors
--
.PARAMETER Limit
Only list this amount of tasks.
.PARAMETER Node
The cluster node name.
.PARAMETER Source
List archived, active or all tasks.
.PARAMETER Start
List tasks beginning from this offset.
.PARAMETER Typefilter
Only list tasks of this type (e.g., vzstart, vzdump).
.PARAMETER Userfilter
Only list tasks from this user.
.PARAMETER Vmid
Only list tasks for this VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Errors,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Limit,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('archive','active','all')]
        [string]$Source,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Start,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Typefilter,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Userfilter,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Errors']) { $parameters['errors'] = $Errors }
        if($PSBoundParameters['Limit']) { $parameters['limit'] = $Limit }
        if($PSBoundParameters['Source']) { $parameters['source'] = $Source }
        if($PSBoundParameters['Start']) { $parameters['start'] = $Start }
        if($PSBoundParameters['Typefilter']) { $parameters['typefilter'] = $Typefilter }
        if($PSBoundParameters['Userfilter']) { $parameters['userfilter'] = $Userfilter }
        if($PSBoundParameters['Vmid']) { $parameters['vmid'] = $Vmid }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/tasks" -Parameters $parameters
    }
}

function Remove-PveNodesTasks
{
<#
.DESCRIPTION
Stop a task.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Upid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Upid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/tasks/$Upid"
    }
}

function Get-PveNodesTasksIdx
{
<#
.DESCRIPTION
--
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Upid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Upid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/tasks/$Upid"
    }
}

function Get-PveNodesTasksLog
{
<#
.DESCRIPTION
Read task log.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Limit
--
.PARAMETER Node
The cluster node name.
.PARAMETER Start
--
.PARAMETER Upid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Limit,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Start,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Upid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Limit']) { $parameters['limit'] = $Limit }
        if($PSBoundParameters['Start']) { $parameters['start'] = $Start }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/tasks/$Upid/log" -Parameters $parameters
    }
}

function Get-PveNodesTasksStatus
{
<#
.DESCRIPTION
Read task status.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Upid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Upid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/tasks/$Upid/status"
    }
}

function Get-PveNodesScan
{
<#
.DESCRIPTION
Index of available scan methods
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/scan"
    }
}

function Get-PveNodesScanZfs
{
<#
.DESCRIPTION
Scan zfs pool list on local node.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/scan/zfs"
    }
}

function Get-PveNodesScanNfs
{
<#
.DESCRIPTION
Scan remote NFS server.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Server
The server address (name or IP).
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Server
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Server']) { $parameters['server'] = $Server }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/scan/nfs" -Parameters $parameters
    }
}

function Get-PveNodesScanCifs
{
<#
.DESCRIPTION
Scan remote CIFS server.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Domain
SMB domain (Workgroup).
.PARAMETER Node
The cluster node name.
.PARAMETER Password
User password.
.PARAMETER Server
The server address (name or IP).
.PARAMETER Username
User name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Domain,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Password,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Server,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Username
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Domain']) { $parameters['domain'] = $Domain }
        if($PSBoundParameters['Password']) { $parameters['password'] = (ConvertFrom-SecureString -SecureString $Password -AsPlainText) }
        if($PSBoundParameters['Server']) { $parameters['server'] = $Server }
        if($PSBoundParameters['Username']) { $parameters['username'] = $Username }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/scan/cifs" -Parameters $parameters
    }
}

function Get-PveNodesScanGlusterfs
{
<#
.DESCRIPTION
Scan remote GlusterFS server.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Server
The server address (name or IP).
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Server
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Server']) { $parameters['server'] = $Server }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/scan/glusterfs" -Parameters $parameters
    }
}

function Get-PveNodesScanIscsi
{
<#
.DESCRIPTION
Scan remote iSCSI server.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Portal
The iSCSI portal (IP or DNS name with optional port).
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Portal
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Portal']) { $parameters['portal'] = $Portal }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/scan/iscsi" -Parameters $parameters
    }
}

function Get-PveNodesScanLvm
{
<#
.DESCRIPTION
List local LVM volume groups.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/scan/lvm"
    }
}

function Get-PveNodesScanLvmthin
{
<#
.DESCRIPTION
List local LVM Thin Pools.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vg
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vg
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Vg']) { $parameters['vg'] = $Vg }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/scan/lvmthin" -Parameters $parameters
    }
}

function Get-PveNodesScanUsb
{
<#
.DESCRIPTION
List local USB devices.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/scan/usb"
    }
}

function Get-PveNodesHardware
{
<#
.DESCRIPTION
Index of hardware types
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/hardware"
    }
}

function Get-PveNodesHardwarePci
{
<#
.DESCRIPTION
List local PCI devices.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER PciClassBlacklist
A list of blacklisted PCI classes, which will not be returned. Following are filtered by default':' Memory Controller (05), Bridge (06), Generic System Peripheral (08) and Processor (0b).
.PARAMETER Verbose_
If disabled, does only print the PCI IDs. Otherwise, additional information like vendor and device will be returned.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$PciClassBlacklist,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Verbose_
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['PciClassBlacklist']) { $parameters['pci-class-blacklist'] = $PciClassBlacklist }
        if($PSBoundParameters['Verbose_']) { $parameters['verbose'] = $Verbose_ }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/hardware/pci" -Parameters $parameters
    }
}

function Get-PveNodesHardwarePciIdx
{
<#
.DESCRIPTION
Index of available pci methods
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Pciid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Pciid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/hardware/pci/$Pciid"
    }
}

function Get-PveNodesHardwarePciMdev
{
<#
.DESCRIPTION
List mediated device types for given PCI device.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Pciid
The PCI ID to list the mdev types for.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Pciid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/hardware/pci/$Pciid/mdev"
    }
}

function Get-PveNodesStorage
{
<#
.DESCRIPTION
Get status for all datastores.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Content
Only list stores which support this content type.
.PARAMETER Enabled
Only list stores which are enabled (not disabled in config).
.PARAMETER Format
Include information about formats
.PARAMETER Node
The cluster node name.
.PARAMETER Storage
Only list status for  specified storage
.PARAMETER Target
If target is different to 'node', we only lists shared storages which content is accessible on this 'node' and the specified 'target' node.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Content,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Enabled,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Format,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Target
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Content']) { $parameters['content'] = $Content }
        if($PSBoundParameters['Enabled']) { $parameters['enabled'] = $Enabled }
        if($PSBoundParameters['Format']) { $parameters['format'] = $Format }
        if($PSBoundParameters['Storage']) { $parameters['storage'] = $Storage }
        if($PSBoundParameters['Target']) { $parameters['target'] = $Target }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/storage" -Parameters $parameters
    }
}

function Get-PveNodesStorageIdx
{
<#
.DESCRIPTION
--
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Storage
The storage identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/storage/$Storage"
    }
}

function Remove-PveNodesStoragePrunebackups
{
<#
.DESCRIPTION
Prune backups. Only those using the standard naming scheme are considered.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER PruneBackups
Use these retention options instead of those from the storage configuration.
.PARAMETER Storage
The storage identifier.
.PARAMETER Type
Either 'qemu' or 'lxc'. Only consider backups for guests of this type.
.PARAMETER Vmid
Only prune backups for this VM.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$PruneBackups,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('qemu','lxc')]
        [string]$Type,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['PruneBackups']) { $parameters['prune-backups'] = $PruneBackups }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }
        if($PSBoundParameters['Vmid']) { $parameters['vmid'] = $Vmid }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/storage/$Storage/prunebackups" -Parameters $parameters
    }
}

function Get-PveNodesStoragePrunebackups
{
<#
.DESCRIPTION
Get prune information for backups. NOTE':' this is only a preview and might not be exactly what a subsequent prune call does, if the hour changes or if backups are removed/added in the meantime.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER PruneBackups
Use these retention options instead of those from the storage configuration.
.PARAMETER Storage
The storage identifier.
.PARAMETER Type
Either 'qemu' or 'lxc'. Only consider backups for guests of this type.
.PARAMETER Vmid
Only consider backups for this guest.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$PruneBackups,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('qemu','lxc')]
        [string]$Type,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['PruneBackups']) { $parameters['prune-backups'] = $PruneBackups }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }
        if($PSBoundParameters['Vmid']) { $parameters['vmid'] = $Vmid }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/storage/$Storage/prunebackups" -Parameters $parameters
    }
}

function Get-PveNodesStorageContent
{
<#
.DESCRIPTION
List storage content.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Content
Only list content of this type.
.PARAMETER Node
The cluster node name.
.PARAMETER Storage
The storage identifier.
.PARAMETER Vmid
Only list images for this VM
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Content,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Content']) { $parameters['content'] = $Content }
        if($PSBoundParameters['Vmid']) { $parameters['vmid'] = $Vmid }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/storage/$Storage/content" -Parameters $parameters
    }
}

function New-PveNodesStorageContent
{
<#
.DESCRIPTION
Allocate disk images.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Filename
The name of the file to create.
.PARAMETER Format
--
.PARAMETER Node
The cluster node name.
.PARAMETER Size
Size in kilobyte (1024 bytes). Optional suffixes 'M' (megabyte, 1024K) and 'G' (gigabyte, 1024M)
.PARAMETER Storage
The storage identifier.
.PARAMETER Vmid
Specify owner VM
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Filename,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('raw','qcow2','subvol')]
        [string]$Format,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Size,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Vmid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Filename']) { $parameters['filename'] = $Filename }
        if($PSBoundParameters['Format']) { $parameters['format'] = $Format }
        if($PSBoundParameters['Size']) { $parameters['size'] = $Size }
        if($PSBoundParameters['Vmid']) { $parameters['vmid'] = $Vmid }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/storage/$Storage/content" -Parameters $parameters
    }
}

function Remove-PveNodesStorageContent
{
<#
.DESCRIPTION
Delete volume
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Delay
Time to wait for the task to finish. We return 'null' if the task finish within that time.
.PARAMETER Node
The cluster node name.
.PARAMETER Storage
The storage identifier.
.PARAMETER Volume
Volume identifier
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Delay,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Volume
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Delay']) { $parameters['delay'] = $Delay }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/storage/$Storage/content/$Volume" -Parameters $parameters
    }
}

function Get-PveNodesStorageContentIdx
{
<#
.DESCRIPTION
Get volume attributes
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Storage
The storage identifier.
.PARAMETER Volume
Volume identifier
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Volume
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/storage/$Storage/content/$Volume"
    }
}

function New-PveNodesStorageContentIdx
{
<#
.DESCRIPTION
Copy a volume. This is experimental code - do not use.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Storage
The storage identifier.
.PARAMETER Target
Target volume identifier
.PARAMETER TargetNode
Target node. Default is local node.
.PARAMETER Volume
Source volume identifier
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Target,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$TargetNode,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Volume
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Target']) { $parameters['target'] = $Target }
        if($PSBoundParameters['TargetNode']) { $parameters['target_node'] = $TargetNode }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/storage/$Storage/content/$Volume" -Parameters $parameters
    }
}

function Get-PveNodesStorageStatus
{
<#
.DESCRIPTION
Read storage status.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Storage
The storage identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/storage/$Storage/status"
    }
}

function Get-PveNodesStorageRrd
{
<#
.DESCRIPTION
Read storage RRD statistics (returns PNG).
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cf
The RRD consolidation function
.PARAMETER Ds
The list of datasources you want to display.
.PARAMETER Node
The cluster node name.
.PARAMETER Storage
The storage identifier.
.PARAMETER Timeframe
Specify the time frame you are interested in.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('AVERAGE','MAX')]
        [string]$Cf,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ds,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('hour','day','week','month','year')]
        [string]$Timeframe
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cf']) { $parameters['cf'] = $Cf }
        if($PSBoundParameters['Ds']) { $parameters['ds'] = $Ds }
        if($PSBoundParameters['Timeframe']) { $parameters['timeframe'] = $Timeframe }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/storage/$Storage/rrd" -Parameters $parameters
    }
}

function Get-PveNodesStorageRrddata
{
<#
.DESCRIPTION
Read storage RRD statistics.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cf
The RRD consolidation function
.PARAMETER Node
The cluster node name.
.PARAMETER Storage
The storage identifier.
.PARAMETER Timeframe
Specify the time frame you are interested in.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('AVERAGE','MAX')]
        [string]$Cf,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('hour','day','week','month','year')]
        [string]$Timeframe
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cf']) { $parameters['cf'] = $Cf }
        if($PSBoundParameters['Timeframe']) { $parameters['timeframe'] = $Timeframe }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/storage/$Storage/rrddata" -Parameters $parameters
    }
}

function New-PveNodesStorageUpload
{
<#
.DESCRIPTION
Upload templates and ISO images.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Content
Content type.
.PARAMETER Filename
The name of the file to create.
.PARAMETER Node
The cluster node name.
.PARAMETER Storage
The storage identifier.
.PARAMETER Tmpfilename
The source file name. This parameter is usually set by the REST handler. You can only overwrite it when connecting to the trusted port on localhost.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Content,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Filename,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tmpfilename
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Content']) { $parameters['content'] = $Content }
        if($PSBoundParameters['Filename']) { $parameters['filename'] = $Filename }
        if($PSBoundParameters['Tmpfilename']) { $parameters['tmpfilename'] = $Tmpfilename }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/storage/$Storage/upload" -Parameters $parameters
    }
}

function Get-PveNodesDisks
{
<#
.DESCRIPTION
Node index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/disks"
    }
}

function Get-PveNodesDisksLvm
{
<#
.DESCRIPTION
List LVM Volume Groups
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/disks/lvm"
    }
}

function New-PveNodesDisksLvm
{
<#
.DESCRIPTION
Create an LVM Volume Group
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER AddStorage
Configure storage using the Volume Group
.PARAMETER Device
The block device you want to create the volume group on
.PARAMETER Name
The storage identifier.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$AddStorage,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Device,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['AddStorage']) { $parameters['add_storage'] = $AddStorage }
        if($PSBoundParameters['Device']) { $parameters['device'] = $Device }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/disks/lvm" -Parameters $parameters
    }
}

function Get-PveNodesDisksLvmthin
{
<#
.DESCRIPTION
List LVM thinpools
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/disks/lvmthin"
    }
}

function New-PveNodesDisksLvmthin
{
<#
.DESCRIPTION
Create an LVM thinpool
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER AddStorage
Configure storage using the thinpool.
.PARAMETER Device
The block device you want to create the thinpool on.
.PARAMETER Name
The storage identifier.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$AddStorage,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Device,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['AddStorage']) { $parameters['add_storage'] = $AddStorage }
        if($PSBoundParameters['Device']) { $parameters['device'] = $Device }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/disks/lvmthin" -Parameters $parameters
    }
}

function Get-PveNodesDisksDirectory
{
<#
.DESCRIPTION
PVE Managed Directory storages.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/disks/directory"
    }
}

function New-PveNodesDisksDirectory
{
<#
.DESCRIPTION
Create a Filesystem on an unused disk. Will be mounted under '/mnt/pve/NAME'.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER AddStorage
Configure storage using the directory.
.PARAMETER Device
The block device you want to create the filesystem on.
.PARAMETER Filesystem
The desired filesystem.
.PARAMETER Name
The storage identifier.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$AddStorage,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Device,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('ext4','xfs')]
        [string]$Filesystem,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['AddStorage']) { $parameters['add_storage'] = $AddStorage }
        if($PSBoundParameters['Device']) { $parameters['device'] = $Device }
        if($PSBoundParameters['Filesystem']) { $parameters['filesystem'] = $Filesystem }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/disks/directory" -Parameters $parameters
    }
}

function Get-PveNodesDisksZfs
{
<#
.DESCRIPTION
List Zpools.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/disks/zfs"
    }
}

function New-PveNodesDisksZfs
{
<#
.DESCRIPTION
Create a ZFS pool.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER AddStorage
Configure storage using the zpool.
.PARAMETER Ashift
Pool sector size exponent.
.PARAMETER Compression
The compression algorithm to use.
.PARAMETER Devices
The block devices you want to create the zpool on.
.PARAMETER Name
The storage identifier.
.PARAMETER Node
The cluster node name.
.PARAMETER Raidlevel
The RAID level to use.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$AddStorage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Ashift,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('on','off','gzip','lz4','lzjb','zle')]
        [string]$Compression,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Devices,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('single','mirror','raid10','raidz','raidz2','raidz3')]
        [string]$Raidlevel
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['AddStorage']) { $parameters['add_storage'] = $AddStorage }
        if($PSBoundParameters['Ashift']) { $parameters['ashift'] = $Ashift }
        if($PSBoundParameters['Compression']) { $parameters['compression'] = $Compression }
        if($PSBoundParameters['Devices']) { $parameters['devices'] = $Devices }
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }
        if($PSBoundParameters['Raidlevel']) { $parameters['raidlevel'] = $Raidlevel }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/disks/zfs" -Parameters $parameters
    }
}

function Get-PveNodesDisksZfsIdx
{
<#
.DESCRIPTION
Get details about a zpool.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Name
The storage identifier.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/disks/zfs/$Name"
    }
}

function Get-PveNodesDisksList
{
<#
.DESCRIPTION
List local disks.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Skipsmart
Skip smart checks.
.PARAMETER Type
Only list specific types of disks.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Skipsmart,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('unused','journal_disks')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Skipsmart']) { $parameters['skipsmart'] = $Skipsmart }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/disks/list" -Parameters $parameters
    }
}

function Get-PveNodesDisksSmart
{
<#
.DESCRIPTION
Get SMART Health of a disk.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Disk
Block device name
.PARAMETER Healthonly
If true returns only the health status
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Disk,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Healthonly,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Disk']) { $parameters['disk'] = $Disk }
        if($PSBoundParameters['Healthonly']) { $parameters['healthonly'] = $Healthonly }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/disks/smart" -Parameters $parameters
    }
}

function New-PveNodesDisksInitgpt
{
<#
.DESCRIPTION
Initialize Disk with GPT
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Disk
Block device name
.PARAMETER Node
The cluster node name.
.PARAMETER Uuid
UUID for the GPT table
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Disk,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Uuid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Disk']) { $parameters['disk'] = $Disk }
        if($PSBoundParameters['Uuid']) { $parameters['uuid'] = $Uuid }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/disks/initgpt" -Parameters $parameters
    }
}

function Get-PveNodesApt
{
<#
.DESCRIPTION
Directory index for apt (Advanced Package Tool).
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/apt"
    }
}

function Get-PveNodesAptUpdate
{
<#
.DESCRIPTION
List available updates.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/apt/update"
    }
}

function New-PveNodesAptUpdate
{
<#
.DESCRIPTION
This is used to resynchronize the package index files from their sources (apt-get update).
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Notify
Send notification mail about new packages (to email address specified for user 'root@pam').
.PARAMETER Quiet
Only produces output suitable for logging, omitting progress indicators.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Notify,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Quiet
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Notify']) { $parameters['notify'] = $Notify }
        if($PSBoundParameters['Quiet']) { $parameters['quiet'] = $Quiet }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/apt/update" -Parameters $parameters
    }
}

function Get-PveNodesAptChangelog
{
<#
.DESCRIPTION
Get package changelogs.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Name
Package name.
.PARAMETER Node
The cluster node name.
.PARAMETER Version
Package version.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Version
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Name']) { $parameters['name'] = $Name }
        if($PSBoundParameters['Version']) { $parameters['version'] = $Version }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/apt/changelog" -Parameters $parameters
    }
}

function Get-PveNodesAptVersions
{
<#
.DESCRIPTION
Get package information for important Proxmox packages.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/apt/versions"
    }
}

function Get-PveNodesFirewall
{
<#
.DESCRIPTION
Directory index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/firewall"
    }
}

function Get-PveNodesFirewallRules
{
<#
.DESCRIPTION
List rules.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/firewall/rules"
    }
}

function New-PveNodesFirewallRules
{
<#
.DESCRIPTION
Create new rule.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Action
Rule action ('ACCEPT', 'DROP', 'REJECT') or security group name.
.PARAMETER Comment
Descriptive comment.
.PARAMETER Dest
Restrict packet destination address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Dport
Restrict TCP/UDP destination port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Enable
Flag to enable/disable a rule.
.PARAMETER Iface
Network interface name. You have to use network configuration key names for VMs and containers ('net\d+'). Host related rules can use arbitrary strings.
.PARAMETER Log
Log level for firewall rule.
.PARAMETER Macro
Use predefined standard macro.
.PARAMETER Node
The cluster node name.
.PARAMETER Pos
Update rule at position <pos>.
.PARAMETER Proto
IP protocol. You can use protocol names ('tcp'/'udp') or simple numbers, as defined in '/etc/protocols'.
.PARAMETER Source
Restrict packet source address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Sport
Restrict TCP/UDP source port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Type
Rule type.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Action,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Enable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iface,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$Log,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Macro,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Proto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Source,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sport,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('in','out','group')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Action']) { $parameters['action'] = $Action }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Dest']) { $parameters['dest'] = $Dest }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Dport']) { $parameters['dport'] = $Dport }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['Iface']) { $parameters['iface'] = $Iface }
        if($PSBoundParameters['Log']) { $parameters['log'] = $Log }
        if($PSBoundParameters['Macro']) { $parameters['macro'] = $Macro }
        if($PSBoundParameters['Pos']) { $parameters['pos'] = $Pos }
        if($PSBoundParameters['Proto']) { $parameters['proto'] = $Proto }
        if($PSBoundParameters['Source']) { $parameters['source'] = $Source }
        if($PSBoundParameters['Sport']) { $parameters['sport'] = $Sport }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/firewall/rules" -Parameters $parameters
    }
}

function Remove-PveNodesFirewallRules
{
<#
.DESCRIPTION
Delete rule.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Node
The cluster node name.
.PARAMETER Pos
Update rule at position <pos>.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/firewall/rules/$Pos" -Parameters $parameters
    }
}

function Get-PveNodesFirewallRulesIdx
{
<#
.DESCRIPTION
Get single rule data.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Pos
Update rule at position <pos>.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/firewall/rules/$Pos"
    }
}

function Set-PveNodesFirewallRules
{
<#
.DESCRIPTION
Modify rule data.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Action
Rule action ('ACCEPT', 'DROP', 'REJECT') or security group name.
.PARAMETER Comment
Descriptive comment.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Dest
Restrict packet destination address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Dport
Restrict TCP/UDP destination port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Enable
Flag to enable/disable a rule.
.PARAMETER Iface
Network interface name. You have to use network configuration key names for VMs and containers ('net\d+'). Host related rules can use arbitrary strings.
.PARAMETER Log
Log level for firewall rule.
.PARAMETER Macro
Use predefined standard macro.
.PARAMETER Moveto
Move rule to new position <moveto>. Other arguments are ignored.
.PARAMETER Node
The cluster node name.
.PARAMETER Pos
Update rule at position <pos>.
.PARAMETER Proto
IP protocol. You can use protocol names ('tcp'/'udp') or simple numbers, as defined in '/etc/protocols'.
.PARAMETER Source
Restrict packet source address. This can refer to a single IP address, an IP set ('+ipsetname') or an IP alias definition. You can also specify an address range like '20.34.101.207-201.3.9.99', or a list of IP addresses and networks (entries are separated by comma). Please do not mix IPv4 and IPv6 addresses inside such lists.
.PARAMETER Sport
Restrict TCP/UDP source port. You can use service names or simple numbers (0-65535), as defined in '/etc/services'. Port ranges can be specified with '\d+':'\d+', for example '80':'85', and you can use comma separated list to match several ports or ranges.
.PARAMETER Type
Rule type.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Action,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Enable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iface,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$Log,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Macro,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Moveto,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Pos,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Proto,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Source,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('in','out','group')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Action']) { $parameters['action'] = $Action }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Dest']) { $parameters['dest'] = $Dest }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Dport']) { $parameters['dport'] = $Dport }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['Iface']) { $parameters['iface'] = $Iface }
        if($PSBoundParameters['Log']) { $parameters['log'] = $Log }
        if($PSBoundParameters['Macro']) { $parameters['macro'] = $Macro }
        if($PSBoundParameters['Moveto']) { $parameters['moveto'] = $Moveto }
        if($PSBoundParameters['Proto']) { $parameters['proto'] = $Proto }
        if($PSBoundParameters['Source']) { $parameters['source'] = $Source }
        if($PSBoundParameters['Sport']) { $parameters['sport'] = $Sport }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/firewall/rules/$Pos" -Parameters $parameters
    }
}

function Get-PveNodesFirewallOptions
{
<#
.DESCRIPTION
Get host firewall options.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/firewall/options"
    }
}

function Set-PveNodesFirewallOptions
{
<#
.DESCRIPTION
Set Firewall options.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Enable
Enable host firewall rules.
.PARAMETER LogLevelIn
Log level for incoming traffic.
.PARAMETER LogLevelOut
Log level for outgoing traffic.
.PARAMETER LogNfConntrack
Enable logging of conntrack information.
.PARAMETER Ndp
Enable NDP (Neighbor Discovery Protocol).
.PARAMETER NfConntrackAllowInvalid
Allow invalid packets on connection tracking.
.PARAMETER NfConntrackMax
Maximum number of tracked connections.
.PARAMETER NfConntrackTcpTimeoutEstablished
Conntrack established timeout.
.PARAMETER NfConntrackTcpTimeoutSynRecv
Conntrack syn recv timeout.
.PARAMETER Node
The cluster node name.
.PARAMETER Nosmurfs
Enable SMURFS filter.
.PARAMETER ProtectionSynflood
Enable synflood protection
.PARAMETER ProtectionSynfloodBurst
Synflood protection rate burst by ip src.
.PARAMETER ProtectionSynfloodRate
Synflood protection rate syn/sec by ip src.
.PARAMETER SmurfLogLevel
Log level for SMURFS filter.
.PARAMETER TcpFlagsLogLevel
Log level for illegal tcp flags filter.
.PARAMETER Tcpflags
Filter illegal combinations of TCP flags.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Enable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$LogLevelIn,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$LogLevelOut,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$LogNfConntrack,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Ndp,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$NfConntrackAllowInvalid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$NfConntrackMax,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$NfConntrackTcpTimeoutEstablished,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$NfConntrackTcpTimeoutSynRecv,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Nosmurfs,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$ProtectionSynflood,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$ProtectionSynfloodBurst,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$ProtectionSynfloodRate,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$SmurfLogLevel,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug','nolog')]
        [string]$TcpFlagsLogLevel,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Tcpflags
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['LogLevelIn']) { $parameters['log_level_in'] = $LogLevelIn }
        if($PSBoundParameters['LogLevelOut']) { $parameters['log_level_out'] = $LogLevelOut }
        if($PSBoundParameters['LogNfConntrack']) { $parameters['log_nf_conntrack'] = $LogNfConntrack }
        if($PSBoundParameters['Ndp']) { $parameters['ndp'] = $Ndp }
        if($PSBoundParameters['NfConntrackAllowInvalid']) { $parameters['nf_conntrack_allow_invalid'] = $NfConntrackAllowInvalid }
        if($PSBoundParameters['NfConntrackMax']) { $parameters['nf_conntrack_max'] = $NfConntrackMax }
        if($PSBoundParameters['NfConntrackTcpTimeoutEstablished']) { $parameters['nf_conntrack_tcp_timeout_established'] = $NfConntrackTcpTimeoutEstablished }
        if($PSBoundParameters['NfConntrackTcpTimeoutSynRecv']) { $parameters['nf_conntrack_tcp_timeout_syn_recv'] = $NfConntrackTcpTimeoutSynRecv }
        if($PSBoundParameters['Nosmurfs']) { $parameters['nosmurfs'] = $Nosmurfs }
        if($PSBoundParameters['ProtectionSynflood']) { $parameters['protection_synflood'] = $ProtectionSynflood }
        if($PSBoundParameters['ProtectionSynfloodBurst']) { $parameters['protection_synflood_burst'] = $ProtectionSynfloodBurst }
        if($PSBoundParameters['ProtectionSynfloodRate']) { $parameters['protection_synflood_rate'] = $ProtectionSynfloodRate }
        if($PSBoundParameters['SmurfLogLevel']) { $parameters['smurf_log_level'] = $SmurfLogLevel }
        if($PSBoundParameters['TcpFlagsLogLevel']) { $parameters['tcp_flags_log_level'] = $TcpFlagsLogLevel }
        if($PSBoundParameters['Tcpflags']) { $parameters['tcpflags'] = $Tcpflags }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/firewall/options" -Parameters $parameters
    }
}

function Get-PveNodesFirewallLog
{
<#
.DESCRIPTION
Read firewall log
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Limit
--
.PARAMETER Node
The cluster node name.
.PARAMETER Start
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Limit,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Start
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Limit']) { $parameters['limit'] = $Limit }
        if($PSBoundParameters['Start']) { $parameters['start'] = $Start }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/firewall/log" -Parameters $parameters
    }
}

function Get-PveNodesReplication
{
<#
.DESCRIPTION
List status of all replication jobs on this node.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Guest
Only list replication jobs for this guest.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Guest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Guest']) { $parameters['guest'] = $Guest }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/replication" -Parameters $parameters
    }
}

function Get-PveNodesReplicationIdx
{
<#
.DESCRIPTION
Directory index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Id
Replication Job ID. The ID is composed of a Guest ID and a job number, separated by a hyphen, i.e. '<GUEST>-<JOBNUM>'.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/replication/$Id"
    }
}

function Get-PveNodesReplicationStatus
{
<#
.DESCRIPTION
Get replication job status.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Id
Replication Job ID. The ID is composed of a Guest ID and a job number, separated by a hyphen, i.e. '<GUEST>-<JOBNUM>'.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/replication/$Id/status"
    }
}

function Get-PveNodesReplicationLog
{
<#
.DESCRIPTION
Read replication job log.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Id
Replication Job ID. The ID is composed of a Guest ID and a job number, separated by a hyphen, i.e. '<GUEST>-<JOBNUM>'.
.PARAMETER Limit
--
.PARAMETER Node
The cluster node name.
.PARAMETER Start
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Limit,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Start
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Limit']) { $parameters['limit'] = $Limit }
        if($PSBoundParameters['Start']) { $parameters['start'] = $Start }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/replication/$Id/log" -Parameters $parameters
    }
}

function New-PveNodesReplicationScheduleNow
{
<#
.DESCRIPTION
Schedule replication job to start as soon as possible.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Id
Replication Job ID. The ID is composed of a Guest ID and a job number, separated by a hyphen, i.e. '<GUEST>-<JOBNUM>'.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/replication/$Id/schedule_now"
    }
}

function Get-PveNodesCertificates
{
<#
.DESCRIPTION
Node index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/certificates"
    }
}

function Get-PveNodesCertificatesAcme
{
<#
.DESCRIPTION
ACME index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/certificates/acme"
    }
}

function Remove-PveNodesCertificatesAcmeCertificate
{
<#
.DESCRIPTION
Revoke existing certificate from CA.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/certificates/acme/certificate"
    }
}

function New-PveNodesCertificatesAcmeCertificate
{
<#
.DESCRIPTION
Order a new certificate from ACME-compatible CA.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Force
Overwrite existing custom certificate.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/certificates/acme/certificate" -Parameters $parameters
    }
}

function Set-PveNodesCertificatesAcmeCertificate
{
<#
.DESCRIPTION
Renew existing certificate from CA.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Force
Force renewal even if expiry is more than 30 days away.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/certificates/acme/certificate" -Parameters $parameters
    }
}

function Get-PveNodesCertificatesInfo
{
<#
.DESCRIPTION
Get information about node's certificates.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/certificates/info"
    }
}

function Remove-PveNodesCertificatesCustom
{
<#
.DESCRIPTION
DELETE custom certificate chain and key.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Restart
Restart pveproxy.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Restart
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Restart']) { $parameters['restart'] = $Restart }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/nodes/$Node/certificates/custom" -Parameters $parameters
    }
}

function New-PveNodesCertificatesCustom
{
<#
.DESCRIPTION
Upload or update custom certificate chain and key.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Certificates
PEM encoded certificate (chain).
.PARAMETER Force
Overwrite existing custom or ACME certificate files.
.PARAMETER Key
PEM encoded private key.
.PARAMETER Node
The cluster node name.
.PARAMETER Restart
Restart pveproxy.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Certificates,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Key,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Restart
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Certificates']) { $parameters['certificates'] = $Certificates }
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }
        if($PSBoundParameters['Key']) { $parameters['key'] = $Key }
        if($PSBoundParameters['Restart']) { $parameters['restart'] = $Restart }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/certificates/custom" -Parameters $parameters
    }
}

function Get-PveNodesConfig
{
<#
.DESCRIPTION
Get node configuration options.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Property
Return only a specific property from the node configuration.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('acme','acmedomain0','acmedomain1','acmedomain2','acmedomain3','acmedomain4','acmedomain5','description','startall-onboot-delay','wakeonlan')]
        [string]$Property
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Property']) { $parameters['property'] = $Property }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/config" -Parameters $parameters
    }
}

function Set-PveNodesConfig
{
<#
.DESCRIPTION
Set node configuration options.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Acme
Node specific ACME settings.
.PARAMETER AcmedomainN
ACME domain and validation plugin
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Description
Node description/comment.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Node
The cluster node name.
.PARAMETER StartallOnbootDelay
Initial delay in seconds, before starting all the Virtual Guests with on-boot enabled.
.PARAMETER Wakeonlan
MAC address for wake on LAN
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Acme,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$AcmedomainN,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$StartallOnbootDelay,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Wakeonlan
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Acme']) { $parameters['acme'] = $Acme }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Description']) { $parameters['description'] = $Description }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['StartallOnbootDelay']) { $parameters['startall-onboot-delay'] = $StartallOnbootDelay }
        if($PSBoundParameters['Wakeonlan']) { $parameters['wakeonlan'] = $Wakeonlan }

        if($PSBoundParameters['AcmedomainN']) { $AcmedomainN.keys | ForEach-Object { $parameters['acmedomain' + $_] = $AcmedomainN[$_] } }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/config" -Parameters $parameters
    }
}

function Get-PveNodesSdn
{
<#
.DESCRIPTION
SDN index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/sdn"
    }
}

function Get-PveNodesSdnZones
{
<#
.DESCRIPTION
Get status for all zones.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/sdn/zones"
    }
}

function Get-PveNodesSdnZonesIdx
{
<#
.DESCRIPTION
--
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Zone
The SDN zone object identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Zone
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/sdn/zones/$Zone"
    }
}

function Get-PveNodesSdnZonesContent
{
<#
.DESCRIPTION
List zone content.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Zone
The SDN zone object identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Zone
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/sdn/zones/$Zone/content"
    }
}

function Get-PveNodesVersion
{
<#
.DESCRIPTION
API version details
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/version"
    }
}

function Get-PveNodesStatus
{
<#
.DESCRIPTION
Read node status
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/status"
    }
}

function New-PveNodesStatus
{
<#
.DESCRIPTION
Reboot or shutdown a node.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Command
Specify the command.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('reboot','shutdown')]
        [string]$Command,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Command']) { $parameters['command'] = $Command }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/status" -Parameters $parameters
    }
}

function Get-PveNodesNetstat
{
<#
.DESCRIPTION
Read tap/vm network device interface counters
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/netstat"
    }
}

function New-PveNodesExecute
{
<#
.DESCRIPTION
Execute multiple commands in order.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Commands
JSON encoded array of commands.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Commands,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Commands']) { $parameters['commands'] = $Commands }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/execute" -Parameters $parameters
    }
}

function New-PveNodesWakeonlan
{
<#
.DESCRIPTION
Try to wake a node via 'wake on LAN' network packet.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
target node for wake on LAN packet
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/wakeonlan"
    }
}

function Get-PveNodesRrd
{
<#
.DESCRIPTION
Read node RRD statistics (returns PNG)
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cf
The RRD consolidation function
.PARAMETER Ds
The list of datasources you want to display.
.PARAMETER Node
The cluster node name.
.PARAMETER Timeframe
Specify the time frame you are interested in.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('AVERAGE','MAX')]
        [string]$Cf,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Ds,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('hour','day','week','month','year')]
        [string]$Timeframe
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cf']) { $parameters['cf'] = $Cf }
        if($PSBoundParameters['Ds']) { $parameters['ds'] = $Ds }
        if($PSBoundParameters['Timeframe']) { $parameters['timeframe'] = $Timeframe }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/rrd" -Parameters $parameters
    }
}

function Get-PveNodesRrddata
{
<#
.DESCRIPTION
Read node RRD statistics
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cf
The RRD consolidation function
.PARAMETER Node
The cluster node name.
.PARAMETER Timeframe
Specify the time frame you are interested in.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('AVERAGE','MAX')]
        [string]$Cf,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('hour','day','week','month','year')]
        [string]$Timeframe
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cf']) { $parameters['cf'] = $Cf }
        if($PSBoundParameters['Timeframe']) { $parameters['timeframe'] = $Timeframe }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/rrddata" -Parameters $parameters
    }
}

function Get-PveNodesSyslog
{
<#
.DESCRIPTION
Read system log
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Limit
--
.PARAMETER Node
The cluster node name.
.PARAMETER Service
Service ID
.PARAMETER Since
Display all log since this date-time string.
.PARAMETER Start
--
.PARAMETER Until
Display all log until this date-time string.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Limit,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Service,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Since,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Start,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Until
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Limit']) { $parameters['limit'] = $Limit }
        if($PSBoundParameters['Service']) { $parameters['service'] = $Service }
        if($PSBoundParameters['Since']) { $parameters['since'] = $Since }
        if($PSBoundParameters['Start']) { $parameters['start'] = $Start }
        if($PSBoundParameters['Until']) { $parameters['until'] = $Until }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/syslog" -Parameters $parameters
    }
}

function Get-PveNodesJournal
{
<#
.DESCRIPTION
Read Journal
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Endcursor
End before the given Cursor. Conflicts with 'until'
.PARAMETER Lastentries
Limit to the last X lines. Conflicts with a range.
.PARAMETER Node
The cluster node name.
.PARAMETER Since
Display all log since this UNIX epoch. Conflicts with 'startcursor'.
.PARAMETER Startcursor
Start after the given Cursor. Conflicts with 'since'
.PARAMETER Until
Display all log until this UNIX epoch. Conflicts with 'endcursor'.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Endcursor,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Lastentries,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Since,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Startcursor,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Until
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Endcursor']) { $parameters['endcursor'] = $Endcursor }
        if($PSBoundParameters['Lastentries']) { $parameters['lastentries'] = $Lastentries }
        if($PSBoundParameters['Since']) { $parameters['since'] = $Since }
        if($PSBoundParameters['Startcursor']) { $parameters['startcursor'] = $Startcursor }
        if($PSBoundParameters['Until']) { $parameters['until'] = $Until }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/journal" -Parameters $parameters
    }
}

function New-PveNodesVncshell
{
<#
.DESCRIPTION
Creates a VNC Shell proxy.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cmd
Run specific command or default to login.
.PARAMETER Height
sets the height of the console in pixels.
.PARAMETER Node
The cluster node name.
.PARAMETER Upgrade
Deprecated, use the 'cmd' property instead! Run 'apt-get dist-upgrade' instead of normal shell.
.PARAMETER Websocket
use websocket instead of standard vnc.
.PARAMETER Width
sets the width of the console in pixels.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('login','ceph_install','upgrade')]
        [string]$Cmd,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Height,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Upgrade,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Websocket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Width
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cmd']) { $parameters['cmd'] = $Cmd }
        if($PSBoundParameters['Height']) { $parameters['height'] = $Height }
        if($PSBoundParameters['Upgrade']) { $parameters['upgrade'] = $Upgrade }
        if($PSBoundParameters['Websocket']) { $parameters['websocket'] = $Websocket }
        if($PSBoundParameters['Width']) { $parameters['width'] = $Width }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/vncshell" -Parameters $parameters
    }
}

function New-PveNodesTermproxy
{
<#
.DESCRIPTION
Creates a VNC Shell proxy.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cmd
Run specific command or default to login.
.PARAMETER Node
The cluster node name.
.PARAMETER Upgrade
Deprecated, use the 'cmd' property instead! Run 'apt-get dist-upgrade' instead of normal shell.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('login','ceph_install','upgrade')]
        [string]$Cmd,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Upgrade
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cmd']) { $parameters['cmd'] = $Cmd }
        if($PSBoundParameters['Upgrade']) { $parameters['upgrade'] = $Upgrade }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/termproxy" -Parameters $parameters
    }
}

function Get-PveNodesVncwebsocket
{
<#
.DESCRIPTION
Opens a weksocket for VNC traffic.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Port
Port number returned by previous vncproxy call.
.PARAMETER Vncticket
Ticket from previous call to vncproxy.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Port,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vncticket
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Port']) { $parameters['port'] = $Port }
        if($PSBoundParameters['Vncticket']) { $parameters['vncticket'] = $Vncticket }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/vncwebsocket" -Parameters $parameters
    }
}

function New-PveNodesSpiceshell
{
<#
.DESCRIPTION
Creates a SPICE shell.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Cmd
Run specific command or default to login.
.PARAMETER Node
The cluster node name.
.PARAMETER Proxy
SPICE proxy server. This can be used by the client to specify the proxy server. All nodes in a cluster runs 'spiceproxy', so it is up to the client to choose one. By default, we return the node where the VM is currently running. As reasonable setting is to use same node you use to connect to the API (This is window.location.hostname for the JS GUI).
.PARAMETER Upgrade
Deprecated, use the 'cmd' property instead! Run 'apt-get dist-upgrade' instead of normal shell.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('login','ceph_install','upgrade')]
        [string]$Cmd,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Proxy,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Upgrade
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Cmd']) { $parameters['cmd'] = $Cmd }
        if($PSBoundParameters['Proxy']) { $parameters['proxy'] = $Proxy }
        if($PSBoundParameters['Upgrade']) { $parameters['upgrade'] = $Upgrade }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/spiceshell" -Parameters $parameters
    }
}

function Get-PveNodesDns
{
<#
.DESCRIPTION
Read DNS settings.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/dns"
    }
}

function Set-PveNodesDns
{
<#
.DESCRIPTION
Write DNS settings.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Dns1
First name server IP address.
.PARAMETER Dns2
Second name server IP address.
.PARAMETER Dns3
Third name server IP address.
.PARAMETER Node
The cluster node name.
.PARAMETER Search
Search domain for host-name lookup.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dns1,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dns2,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Dns3,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Search
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Dns1']) { $parameters['dns1'] = $Dns1 }
        if($PSBoundParameters['Dns2']) { $parameters['dns2'] = $Dns2 }
        if($PSBoundParameters['Dns3']) { $parameters['dns3'] = $Dns3 }
        if($PSBoundParameters['Search']) { $parameters['search'] = $Search }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/dns" -Parameters $parameters
    }
}

function Get-PveNodesTime
{
<#
.DESCRIPTION
Read server time and time zone settings.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/time"
    }
}

function Set-PveNodesTime
{
<#
.DESCRIPTION
Set time zone.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Timezone
Time zone. The file '/usr/share/zoneinfo/zone.tab' contains the list of valid names.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Timezone
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Timezone']) { $parameters['timezone'] = $Timezone }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$Node/time" -Parameters $parameters
    }
}

function Get-PveNodesAplinfo
{
<#
.DESCRIPTION
Get list of appliances.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/aplinfo"
    }
}

function New-PveNodesAplinfo
{
<#
.DESCRIPTION
Download appliance templates.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Storage
The storage where the template will be stored
.PARAMETER Template
The template which will downloaded
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Template
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Storage']) { $parameters['storage'] = $Storage }
        if($PSBoundParameters['Template']) { $parameters['template'] = $Template }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/aplinfo" -Parameters $parameters
    }
}

function Get-PveNodesReport
{
<#
.DESCRIPTION
Gather various systems information about a node
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/report"
    }
}

function New-PveNodesStartall
{
<#
.DESCRIPTION
Start all VMs and containers located on this node (by default only those with onboot=1).
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Force
Issue start command even if virtual guest have 'onboot' not set or set to off.
.PARAMETER Node
The cluster node name.
.PARAMETER Vms
Only consider guests from this comma separated list of VMIDs.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Force,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vms
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Force']) { $parameters['force'] = $Force }
        if($PSBoundParameters['Vms']) { $parameters['vms'] = $Vms }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/startall" -Parameters $parameters
    }
}

function New-PveNodesStopall
{
<#
.DESCRIPTION
Stop all VMs and Containers.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.PARAMETER Vms
Only consider Guests with these IDs.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vms
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Vms']) { $parameters['vms'] = $Vms }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/stopall" -Parameters $parameters
    }
}

function New-PveNodesMigrateall
{
<#
.DESCRIPTION
Migrate all VMs and Containers.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Maxworkers
Maximal number of parallel migration job. If not set use 'max_workers' from datacenter.cfg, one of both must be set!
.PARAMETER Node
The cluster node name.
.PARAMETER Target
Target node.
.PARAMETER Vms
Only consider Guests with these IDs.
.PARAMETER WithLocalDisks
Enable live storage migration for local disk
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Maxworkers,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Target,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vms,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$WithLocalDisks
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Maxworkers']) { $parameters['maxworkers'] = $Maxworkers }
        if($PSBoundParameters['Target']) { $parameters['target'] = $Target }
        if($PSBoundParameters['Vms']) { $parameters['vms'] = $Vms }
        if($PSBoundParameters['WithLocalDisks']) { $parameters['with-local-disks'] = $WithLocalDisks }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/migrateall" -Parameters $parameters
    }
}

function Get-PveNodesHosts
{
<#
.DESCRIPTION
Get the content of /etc/hosts.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$Node/hosts"
    }
}

function New-PveNodesHosts
{
<#
.DESCRIPTION
Write /etc/hosts.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Data
The target content of /etc/hosts.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Node
The cluster node name.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Data,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Data']) { $parameters['data'] = $Data }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$Node/hosts" -Parameters $parameters
    }
}

function Get-PveStorage
{
<#
.DESCRIPTION
Storage index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Type
Only list storage of specific type
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('cephfs','cifs','dir','drbd','glusterfs','iscsi','iscsidirect','lvm','lvmthin','nfs','pbs','rbd','zfs','zfspool')]
        [string]$Type
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/storage" -Parameters $parameters
    }
}

function New-PveStorage
{
<#
.DESCRIPTION
Create a new storage.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Authsupported
Authsupported.
.PARAMETER Base
Base volume. This volume is automatically activated.
.PARAMETER Blocksize
block size
.PARAMETER Bwlimit
Set bandwidth/io limits various operations.
.PARAMETER ComstarHg
host group for comstar views
.PARAMETER ComstarTg
target group for comstar views
.PARAMETER Content
Allowed content types.NOTE':' the value 'rootdir' is used for Containers, and value 'images' for VMs.
.PARAMETER Datastore
Proxmox backup server datastore name.
.PARAMETER Disable
Flag to disable the storage.
.PARAMETER Domain
CIFS domain.
.PARAMETER EncryptionKey
Encryption key. Use 'autogen' to generate one automatically without passphrase.
.PARAMETER Export
NFS export path.
.PARAMETER Fingerprint
Certificate SHA 256 fingerprint.
.PARAMETER Format
Default image format.
.PARAMETER Fuse
Mount CephFS through FUSE.
.PARAMETER IsMountpoint
Assume the given path is an externally managed mountpoint and consider the storage offline if it is not mounted. Using a boolean (yes/no) value serves as a shortcut to using the target path in this field.
.PARAMETER Iscsiprovider
iscsi provider
.PARAMETER Krbd
Always access rbd through krbd kernel module.
.PARAMETER LioTpg
target portal group for Linux LIO targets
.PARAMETER Maxfiles
Maximal number of backup files per VM. Use '0' for unlimted.
.PARAMETER Mkdir
Create the directory if it doesn't exist.
.PARAMETER Monhost
IP addresses of monitors (for external clusters).
.PARAMETER Mountpoint
mount point
.PARAMETER Nodes
List of cluster node names.
.PARAMETER Nowritecache
disable write caching on the target
.PARAMETER Options
NFS mount options (see 'man nfs')
.PARAMETER Password
Password for accessing the share/datastore.
.PARAMETER Path
File system path.
.PARAMETER Pool
Pool.
.PARAMETER Portal
iSCSI portal (IP or DNS name with optional port).
.PARAMETER PruneBackups
The retention options with shorter intervals are processed first with --keep-last being the very first one. Each option covers a specific period of time. We say that backups within this period are covered by this option. The next option does not take care of already covered backups and only considers older backups.
.PARAMETER Redundancy
The redundancy count specifies the number of nodes to which the resource should be deployed. It must be at least 1 and at most the number of nodes in the cluster.
.PARAMETER Saferemove
Zero-out data when removing LVs.
.PARAMETER SaferemoveThroughput
Wipe throughput (cstream -t parameter value).
.PARAMETER Server
Server IP or DNS name.
.PARAMETER Server2
Backup volfile server IP or DNS name.
.PARAMETER Share
CIFS share.
.PARAMETER Shared
Mark storage as shared.
.PARAMETER Smbversion
SMB protocol version
.PARAMETER Sparse
use sparse volumes
.PARAMETER Storage
The storage identifier.
.PARAMETER Subdir
Subdir to mount.
.PARAMETER TaggedOnly
Only use logical volumes tagged with 'pve-vm-ID'.
.PARAMETER Target
iSCSI target.
.PARAMETER Thinpool
LVM thin pool LV name.
.PARAMETER Transport
Gluster transport':' tcp or rdma
.PARAMETER Type
Storage type.
.PARAMETER Username
RBD Id.
.PARAMETER Vgname
Volume group name.
.PARAMETER Volume
Glusterfs Volume.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Authsupported,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Base,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Blocksize,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Bwlimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ComstarHg,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ComstarTg,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Content,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Datastore,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Disable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Domain,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$EncryptionKey,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Export,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Fingerprint,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Format,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Fuse,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$IsMountpoint,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Iscsiprovider,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Krbd,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$LioTpg,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Maxfiles,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Mkdir,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Monhost,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Mountpoint,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Nodes,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Nowritecache,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Options,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Password,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Path,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Pool,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Portal,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$PruneBackups,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Redundancy,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Saferemove,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$SaferemoveThroughput,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Server,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Server2,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Share,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Shared,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('2.0','2.1','3.0')]
        [string]$Smbversion,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Sparse,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Subdir,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$TaggedOnly,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Target,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Thinpool,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('tcp','rdma','unix')]
        [string]$Transport,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('cephfs','cifs','dir','drbd','glusterfs','iscsi','iscsidirect','lvm','lvmthin','nfs','pbs','rbd','zfs','zfspool')]
        [string]$Type,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Username,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vgname,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Volume
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Authsupported']) { $parameters['authsupported'] = $Authsupported }
        if($PSBoundParameters['Base']) { $parameters['base'] = $Base }
        if($PSBoundParameters['Blocksize']) { $parameters['blocksize'] = $Blocksize }
        if($PSBoundParameters['Bwlimit']) { $parameters['bwlimit'] = $Bwlimit }
        if($PSBoundParameters['ComstarHg']) { $parameters['comstar_hg'] = $ComstarHg }
        if($PSBoundParameters['ComstarTg']) { $parameters['comstar_tg'] = $ComstarTg }
        if($PSBoundParameters['Content']) { $parameters['content'] = $Content }
        if($PSBoundParameters['Datastore']) { $parameters['datastore'] = $Datastore }
        if($PSBoundParameters['Disable']) { $parameters['disable'] = $Disable }
        if($PSBoundParameters['Domain']) { $parameters['domain'] = $Domain }
        if($PSBoundParameters['EncryptionKey']) { $parameters['encryption-key'] = $EncryptionKey }
        if($PSBoundParameters['Export']) { $parameters['export'] = $Export }
        if($PSBoundParameters['Fingerprint']) { $parameters['fingerprint'] = $Fingerprint }
        if($PSBoundParameters['Format']) { $parameters['format'] = $Format }
        if($PSBoundParameters['Fuse']) { $parameters['fuse'] = $Fuse }
        if($PSBoundParameters['IsMountpoint']) { $parameters['is_mountpoint'] = $IsMountpoint }
        if($PSBoundParameters['Iscsiprovider']) { $parameters['iscsiprovider'] = $Iscsiprovider }
        if($PSBoundParameters['Krbd']) { $parameters['krbd'] = $Krbd }
        if($PSBoundParameters['LioTpg']) { $parameters['lio_tpg'] = $LioTpg }
        if($PSBoundParameters['Maxfiles']) { $parameters['maxfiles'] = $Maxfiles }
        if($PSBoundParameters['Mkdir']) { $parameters['mkdir'] = $Mkdir }
        if($PSBoundParameters['Monhost']) { $parameters['monhost'] = $Monhost }
        if($PSBoundParameters['Mountpoint']) { $parameters['mountpoint'] = $Mountpoint }
        if($PSBoundParameters['Nodes']) { $parameters['nodes'] = $Nodes }
        if($PSBoundParameters['Nowritecache']) { $parameters['nowritecache'] = $Nowritecache }
        if($PSBoundParameters['Options']) { $parameters['options'] = $Options }
        if($PSBoundParameters['Password']) { $parameters['password'] = (ConvertFrom-SecureString -SecureString $Password -AsPlainText) }
        if($PSBoundParameters['Path']) { $parameters['path'] = $Path }
        if($PSBoundParameters['Pool']) { $parameters['pool'] = $Pool }
        if($PSBoundParameters['Portal']) { $parameters['portal'] = $Portal }
        if($PSBoundParameters['PruneBackups']) { $parameters['prune-backups'] = $PruneBackups }
        if($PSBoundParameters['Redundancy']) { $parameters['redundancy'] = $Redundancy }
        if($PSBoundParameters['Saferemove']) { $parameters['saferemove'] = $Saferemove }
        if($PSBoundParameters['SaferemoveThroughput']) { $parameters['saferemove_throughput'] = $SaferemoveThroughput }
        if($PSBoundParameters['Server']) { $parameters['server'] = $Server }
        if($PSBoundParameters['Server2']) { $parameters['server2'] = $Server2 }
        if($PSBoundParameters['Share']) { $parameters['share'] = $Share }
        if($PSBoundParameters['Shared']) { $parameters['shared'] = $Shared }
        if($PSBoundParameters['Smbversion']) { $parameters['smbversion'] = $Smbversion }
        if($PSBoundParameters['Sparse']) { $parameters['sparse'] = $Sparse }
        if($PSBoundParameters['Storage']) { $parameters['storage'] = $Storage }
        if($PSBoundParameters['Subdir']) { $parameters['subdir'] = $Subdir }
        if($PSBoundParameters['TaggedOnly']) { $parameters['tagged_only'] = $TaggedOnly }
        if($PSBoundParameters['Target']) { $parameters['target'] = $Target }
        if($PSBoundParameters['Thinpool']) { $parameters['thinpool'] = $Thinpool }
        if($PSBoundParameters['Transport']) { $parameters['transport'] = $Transport }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }
        if($PSBoundParameters['Username']) { $parameters['username'] = $Username }
        if($PSBoundParameters['Vgname']) { $parameters['vgname'] = $Vgname }
        if($PSBoundParameters['Volume']) { $parameters['volume'] = $Volume }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/storage" -Parameters $parameters
    }
}

function Remove-PveStorage
{
<#
.DESCRIPTION
Delete storage configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Storage
The storage identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/storage/$Storage"
    }
}

function Get-PveStorageIdx
{
<#
.DESCRIPTION
Read storage configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Storage
The storage identifier.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/storage/$Storage"
    }
}

function Set-PveStorage
{
<#
.DESCRIPTION
Update storage configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Blocksize
block size
.PARAMETER Bwlimit
Set bandwidth/io limits various operations.
.PARAMETER ComstarHg
host group for comstar views
.PARAMETER ComstarTg
target group for comstar views
.PARAMETER Content
Allowed content types.NOTE':' the value 'rootdir' is used for Containers, and value 'images' for VMs.
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Disable
Flag to disable the storage.
.PARAMETER Domain
CIFS domain.
.PARAMETER EncryptionKey
Encryption key. Use 'autogen' to generate one automatically without passphrase.
.PARAMETER Fingerprint
Certificate SHA 256 fingerprint.
.PARAMETER Format
Default image format.
.PARAMETER Fuse
Mount CephFS through FUSE.
.PARAMETER IsMountpoint
Assume the given path is an externally managed mountpoint and consider the storage offline if it is not mounted. Using a boolean (yes/no) value serves as a shortcut to using the target path in this field.
.PARAMETER Krbd
Always access rbd through krbd kernel module.
.PARAMETER LioTpg
target portal group for Linux LIO targets
.PARAMETER Maxfiles
Maximal number of backup files per VM. Use '0' for unlimted.
.PARAMETER Mkdir
Create the directory if it doesn't exist.
.PARAMETER Monhost
IP addresses of monitors (for external clusters).
.PARAMETER Mountpoint
mount point
.PARAMETER Nodes
List of cluster node names.
.PARAMETER Nowritecache
disable write caching on the target
.PARAMETER Options
NFS mount options (see 'man nfs')
.PARAMETER Password
Password for accessing the share/datastore.
.PARAMETER Pool
Pool.
.PARAMETER PruneBackups
The retention options with shorter intervals are processed first with --keep-last being the very first one. Each option covers a specific period of time. We say that backups within this period are covered by this option. The next option does not take care of already covered backups and only considers older backups.
.PARAMETER Redundancy
The redundancy count specifies the number of nodes to which the resource should be deployed. It must be at least 1 and at most the number of nodes in the cluster.
.PARAMETER Saferemove
Zero-out data when removing LVs.
.PARAMETER SaferemoveThroughput
Wipe throughput (cstream -t parameter value).
.PARAMETER Server
Server IP or DNS name.
.PARAMETER Server2
Backup volfile server IP or DNS name.
.PARAMETER Shared
Mark storage as shared.
.PARAMETER Smbversion
SMB protocol version
.PARAMETER Sparse
use sparse volumes
.PARAMETER Storage
The storage identifier.
.PARAMETER Subdir
Subdir to mount.
.PARAMETER TaggedOnly
Only use logical volumes tagged with 'pve-vm-ID'.
.PARAMETER Transport
Gluster transport':' tcp or rdma
.PARAMETER Username
RBD Id.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Blocksize,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Bwlimit,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ComstarHg,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ComstarTg,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Content,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Disable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Domain,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$EncryptionKey,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Fingerprint,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Format,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Fuse,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$IsMountpoint,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Krbd,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$LioTpg,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Maxfiles,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Mkdir,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Monhost,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Mountpoint,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Nodes,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Nowritecache,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Options,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Password,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Pool,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$PruneBackups,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Redundancy,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Saferemove,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$SaferemoveThroughput,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Server,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Server2,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Shared,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('2.0','2.1','3.0')]
        [string]$Smbversion,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Sparse,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Subdir,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$TaggedOnly,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('tcp','rdma','unix')]
        [string]$Transport,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Username
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Blocksize']) { $parameters['blocksize'] = $Blocksize }
        if($PSBoundParameters['Bwlimit']) { $parameters['bwlimit'] = $Bwlimit }
        if($PSBoundParameters['ComstarHg']) { $parameters['comstar_hg'] = $ComstarHg }
        if($PSBoundParameters['ComstarTg']) { $parameters['comstar_tg'] = $ComstarTg }
        if($PSBoundParameters['Content']) { $parameters['content'] = $Content }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Disable']) { $parameters['disable'] = $Disable }
        if($PSBoundParameters['Domain']) { $parameters['domain'] = $Domain }
        if($PSBoundParameters['EncryptionKey']) { $parameters['encryption-key'] = $EncryptionKey }
        if($PSBoundParameters['Fingerprint']) { $parameters['fingerprint'] = $Fingerprint }
        if($PSBoundParameters['Format']) { $parameters['format'] = $Format }
        if($PSBoundParameters['Fuse']) { $parameters['fuse'] = $Fuse }
        if($PSBoundParameters['IsMountpoint']) { $parameters['is_mountpoint'] = $IsMountpoint }
        if($PSBoundParameters['Krbd']) { $parameters['krbd'] = $Krbd }
        if($PSBoundParameters['LioTpg']) { $parameters['lio_tpg'] = $LioTpg }
        if($PSBoundParameters['Maxfiles']) { $parameters['maxfiles'] = $Maxfiles }
        if($PSBoundParameters['Mkdir']) { $parameters['mkdir'] = $Mkdir }
        if($PSBoundParameters['Monhost']) { $parameters['monhost'] = $Monhost }
        if($PSBoundParameters['Mountpoint']) { $parameters['mountpoint'] = $Mountpoint }
        if($PSBoundParameters['Nodes']) { $parameters['nodes'] = $Nodes }
        if($PSBoundParameters['Nowritecache']) { $parameters['nowritecache'] = $Nowritecache }
        if($PSBoundParameters['Options']) { $parameters['options'] = $Options }
        if($PSBoundParameters['Password']) { $parameters['password'] = (ConvertFrom-SecureString -SecureString $Password -AsPlainText) }
        if($PSBoundParameters['Pool']) { $parameters['pool'] = $Pool }
        if($PSBoundParameters['PruneBackups']) { $parameters['prune-backups'] = $PruneBackups }
        if($PSBoundParameters['Redundancy']) { $parameters['redundancy'] = $Redundancy }
        if($PSBoundParameters['Saferemove']) { $parameters['saferemove'] = $Saferemove }
        if($PSBoundParameters['SaferemoveThroughput']) { $parameters['saferemove_throughput'] = $SaferemoveThroughput }
        if($PSBoundParameters['Server']) { $parameters['server'] = $Server }
        if($PSBoundParameters['Server2']) { $parameters['server2'] = $Server2 }
        if($PSBoundParameters['Shared']) { $parameters['shared'] = $Shared }
        if($PSBoundParameters['Smbversion']) { $parameters['smbversion'] = $Smbversion }
        if($PSBoundParameters['Sparse']) { $parameters['sparse'] = $Sparse }
        if($PSBoundParameters['Subdir']) { $parameters['subdir'] = $Subdir }
        if($PSBoundParameters['TaggedOnly']) { $parameters['tagged_only'] = $TaggedOnly }
        if($PSBoundParameters['Transport']) { $parameters['transport'] = $Transport }
        if($PSBoundParameters['Username']) { $parameters['username'] = $Username }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/storage/$Storage" -Parameters $parameters
    }
}

function Get-PveAccess
{
<#
.DESCRIPTION
Directory index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access"
    }
}

function Get-PveAccessUsers
{
<#
.DESCRIPTION
User index.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Enabled
Optional filter for enable property.
.PARAMETER Full
Include group and token information.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Enabled,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Full
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Enabled']) { $parameters['enabled'] = $Enabled }
        if($PSBoundParameters['Full']) { $parameters['full'] = $Full }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access/users" -Parameters $parameters
    }
}

function New-PveAccessUsers
{
<#
.DESCRIPTION
Create new user.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
--
.PARAMETER Email
--
.PARAMETER Enable
Enable the account (default). You can set this to '0' to disable the account
.PARAMETER Expire
Account expiration date (seconds since epoch). '0' means no expiration date.
.PARAMETER Firstname
--
.PARAMETER Groups
--
.PARAMETER Keys
Keys for two factor auth (yubico).
.PARAMETER Lastname
--
.PARAMETER Password
Initial password.
.PARAMETER Userid
User ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Email,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Enable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Expire,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Firstname,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Groups,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Keys,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Lastname,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Password,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Userid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Email']) { $parameters['email'] = $Email }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['Expire']) { $parameters['expire'] = $Expire }
        if($PSBoundParameters['Firstname']) { $parameters['firstname'] = $Firstname }
        if($PSBoundParameters['Groups']) { $parameters['groups'] = $Groups }
        if($PSBoundParameters['Keys']) { $parameters['keys'] = $Keys }
        if($PSBoundParameters['Lastname']) { $parameters['lastname'] = $Lastname }
        if($PSBoundParameters['Password']) { $parameters['password'] = (ConvertFrom-SecureString -SecureString $Password -AsPlainText) }
        if($PSBoundParameters['Userid']) { $parameters['userid'] = $Userid }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/access/users" -Parameters $parameters
    }
}

function Remove-PveAccessUsers
{
<#
.DESCRIPTION
Delete user.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Userid
User ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Userid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/access/users/$Userid"
    }
}

function Get-PveAccessUsersIdx
{
<#
.DESCRIPTION
Get user configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Userid
User ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Userid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access/users/$Userid"
    }
}

function Set-PveAccessUsers
{
<#
.DESCRIPTION
Update user configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Append
--
.PARAMETER Comment
--
.PARAMETER Email
--
.PARAMETER Enable
Enable the account (default). You can set this to '0' to disable the account
.PARAMETER Expire
Account expiration date (seconds since epoch). '0' means no expiration date.
.PARAMETER Firstname
--
.PARAMETER Groups
--
.PARAMETER Keys
Keys for two factor auth (yubico).
.PARAMETER Lastname
--
.PARAMETER Userid
User ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Append,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Email,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Enable,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Expire,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Firstname,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Groups,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Keys,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Lastname,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Userid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Append']) { $parameters['append'] = $Append }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Email']) { $parameters['email'] = $Email }
        if($PSBoundParameters['Enable']) { $parameters['enable'] = $Enable }
        if($PSBoundParameters['Expire']) { $parameters['expire'] = $Expire }
        if($PSBoundParameters['Firstname']) { $parameters['firstname'] = $Firstname }
        if($PSBoundParameters['Groups']) { $parameters['groups'] = $Groups }
        if($PSBoundParameters['Keys']) { $parameters['keys'] = $Keys }
        if($PSBoundParameters['Lastname']) { $parameters['lastname'] = $Lastname }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/access/users/$Userid" -Parameters $parameters
    }
}

function Get-PveAccessUsersTfa
{
<#
.DESCRIPTION
Get user TFA types (Personal and Realm).
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Userid
User ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Userid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access/users/$Userid/tfa"
    }
}

function Get-PveAccessUsersToken
{
<#
.DESCRIPTION
Get user API tokens.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Userid
User ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Userid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access/users/$Userid/token"
    }
}

function Remove-PveAccessUsersToken
{
<#
.DESCRIPTION
Remove API token for a specific user.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Tokenid
User-specific token identifier.
.PARAMETER Userid
User ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tokenid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Userid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/access/users/$Userid/token/$Tokenid"
    }
}

function Get-PveAccessUsersTokenIdx
{
<#
.DESCRIPTION
Get specific API token information.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Tokenid
User-specific token identifier.
.PARAMETER Userid
User ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tokenid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Userid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access/users/$Userid/token/$Tokenid"
    }
}

function New-PveAccessUsersToken
{
<#
.DESCRIPTION
Generate a new API token for a specific user. NOTE':' returns API token value, which needs to be stored as it cannot be retrieved afterwards!
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
--
.PARAMETER Expire
API token expiration date (seconds since epoch). '0' means no expiration date.
.PARAMETER Privsep
Restrict API token privileges with separate ACLs (default), or give full privileges of corresponding user.
.PARAMETER Tokenid
User-specific token identifier.
.PARAMETER Userid
User ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Expire,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Privsep,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tokenid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Userid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Expire']) { $parameters['expire'] = $Expire }
        if($PSBoundParameters['Privsep']) { $parameters['privsep'] = $Privsep }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/access/users/$Userid/token/$Tokenid" -Parameters $parameters
    }
}

function Set-PveAccessUsersToken
{
<#
.DESCRIPTION
Update API token for a specific user.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
--
.PARAMETER Expire
API token expiration date (seconds since epoch). '0' means no expiration date.
.PARAMETER Privsep
Restrict API token privileges with separate ACLs (default), or give full privileges of corresponding user.
.PARAMETER Tokenid
User-specific token identifier.
.PARAMETER Userid
User ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Expire,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Privsep,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tokenid,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Userid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Expire']) { $parameters['expire'] = $Expire }
        if($PSBoundParameters['Privsep']) { $parameters['privsep'] = $Privsep }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/access/users/$Userid/token/$Tokenid" -Parameters $parameters
    }
}

function Get-PveAccessGroups
{
<#
.DESCRIPTION
Group index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access/groups"
    }
}

function New-PveAccessGroups
{
<#
.DESCRIPTION
Create new group.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
--
.PARAMETER Groupid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Groupid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Groupid']) { $parameters['groupid'] = $Groupid }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/access/groups" -Parameters $parameters
    }
}

function Remove-PveAccessGroups
{
<#
.DESCRIPTION
Delete group.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Groupid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Groupid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/access/groups/$Groupid"
    }
}

function Get-PveAccessGroupsIdx
{
<#
.DESCRIPTION
Get group configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Groupid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Groupid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access/groups/$Groupid"
    }
}

function Set-PveAccessGroups
{
<#
.DESCRIPTION
Update group data.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
--
.PARAMETER Groupid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Groupid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/access/groups/$Groupid" -Parameters $parameters
    }
}

function Get-PveAccessRoles
{
<#
.DESCRIPTION
Role index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access/roles"
    }
}

function New-PveAccessRoles
{
<#
.DESCRIPTION
Create new role.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Privs
--
.PARAMETER Roleid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Privs,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Roleid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Privs']) { $parameters['privs'] = $Privs }
        if($PSBoundParameters['Roleid']) { $parameters['roleid'] = $Roleid }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/access/roles" -Parameters $parameters
    }
}

function Remove-PveAccessRoles
{
<#
.DESCRIPTION
Delete role.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Roleid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Roleid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/access/roles/$Roleid"
    }
}

function Get-PveAccessRolesIdx
{
<#
.DESCRIPTION
Get role configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Roleid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Roleid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access/roles/$Roleid"
    }
}

function Set-PveAccessRoles
{
<#
.DESCRIPTION
Update an existing role.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Append
--
.PARAMETER Privs
--
.PARAMETER Roleid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Append,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Privs,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Roleid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Append']) { $parameters['append'] = $Append }
        if($PSBoundParameters['Privs']) { $parameters['privs'] = $Privs }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/access/roles/$Roleid" -Parameters $parameters
    }
}

function Get-PveAccessAcl
{
<#
.DESCRIPTION
Get Access Control List (ACLs).
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access/acl"
    }
}

function Set-PveAccessAcl
{
<#
.DESCRIPTION
Update Access Control List (add or remove permissions).
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Delete
Remove permissions (instead of adding it).
.PARAMETER Groups
List of groups.
.PARAMETER Path
Access control path
.PARAMETER Propagate
Allow to propagate (inherit) permissions.
.PARAMETER Roles
List of roles.
.PARAMETER Tokens
List of API tokens.
.PARAMETER Users
List of users.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Groups,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Path,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Propagate,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Roles,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tokens,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Users
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Groups']) { $parameters['groups'] = $Groups }
        if($PSBoundParameters['Path']) { $parameters['path'] = $Path }
        if($PSBoundParameters['Propagate']) { $parameters['propagate'] = $Propagate }
        if($PSBoundParameters['Roles']) { $parameters['roles'] = $Roles }
        if($PSBoundParameters['Tokens']) { $parameters['tokens'] = $Tokens }
        if($PSBoundParameters['Users']) { $parameters['users'] = $Users }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/access/acl" -Parameters $parameters
    }
}

function Get-PveAccessDomains
{
<#
.DESCRIPTION
Authentication domain index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access/domains"
    }
}

function New-PveAccessDomains
{
<#
.DESCRIPTION
Add an authentication server.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER BaseDn
LDAP base domain name
.PARAMETER BindDn
LDAP bind domain name
.PARAMETER Capath
Path to the CA certificate store
.PARAMETER Cert
Path to the client certificate
.PARAMETER Certkey
Path to the client certificate key
.PARAMETER Comment
Description.
.PARAMETER Default
Use this as default realm
.PARAMETER Domain
AD domain name
.PARAMETER Filter
LDAP filter for user sync.
.PARAMETER GroupClasses
The objectclasses for groups.
.PARAMETER GroupDn
LDAP base domain name for group sync. If not set, the base_dn will be used.
.PARAMETER GroupFilter
LDAP filter for group sync.
.PARAMETER GroupNameAttr
LDAP attribute representing a groups name. If not set or found, the first value of the DN will be used as name.
.PARAMETER Mode
LDAP protocol mode.
.PARAMETER Password
LDAP bind password. Will be stored in '/etc/pve/priv/realm/<REALM>.pw'.
.PARAMETER Port
Server port.
.PARAMETER Realm
Authentication domain ID
.PARAMETER Secure
Use secure LDAPS protocol. DEPRECATED':' use 'mode' instead.
.PARAMETER Server1
Server IP address (or DNS name)
.PARAMETER Server2
Fallback Server IP address (or DNS name)
.PARAMETER Sslversion
LDAPS TLS/SSL version. It's not recommended to use version older than 1.2!
.PARAMETER SyncDefaultsOptions
The default options for behavior of synchronizations.
.PARAMETER SyncAttributes
Comma separated list of key=value pairs for specifying which LDAP attributes map to which PVE user field. For example, to map the LDAP attribute 'mail' to PVEs 'email', write  'email=mail'. By default, each PVE user field is represented  by an LDAP attribute of the same name.
.PARAMETER Tfa
Use Two-factor authentication.
.PARAMETER Type
Realm type.
.PARAMETER UserAttr
LDAP user attribute name
.PARAMETER UserClasses
The objectclasses for users.
.PARAMETER Verify
Verify the server's SSL certificate
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$BaseDn,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$BindDn,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Capath,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cert,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Certkey,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Default,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Domain,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Filter,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupClasses,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupDn,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupFilter,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupNameAttr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('ldap','ldaps','ldap+starttls')]
        [string]$Mode,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Password,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Port,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Realm,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Secure,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Server1,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Server2,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('tlsv1','tlsv1_1','tlsv1_2','tlsv1_3')]
        [string]$Sslversion,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$SyncDefaultsOptions,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$SyncAttributes,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tfa,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('ad','ldap','pam','pve')]
        [string]$Type,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$UserAttr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$UserClasses,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Verify
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['BaseDn']) { $parameters['base_dn'] = $BaseDn }
        if($PSBoundParameters['BindDn']) { $parameters['bind_dn'] = $BindDn }
        if($PSBoundParameters['Capath']) { $parameters['capath'] = $Capath }
        if($PSBoundParameters['Cert']) { $parameters['cert'] = $Cert }
        if($PSBoundParameters['Certkey']) { $parameters['certkey'] = $Certkey }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Default']) { $parameters['default'] = $Default }
        if($PSBoundParameters['Domain']) { $parameters['domain'] = $Domain }
        if($PSBoundParameters['Filter']) { $parameters['filter'] = $Filter }
        if($PSBoundParameters['GroupClasses']) { $parameters['group_classes'] = $GroupClasses }
        if($PSBoundParameters['GroupDn']) { $parameters['group_dn'] = $GroupDn }
        if($PSBoundParameters['GroupFilter']) { $parameters['group_filter'] = $GroupFilter }
        if($PSBoundParameters['GroupNameAttr']) { $parameters['group_name_attr'] = $GroupNameAttr }
        if($PSBoundParameters['Mode']) { $parameters['mode'] = $Mode }
        if($PSBoundParameters['Password']) { $parameters['password'] = (ConvertFrom-SecureString -SecureString $Password -AsPlainText) }
        if($PSBoundParameters['Port']) { $parameters['port'] = $Port }
        if($PSBoundParameters['Realm']) { $parameters['realm'] = $Realm }
        if($PSBoundParameters['Secure']) { $parameters['secure'] = $Secure }
        if($PSBoundParameters['Server1']) { $parameters['server1'] = $Server1 }
        if($PSBoundParameters['Server2']) { $parameters['server2'] = $Server2 }
        if($PSBoundParameters['Sslversion']) { $parameters['sslversion'] = $Sslversion }
        if($PSBoundParameters['SyncDefaultsOptions']) { $parameters['sync-defaults-options'] = $SyncDefaultsOptions }
        if($PSBoundParameters['SyncAttributes']) { $parameters['sync_attributes'] = $SyncAttributes }
        if($PSBoundParameters['Tfa']) { $parameters['tfa'] = $Tfa }
        if($PSBoundParameters['Type']) { $parameters['type'] = $Type }
        if($PSBoundParameters['UserAttr']) { $parameters['user_attr'] = $UserAttr }
        if($PSBoundParameters['UserClasses']) { $parameters['user_classes'] = $UserClasses }
        if($PSBoundParameters['Verify']) { $parameters['verify'] = $Verify }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/access/domains" -Parameters $parameters
    }
}

function Remove-PveAccessDomains
{
<#
.DESCRIPTION
Delete an authentication server.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Realm
Authentication domain ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Realm
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/access/domains/$Realm"
    }
}

function Get-PveAccessDomainsIdx
{
<#
.DESCRIPTION
Get auth server configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Realm
Authentication domain ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Realm
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access/domains/$Realm"
    }
}

function Set-PveAccessDomains
{
<#
.DESCRIPTION
Update authentication server settings.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER BaseDn
LDAP base domain name
.PARAMETER BindDn
LDAP bind domain name
.PARAMETER Capath
Path to the CA certificate store
.PARAMETER Cert
Path to the client certificate
.PARAMETER Certkey
Path to the client certificate key
.PARAMETER Comment
Description.
.PARAMETER Default
Use this as default realm
.PARAMETER Delete
A list of settings you want to delete.
.PARAMETER Digest
Prevent changes if current configuration file has different SHA1 digest. This can be used to prevent concurrent modifications.
.PARAMETER Domain
AD domain name
.PARAMETER Filter
LDAP filter for user sync.
.PARAMETER GroupClasses
The objectclasses for groups.
.PARAMETER GroupDn
LDAP base domain name for group sync. If not set, the base_dn will be used.
.PARAMETER GroupFilter
LDAP filter for group sync.
.PARAMETER GroupNameAttr
LDAP attribute representing a groups name. If not set or found, the first value of the DN will be used as name.
.PARAMETER Mode
LDAP protocol mode.
.PARAMETER Password
LDAP bind password. Will be stored in '/etc/pve/priv/realm/<REALM>.pw'.
.PARAMETER Port
Server port.
.PARAMETER Realm
Authentication domain ID
.PARAMETER Secure
Use secure LDAPS protocol. DEPRECATED':' use 'mode' instead.
.PARAMETER Server1
Server IP address (or DNS name)
.PARAMETER Server2
Fallback Server IP address (or DNS name)
.PARAMETER Sslversion
LDAPS TLS/SSL version. It's not recommended to use version older than 1.2!
.PARAMETER SyncDefaultsOptions
The default options for behavior of synchronizations.
.PARAMETER SyncAttributes
Comma separated list of key=value pairs for specifying which LDAP attributes map to which PVE user field. For example, to map the LDAP attribute 'mail' to PVEs 'email', write  'email=mail'. By default, each PVE user field is represented  by an LDAP attribute of the same name.
.PARAMETER Tfa
Use Two-factor authentication.
.PARAMETER UserAttr
LDAP user attribute name
.PARAMETER UserClasses
The objectclasses for users.
.PARAMETER Verify
Verify the server's SSL certificate
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$BaseDn,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$BindDn,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Capath,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Cert,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Certkey,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Default,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Delete,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Digest,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Domain,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Filter,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupClasses,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupDn,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupFilter,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupNameAttr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('ldap','ldaps','ldap+starttls')]
        [string]$Mode,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Password,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Port,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Realm,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Secure,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Server1,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Server2,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('tlsv1','tlsv1_1','tlsv1_2','tlsv1_3')]
        [string]$Sslversion,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$SyncDefaultsOptions,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$SyncAttributes,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Tfa,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$UserAttr,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$UserClasses,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Verify
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['BaseDn']) { $parameters['base_dn'] = $BaseDn }
        if($PSBoundParameters['BindDn']) { $parameters['bind_dn'] = $BindDn }
        if($PSBoundParameters['Capath']) { $parameters['capath'] = $Capath }
        if($PSBoundParameters['Cert']) { $parameters['cert'] = $Cert }
        if($PSBoundParameters['Certkey']) { $parameters['certkey'] = $Certkey }
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Default']) { $parameters['default'] = $Default }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Digest']) { $parameters['digest'] = $Digest }
        if($PSBoundParameters['Domain']) { $parameters['domain'] = $Domain }
        if($PSBoundParameters['Filter']) { $parameters['filter'] = $Filter }
        if($PSBoundParameters['GroupClasses']) { $parameters['group_classes'] = $GroupClasses }
        if($PSBoundParameters['GroupDn']) { $parameters['group_dn'] = $GroupDn }
        if($PSBoundParameters['GroupFilter']) { $parameters['group_filter'] = $GroupFilter }
        if($PSBoundParameters['GroupNameAttr']) { $parameters['group_name_attr'] = $GroupNameAttr }
        if($PSBoundParameters['Mode']) { $parameters['mode'] = $Mode }
        if($PSBoundParameters['Password']) { $parameters['password'] = (ConvertFrom-SecureString -SecureString $Password -AsPlainText) }
        if($PSBoundParameters['Port']) { $parameters['port'] = $Port }
        if($PSBoundParameters['Secure']) { $parameters['secure'] = $Secure }
        if($PSBoundParameters['Server1']) { $parameters['server1'] = $Server1 }
        if($PSBoundParameters['Server2']) { $parameters['server2'] = $Server2 }
        if($PSBoundParameters['Sslversion']) { $parameters['sslversion'] = $Sslversion }
        if($PSBoundParameters['SyncDefaultsOptions']) { $parameters['sync-defaults-options'] = $SyncDefaultsOptions }
        if($PSBoundParameters['SyncAttributes']) { $parameters['sync_attributes'] = $SyncAttributes }
        if($PSBoundParameters['Tfa']) { $parameters['tfa'] = $Tfa }
        if($PSBoundParameters['UserAttr']) { $parameters['user_attr'] = $UserAttr }
        if($PSBoundParameters['UserClasses']) { $parameters['user_classes'] = $UserClasses }
        if($PSBoundParameters['Verify']) { $parameters['verify'] = $Verify }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/access/domains/$Realm" -Parameters $parameters
    }
}

function New-PveAccessDomainsSync
{
<#
.DESCRIPTION
Syncs users and/or groups from the configured LDAP to user.cfg. NOTE':' Synced groups will have the name 'name-$realm', so make sure those groups do not exist to prevent overwriting.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER DryRun
If set, does not write anything.
.PARAMETER EnableNew
Enable newly synced users immediately.
.PARAMETER Full
If set, uses the LDAP Directory as source of truth, deleting users or groups not returned from the sync. Otherwise only syncs information which is not already present, and does not deletes or modifies anything else.
.PARAMETER Purge
Remove ACLs for users or groups which were removed from the config during a sync.
.PARAMETER Realm
Authentication domain ID
.PARAMETER Scope
Select what to sync.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$DryRun,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$EnableNew,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Full,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Purge,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Realm,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('users','groups','both')]
        [string]$Scope
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['DryRun']) { $parameters['dry-run'] = $DryRun }
        if($PSBoundParameters['EnableNew']) { $parameters['enable-new'] = $EnableNew }
        if($PSBoundParameters['Full']) { $parameters['full'] = $Full }
        if($PSBoundParameters['Purge']) { $parameters['purge'] = $Purge }
        if($PSBoundParameters['Scope']) { $parameters['scope'] = $Scope }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/access/domains/$Realm/sync" -Parameters $parameters
    }
}

function Get-PveAccessTicket
{
<#
.DESCRIPTION
Dummy. Useful for formatters which want to provide a login page.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access/ticket"
    }
}

function New-PveAccessTicket
{
<#
.DESCRIPTION
Create or verify authentication ticket.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Otp
One-time password for Two-factor authentication.
.PARAMETER Password
The secret password. This can also be a valid ticket.
.PARAMETER Path
Verify ticket, and check if user have access 'privs' on 'path'
.PARAMETER Privs
Verify ticket, and check if user have access 'privs' on 'path'
.PARAMETER Realm
You can optionally pass the realm using this parameter. Normally the realm is simply added to the username <username>@<relam>.
.PARAMETER Username
User name
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Otp,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Password,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Path,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Privs,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Realm,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Username
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Otp']) { $parameters['otp'] = $Otp }
        if($PSBoundParameters['Password']) { $parameters['password'] = (ConvertFrom-SecureString -SecureString $Password -AsPlainText) }
        if($PSBoundParameters['Path']) { $parameters['path'] = $Path }
        if($PSBoundParameters['Privs']) { $parameters['privs'] = $Privs }
        if($PSBoundParameters['Realm']) { $parameters['realm'] = $Realm }
        if($PSBoundParameters['Username']) { $parameters['username'] = $Username }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/access/ticket" -Parameters $parameters
    }
}

function Set-PveAccessPassword
{
<#
.DESCRIPTION
Change user password.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Password
The new password.
.PARAMETER Userid
User ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Password,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Userid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Password']) { $parameters['password'] = (ConvertFrom-SecureString -SecureString $Password -AsPlainText) }
        if($PSBoundParameters['Userid']) { $parameters['userid'] = $Userid }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/access/password" -Parameters $parameters
    }
}

function New-PveAccessTfa
{
<#
.DESCRIPTION
Finish a u2f challenge.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Response
The response to the current authentication challenge.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Response
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Response']) { $parameters['response'] = $Response }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/access/tfa" -Parameters $parameters
    }
}

function Set-PveAccessTfa
{
<#
.DESCRIPTION
Change user u2f authentication.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Action
The action to perform
.PARAMETER Config
A TFA configuration. This must currently be of type TOTP of not set at all.
.PARAMETER Key
When adding TOTP, the shared secret value.
.PARAMETER Password
The current password.
.PARAMETER Response
Either the the response to the current u2f registration challenge, or, when adding TOTP, the currently valid TOTP value.
.PARAMETER Userid
User ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][ValidateSet('delete','new','confirm')]
        [string]$Action,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Config,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Key,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SecureString]$Password,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Response,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Userid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Action']) { $parameters['action'] = $Action }
        if($PSBoundParameters['Config']) { $parameters['config'] = $Config }
        if($PSBoundParameters['Key']) { $parameters['key'] = $Key }
        if($PSBoundParameters['Password']) { $parameters['password'] = (ConvertFrom-SecureString -SecureString $Password -AsPlainText) }
        if($PSBoundParameters['Response']) { $parameters['response'] = $Response }
        if($PSBoundParameters['Userid']) { $parameters['userid'] = $Userid }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/access/tfa" -Parameters $parameters
    }
}

function Get-PveAccessPermissions
{
<#
.DESCRIPTION
Retrieve effective permissions of given user/token.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Path
Only dump this specific path, not the whole tree.
.PARAMETER Userid
User ID or full API token ID
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Path,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Userid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Path']) { $parameters['path'] = $Path }
        if($PSBoundParameters['Userid']) { $parameters['userid'] = $Userid }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/access/permissions" -Parameters $parameters
    }
}

function Get-PvePools
{
<#
.DESCRIPTION
Pool index.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/pools"
    }
}

function New-PvePools
{
<#
.DESCRIPTION
Create new pool.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
--
.PARAMETER Poolid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Poolid
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Poolid']) { $parameters['poolid'] = $Poolid }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/pools" -Parameters $parameters
    }
}

function Remove-PvePools
{
<#
.DESCRIPTION
Delete pool.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Poolid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Poolid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Delete -Resource "/pools/$Poolid"
    }
}

function Get-PvePoolsIdx
{
<#
.DESCRIPTION
Get pool configuration.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Poolid
--
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Poolid
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/pools/$Poolid"
    }
}

function Set-PvePools
{
<#
.DESCRIPTION
Update pool data.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Comment
--
.PARAMETER Delete
Remove vms/storage (instead of adding it).
.PARAMETER Poolid
--
.PARAMETER Storage
List of storage IDs.
.PARAMETER Vms
List of virtual machines.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Comment,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Delete,

        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Poolid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Storage,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Vms
    )

    process {
        $parameters = @{}
        if($PSBoundParameters['Comment']) { $parameters['comment'] = $Comment }
        if($PSBoundParameters['Delete']) { $parameters['delete'] = $Delete }
        if($PSBoundParameters['Storage']) { $parameters['storage'] = $Storage }
        if($PSBoundParameters['Vms']) { $parameters['vms'] = $Vms }

        return Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/pools/$Poolid" -Parameters $parameters
    }
}

function Get-PveVersion
{
<#
.DESCRIPTION
API version details. The result also includes the global datacenter confguration.
.PARAMETER PveTicket
Ticket data connection.
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket
    )

    process {
        return Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/version"
    }
}
