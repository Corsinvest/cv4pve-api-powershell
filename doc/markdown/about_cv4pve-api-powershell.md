# cv4pve-api-powershell
## about_cv4pve-api-powershell

# SHORT DESCRIPTION
PowerShell module for managing Proxmox VE via its REST API, similar to VMware PowerCLI.

# LONG DESCRIPTION
The `cv4pve-api-powershell` module enables system administrators and developers to manage and automate Proxmox VE environments using PowerShell.

It provides a comprehensive set of cmdlets that wrap the Proxmox REST API, allowing operations such as VM and container management, node monitoring, backup handling, and storage inspection—all from PowerShell.

This module serves as the **PowerCLI equivalent for Proxmox VE**:
- While PowerCLI facilitates VMware vSphere automation via PowerShell,
- `cv4pve-api-powershell` offers similar capabilities for Proxmox VE environments.

## EXAMPLES

### Install the module from PowerShell Gallery:
```powershell
Install-Module -Name Corsinvest.ProxmoxVE.Api
```

### Connect to a Proxmox server:
```powershell
Connect-PveCluster -Credentials (Get-Credential) -HostsAndPorts 192.168.1.10:8006
```

### List virtual machines on a specific node:
```powershell
Get-PveVm -Node pve-node1
```

## KEYWORDS
- Proxmox
- PowerShell
- Automation
- Virtualization
- API
- PowerCLI

## SEE ALSO
Online documentation: [cv4pve-api-powershell GitHub Repository](https://github.com/Corsinvest/cv4pve-api-powershell)