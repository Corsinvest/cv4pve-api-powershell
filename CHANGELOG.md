# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
The version follows Proxmox VE: 9.2.x is built on the API of Proxmox VE 9.2.

## [9.2.3] - 2026-09-30

### Added
- Documentation site: https://corsinvest.github.io/cv4pve-api-powershell/, replaces the MkDocs site; a page for every cmdlet with its endpoint, guides, examples with their output, Coming from PowerCLI; old URLs redirect to the new pages ([#68](https://github.com/Corsinvest/cv4pve-api-powershell/pull/68), [#69](https://github.com/Corsinvest/cv4pve-api-powershell/pull/69))
- `Get-PveGuest` with the selection of the cv4pve tools: id, range, name (exact, `%text%`, `text%`, `%text`, PowerShell wildcards), `@node-`, `@pool-` with nested pools, `@tag-`, `@all`, exclusions with `-` ([#70](https://github.com/Corsinvest/cv4pve-api-powershell/pull/70))
- `Stop-PveGuest -Shutdown [-Timeout] [-ForceStop]` and `Restart-PveGuest`: clean shutdown and reboot through the guest ([#70](https://github.com/Corsinvest/cv4pve-api-powershell/pull/70))
- `Get-PveTaskExitStatus`; the response of the call that started a task can be piped into `Wait-PveTaskIsFinish` and `Wait-PveTaskIsFinishedWithProgress` ([#70](https://github.com/Corsinvest/cv4pve-api-powershell/pull/70))
- `-WhatIf` and `-Confirm` on the 338 `Set-`, `New-` and `Remove-` cmdlets and on the guest functions; nothing asks by default ([#71](https://github.com/Corsinvest/cv4pve-api-powershell/pull/71))
- Cmdlets for every endpoint of the current Proxmox VE API: 680 (663 before), e.g. `Get-PveNodesSdnVnets`, `Get-PveNodesSdnFabrics*`, `Get-PveNodesStorageFileRestoreList`, `New-PveClusterNotificationsTargetsTest`, `Get-`/`Set-PveClusterCephHealthMute` ([#71](https://github.com/Corsinvest/cv4pve-api-powershell/pull/71))
- `Connect-PveCluster -Otp` accepts a recovery key as `recovery:<key>` ([#72](https://github.com/Corsinvest/cv4pve-api-powershell/pull/72))
- `-HostsAndPorts` accepts one string with the nodes separated by commas (`'pve01:8006,pve02:8006'`), as its help says ([#73](https://github.com/Corsinvest/cv4pve-api-powershell/pull/73))

### Changed (behaviour)
- Power and snapshot functions (`Start`, `Stop`, `Suspend`, `Resume`, `Reset`, `Unlock`, `*-PveGuestSnapshot`) act on every selected guest and call the `qemu` or `lxc` endpoint for each one; with several guests matched, all went to the `qemu` endpoint. When nothing matches they write `VM/CT '…' not found!` ([#70](https://github.com/Corsinvest/cv4pve-api-powershell/pull/70))
- A task status that cannot be read (node down, missing privilege) throws, instead of being taken for a finished task ([#70](https://github.com/Corsinvest/cv4pve-api-powershell/pull/70))
- `Wait-PveTaskIsFinish` and `Wait-PveTaskIsFinishedWithProgress` return `$true` when the task finished, also when the last check came after the timeout; the result was computed from the elapsed time ([#72](https://github.com/Corsinvest/cv4pve-api-powershell/pull/72))
- `-Asn` (SDN controllers), `-Level` (custom CPU models) and `-Seq` (prefix lists) are `[long]`: values up to 4294967295 ([#71](https://github.com/Corsinvest/cv4pve-api-powershell/pull/71))
- `Test-PortQuick`, `VmCheckIdOrName` and the internal helpers are no longer exported; the unused `PveValidate*` classes are removed ([#70](https://github.com/Corsinvest/cv4pve-api-powershell/pull/70))
- The manifest requires PowerShell 7.0; the module uses the ternary operator and never loaded on PowerShell 6 ([#73](https://github.com/Corsinvest/cv4pve-api-powershell/pull/73))

### Fixed
- `Connect-PveCluster -Otp` never worked on Proxmox VE 7 and later: it always failed with `missing Two Factor Authentication (TFA)`; the code is now sent in the response to the TFA challenge ([#72](https://github.com/Corsinvest/cv4pve-api-powershell/pull/72))
- `-Debug` printed the password, the ticket and the tokens: request parameters and response data are now shown with those values as `****`, and `Invoke-RestMethod` no longer writes the body and the response to the debug stream ([#73](https://github.com/Corsinvest/cv4pve-api-powershell/pull/73))
- The query string of GET and DELETE calls was not encoded: values with `&`, `=`, `#`, `+`, `%` or spaces broke the call ([#73](https://github.com/Corsinvest/cv4pve-api-powershell/pull/73))
- `New-`/`Set-PveClusterHaRules` had lost `-Type`, `-Resources`, `-Nodes`, `-Affinity`, `-Strict` and the other parameters the API describes with `allOf`/`oneOf` ([#71](https://github.com/Corsinvest/cv4pve-api-powershell/pull/71))
- Three cmdlets called a URL with a literal `{route_map_id}` or `{pci_id_or_mapping}`; the SDN prefix-list entry cmdlets get the path parameters `-Id` and `-UrlSeq` the API does not declare ([#71](https://github.com/Corsinvest/cv4pve-api-powershell/pull/71))
- `New-PveVmSnapshot -Vmstate` never worked (a switch passed to a `[bool]`); an omitted `-Description` is no longer sent ([#70](https://github.com/Corsinvest/cv4pve-api-powershell/pull/70))
- `@tag-` failed for guests with several tags; `@all` and the documented exclusions were not implemented ([#70](https://github.com/Corsinvest/cv4pve-api-powershell/pull/70))
- Examples of `Connect-PveCluster` and `Invoke-PveRestApi` ended with `.`, a syntax error when copied ([#73](https://github.com/Corsinvest/cv4pve-api-powershell/pull/73))

### Changed
- Help text of the generated cmdlets as the API writes it: no `':'` or `\[`, no words glued across lines ([#71](https://github.com/Corsinvest/cv4pve-api-powershell/pull/71))
- The former `*-PveVm` names stay as aliases of the `*-PveGuest` functions; every alias is kept ([#70](https://github.com/Corsinvest/cv4pve-api-powershell/pull/70))
- README shortened, with links to the documentation; product icon (Lucide `terminal`), also as `IconUri` of the manifest ([#68](https://github.com/Corsinvest/cv4pve-api-powershell/pull/68))
- `build.ps1` replaces `Tools.psm1` (analyzer, manifest exports, cmdlet reference, tests); offline tests in `tests/`, a cluster test in `tests/Invoke-ClusterTest.ps1` ([#70](https://github.com/Corsinvest/cv4pve-api-powershell/pull/70), [#73](https://github.com/Corsinvest/cv4pve-api-powershell/pull/73))
- Removed the MkDocs site, the old video and `Tutorial.dib`; LF line endings with `.gitattributes`, as the other cv4pve repositories ([#68](https://github.com/Corsinvest/cv4pve-api-powershell/pull/68))
- Workflows declare their permissions and job timeouts ([#67](https://github.com/Corsinvest/cv4pve-api-powershell/pull/67)); the GitHub release takes its notes from this file
