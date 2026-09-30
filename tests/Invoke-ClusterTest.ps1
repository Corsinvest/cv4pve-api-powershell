# SPDX-FileCopyrightText: Copyright Corsinvest Srl
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
Tests the guest and task functions against a real Proxmox VE cluster.

.DESCRIPTION
Creates a test VM (no operating system) and a test container, both tagged 'cv4pve-test', runs the
hand-written functions on them (selection, snapshots, start, suspend, resume, reset, restart, shutdown (Stop-PveGuest -Shutdown),
stop, unlock, task wait and exit status) and removes them at the end, also when a test fails.
Nothing else in the cluster is changed; the selection tests on the rest of the cluster only read.

Use a test cluster. The account needs to create, change and remove guests on the node, the storage and
the pool; Unlock-PveGuest on a VM needs root@pam.

Exit code 0 when every test passes.

.PARAMETER HostsAndPorts
Nodes to connect to, as Connect-PveCluster.
.PARAMETER ApiToken
API token, as Connect-PveCluster. Or use Credentials.
.PARAMETER Credentials
User and password, as Connect-PveCluster.
.PARAMETER SkipCertificateCheck
As Connect-PveCluster.
.PARAMETER Node
Node where the test guests are created.
.PARAMETER Storage
Storage for their disks; it must support snapshots (e.g. zfspool, lvmthin).
.PARAMETER Template
Container template, e.g. local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst.
.PARAMETER Pool
Existing pool the test guests join, to test @pool-. Optional.
.PARAMETER KeepGuests
Do not remove the test guests at the end.

.EXAMPLE
$cred = Get-Credential root@pam
pwsh -File tests/Invoke-ClusterTest.ps1 -HostsAndPorts pve01 -Credentials $cred -SkipCertificateCheck `
    -Node pve01 -Storage local-zfs -Template local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst -Pool test
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string[]]$HostsAndPorts,
    [string]$ApiToken,
    [pscredential]$Credentials,
    [switch]$SkipCertificateCheck,
    [Parameter(Mandatory)] [string]$Node,
    [Parameter(Mandatory)] [string]$Storage,
    [Parameter(Mandatory)] [string]$Template,
    [string]$Pool,
    [switch]$KeepGuests
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../Corsinvest.ProxmoxVE.Api/Corsinvest.ProxmoxVE.Api.psd1') -Force -DisableNameChecking

$script:passed = 0
$script:failed = [System.Collections.Generic.List[string]]::new()
$tag = 'cv4pve-test'

function Assert-True([string]$Name, [bool]$Condition, [string]$Detail = '') {
    if ($Condition) { $script:passed++; Write-Host "  ok   $Name" -ForegroundColor DarkGray }
    else { $script:failed.Add("$Name $Detail".Trim()); Write-Host "  FAIL $Name $Detail" -ForegroundColor Red }
}

function Assert-Equal([string]$Name, $Expected, $Actual) {
    $e = @($Expected) -join ','; $a = @($Actual) -join ','
    Assert-True $Name ($e -eq $a) "expected: $e actual: $a"
}

# Wait for the task of each response and check that it ended with OK.
function Assert-Task([string]$Name, $Responses, [int]$Timeout = 120000) {
    foreach ($r in @($Responses)) {
        if (-not $r.IsSuccessStatusCode) { Assert-True $Name $false "call failed: $($r.StatusCode) $($r.ReasonPhrase)"; continue }
        $finished = $r | Wait-PveTaskIsFinish -Timeout $Timeout
        $exit = Get-PveTaskExitStatus -Upid $r.Response.data
        Assert-True $Name ($finished -and $exit -eq 'OK') "finished: $finished exit: $exit ($($r.RequestResource))"
    }
}

# Current status from the guest itself: /cluster/resources (Get-PveGuest) is updated a few seconds later.
function Get-Status([long]$VmId) {
    $type = $VmId -eq $script:vmId ? 'Qemu' : 'Lxc'
    (& "Get-PveNodes${type}StatusCurrent" -Node $Node -Vmid $VmId).Response.data.status
}

# Wait until a new guest appears in /cluster/resources with its name: the resources are updated a few
# seconds after the guest is created.
function Wait-GuestName([long]$VmId, [string]$Name) {
    for ($i = 0; $i -lt 60 -and (Get-PveGuest -VmIdOrName $VmId).name -ne $Name; $i++) { Start-Sleep -Seconds 1 }
    Write-Host "  guest $VmId name '$((Get-PveGuest -VmIdOrName $VmId).name)' after $i s" -ForegroundColor DarkGray
}

# Selection of a guest just created: its entry in /cluster/resources can still miss the name for a moment,
# so retry for a few seconds before failing.
function Select-NewGuest([string]$Selection) {
    for ($i = 0; $i -lt 15; $i++) {
        $ids = (Get-PveGuest -VmIdOrName $Selection).vmid
        if ($ids) { return $ids }
        Start-Sleep -Seconds 1
    }
}

$connect = @{ HostsAndPorts = $HostsAndPorts; SkipCertificateCheck = $SkipCertificateCheck }
if ($ApiToken) { $connect.ApiToken = $ApiToken } else { $connect.Credentials = $Credentials }
Connect-PveCluster @connect | Out-Null

$script:vmId = $null; $ctId = $null
try {
    Write-Host 'Selection on the whole cluster (read only)'
    $resources = @((Get-PveClusterResources -Type vm).Response.data)
    Assert-Equal 'all' ($resources.vmid | Sort-Object) ((Get-PveGuest -VmIdOrName 'all').vmid | Sort-Object)
    Assert-Equal '@all' ($resources.vmid | Sort-Object) ((Get-PveGuest -VmIdOrName '@all').vmid | Sort-Object)
    Assert-Equal "@node-$Node" (($resources | Where-Object node -eq $Node).vmid | Sort-Object) ((Get-PveGuest -VmIdOrName "@node-$Node").vmid | Sort-Object)
    $multiTag = $resources | Where-Object { "$($_.tags)".Contains(';') } | Select-Object -First 1
    if ($multiTag) {
        $firstTag = $multiTag.tags.Split(';')[0]
        Assert-Equal "@tag-$firstTag (guests with several tags)" (($resources | Where-Object { ("$($_.tags)" -split ';') -contains $firstTag }).vmid | Sort-Object) `
            ((Get-PveGuest -VmIdOrName "@tag-$firstTag").vmid | Sort-Object)
    }

    Write-Host 'Create the test guests'
    $script:vmId = $vmId = [long](Get-PveClusterNextid).Response.data
    $vmCreate = @{ Node = $Node; Vmid = $vmId; Name = 'cv4pve-test-vm'; Memory = '512'; Cores = 1; Tags = "$tag;x-test"; ScsiN = @{ 0 = "$($Storage):1" } }
    if ($Pool) { $vmCreate.Pool = $Pool }
    Assert-Task "create VM $vmId" (New-PveNodesQemu @vmCreate)

    $ctId = [long](Get-PveClusterNextid).Response.data
    $ctCreate = @{ Node = $Node; Vmid = $ctId; Hostname = 'cv4pve-test-ct'; Ostemplate = $Template; Rootfs = "$($Storage):2"; Memory = 256; Unprivileged = $true; Tags = $tag }
    if ($Pool) { $ctCreate.Pool = $Pool }
    Assert-Task "create CT $ctId" (New-PveNodesLxc @ctCreate) 300000
    $both = "@tag-$tag"

    Write-Host 'Selection of the test guests'
    Wait-GuestName $vmId 'cv4pve-test-vm'; Wait-GuestName $ctId 'cv4pve-test-ct'
    Assert-Equal "$both (the VM has two tags)" @($vmId, $ctId | Sort-Object) ((Get-PveGuest -VmIdOrName $both).vmid | Sort-Object)
    Assert-Equal "$both,-$ctId" $vmId (Get-PveGuest -VmIdOrName "$both,-$ctId").vmid
    Assert-Equal 'name with %' $vmId (Select-NewGuest 'cv4pve-test-v%')
    Assert-Equal 'name with *' $ctId (Select-NewGuest 'cv4pve-test-c*')
    if ($Pool) {
        $inPool = (Get-PveGuest -VmIdOrName "@pool-$Pool").vmid
        Assert-True "@pool-$Pool contains the test guests" (($inPool -contains $vmId) -and ($inPool -contains $ctId)) "found: $($inPool -join ',')"
    }

    Write-Host 'Snapshots (stopped)'
    Assert-Task 'New-PveGuestSnapshot without description' (New-PveGuestSnapshot -VmIdOrName $both -Snapname cvtest1)
    Assert-Task 'New-PveGuestSnapshot with description' (New-PveGuestSnapshot -VmIdOrName $both -Snapname cvtest2 -Description 'cv4pve test')
    foreach ($r in (Get-PveGuestSnapshot -VmIdOrName $both)) {
        $snaps = @($r.Response.data)
        Assert-True "Get-PveGuestSnapshot $($r.RequestResource)" ((($snaps.name -contains 'cvtest1') -and ($snaps.name -contains 'cvtest2')))
        # Proxmox VE ends the description of a container snapshot with a newline
        Assert-Equal "description of cvtest2 $($r.RequestResource)" 'cv4pve test' "$(($snaps | Where-Object name -eq 'cvtest2').description)".Trim()
    }
    # ZFS rolls back only to the most recent snapshot
    Assert-Task 'Undo-PveGuestSnapshot' (Undo-PveGuestSnapshot -VmIdOrName $both -Snapname cvtest2)

    $dup = New-PveGuestSnapshot -VmIdOrName $vmId -Snapname cvtest1
    if ($dup.IsSuccessStatusCode) {
        [void]($dup | Wait-PveTaskIsFinish -Timeout 60000)
        $exit = Get-PveTaskExitStatus -Upid $dup.Response.data
        Assert-True 'Get-PveTaskExitStatus of a failed task is not OK' ($exit -and $exit -ne 'OK') "exit: $exit"
    }
    else { Assert-True 'duplicate snapshot refused' ($dup.StatusCode -ge 400) }

    Write-Host 'Power'
    Assert-Task 'Start-PveGuest VM and CT' (Start-PveGuest -VmIdOrName $both)
    Assert-Equal 'both running' @('running', 'running') @(Get-Status $vmId; Get-Status $ctId)

    Assert-Task 'New-PveGuestSnapshot -Vmstate (running VM)' (New-PveGuestSnapshot -VmIdOrName $vmId -Snapname cvtest3 -Vmstate)
    $snap3 = (Get-PveGuestSnapshot -VmIdOrName $vmId).Response.data | Where-Object name -eq 'cvtest3'
    Assert-True 'cvtest3 has the vmstate' ($snap3.vmstate -eq 1) "vmstate: $($snap3.vmstate)"

    Assert-Task 'Suspend-PveGuest VM' (Suspend-PveGuest -VmIdOrName $vmId)
    Assert-Equal 'VM paused' 'paused' (Get-PveNodesQemuStatusCurrent -Node $Node -Vmid $vmId).Response.data.qmpstatus
    Assert-Task 'Resume-PveGuest VM' (Resume-PveGuest -VmIdOrName $vmId)
    Assert-Equal 'VM running again' 'running' (Get-PveNodesQemuStatusCurrent -Node $Node -Vmid $vmId).Response.data.qmpstatus

    $reset = @(Reset-PveGuest -VmIdOrName $both -ErrorAction SilentlyContinue -ErrorVariable resetErrors)
    Assert-Equal 'Reset-PveGuest resets only the VM' 1 $reset.Count
    Assert-Equal 'Reset-PveGuest writes one error for the CT' 1 @($resetErrors).Count
    Assert-Task 'Reset-PveGuest VM task' $reset

    Assert-Task 'Restart-PveGuest CT' (Restart-PveGuest -VmIdOrName $ctId -Timeout 60) 180000
    Assert-Equal 'CT running after restart' 'running' (Get-Status $ctId)

    Assert-Task 'Stop-PveGuest -Shutdown -ForceStop (the VM has no OS)' (Stop-PveGuest -VmIdOrName $both -Shutdown -Timeout 20 -ForceStop) 180000
    Assert-Equal 'both stopped' @('stopped', 'stopped') @(Get-Status $vmId; Get-Status $ctId)

    Assert-Task 'Start-PveGuest VM' (Start-PveGuest -VmIdOrName $vmId)
    Assert-Task 'Stop-PveGuest VM' (Stop-PveGuest -VmIdOrName $vmId)
    Assert-Equal 'VM stopped' 'stopped' (Get-Status $vmId)

    $unlock = @(Unlock-PveGuest -VmIdOrName $both)
    Assert-True 'Unlock-PveGuest' (@($unlock | Where-Object { -not $_.IsSuccessStatusCode }).Count -eq 0) (($unlock | ForEach-Object { "$($_.StatusCode) $($_.ReasonPhrase)" }) -join '; ')

    Write-Host 'Remove snapshots'
    Assert-Task 'Remove-PveGuestSnapshot cvtest3' (Remove-PveGuestSnapshot -VmIdOrName $vmId -Snapname cvtest3)
    Assert-Task 'Remove-PveGuestSnapshot cvtest2' (Remove-PveGuestSnapshot -VmIdOrName $both -Snapname cvtest2)
    Assert-Task 'Remove-PveGuestSnapshot cvtest1' (Remove-PveGuestSnapshot -VmIdOrName $both -Snapname cvtest1)
}
catch {
    Assert-True 'unexpected error' $false $_.Exception.Message
}
finally {
    if (-not $KeepGuests) {
        Write-Host 'Remove the test guests'
        foreach ($id in @($vmId, $ctId) | Where-Object { $_ }) {
            $guest = Get-PveGuest -VmIdOrName $id
            if (-not $guest) { continue }
            if ($guest.status -eq 'running') { Stop-PveGuest -VmIdOrName $id | Wait-PveTaskIsFinish -Timeout 60000 | Out-Null }
            $remove = if ($guest.type -eq 'qemu') { Remove-PveNodesQemu -Node $guest.node -Vmid $id -Purge $true -DestroyUnreferencedDisks $true }
                      else { Remove-PveNodesLxc -Node $guest.node -Vmid $id -Purge $true -DestroyUnreferencedDisks $true }
            Assert-Task "remove $($guest.type) $id" $remove
        }
    }
}

$total = $script:passed + $script:failed.Count
if ($script:failed.Count) {
    $script:failed | ForEach-Object { Write-Host "FAIL $_" -ForegroundColor Red }
    Write-Host "$($script:failed.Count) of $total tests failed" -ForegroundColor Red
    exit 1
}
Write-Host "All $total tests passed" -ForegroundColor Green
