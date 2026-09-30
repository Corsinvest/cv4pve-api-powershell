# Changelog

The version follows Proxmox VE: 9.2.x is built on the API of Proxmox VE 9.2.

---

## [9.2.3] — 2026-09-30

### Guests
- **`Get-PveGuest`** replaces `Get-PveVm`, with the selection of the other cv4pve tools: id, range, name (exact, `%text%`, `text%`, `%text`, or PowerShell wildcards), `@node-`, `@pool-` with nested pools, `@tag-`, `@all`, and exclusions with `-` (`@all,-100,-@tag-template`). Each guest once, sorted by node and id.
- **Power and snapshot functions** (`Start`, `Stop`, `Suspend`, `Resume`, `Reset`, `Unlock`, `*-PveGuestSnapshot`) act on every selected guest and call the `qemu` or `lxc` endpoint for each one. With several guests matched, all of them used to go to the `qemu` endpoint.
- New **`Stop-PveGuest -Shutdown [-Timeout] [-ForceStop]`** and **`Restart-PveGuest`**: clean shutdown and reboot through the guest.
- The former `*-PveVm` names stay as aliases.

### Cmdlets
- **Regenerated from the current Proxmox VE API**: a cmdlet for each of the 680 endpoints (663 before), e.g. SDN vnets and fabrics of a node, file restore of a storage, Ceph health mute, notification target test.
- **`-WhatIf` and `-Confirm`** on every `Set-`, `New-` and `Remove-` cmdlet and on the guest functions. Nothing asks by default: scripts behave as before.
- `New-`/`Set-PveClusterHaRules` have all their parameters again (`-Type`, `-Resources`, `-Nodes`, `-Affinity`, `-Strict`…).
- Three cmdlets called a URL with a literal `{route_map_id}` or `{pci_id_or_mapping}`; the SDN prefix-list entry cmdlets get the path parameters `-Id` and `-UrlSeq`.
- `-Asn` (SDN controllers), `-Level` (custom CPU models) and `-Seq` (prefix lists) are `[long]`: values up to 4294967295.
- Help text as the API writes it.

### Tasks
- **New `Get-PveTaskExitStatus`**; the response of the call that started a task can be piped into `Wait-PveTaskIsFinish` and `Wait-PveTaskIsFinishedWithProgress`.
- A task status that cannot be read (node down, missing privilege) throws, instead of being taken for a finished task.
- `Wait-PveTaskIsFinish` and `Wait-PveTaskIsFinishedWithProgress` return `$true` when the task finished, also when the last check came after the timeout.

### Fixes
- **Two-factor authentication**: `Connect-PveCluster -Otp` works on Proxmox VE 7 and later, with a TOTP code or `recovery:<key>`. It always failed with `missing Two Factor Authentication (TFA)`.
- **`-Debug` no longer prints passwords, second factors, tickets or tokens**; `Connect-PveCluster -Debug` printed the password and the ticket.
- The query string of GET and DELETE calls is URL-encoded: values with `&`, `=`, `#`, `+`, `%` or spaces broke the call.
- `-HostsAndPorts` also takes one string with the nodes separated by commas (`'pve01:8006,pve02:8006'`), as its help says.
- `New-PveVmSnapshot -Vmstate` never worked; an omitted `-Description` is no longer sent; `@tag-` failed for guests with several tags.

### Changes to check
- `Test-PortQuick` and `VmCheckIdOrName` are no longer exported; the unused `PveValidate*` classes are removed.
- The manifest requires PowerShell 7.0. The module already needed it: it never loaded on PowerShell 6.

### Documentation
- New site: https://corsinvest.github.io/cv4pve-api-powershell/ — getting started, connection, coming from PowerCLI, concepts, guides, examples with their output, and a page for every cmdlet.
