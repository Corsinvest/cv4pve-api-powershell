# SPDX-FileCopyrightText: Copyright Corsinvest Srl
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
Offline tests of what the caller gets when a request fails: no cluster needed.

.DESCRIPTION
Replaces, inside the module, Invoke-RestMethod and the port check with fakes, then checks:
- every request has a timeout;
- -Debug and the PveResponse do not show secrets sent in the query string;
- a login answered without a ticket is refused, and a refused login says why;
- the body of an HTTP error (the refused parameters) is kept;
- a guest listing that fails is reported with its reason, not as "not found";
- null parameters are not sent.

Exit code 0 when every test passes.

.EXAMPLE
pwsh -NoProfile -File tests/Test-Failures.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$module = Import-Module (Join-Path $PSScriptRoot '../Corsinvest.ProxmoxVE.Api/Corsinvest.ProxmoxVE.Api.psd1') -Force -PassThru -DisableNameChecking

$script:passed = 0
$script:failed = [System.Collections.Generic.List[string]]::new()

function Assert-Equal([string]$Name, $Expected, $Actual) {
    $e = @($Expected) -join ','
    $a = @($Actual) -join ','
    if ($e -eq $a) { $script:passed++ }
    else { $script:failed.Add("$Name`n    expected: $e`n    actual:   $a") }
}

# Run a script block inside the module, where the private functions and the classes are visible.
function InModule([scriptblock]$Block, [object[]]$Arguments = @()) { & $module $Block @Arguments }

#region fakes
InModule {
    # calls made, last first; the answer comes from $script:Respond, which returns the response or throws
    $script:Calls = [System.Collections.Generic.List[hashtable]]::new()
    $script:Ok = { [pscustomobject]@{ data = 'ok' } }
    $script:Respond = $script:Ok

    function Invoke-RestMethod {
        $bound = @{}; for ($i = 0; $i -lt $args.Count; $i += 2) { $bound[$args[$i].TrimStart('-').TrimEnd(':')] = $args[$i + 1] }
        $script:Calls.Insert(0, $bound)
        & $script:Respond $bound
    }
    function Test-PortQuick { param($HostName, $Port, $Timeout) $true }
    Set-Item function:script:Invoke-RestMethod ${function:Invoke-RestMethod}
    Set-Item function:script:Test-PortQuick ${function:Test-PortQuick}
}

# Answer of the fake: what Invoke-RestMethod throws for an HTTP error, with the body as ErrorDetails
function Set-HttpError([int]$Status, [string]$Reason, [string]$Body) {
    InModule {
        param($Status, $Reason, $Body)
        $script:Respond = {
            $message = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$Status)
            $message.ReasonPhrase = $Reason
            $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Response status code does not indicate success: $Status ($Reason).", $message)
            $record = [System.Management.Automation.ErrorRecord]::new($exception, 'WebCmdletWebResponseException', 'InvalidOperation', $null)
            if ($Body) { $record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($Body) }
            throw $record
        }.GetNewClosure()
    } @($Status, $Reason, $Body)
}
function Set-Answer([scriptblock]$Respond) { InModule { param($Respond) $script:Respond = $Respond } @($Respond) }
function Set-Ok { InModule { $script:Respond = $script:Ok } }
function Get-LastCall { InModule { $script:Calls[0] } }
function Get-CallCount { InModule { $script:Calls.Count } }
#endregion

$cred = [pscredential]::new('root@pam', (ConvertTo-SecureString 'password-secret' -AsPlainText -Force))
$ticket = Connect-PveCluster -HostsAndPorts pve01 -ApiToken 'root@pam!ps=token-secret' -SkipRefreshPveTicketLast

#region timeout
$null = Invoke-PveRestApi -PveTicket $ticket -Method Get -Resource '/version'
Assert-Equal 'a request has a timeout, 100 seconds by default' 100 (Get-LastCall).TimeoutSec
$short = Connect-PveCluster -HostsAndPorts pve01 -ApiToken 'root@pam!ps=token-secret' -TimeoutSec 5 -SkipRefreshPveTicketLast
$null = Invoke-PveRestApi -PveTicket $short -Method Get -Resource '/version'
Assert-Equal '-TimeoutSec of Connect-PveCluster is used' 5 (Get-LastCall).TimeoutSec

Set-Answer { throw [System.Threading.Tasks.TaskCanceledException]::new('The request was canceled due to the configured HttpClient.Timeout of 5 seconds elapsing.') }
$r = Invoke-PveRestApi -PveTicket $short -Method Get -Resource '/version'
Assert-Equal 'a timeout gives StatusCode -1' -1 $r.StatusCode
Assert-Equal 'a timeout is not a success' $false $r.IsSuccessStatusCode
Assert-Equal 'a timeout gives its reason' $true ($r.ReasonPhrase -like '*Timeout of 5 seconds*')
Set-Ok
#endregion

#region secrets sent in the query string
$debug = & {
    $r = Invoke-PveRestApi -PveTicket $ticket -Method Get -Resource '/nodes/pve01/qemu/100/vncwebsocket' -Parameters @{ port = 5900; vncticket = 'vnc-secret' } -Debug
    $r
} 5>&1
$r = $debug | Where-Object { $_.GetType().Name -eq 'PveResponse' }
$debug = $debug | Out-String
Assert-Equal '-Debug does not show a secret of the query string' $false ($debug.Contains('vnc-secret'))
Assert-Equal '-Debug shows the request without the query string' $true ($debug.Contains('Get https://pve01:8006/api2/json/nodes/pve01/qemu/100/vncwebsocket'))
Assert-Equal '-Debug shows the other parameters' $true ($debug.Contains('5900'))
Assert-Equal 'the request is sent with the real value' $true ((Get-LastCall).Uri.Contains('vncticket=vnc-secret'))
Assert-Equal 'PveResponse.Parameters hides the secret' '****' $r.Parameters.vncticket
Assert-Equal 'PveResponse.Parameters keeps the other values' 5900 $r.Parameters.port
Assert-Equal 'the PveResponse printed does not show the secret' $false (($r | Format-List | Out-String).Contains('vnc-secret'))
#endregion

#region null parameters
$null = Invoke-PveRestApi -PveTicket $ticket -Method Get -Resource '/cluster/resources' -Parameters @{ type = 'vm'; node = $null }
Assert-Equal 'GET: a null parameter is not sent' 'https://pve01:8006/api2/json/cluster/resources?type=vm' (Get-LastCall).Uri
$null = Invoke-PveRestApi -PveTicket $ticket -Method Set -Resource '/nodes/pve01/qemu/100/config' -Parameters @{ cores = 2; description = $null }
Assert-Equal 'PUT: a null parameter is not sent' 'cores' (((Get-LastCall).Body | ConvertFrom-Json).PSObject.Properties.Name)
#endregion

#region HTTP errors
Set-HttpError 400 'Parameter verification failed.' '{"data":null,"errors":{"vmid":"invalid format","name":"too long"}}'
$r = Invoke-PveRestApi -PveTicket $ticket -Method Set -Resource '/nodes/pve01/qemu/abc/config' -Parameters @{ name = 'x' }
Assert-Equal 'HTTP error: status' 400 $r.StatusCode
Assert-Equal 'HTTP error: reason' 'Parameter verification failed.' $r.ReasonPhrase
Assert-Equal 'HTTP error: not a success' $false $r.IsSuccessStatusCode
Assert-Equal 'HTTP error: the refused parameters are kept' 'invalid format' $r.Response.errors.vmid
Assert-Equal 'HTTP error: ResponseInError' $true $r.ResponseInError()

Set-HttpError 403 'Permission check failed (/vms/100, VM.Snapshot)' '{"data":null}'
$r = Invoke-PveRestApi -PveTicket $ticket -Method Create -Resource '/nodes/pve01/qemu/100/snapshot' -Parameters @{ snapname = 'a' }
Assert-Equal 'HTTP error without errors: reason' 'Permission check failed (/vms/100, VM.Snapshot)' $r.ReasonPhrase
Assert-Equal 'HTTP error without errors: not ResponseInError' $false $r.ResponseInError()

Set-HttpError 502 'Bad Gateway' '<html>proxy</html>'
$r = Invoke-PveRestApi -PveTicket $ticket -Method Get -Resource '/version'
Assert-Equal 'HTTP error with a body that is not JSON: status kept' 502 $r.StatusCode
Assert-Equal 'HTTP error with a body that is not JSON: no response' $true ($null -eq $r.Response)

Set-Answer { throw [System.Net.Http.HttpRequestException]::new('No such host is known. (pve01:8006)') }
$r = Invoke-PveRestApi -PveTicket $ticket -Method Get -Resource '/version'
Assert-Equal 'no answer: StatusCode -1' -1 $r.StatusCode
Assert-Equal 'no answer: reason' 'No such host is known. (pve01:8006)' $r.ReasonPhrase
Assert-Equal 'no answer: ResponseInError does not fail' $false $r.ResponseInError()
Set-Ok
#endregion

#region login
function Get-ConnectError([scriptblock]$Respond) {
    Set-Answer $Respond
    $Global:PveTicketLast = $ticket
    try { $null = Connect-PveCluster -HostsAndPorts pve01 -Credentials $cred; 'no exception' }
    catch { $_.Exception.Message }
    finally { Set-Ok }
}

$message = Get-ConnectError { '<html>proxy login</html>' }
Assert-Equal 'login answered with a page: refused' $true ($message -like '*no ticket*')
Assert-Equal 'login answered with a page: the last ticket is not replaced' $ticket.ApiToken $Global:PveTicketLast.ApiToken
Assert-Equal 'login answered with an empty body: refused' $true ((Get-ConnectError { $null }) -like '*no ticket*')
Assert-Equal 'login answered without a ticket: refused' $true ((Get-ConnectError { [pscustomobject]@{ data = [pscustomobject]@{} } }) -like '*no ticket*')

Set-HttpError 401 '' ''
$message = Get-ConnectError (InModule { $script:Respond })
Assert-Equal 'login refused without a reason: the status is in the message' $true ($message -like '*401*')
Set-HttpError 401 'authentication failure' '{"data":null}'
$message = Get-ConnectError (InModule { $script:Respond })
Assert-Equal 'login refused: the reason is in the message' $true ($message -like '*authentication failure*')
$Global:PveTicketLast = $null
#endregion

#region guest listing that fails
Set-HttpError 403 'Permission check failed (/, Sys.Audit)' '{"data":null}'
$message = try { $null = Get-PveGuest -PveTicket $ticket -VmIdOrName 100; 'no error' } catch { $_.Exception.Message }
Assert-Equal 'Get-PveGuest: a refused listing is reported with status and reason' $true ($message -like '*403*Permission check failed*')
$message = try { $null = Start-PveGuest -PveTicket $ticket -VmIdOrName 100 -Confirm:$false; 'no error' } catch { $_.Exception.Message }
Assert-Equal 'Start-PveGuest: the reason of the refused listing, not "not found"' $true ($message -like '*403*Permission check failed*')
Set-Ok
#endregion

Remove-Module $module -Force

$total = $script:passed + $script:failed.Count
if ($script:failed.Count) {
    $script:failed | ForEach-Object { Write-Host "FAIL $_" -ForegroundColor Red }
    Write-Host "$($script:failed.Count) of $total tests failed" -ForegroundColor Red
    exit 1
}
Write-Host "All $total tests passed" -ForegroundColor Green
