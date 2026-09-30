# SPDX-FileCopyrightText: Copyright Corsinvest Srl
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
Offline tests of Connect-PveCluster and Invoke-PveRestApi: no cluster needed.

.DESCRIPTION
Replaces, inside the module, Invoke-RestMethod and the port check with fakes, then checks:
- the query string of GET and DELETE is encoded;
- -HostsAndPorts takes a list or one string with the nodes separated by commas;
- -Debug does not show passwords, second factors, tickets or tokens.

Exit code 0 when every test passes.

.EXAMPLE
pwsh -NoProfile -File tests/Test-RestApi.ps1
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
    # calls made, last first; /access/ticket answers with a ticket, the second factor with a full ticket
    $script:Calls = [System.Collections.Generic.List[hashtable]]::new()
    function Invoke-RestMethod {
        $bound = @{}; for ($i = 0; $i -lt $args.Count; $i += 2) { $bound[$args[$i].TrimStart('-').TrimEnd(':')] = $args[$i + 1] }
        $script:Calls.Insert(0, $bound)
        $body = $bound.Body ? ($bound.Body | ConvertFrom-Json) : $null
        if ($bound.Uri -like '*/access/ticket') {
            if ($body.'tfa-challenge') { return [pscustomobject]@{ data = [pscustomobject]@{ ticket = 'PVE:full-ticket-secret'; CSRFPreventionToken = 'csrf-secret'; username = $body.username } } }
            if ($body.username -like 'tfa*') { return [pscustomobject]@{ data = [pscustomobject]@{ ticket = 'PVE:!tfa!challenge-secret'; NeedTFA = 1; CSRFPreventionToken = 'csrf-secret'; username = $body.username } } }
            return [pscustomobject]@{ data = [pscustomobject]@{ ticket = 'PVE:ticket-secret'; CSRFPreventionToken = 'csrf-secret'; username = $body.username } }
        }
        return [pscustomobject]@{ data = 'ok' }
    }
    function Test-PortQuick { param($HostName, $Port, $Timeout) $HostName -notlike 'down*' }
    Set-Item function:script:Invoke-RestMethod ${function:Invoke-RestMethod}
    Set-Item function:script:Test-PortQuick ${function:Test-PortQuick}
}
#endregion

$cred = [pscredential]::new('root@pam', (ConvertTo-SecureString 'password-secret' -AsPlainText -Force))
$tfaCred = [pscredential]::new('tfa@pve', (ConvertTo-SecureString 'password-secret' -AsPlainText -Force))
$ticket = Connect-PveCluster -HostsAndPorts pve01 -Credentials $cred -SkipRefreshPveTicketLast

#region query string
$lastUri = { InModule { $script:Calls[0].Uri } }
$null = Invoke-PveRestApi -PveTicket $ticket -Method Get -Resource '/cluster/resources' -Parameters @{ type = 'a&b=c #+%' }
Assert-Equal 'GET query string encoded' 'https://pve01:8006/api2/json/cluster/resources?type=a%26b%3Dc%20%23%2B%25' (& $lastUri)
$null = Invoke-PveRestApi -PveTicket $ticket -Method Delete -Resource '/nodes/pve01/qemu/100' -Parameters @{ purge = $true }
Assert-Equal 'DELETE query string, bool as 1' 'https://pve01:8006/api2/json/nodes/pve01/qemu/100?purge=1' (& $lastUri)
$null = Invoke-PveRestApi -PveTicket $ticket -Method Create -Resource '/nodes/pve01/qemu/100/status/start' -Parameters @{ timeout = 10 }
Assert-Equal 'POST parameters in the body, not in the URL' 'https://pve01:8006/api2/json/nodes/pve01/qemu/100/status/start' (& $lastUri)
#endregion

#region -HostsAndPorts
function Get-Node([string[]]$HostsAndPorts) {
    try { $t = Connect-PveCluster -HostsAndPorts $HostsAndPorts -Credentials $cred -SkipRefreshPveTicketLast; "$($t.HostName):$($t.Port)" }
    catch { "throws: $($_.Exception.Message)" }
}
Assert-Equal 'one string with commas: first node that answers' 'pve02:8007' (Get-Node 'down1:8006,pve02:8007')
Assert-Equal 'one string with commas and spaces, default port' 'pve03:8006' (Get-Node 'down1:8006, down2 ,pve03')
Assert-Equal 'a list' 'pve04:8010' (Get-Node 'down1', 'pve04:8010')
#endregion

#region second factor
$t = Connect-PveCluster -HostsAndPorts pve01 -Credentials $tfaCred -Otp 123456 -SkipRefreshPveTicketLast
Assert-Equal 'TFA: full ticket from the second call' 'PVE:full-ticket-secret' $t.Ticket
$body = InModule { $script:Calls[0].Body } | ConvertFrom-Json
Assert-Equal 'TFA: code sent as totp:' 'totp:123456' $body.password
Assert-Equal 'TFA: challenge from the first call' 'PVE:!tfa!challenge-secret' $body.'tfa-challenge'
$null = Connect-PveCluster -HostsAndPorts pve01 -Credentials $tfaCred -Otp 'recovery:abcd' -SkipRefreshPveTicketLast
Assert-Equal 'TFA: type:value sent as it is' 'recovery:abcd' (InModule { $script:Calls[0].Body } | ConvertFrom-Json).password
$message = try { Connect-PveCluster -HostsAndPorts pve01 -Credentials $tfaCred -SkipRefreshPveTicketLast; 'no exception' } catch { $_.Exception.Message }
Assert-Equal 'TFA without a code throws' $true ($message -like '*Two Factor*')
#endregion

#region -Debug hides secrets
$debug = & {
    # -Debug: Write-Debug writes without asking (PowerShell 7)
    $null = Connect-PveCluster -HostsAndPorts pve01 -Credentials $tfaCred -Otp 123456 -SkipRefreshPveTicketLast -Debug
    $t = Connect-PveCluster -HostsAndPorts pve01 -ApiToken 'root@pam!ps=token-secret' -SkipRefreshPveTicketLast -Debug
    $null = Invoke-PveRestApi -PveTicket $t -Method Create -Resource '/access/users/a@pve/token/t1' -Parameters @{ comment = 'visible-comment' } -Debug
    $null = Invoke-PveRestApi -PveTicket $t -Method Set -Resource '/access/password' -Parameters @{ userid = 'a@pve'; password = 'new-password-secret' } -Debug
} 5>&1 | Out-String
foreach ($secret in 'password-secret', '123456', 'ticket-secret', 'challenge-secret', 'csrf-secret', 'token-secret', 'new-password-secret') {
    Assert-Equal "-Debug does not show '$secret'" $false ($debug.Contains($secret))
}
Assert-Equal '-Debug shows the other parameters' $true ($debug.Contains('visible-comment'))
# Invoke-RestMethod (PowerShell 7.4+) writes the body and the response to the debug stream by itself
Assert-Equal 'Invoke-RestMethod called with -Debug:$false' $false (InModule { $script:Calls[0].Debug })
Assert-Equal '-Debug shows the request' $true ($debug.Contains('Post https://pve01:8006/api2/json/access/ticket'))

InModule {
    $masked = Hide-PveSensitiveValue -Data ([pscustomobject]@{ 'full-tokenid' = 'a@pve!t1'; value = 'uuid-secret' }) -Resource '/access/users/a@pve/token/t1'
    Set-Variable -Scope Global -Name TestMasked -Value $masked
}
Assert-Equal 'value of a new API token hidden' '****' $Global:TestMasked.value
Assert-Equal 'id of a new API token hidden too (contains token)' '****' $Global:TestMasked.'full-tokenid'
Remove-Variable -Scope Global -Name TestMasked
#endregion

Remove-Module $module -Force

$total = $script:passed + $script:failed.Count
if ($script:failed.Count) {
    $script:failed | ForEach-Object { Write-Host "FAIL $_" -ForegroundColor Red }
    Write-Host "$($script:failed.Count) of $total tests failed" -ForegroundColor Red
    exit 1
}
Write-Host "All $total tests passed" -ForegroundColor Green
