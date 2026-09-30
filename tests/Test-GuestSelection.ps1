# SPDX-FileCopyrightText: Copyright Corsinvest Srl
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
Offline tests of the hand-written guest and task functions: no cluster needed.

.DESCRIPTION
Replaces, inside the module, the generated cmdlets these functions call (cluster resources, pools, task
status, status and snapshot endpoints) with fakes, then checks:
- the selection of Get-PveGuest -VmIdOrName, with the cases of the tests of cv4pve-api-dotnet
  (VmJollyTests, VmCheckIdOrNameTests) plus the PowerShell wildcards;
- that the power and snapshot functions call the qemu or lxc endpoint for each selected guest;
- the task functions: failed status reads throw, a failed call has nothing to wait for.

Exit code 0 when every test passes.

.EXAMPLE
pwsh -NoProfile -File tests/Test-GuestSelection.ps1
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
    function New-FakeResponse($Data, [int]$StatusCode = 200, [string]$Reason = 'OK') {
        $r = [PveResponse]::new()
        $r.StatusCode = $StatusCode
        $r.ReasonPhrase = $Reason
        $r.IsSuccessStatusCode = $StatusCode -ge 200 -and $StatusCode -lt 300
        if ($r.IsSuccessStatusCode) { $r.Response = [pscustomobject]@{ data = $Data } }
        return $r
    }
    Set-Item function:script:New-FakeResponse ${function:New-FakeResponse}

    function Vm($vmid, $name, $node, $tags = '', $type = 'qemu') {
        [pscustomobject]@{ id = "$type/$vmid"; vmid = $vmid; name = $name; node = $node; tags = $tags; type = $type }
    }

    # the guests of VmJollyTests (cv4pve-api-dotnet)
    $script:FakeVms = @(
        (Vm 100 'web-01' 'pve1' 'prod;web'),
        (Vm 101 'web-02' 'pve1' 'prod;web'),
        (Vm 102 'db-01' 'pve2' 'prod'),
        (Vm 150 'test-01' 'pve2' 'test'),
        (Vm 200 'ct-01' 'pve2' '' 'lxc'),
        (Vm 1006 'app-01' 'pve3'),
        (Vm 1007 'app-02' 'pve3')
    )
    # pool 'prod' with a nested pool 'prod/db'
    $script:FakePools = @{ 'prod' = @('qemu/100', 'qemu/102'); 'prod/db' = @('lxc/200') }
    $script:FakeCalls = [System.Collections.Generic.List[string]]::new()
    $script:FakeTaskStatus = $null

    function script:Get-PveClusterResources { param($PveTicket, $Type) New-FakeResponse $script:FakeVms }

    function script:Get-PvePools {
        param($PveTicket, $Poolid)
        if ($Poolid) {
            New-FakeResponse @([pscustomobject]@{ poolid = $Poolid; members = @($script:FakePools[$Poolid] | ForEach-Object { [pscustomobject]@{ id = $_ } }) })
        }
        else { New-FakeResponse @($script:FakePools.Keys | ForEach-Object { [pscustomobject]@{ poolid = $_ } }) }
    }

    function script:Get-PveNodesTasksStatus { param($PveTicket, $Node, $Upid) $script:FakeLastUpid = $Upid; $script:FakeTaskStatus }

    # status and snapshot endpoints: record the call, return a task
    $endpoints = foreach ($type in 'Qemu', 'Lxc') {
        foreach ($action in 'StatusStart', 'StatusStop', 'StatusShutdown', 'StatusReboot', 'StatusSuspend', 'StatusResume', 'StatusReset',
                            'Snapshot', 'SnapshotRollback') { "New-PveNodes$type$action" }
        "Get-PveNodes${type}Snapshot"; "Remove-PveNodes${type}Snapshot"; "Set-PveNodes${type}Config"
    }
    foreach ($endpoint in $endpoints) {
        $body = {
            [CmdletBinding(SupportsShouldProcess)]
            param(
                [Parameter(ValueFromPipelineByPropertyName)] $Node,
                [Parameter(ValueFromPipelineByPropertyName)] $Vmid,
                $PveTicket, $Snapname, $Description, $Vmstate, $Timeout, $Forcestop, $Delete, $Skiplock
            )
            process {
                $args = ($PSBoundParameters.Keys | Where-Object { $_ -notin 'Node', 'Vmid', 'PveTicket', 'Confirm', 'WhatIf' } | Sort-Object |
                         ForEach-Object { "$_=$($PSBoundParameters[$_])" }) -join ' '
                $script:FakeCalls.Add("$($MyInvocation.MyCommand.Name) $Vmid $args".Trim())
                New-FakeResponse "UPID:$($Node):0000:0000:0000:task:$($Vmid):root@pam:"
            }
        }
        Set-Item "function:script:$endpoint" $body
    }
}
#endregion

function Select-Ids([string]$Selection) {
    InModule { param($s) (Get-PveGuest -VmIdOrName $s).vmid | Sort-Object } $Selection
}

#region selection (VmJollyTests)
$all = 100, 101, 102, 150, 200, 1006, 1007
$cases = @(
    @('@all', @($all)),
    @('all', @($all)),
    @('100,web-02', @(100, 101)),
    @('100:150', @(100, 101, 102, 150)),
    @('%app%', @(1006, 1007)),
    @('@node-PVE1', @(100, 101)),
    @('@all-pve3', @(1006, 1007)),
    @('all-pve3', @(1006, 1007)),
    @('@tag-WEB', @(100, 101)),
    @('@pool-prod', @(100, 102, 200)),
    @('@pool-PROD', @(100, 102, 200)),
    @('@all,-100', @(101, 102, 150, 200, 1006, 1007)),
    @('-100,@all', @(101, 102, 150, 200, 1006, 1007)),
    @('@all,-@tag-prod', @(150, 200, 1006, 1007)),
    @('@all,-@node-pve2,-web-01', @(101, 1006, 1007)),
    @('100:199,-150', @(100, 101, 102)),
    @('1006,-150:200', @(1006)),
    @('@node-pve3,-150:200', @(1006, 1007)),
    @('1007,-1006:1006', @(1007)),
    @('@all,-@pool-prod', @(101, 150, 1006, 1007)),
    @('@pool-prod,-100', @(102, 200)),
    @('@pool-prod,-@tag-prod', @(200)),
    @('@pool-prod,100,102', @(100, 102, 200)),
    @('100,web-01,@tag-web,100:101', @(100, 101)),
    @('999', @(@())),
    @('@pool-missing', @(@())),
    @('@tag-missing', @(@())),
    # PowerShell wildcards and spaces around the items
    @('web*', @(100, 101)),
    @('app-0?', @(1006, 1007)),
    @('100, 101', @(100, 101))
)
foreach ($case in $cases) { Assert-Equal "Get-PveGuest '$($case[0])'" $case[1] (Select-Ids $case[0]) }
Assert-Equal 'Get-PveGuest without selection' $all ((InModule { Get-PveGuest }).vmid | Sort-Object)
#endregion

#region names (VmCheckIdOrNameTests)
function Test-Name([string]$Pattern, [string]$Name, [long]$VmId = 100) {
    InModule { param($p, $n, $i) Test-GuestIdOrName -Vm ([pscustomobject]@{ vmid = $i; name = $n }) -VmIdOrName $p } $Pattern, $Name, $VmId
}
foreach ($case in @(
        @('%web%', 'my-web-01', $true), @('%WEB%', 'my-web-01', $true), @('%web%', 'db-01', $false),
        @('web%', 'web-01', $true), @('web%', 'my-web', $false), @('%web', 'my-web', $true), @('%web', 'web-01', $false),
        @('web-01', 'web-01', $true), @('WEB-01', 'web-01', $true), @('web', 'web-01', $false))) {
    Assert-Equal "Test-GuestIdOrName '$($case[0])' '$($case[1])'" $case[2] (Test-Name $case[0] $case[1])
}
foreach ($case in @(@('105', $true), @('100:110', $true), @('105:105', $true), @('106:110', $false), @('100:abc', $false))) {
    Assert-Equal "Test-GuestIdOrName '$($case[0])' on 105" $case[1] (Test-Name $case[0] 'web-01' 105)
}
#endregion

#region guest functions: one call per guest, qemu or lxc endpoint
function Get-Calls([scriptblock]$Block) {
    # expected errors (e.g. reset of a container) must not stop the test
    $ErrorActionPreference = 'Continue'
    InModule { $script:FakeCalls.Clear() }
    InModule $Block 2>$null | Out-Null
    InModule { @($script:FakeCalls) }
}

Assert-Equal 'Start-PveGuest mixed selection' @('New-PveNodesQemuStatusStart 100', 'New-PveNodesQemuStatusStart 101', 'New-PveNodesLxcStatusStart 200') `
    (Get-Calls { Start-PveGuest -VmIdOrName '@tag-web,200' })
Assert-Equal 'Stop-PveGuest' @('New-PveNodesLxcStatusStop 200') (Get-Calls { Stop-PveGuest -VmIdOrName 'ct-01' })
Assert-Equal 'Stop-PveGuest -Shutdown options' @('New-PveNodesQemuStatusShutdown 102 Forcestop=True Timeout=30', 'New-PveNodesLxcStatusShutdown 200 Forcestop=True Timeout=30') `
    (Get-Calls { Stop-PveGuest -VmIdOrName '102,200' -Shutdown -Timeout 30 -ForceStop })
Assert-Equal 'Stop-PveGuest -Shutdown without options' @('New-PveNodesQemuStatusShutdown 102') (Get-Calls { Stop-PveGuest -VmIdOrName 102 -Shutdown })
Assert-Equal 'Restart-PveGuest' @('New-PveNodesLxcStatusReboot 200 Timeout=60') (Get-Calls { Restart-PveGuest -VmIdOrName 200 -Timeout 60 })
Assert-Equal 'Suspend/Resume-PveGuest' @('New-PveNodesQemuStatusSuspend 150', 'New-PveNodesQemuStatusResume 150') `
    (Get-Calls { Suspend-PveGuest -VmIdOrName 150; Resume-PveGuest -VmIdOrName 150 })
Assert-Equal 'Reset-PveGuest skips containers' @('New-PveNodesQemuStatusReset 102') (Get-Calls { Reset-PveGuest -VmIdOrName '102,200' -ErrorAction SilentlyContinue })
Assert-Equal 'Unlock-PveGuest' @('Set-PveNodesQemuConfig 100 Delete=lock Skiplock=True', 'Set-PveNodesLxcConfig 200 Delete=lock') `
    (Get-Calls { Unlock-PveGuest -VmIdOrName '100,200' })
Assert-Equal 'New-PveGuestSnapshot without description' @('New-PveNodesQemuSnapshot 100 Snapname=s1 Vmstate=False', 'New-PveNodesLxcSnapshot 200 Snapname=s1') `
    (Get-Calls { New-PveGuestSnapshot -VmIdOrName '100,200' -Snapname s1 })
Assert-Equal 'New-PveGuestSnapshot with description and vmstate' @('New-PveNodesQemuSnapshot 100 Description=d Snapname=s2 Vmstate=True') `
    (Get-Calls { New-PveGuestSnapshot -VmIdOrName 100 -Snapname s2 -Description d -Vmstate })
Assert-Equal 'Get/Undo/Remove-PveGuestSnapshot' @('Get-PveNodesLxcSnapshot 200', 'New-PveNodesLxcSnapshotRollback 200 Snapname=s1', 'Remove-PveNodesLxcSnapshot 200 Snapname=s1') `
    (Get-Calls { Get-PveGuestSnapshot -VmIdOrName 200; Undo-PveGuestSnapshot -VmIdOrName 200 -Snapname s1; Remove-PveGuestSnapshot -VmIdOrName 200 -Snapname s1 })
Assert-Equal 'old names are aliases' 'Start-PveGuest' (Get-Alias Start-PveVm).Definition
# -WhatIf: nothing is called; -Confirm:$false: called as usual
Assert-Equal 'Start-PveGuest -WhatIf calls nothing' @() (Get-Calls { Start-PveGuest -VmIdOrName '@tag-web,200' -WhatIf })
Assert-Equal 'Stop-PveGuest -Shutdown -WhatIf calls nothing' @() (Get-Calls { Stop-PveGuest -VmIdOrName '100,200' -Shutdown -WhatIf })
Assert-Equal 'New-PveGuestSnapshot -WhatIf calls nothing' @() (Get-Calls { New-PveGuestSnapshot -VmIdOrName 100 -Snapname s3 -WhatIf })
Assert-Equal 'Reset-PveGuest -WhatIf calls nothing' @() (Get-Calls { Reset-PveGuest -VmIdOrName '102,200' -WhatIf -ErrorAction SilentlyContinue })
Assert-Equal 'Unlock-PveGuest -WhatIf calls nothing' @() (Get-Calls { Unlock-PveGuest -VmIdOrName '100,200' -WhatIf })
Assert-Equal 'Start-PveGuest -Confirm:$false' @('New-PveNodesQemuStatusStart 100') (Get-Calls { Start-PveGuest -VmIdOrName 100 -Confirm:$false })
$shutdownOnly = try { InModule { Stop-PveGuest -VmIdOrName 102 -Timeout 30 }; 'accepted' } catch { 'refused' }
Assert-Equal 'Stop-PveGuest -Timeout without -Shutdown is refused' 'refused' $shutdownOnly

$notFound = InModule { Start-PveGuest -VmIdOrName 'missing' -ErrorAction SilentlyContinue -ErrorVariable err; @($err).Count }
Assert-Equal 'no guest found writes an error' 1 $notFound
#endregion

#region tasks
$upid = 'UPID:pve1:00004A1A:0964214C:5EECEF11:vzdump:134:root@pam:'
function Set-TaskStatus($Response) { InModule { param($r) $script:FakeTaskStatus = $r } $Response }
function Invoke-Safe([scriptblock]$Block) { try { InModule $Block $upid } catch { "throws: $($_.Exception.Message)" } }

Set-TaskStatus (InModule { New-FakeResponse ([pscustomobject]@{ status = 'stopped'; exitstatus = 'OK' }) })
Assert-Equal 'Get-PveTaskIsRunning stopped' $false (Invoke-Safe { param($u) Get-PveTaskIsRunning -Upid $u })
Assert-Equal 'Get-PveTaskExitStatus' 'OK' (Invoke-Safe { param($u) Get-PveTaskExitStatus -Upid $u })
Assert-Equal 'Wait-PveTaskIsFinish finished' $true (Invoke-Safe { param($u) Wait-PveTaskIsFinish -Upid $u -Wait 10 -Timeout 1000 })
Assert-Equal 'Wait-PveTaskIsFinish from response' $true (Invoke-Safe { param($u) New-FakeResponse $u | Wait-PveTaskIsFinish -Wait 10 -Timeout 1000 })
Assert-Equal 'Wait-PveTaskIsFinish from response reads its UPID' $upid (InModule { $script:FakeLastUpid })

Set-TaskStatus (InModule { New-FakeResponse ([pscustomobject]@{ status = 'running' }) })
Assert-Equal 'Get-PveTaskIsRunning running' $true (Invoke-Safe { param($u) Get-PveTaskIsRunning -Upid $u })
Assert-Equal 'Wait-PveTaskIsFinish timeout' $false (Invoke-Safe { param($u) Wait-PveTaskIsFinish -Upid $u -Wait 10 -Timeout 100 })

Set-TaskStatus (InModule { New-FakeResponse $null 403 'Permission check failed' })
Assert-Equal 'Get-PveTaskIsRunning 403 throws' "throws: Read status of task '$upid' failed (403 Permission check failed): Permission check failed" `
    (Invoke-Safe { param($u) Get-PveTaskIsRunning -Upid $u })
Assert-Equal 'Wait-PveTaskIsFinish 403 throws' $true ((Invoke-Safe { param($u) Wait-PveTaskIsFinish -Upid $u -Wait 10 -Timeout 1000 }) -like 'throws:*')

Assert-Equal 'Wait-PveTaskIsFinish failed call: nothing to wait' $true (Invoke-Safe { New-FakeResponse $null 500 'error' | Wait-PveTaskIsFinish })
Assert-Equal 'Wait-PveTaskIsFinish call without task: nothing to wait' $true (Invoke-Safe { New-FakeResponse ([pscustomobject]@{ a = 1 }) | Wait-PveTaskIsFinish })
#endregion

Remove-Module $module -Force

$total = $script:passed + $script:failed.Count
if ($script:failed.Count) {
    $script:failed | ForEach-Object { Write-Host "FAIL $_" -ForegroundColor Red }
    Write-Host "$($script:failed.Count) of $total tests failed" -ForegroundColor Red
    exit 1
}
Write-Host "All $total tests passed" -ForegroundColor Green
