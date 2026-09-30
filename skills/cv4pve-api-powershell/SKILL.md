---
name: cv4pve-api-powershell
description: Read and operate a Proxmox VE cluster from PowerShell 7 with the Corsinvest.ProxmoxVE.Api module — list and find VMs, containers and nodes, read configurations, start, stop, snapshot, and call any API endpoint. Use it when the user works in PowerShell or asks for a PowerShell script for Proxmox VE.
---

# cv4pve-api-powershell

The PowerShell module `Corsinvest.ProxmoxVE.Api` has one cmdlet per Proxmox VE API endpoint plus a few
functions for guests and tasks. It needs PowerShell 7 (`pwsh`). Every change goes to the cluster at once,
with the privileges of the token.

## Rules

- Your shell does not keep the connection between commands: start every command with
  `Connect-PveCluster -HostsAndPorts <host> -ApiToken $env:PVE_API_TOKEN`, adding `-SkipCertificateCheck`
  if the nodes have a self-signed certificate. Ask the user for the host; never print the variable.
- Never call `Connect-PveCluster` without `-ApiToken` or `-Credentials`: it waits for `Get-Credential`.
  Do not use `Out-GridView` or `.ToGridView()` either.
- Reads need no agreement. Before any `New-`, `Set-`, `Remove-` cmdlet or guest function that changes
  something (`Start-`, `Stop-`, `Restart-`, `Reset-`, `Suspend-`, `Resume-PveGuest`, `New-`, `Remove-`,
  `Undo-PveGuestSnapshot`, `Unlock-PveGuest`): run the same command with `-WhatIf`, show the user its
  `What if:` lines, and run it for real only after the user agrees.
- `Invoke-PveRestApi` has no `-WhatIf`: before a call with `-Method Set`, `Create` or `Delete`, show the
  method, the path and the parameters and wait for agreement.
- A failed call does not throw: check `IsSuccessStatusCode` of every response; `StatusCode` and
  `ReasonPhrase` say why (400 parameter, 401 token, 403 privilege, 500 server, -1 no answer).
- If a parameter is refused, read `Get-Help <cmdlet> -Full`: this skill can be newer than the module
  (`(Get-Module Corsinvest.ProxmoxVE.Api -ListAvailable).Version`).

## Find the cmdlet

Generated cmdlets follow the API path: `GET /nodes/{node}/qemu/{vmid}/config` is `Get-PveNodesQemuConfig`,
`POST /nodes/{node}/qemu/{vmid}/snapshot` is `New-PveNodesQemuSnapshot`, `PUT` is `Set-`, `DELETE` is
`Remove-`.

```powershell
Get-Command -Module Corsinvest.ProxmoxVE.Api -Name *Qemu*Snapshot*   # cmdlets about QEMU snapshots
Get-Help New-PveNodesQemuSnapshot -Full                              # parameters
```

## Read

```powershell
Get-PveGuest | Select-Object vmid, name, node, type, status          # every VM and container
Get-PveGuest -VmIdOrName '@tag-prod,-@node-pve03'                    # a selection, as in the other cv4pve tools
Get-PveNode
(Get-PveGuest -VmIdOrName 100 | Get-PveNodesQemuConfig).Response.data
```

`Get-PveGuest` and `Get-PveNode` return the objects. The generated cmdlets return a `PveResponse`: the data
is in `.Response.data`. Guests have `type` `qemu` (VM) or `lxc` (container): use the `Qemu` or `Lxc`
cmdlets accordingly. Output JSON with `ConvertTo-Json -Depth 5` when you need to parse it.

## Change

```powershell
Stop-PveGuest -VmIdOrName 120 -WhatIf                                # 1. what would happen
$r = Stop-PveGuest -VmIdOrName 120                                   # 2. after agreement
New-PveGuestSnapshot -VmIdOrName 120 -Snapname before-update -WhatIf
```

A change that starts a task returns its UPID in `.Response.data`. Wait for it and check the outcome:

```powershell
$r | Wait-PveTaskIsFinish -Timeout 600000              # milliseconds; the default is 10 seconds
Get-PveTaskExitStatus -Upid $r.Response.data            # 'OK', or the error of the task
```

Documentation: https://corsinvest.github.io/cv4pve-api-powershell/
