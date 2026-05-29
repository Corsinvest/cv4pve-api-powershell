# SPDX-FileCopyrightText: Copyright Corsinvest Srl
# SPDX-License-Identifier: MIT

#Requires -Version 6.0

class PveValidateVmId : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() { return Get-PveVm | Select-Object -ExpandProperty vmid }
}

class PveValidateVmName : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        return Get-PveVm | Where-Object { $_.status -ne 'unknown' } | Select-Object -ExpandProperty name
    }
}

class PveValidateNode : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() { return Get-PveNodes | Select-Object -ExpandProperty node }
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

$Global:PveTicketLast = $null

##########
## CORE ##
##########
#region Core

function Test-PortQuick {
    param (
        [string]$HostName,
        [int]$Port,
        [int]$Timeout = 5000 # Timeout in millisecondi
    )

    $ret = $false
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.ReceiveTimeout = $Timeout
        $tcpClient.SendTimeout = $Timeout

        $connection = $tcpClient.BeginConnect($HostName, $Port, $null, $null)
        if ($connection.AsyncWaitHandle.WaitOne($Timeout, $false)) {
            $tcpClient.EndConnect($connection)
            $ret = $true
        }
        else {
            #Write-Host "Timeout for ${HostName}:${Port}."
        }
    }
    catch {
        Write-Debug "Port $Port on $HostName It is NOT reachable."
    }
    finally {
        $tcpClient.Close() | Out-Null
    }

    return $ret
}

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
.PARAMETER ApiToken
Api Token format USER@REALM!TOKENID=UUID
.PARAMETER Otp
One-time password for Two-factor authentication.
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

        [string]$Otp,

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

            if (Test-PortQuick -HostName $hostTmp -Port $portTmp -Timeout 2000) {
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

            if($PSBoundParameters['Otp']) { $parameters['otp'] = $Otp }

            $response = Invoke-PveRestApi -PveTicket $pveTicket -Method Create -Resource '/access/ticket' -Parameters $parameters

            #erro response
            if (!$response.IsSuccessStatusCode -or $response.StatusCode -le 0) {
                throw $response.ReasonPhrase
            }

            if ($response.Response.data.NeedTFA){
                throw "Couldn't authenticate user: missing Two Factor Authentication (TFA)"
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
(Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource '/version').Resonse.data

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
        [ValidateSet('json', 'extjs', 'html', 'text', 'png','')]
        [string]$ResponseType = 'json',

        [hashtable]$Parameters
    )

    process {
        #use last ticket
        if ($null -eq $PveTicket) {
            if ($null -ne $Global:PveTicketLast) {
                $PveTicket = $Global:PveTicketLast
            } else {
                throw 'No PveTicket - Cluster Connect missing?'
            }
        }

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

        $parametersTmp = @{}

        if ($Parameters -and $Parameters.Count -gt 0 )
        {
             $Parameters.keys | ForEach-Object {
                $parametersTmp[$_] = ($Parameters[$_] -is [switch] -or $Parameters[$_] -is [bool]) `
                                         ? $Parameters[$_] ? 1 : 0 `
                                         : $Parameters[$_]
             }
        }

        if ($parametersTmp.Count -gt 0 -and $('Get', 'Delete').IndexOf($restMethod) -ge 0) {
            Write-Debug 'Parameters:'
            $parametersTmp.keys | ForEach-Object { Write-Debug "$_ => $($parametersTmp[$_])" }

            $query = '?' + (($parametersTmp.Keys | ForEach-Object { "$_=$($parametersTmp[$_])" }) -join '&')
        }

        $response = New-Object PveResponse -Property @{
            Method          = $restMethod
            Parameters      = $parametersTmp
            ResponseType    = $ResponseType
            RequestResource = $Resource
        }

        $headers = @{ CSRFPreventionToken = $PveTicket.CSRFPreventionToken }
        if($PveTicket.ApiToken -ne '') { $headers.Authorization = 'PVEAPIToken ' + $PveTicket.ApiToken }

        $url = "https://$($PveTicket.HostName):$($PveTicket.Port)/api2"
        if($ResponseType -ne '') { $url += "/$ResponseType" }
        $url += "$Resource$query"

        $params = @{
            Uri                  = $url
            Method               = $restMethod
            WebSession           = $session
            SkipCertificateCheck = $PveTicket.SkipCertificateCheck
            Headers              = $headers
        }

        Write-Debug ($params | Format-List | Out-String)

        #body parameters
        if ($parametersTmp.Count -gt 0 -and $('Post', 'Put').IndexOf($restMethod) -ge 0) {
            $params['ContentType'] = 'application/json'
            $params['body'] = ($parametersTmp | ConvertTo-Json)
            Write-Debug "Body: $($params.body | Format-Table | Out-String)"
        }

        try {
            Write-Debug "Params: $($params | Format-Table | Out-String)"

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
#region Convert Time Windows/Unix
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
    [OutputType([long])]
    param (
        [Parameter(Mandatory,Position = 0,ValueFromPipeline )]
        [DateTime]$Date
    )

    process {
        [long] (New-Object -TypeName System.DateTimeOffset -ArgumentList ($Date)).ToUnixTimeSeconds()
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

    return [System.DateTimeOffset]::FromUnixTimeSeconds($Time).DateTime
}
#endregion

Function Invoke-PveSpice {
    <#
.DESCRIPTION
Enter Spice VM.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER VmIdOrName
The (unique) ID or Name of the VM.
.PARAMETER Viewer
Path of Spice remove viewer.
- Linux /usr/bin/remote-viewer
- Windows C:\Program Files\VirtViewer v?.?-???\bin\remote-viewer.exe
.OUTPUTS
PveResponse. Return response.
#>
    [OutputType([PveResponse])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$VmIdOrName,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Viewer
    )

    process {
        $vm = Get-PveVm -PveTicket $PveTicket -VmIdOrName $VmIdOrName | Select-Object -First 1
        if ($vm.type -eq 'qemu') {
            $node = $vm.node
            $vmid = $vm.vmid

            $parameters = @{ proxy = $null -eq $PveTicket ? $PveTicketLast.HostName : $PveTicket.HostName }

            $ret = Invoke-PveRestApi -PveTicket $PveTicket -Method Create -ResponseType '' -Resource "/spiceconfig/nodes/$node/qemu/$vmid/spiceproxy" -Parameters $parameters

            Write-Debug "======================================="
            Write-Debug "SPICE Proxy Configuration"
            Write-Debug "======================================="
            Write-Debug $ret
            Write-Debug "======================================="

            $tmp = New-TemporaryFile
            $ret.Response | Out-File $tmp.FullName

            Start-Process -FilePath $Viewer -Args $tmp.FullName
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
Bool. $True Return task is done within Timeout, $False if not
#>
    [OutputType([bool])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
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
        if ($Wait -le 0) { $Wait = 500; }
        if ($Timeout -lt $Wait) { $Timeout = $Wait + 5000; }
        $timeStart = [DateTime]::Now

        while ($isRunning -and ([DateTime]::Now - $timeStart).TotalMilliseconds -lt $Timeout) {
            $isRunning = Get-PveTaskIsRunning -PveTicket $PveTicket -Upid $Upid
            Start-Sleep -Milliseconds $Wait
        }

        #check timeout
        return ([DateTime]::Now - $timeStart).TotalMilliseconds -lt $Timeout
    }
}

function Wait-PveTaskIsFinishedWithProgress {
    <#
.DESCRIPTION
Wait for a task to finish, show Powershell Progressbar while waiting
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Upid
Upid task e.g UPID:pve1:00004A1A:0964214C:5EECEF11:vzdump:134:root@pam:
.PARAMETER Wait
Millisecond wait next check
.PARAMETER Timeout
Millisecond timeout
.PARAMETER ProgressActivityText
Acitivity (Text) for Write-Progress, defaults to Upid when empty
.PARAMETER ProgressStatusText
Status-Text for Write-Progress, default is "Waiting...", is shown in front of remaining time and percent
.PARAMETER ProgessActivityId
Id for Write-Progress, change when other Write-Progress is already shown
.OUTPUTS
Bool. $True Return task is done within Timeout, $False if not
#>
    [OutputType([bool])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Upid,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Wait = 500,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Timeout = 10000,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ProgressActivityText,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ProgressStatusText = "Waiting...",

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$ProgessActivityId = 1
    )

    process {
        $isRunning = $true;
        if ($Wait -le 0) { $Wait = 500; }
        if ($Timeout -lt $Wait) { $Timeout = $Wait + 5000; }
        if ($null -eq $ProgressActivityText -OR $ProgressActivityText -eq "") { $ProgressActivityText = $Upid; }
        $timeStart = [DateTime]::Now
        $waitTimeMs = $timeStart
        $timePercent = 0

        while ($isRunning -and ([DateTime]::Now - $timeStart).TotalMilliseconds -lt $Timeout) {
            $waitTimeMs = $([DateTime]::Now - $timeStart).TotalMilliseconds
            $timePercent = $waitTimeMs * (100 / $Timeout)
            Write-Progress -Id $ProgessActivityId -Activity $ProgressActivityText -Status "$($ProgressStatusText) ($([Math]::Round($waitTimeMs/1000))/$([Math]::Round($Timeout/1000)) Seconds)" -PercentComplete $timePercent
            $isRunning = Get-PveTaskIsRunning -PveTicket $PveTicket -Upid $Upid
            Start-Sleep -Milliseconds $Wait
        }

        # end Write-Progress
        Write-Progress -Id $ProgessActivityId -Activity $ProgressActivityText -Completed

        #check timeout
        return ([DateTime]::Now - $timeStart).TotalMilliseconds -lt $Timeout
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
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Upid
    )

    process {
        return (Get-PveNodesTasksStatus -PveTicket $PveTicket -Node $Upid.Split(':')[1] -Upid $Upid).Response.data.status -eq 'running'
    }
}
#endregion

# function Get-PveStorage {
#     <#
# .DESCRIPTION
# Get nodes
# .PARAMETER PveTicket
# Ticket data connection.
# .PARAMETER Storage
# The Name of the storage.
# .OUTPUTS
# PSCustomObject. Return Vm Data.
# #>
#     [OutputType([PSCustomObject])]
#     [CmdletBinding()]
#     Param(
#         [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
#         [PveTicket]$PveTicket,

#         [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
#         [string]$Storage
#     )

#     process {
#         return $null -eq $Storage

#         $data = (Get-PveClusterResources -PveTicket $PveTicket -Type storage).Response.data
#         return $null -eq $Storage ?
#                 $data :
#                 $data | Where-Object { $_.storage -like $Storage }
#     }
# }

function Get-PveNode {
    <#
.DESCRIPTION
Get nodes
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER Node
The Name of the node.
.OUTPUTS
PSCustomObject. Return Node/s data.
#>
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Node
    )

    process {
        $data = (Get-PveClusterResources -PveTicket $PveTicket -Type node).Response.data
        if($PSBoundParameters['Node'])
        {
            return $data | Where-Object { $_.node -like $Node }
        }
        else
        {
            return $data
        }
    }
}

function Get-PveVm {
    <#
.DESCRIPTION
Get VMs/CTs from id or name.
.PARAMETER PveTicket
Ticket data connection.
.PARAMETER VmIdOrName
The id or name VM/CT comma separated (eg. 100,101,102,TestDebian)
-vmid or -name exclude (e.g. -200,-TestUbuntu)
range 100:107,-105,200:204
'@pool-???' for all VM/CT in specific pool (e.g. @pool-customer1),
'@tag-???' for all VM/CT in specific tags (e.g. @tag-customerA),
'@node-???' for all VM/CT in specific node (e.g. @node-pve1, @node-\$(hostname)),
'@all-???' for all VM/CT in specific host (e.g. @all-pve1, @all-\$(hostname)),
'@all' for all VM/CT in cluster";
.OUTPUTS
PSCustomObject. Return Vm/s data.
#>
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PveTicket]$PveTicket,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$VmIdOrName
    )

    process {
        $data = (Get-PveClusterResources -PveTicket $PveTicket -Type vm).Response.data
        if ($PSBoundParameters['VmIdOrName'])
        {
            return $data | Where-Object { VmCheckIdOrName -Vm $_ -VmIdOrName $VmIdOrName }
        }
        else
        {
            return $data
        }
    }
}

function IsNumeric([string]$x) {
    return $null -ne ($x -as [double])
}

function VmCheckIdOrName
{
    [OutputType([bool])]
    Param(
        [PSCustomObject]$Vm,

        [ValidateNotNullOrEmpty()]
        [string]$VmIdOrName
    )

    if($VmIdOrName -eq 'all') { return $true }

    foreach ($item in $VmIdOrName.Split(","))
    {
        If($item -like '*:*')
        {
            #range number
            $range = $item.Split(":");
            if(($range.Length -eq 2) -and (IsNumeric($range[0])) -and (IsNumeric($range[1])))
            {
                if (($vm.vmid -ge $range[0]) -and ($vm.vmid -le $range[1])) {
                    return $true
                }
            }
        }
        ElseIf((IsNumeric($item)))
        {
            if($vm.vmid -eq $item) { return $true }
        }
        Elseif($item.IndexOf("all-") -eq 0 -and $item.Substring(4) -eq $vm.node)
        {
            #all vm in node
            return $true
        }
        Elseif($item.IndexOf("@all-") -eq 0 -and $item.Substring(5) -eq $vm.node)
        {
            #all vm in node
            return $true
        }
        Elseif($item.IndexOf("@node-") -eq 0 -and $item.Substring(6) -eq $vm.node)
        {
            #all vm in node
            return $true
        }
        Elseif($item.IndexOf("@pool-") -eq 0 -and $item.Substring(6) -eq $vm.pool)
        {
            #all vm in pool
            return $true
        }
        Elseif($item.IndexOf("@tag-") -eq 0 -and ($vm.tags + "").Split(",").Contains($item.Substring(5)))
        {
            #all vm in tag
            return $true
        }
        ElseIf($vm.name -like $item) {
            #name
            return $true
        }
    }

    return $false
}

function Unlock-PveVm {
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
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$VmIdOrName
    )

    process {
        $vm = Get-PveVm -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return Set-PveNodesQemuConfig -PveTicket $PveTicket -node $vm.node -Vmid $vm.vmid -Delete 'lock' -Skiplock:$true }
        ElseIf ($vm.type -eq 'lxc') { return Set-PveNodesLxcConfig -PveTicket $PveTicket -node $vm.node -Vmid $vm.vmid -Delete 'lock' }
    }
}

#region VM status
function Start-PveVm {
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
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$VmIdOrName
    )

    process {
        $vm = Get-PveVm -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | New-PveNodesQemuStatusStart -PveTicket $PveTicket }
        ElseIf ($vm.type -eq 'lxc') { return $vm | New-PveNodesLxcStatusStart -PveTicket $PveTicket }
    }
}

function Stop-PveVm {
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
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$VmIdOrName
    )

    process {
        $vm = Get-PveVm -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | New-PveNodesQemuStatusStop -PveTicket $PveTicket }
        ElseIf ($vm.type -eq 'lxc') { return $vm | New-PveNodesLxcStatusStop -PveTicket $PveTicket }
    }
}

function Suspend-PveVm {
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
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$VmIdOrName
    )

    process {
        $vm = Get-PveVm -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | New-PveNodesQemuStatusSuspend -PveTicket $PveTicket }
        ElseIf ($vm.type -eq 'lxc') { return $vm | New-PveNodesLxcStatusSuspend -PveTicket $PveTicket }
    }
}

function Resume-PveVm {
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
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$VmIdOrName
    )

    process {
        $vm = Get-PveVm -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | New-PveNodesQemuStatusResume -PveTicket $PveTicket }
        ElseIf ($vm.type -eq 'lxc') { return $vm | New-PveNodesLxcStatusResume -PveTicket $PveTicket }
    }
}

function Reset-PveVm {
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
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$VmIdOrName
    )

    process {
        $vm = Get-PveVm -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | New-PveNodesQemuStatusReset -PveTicket $PveTicket }
        ElseIf ($vm.type -eq 'lxc') { throw "Lxc not implement reset!" }
    }
}
#endregion

#region Snapshot
function Get-PveVmSnapshot {
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
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$VmIdOrName
    )

    process {
        $vm = Get-PveVm -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | Get-PveNodesQemuSnapshot -PveTicket $PveTicket }
        ElseIf ($vm.type -eq 'lxc') { return $vm | Get-PveNodesLxcSnapshot -PveTicket $PveTicket }
    }
}

function New-PveVmSnapshot {
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

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$VmIdOrName,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Snapname,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch]$Vmstate = $false
    )

    process {
        $vm = Get-PveVm -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu')
        {
            if ($Vmstate) {
                return $vm | New-PveNodesQemuSnapshot -PveTicket $PveTicket -Snapname $Snapname -Description $Description -Vmstate
            }
            else
            {
                return $vm | New-PveNodesQemuSnapshot -PveTicket $PveTicket -Snapname $Snapname -Description $Description
            }
        }
        ElseIf ($vm.type -eq 'lxc')
        {
            return $vm | New-PveNodesLxcSnapshot -PveTicket $PveTicket -Snapname $Snapname -Description $Description
        }
    }
}

function Remove-PveVmSnapshot {
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
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$VmIdOrName,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Snapname
    )

    process {
        $vm = Get-PveVm -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | Remove-PveNodesQemuSnapshot -PveTicket $PveTicket -Snapname $Snapname }
        ElseIf ($vm.type -eq 'lxc') { return $vm | Remove-PveNodesLxcSnapshot -PveTicket $PveTicket -Snapname $Snapname }
    }
}

function Undo-PveVmSnapshot {
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
        [PveTicket]$PveTicket,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$VmIdOrName,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Snapname
    )

    process {
        $vm = Get-PveVm -PveTicket $PveTicket -VmIdOrName $VmIdOrName
        if ($vm.type -eq 'qemu') { return $vm | New-PveNodesQemuSnapshotRollback -PveTicket $PveTicket -Snapname $Snapname }
        ElseIf ($vm.type -eq 'lxc') { return $vm | New-PveNodesLxcSnapshotRollback -PveTicket $PveTicket -Snapname $Snapname }
    }
}
#endregion
#endregion

###########
## ALIAS ##
###########

Set-Alias -Name Show-PveSpice -Value Invoke-PveSpice -PassThru
Set-Alias -Name Get-PveTasksStatus -Value Get-PveNodesTasksStatus -PassThru

#MONITORING
Set-Alias -Name Get-PveQemuMonitoring -Value Get-PveNodesQemuRrddata -PassThru
Set-Alias -Name Get-PveQemuMonitoring -Value Get-PveNodesQemuRrddata -PassThru
Set-Alias -Name Get-PveLxcMonitoring -Value Get-PveNodesLxcRrddata -PassThru

#QEMU

## status
Set-Alias -Name Start-PveQemu -Value New-PveNodesQemuStatusStart -PassThru
Set-Alias -Name Stop-PveQemu -Value New-PveNodesQeumStatusStop -PassThru
Set-Alias -Name Suspend-PveQemu -Value New-PveNodesQemuStatusSuspend -PassThru
Set-Alias -Name Resume-PveQemu -Value New-PveNodesQemuStatusResume -PassThru
Set-Alias -Name Reset-PveQemu -Value New-PveNodesQemuStatusReset -PassThru
Set-Alias -Name Restart-PveQemu -Value New-PveNodesQemuStatusReboot -PassThru
Set-Alias -Name Shutdown-PveQemu -Value New-PveNodesQemuStatusShutdown -PassThru

## snapshot
Set-Alias -Name Create-PveQemuSnapshot -Value New-PveNodesQemuSnapshot -PassThru
Set-Alias -Name Remove-PveQemuSnapshot -Value Remove-PveNodesQemuSnapshot -PassThru
Set-Alias -Name Undo-PveQemuSnapshot -Value New-PveNodesQemuSnapshotRollback -PassThru
Set-Alias  -Name Get-PveQemuSnapshot -Value Get-PveNodesQemuSnapshot -PassThru
Set-Alias -Name Get-PveQemuSnapshotConfig -Value Get-PveNodesQemuSnapshotConfig -PassThru
Set-Alias -Name Set-PveQemuSnapshot -Value Set-PveNodesQemuSnapshotConfig -PassThru

## misc
Set-Alias -Name Move-PveQemu -Value New-PveNodesQemuMigrate -PassThru
Set-Alias -Name Copy-PveQemu -Value New-PveNodesQemuClone -PassThru
Set-Alias -Name New-PveQemu -Value New-PveNodesQemu -PassThru
Set-Alias -Name Remove-PveQemu -Value Remove-PveNodesQemu -PassThru
Set-Alias -Name Set-PveQemuConfig -Value Set-PveNodesQemuConfig -PassThru
Set-Alias -Name Get-PveQemuConfig -Value Get-PveNodesQemuConfig -PassThru

#LXC
## status
Set-Alias -Name Start-PveLxc -Value New-PveNodesLxcStatusStart -PassThru
Set-Alias -Name Stop-PveLxc -Value New-PveNodesLxcStatusStop -PassThru
Set-Alias -Name Suspend-PveLxc -Value New-PveNodesLxcStatusSuspend -PassThru
Set-Alias -Name Resume-PveLxc -Value New-PveNodesLxcStatusResume -PassThru
Set-Alias -Name Restart-PveLxc -Value New-PveNodesLxcStatusReboot -PassThru
Set-Alias -Name Shutdown-PveLxc -Value New-PveNodesLxcStatusShutdown

## snapshot
Set-Alias -Name Create-PveLxcSnapshot -Value New-PveNodesLxcSnapshot -PassThru
Set-Alias -Name Remove-PveLxcSnapshot -Value Remove-PveNodesLxcSnapshot -PassThru
Set-Alias -Name Undo-PveLxcSnapshot -Value New-PveNodesLxcSnapshotRollback -PassThru
Set-Alias  -Name Get-PveLxcSnapshot -Value Get-PveNodesLxcSnapshot -PassThru
Set-Alias -Name Get-PveLxcSnapshotConfig -Value Get-PveNodesLxcSnapshotConfig -PassThru
Set-Alias -Name Set-PveLxcSnapshot -Value Set-PveNodesLxcSnapshotConfig -PassThru

## misc
Set-Alias -Name Move-PveLxc -Value New-PveNodesLxcMigrate -PassThru
Set-Alias -Name Copy-PveLxc -Value New-PveNodesLxcClone -PassThru
Set-Alias -Name New-PveLxc -Value New-PveNodesLxc -PassThru
Set-Alias -Name Remove-PveLxc -Value Remove-PveNodesLxc -PassThru
Set-Alias -Name Set-PveLxcConfig -Value Set-PveNodesLxcConfig -PassThru
Set-Alias -Name Get-PveLxcConfig -Value Get-PveNodesLxcConfig -PassThru

#NODE
Set-Alias -Name Update-PveNode -Value New-PveNodesAptUpdate -PassThru
Set-Alias -Name Backup-PveVzdump -Value New-PveNodesVzdump -PassThru
#Set-Alias -Name Stop-PveNode -Value New-PveNodesStatus -Command 'shutdown' -PassThru

#######################
## API AUTOGENERATED ##
#######################
# Load autogenerated API functions (dot-sourced into this module scope)
. "$PSScriptRoot\Corsinvest.ProxmoxVE.Api.Generated.ps1"
