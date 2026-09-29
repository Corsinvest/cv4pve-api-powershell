# <img src="icon.png" alt="" height="36" align="top"> cv4pve-api-powershell

```
     ______                _                      __
    / ____/___  __________(_)___ _   _____  _____/ /_
   / /   / __ \/ ___/ ___/ / __ \ | / / _ \/ ___/ __/
  / /___/ /_/ / /  (__  ) / / / / |/ /  __(__  ) /_
  \____/\____/_/  /____/_/_/ /_/|___/\___/____/\__/

PowerShell for Proxmox VE (Made in Italy)
```

[![License](https://img.shields.io/github/license/Corsinvest/cv4pve-api-powershell.svg?style=flat-square)](LICENSE)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/Corsinvest.ProxmoxVE.Api?style=flat-square&logo=powershell)](https://www.powershellgallery.com/packages/Corsinvest.ProxmoxVE.Api/)
[![Downloads](https://img.shields.io/powershellgallery/dt/Corsinvest.ProxmoxVE.Api?style=flat-square)](https://www.powershellgallery.com/packages/Corsinvest.ProxmoxVE.Api/)

> **The PowerCLI for Proxmox VE** — a PowerShell module with a cmdlet for every endpoint of the Proxmox VE API, running on your machine and talking only to the API.
>
> **[Documentation](https://corsinvest.github.io/cv4pve-api-powershell/)**

---

## Why

The Proxmox VE web interface is made for one action at a time. Snapshot forty VMs before an update, list every VM with its disks for an audit, clone a template ten times, shut down a lab every evening: by hand it is slow and error-prone.

VMware administrators have PowerCLI for this. cv4pve-api-powershell is the same idea for Proxmox VE: the whole API as PowerShell cmdlets, so your scripts, scheduled tasks and habits keep working — objects in the pipeline, `Where-Object`, `Export-Csv`, `Get-Help`.

It **runs on your machine and uses only the Proxmox VE API**: nothing to install on the nodes, no SSH.

---

## Features

- **The whole API** — one cmdlet per endpoint and method, generated from the Proxmox VE API, with its parameters, types and allowed values.
- **VMs by id or name** — `Get-PveVm` finds VMs and containers by id, name, range, pool, tag or node, and pipes them into the other cmdlets.
- **API token or password** — list several nodes and the first that answers is used.
- **Objects, not text** — the Proxmox VE data as PowerShell objects, with the HTTP outcome beside it.
- **Tasks** — start a backup, clone or migration and wait for it to finish, with a progress bar if you like.
- **Anything else** — `Invoke-PveRestApi` calls any path of the API with the same connection.
- **Cross-platform** — PowerShell 7 on Windows, Linux and macOS.

---

## Quick start

```powershell
Install-Module -Name Corsinvest.ProxmoxVE.Api -Scope CurrentUser

# connect to any node of the cluster, with an API token
Connect-PveCluster -HostsAndPorts pve01 -ApiToken 'automation@pve!ps=<secret>'

# every VM and container of the cluster
Get-PveVm | Format-Table vmid, name, node, type, status

# the generated cmdlets return the data in .Response.data
(Get-PveNodesQemuConfig -Node pve01 -Vmid 100).Response.data
```

Requires PowerShell 7. With a self-signed certificate add `-SkipCertificateCheck`. What the token needs: [Permissions](https://corsinvest.github.io/cv4pve-api-powershell/permissions/).

---

## What it looks like

```powershell
PS> Get-PveVm | Format-Table vmid, name, node, type, status

vmid name        node  type status
---- ----        ----  ---- ------
 100 backup01    pve02 lxc  running
 102 firewall02  pve02 qemu running
 105 test        pve01 lxc  stopped
1006 dc01        pve01 qemu running
1012 mailstore   pve02 qemu running

PS> Get-PveNode | Select-Object node, status, @{ n = 'cpu%'; e = { [math]::Round($_.cpu * 100, 1) } }

node  status cpu%
----  ------ ----
pve02 online 1.50
pve01 online 4.20
```

`Get-PveVm` returns the guests themselves; the generated cmdlets return a `PveResponse` with the data in `.Response.data`. More recipes, each with its output: [Common tasks](https://corsinvest.github.io/cv4pve-api-powershell/examples/common-tasks/).

---

## Documentation

| | |
|---|---|
| [Getting started](https://corsinvest.github.io/cv4pve-api-powershell/getting-started/) | Install, connect, first cmdlets |
| [Connection](https://corsinvest.github.io/cv4pve-api-powershell/connection/) | API token or password, several nodes, certificates, permissions |
| [Concepts](https://corsinvest.github.io/cv4pve-api-powershell/concepts/results/) | Results, parameters, tasks, errors, raw API calls |
| [Guides](https://corsinvest.github.io/cv4pve-api-powershell/guides/finding-vms/) | VMs by id or name, power, snapshots, SPICE |
| [Examples](https://corsinvest.github.io/cv4pve-api-powershell/examples/common-tasks/) | Common tasks with their output, inventory to CSV, creating VMs, guest agent, backups |
| [Cmdlet reference](https://corsinvest.github.io/cv4pve-api-powershell/reference/) | Every cmdlet with its endpoint and parameters |
| [Troubleshooting](https://corsinvest.github.io/cv4pve-api-powershell/troubleshooting/) | `-Debug` and the common errors |

---

## Related tools

Prefer the command line in any shell? [cv4pve-cli](https://github.com/Corsinvest/cv4pve-cli) calls the same API. From .NET: [cv4pve-api-dotnet](https://github.com/Corsinvest/cv4pve-api-dotnet). The whole suite: [corsinvest.it/cv4pve](https://www.corsinvest.it/en/cv4pve/).

---

## Support

Professional support and consulting available through [Corsinvest](https://www.corsinvest.it/en/cv4pve/).

---

Part of [cv4pve](https://www.corsinvest.it/cv4pve) suite | Made with ❤️ in Italy by [Corsinvest](https://www.corsinvest.it)

Copyright © Corsinvest Srl
