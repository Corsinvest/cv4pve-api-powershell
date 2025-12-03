# cv4pve-api-powershell

[![PowerShell for Proxmox VE](https://img.shields.io/badge/PowerShell-Proxmox%20VE-blue?style=for-the-badge)](https://www.powershellgallery.com/packages/Corsinvest.ProxmoxVE.Api/)
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/Corsinvest.ProxmoxVE.Api?style=for-the-badge)](https://www.powershellgallery.com/packages/Corsinvest.ProxmoxVE.Api/)
[![Downloads](https://img.shields.io/powershellgallery/dt/Corsinvest.ProxmoxVE.Api?style=for-the-badge)](https://www.powershellgallery.com/packages/Corsinvest.ProxmoxVE.Api/)
[![License](https://img.shields.io/github/license/Corsinvest/cv4pve-api-powershell?style=for-the-badge)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/Corsinvest/cv4pve-api-powershell?style=for-the-badge)](https://github.com/Corsinvest/cv4pve-api-powershell/stargazers)

```text
    ______                _                      __
   / ____/___  __________(_)___ _   _____  _____/ /_
  / /   / __ \/ ___/ ___/ / __ \ | / / _ \/ ___/ __/
 / /___/ /_/ / /  (__  ) / / / / |/ /  __(__  ) /_
 \____/\____/_/  /____/_/_/ /_/|___/\___/____/\__/

         Corsinvest - Proxmox VE API PowerShell
```

A comprehensive PowerShell module that provides everything you need to build powerful automation scripts that manage [Proxmox VE](https://www.proxmox.com/en/proxmox-ve) infrastructure programmatically.

Part of the [cv4pve](https://www.corsinvest.it/cv4pve) suite of tools.

**Quick Links:** [PowerShell Gallery](https://www.powershellgallery.com/packages/Corsinvest.ProxmoxVE.Api/) | [Documentation](https://corsinvest.github.io/cv4pve-api-powershell/) | [Proxmox VE API](https://pve.proxmox.com/pve-docs/api-viewer/)

## 📰 Copyright and License

Copyright © 2020-2025 Corsinvest Srl

For licensing details please visit [LICENSE](LICENSE)

## 🦺 Commercial Support

This software is part of a suite of tools called cv4pve-api-powershell.
If you require commercial support, please visit the [Corsinvest website](https://www.corsinvest.it/cv4pve)

## 📚 Overview

The **cv4pve-api-powershell** module enables system administrators and developers to manage and automate Proxmox VE environments using PowerShell.

It provides a comprehensive set of cmdlets that wrap the Proxmox REST API, allowing operations such as VM and container management, node monitoring, backup handling, and storage inspection—all from PowerShell.

This module serves as the **PowerCLI equivalent for Proxmox VE**:
- While PowerCLI facilitates VMware vSphere automation via PowerShell
- **cv4pve-api-powershell** offers similar capabilities for Proxmox VE environments

![PowerShell for Proxmox VE](https://raw.githubusercontent.com/Corsinvest/cv4pve-api-powershell/master/images/powershell.png)

## ✨ Key Features

### Core Capabilities
* **Easy to Learn** - Intuitive PowerShell cmdlet interface
* **Complete API Coverage** - Automatically generated from official Proxmox VE API documentation
* **Multiple Response Types** - Support for JSON, PNG, ExtJS, HTML, and text formats
* **Rich Response Objects** - PveResponse class with detailed request/response information
* **Cross-Platform** - Works on Windows, Linux, and macOS (PowerShell 6.0+)
* **No Remote Installation Required** - Execute from any machine outside Proxmox VE

### Authentication & Security
* **API Token Support** - Proxmox VE 6.2+ API token authentication
* **Two-Factor Authentication** - One-time password (OTP) support
* **Secure Connections** - TLS/SSL support with certificate validation options
* **High Availability** - Multi-host cluster connection for HA environments

### Virtual Machine & Container Management
* **VM Operations** - Start, stop, suspend, resume, reset, unlock
* **Container Support** - Full LXC container lifecycle management
* **Snapshot Management** - Create, list, rollback, and delete snapshots
* **Clone Operations** - Clone VMs and containers
* **Resource Monitoring** - RRD data collection from nodes, QEMU VMs, and LXC containers

### Advanced Features
* **Direct API Access** - Use `Invoke-PveRestApi` for custom API calls
* **Indexed Parameters** - Support for indexed parameters (e.g., -NetN, -ScsiN, -IdeN)
* **Task Management** - Wait for task completion, check task status
* **Utility Functions** - Unix time conversion, VM lookup by ID or name, and more
* **SPICE Integration** - Connect to VM consoles via `Invoke-PveSpice`
* **Documentation Generation** - Built-in help documentation builder

### Developer-Friendly
* **PowerShell Gallery** - Simple installation via `Install-Module`
* **Comprehensive Documentation** - HTML and Markdown documentation included
* **Interactive Tutorials** - VSCode notebook tutorials available
* **Open Source** - Full source code available on GitHub

## 🛠️ Utility Functions

The module includes a rich set of utility cmdlets to simplify common operations:

### Time Conversion
* `ConvertFrom-PveUnixTime` - Convert Unix timestamp to DateTime
* `ConvertTo-PveUnixTime` - Convert DateTime to Unix timestamp

### Task Management
* `Wait-PveTaskIsFinish` - Wait for a task to complete
* `Get-PveTaskIsRunning` - Check if a task is still running

### VM Operations (by ID or Name)
* `Get-PveVm` - Find VM by ID or name
* `Start-PveVm` - Start a VM
* `Stop-PveVm` - Stop a VM
* `Suspend-PveVm` - Suspend a VM
* `Resume-PveVm` - Resume a VM
* `Reset-PveVm` - Reset a VM
* `Unlock-PveVm` - Unlock a VM

### Monitoring & Statistics
* `Get-PveNodeMonitoring` - Get RRD monitoring data from nodes
* `Get-PveQemuMonitoring` - Get RRD monitoring data from QEMU VMs
* `Get-PveLxcMonitoring` - Get RRD monitoring data from LXC containers

### Snapshot Management
* `Get-PveVmSnapshot` - Get snapshots for a VM
* `New-PveVmSnapshot` - Create a new snapshot
* `Undo-PveVmSnapshot` - Rollback to a snapshot
* `Remove-PveVmSnapshot` - Delete a snapshot

And many more! Explore the full cmdlet list with `Get-Command -Module Corsinvest.ProxmoxVE.Api`

## 📙 Documentation

Comprehensive documentation is available in multiple formats:

* **[HTML Documentation](https://corsinvest.github.io/cv4pve-api-powershell/)** - Full API reference in HTML format
* **[Markdown Documentation](https://github.com/Corsinvest/cv4pve-api-powershell/blob/master/doc/markdown/about_cv4pve-api-powershell.md)** - Documentation in Markdown format

## 🎓 Tutorial & Learning Resources

* **[Interactive VSCode Notebook Tutorial](https://tinyurl.com/cv4pve-api-pwsh-learn)** - Learn by doing with interactive examples
* **[Video Demo](https://asciinema.org/a/656606)** - Watch a quick demonstration of the module in action

<a href="https://asciinema.org/a/656606" target="_blank"><img src="https://asciinema.org/a/656606.svg" /></a>

## 📋 Requirements

* **PowerShell 6.0 or higher** (PowerShell Core)
* **Network access** to your Proxmox VE cluster
* **Valid credentials** or API token for Proxmox VE

## 📦 Installation

### Prerequisites

First, ensure you have [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell) installed on your system (version 6.0 or later).

### From PowerShell Gallery (Recommended)

The easiest way to install is directly from the [PowerShell Gallery](https://www.powershellgallery.com/packages/Corsinvest.ProxmoxVE.Api/):

```powershell
Install-Module -Name Corsinvest.ProxmoxVE.Api
```

### Manual Installation

1. Download the `Corsinvest.ProxmoxVE.Api` folder from the repository
2. Copy it to one of your PowerShell module paths

To view your module paths:
```powershell
# Display module paths
$env:PSModulePath -split [IO.Path]::PathSeparator
```

## 🚀 Quick Start

### Connecting to Your Cluster

Use `Connect-PveCluster` to establish a connection. This cmdlet supports both username/password and API token authentication.

#### Using Username and Password

```powershell
# Connect with username and password
Connect-PveCluster -HostsAndPorts 192.168.1.100:8006 -SkipCertificateCheck

# PowerShell will prompt for credentials
# Username format: user@pam, user@pve, or user@yourdomain
```

#### Using API Token (Proxmox VE 6.2+)

From Proxmox VE 6.2+, you can use [API tokens](https://pve.proxmox.com/pve-docs/pveum-plain.html) for authentication without username/password.

```powershell
# Connect using API token
Connect-PveCluster -HostsAndPorts 192.168.1.100:8006 `
                   -SkipCertificateCheck `
                   -ApiToken "root@pam!mytoken=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

**Note:** API token format is `USER@REALM!TOKENID=UUID`. If using **Privilege Separation**, ensure proper permissions are configured.

### Connection Management

The `Connect-PveCluster` function creates a `PveTicket` object and stores it in `$Global:PveTicketLast`. All cmdlets use this ticket by default, or you can specify a different ticket with the `-PveTicket` parameter.

## 💡 Usage Examples

### Basic Operations

```powershell
# Connect to cluster
Connect-PveCluster -HostsAndPorts 192.168.1.100:8006 -SkipCertificateCheck

# Get Proxmox VE version
Get-PveVersion | Select-Object -ExpandProperty Response | Select-Object -ExpandProperty data
# Output: version : 8.2.0, release : 1, repoid : abc123...

# List all VMs in the cluster
Get-PveClusterResources -Type vm | Select-Object -ExpandProperty Response | Select-Object -ExpandProperty data
# Output: vmid, name, status, node, uptime, etc.
```

### VM Management

```powershell
# Start a VM (by ID or name)
Start-PveVm -VmIdOrName 100
# Output: UPID:pve1:00001234:...

# Stop a VM gracefully
Stop-PveVm -VmIdOrName "my-vm"

# Suspend/Resume a VM
Suspend-PveVm -VmIdOrName 100
Resume-PveVm -VmIdOrName 100

# Reset a VM
Reset-PveVm -VmIdOrName 100

# Unlock a VM
Unlock-PveVm -VmIdOrName 100
```

### Snapshot Management

```powershell
# List snapshots for a VM
Get-PveNodesQemuSnapshot -Node pve1 -Vmid 100 | Select -Expand Response | Select -Expand data
# Output: name, snaptime, description, vmstate...

# Using Get-PveVm helper
Get-PveVm -VmIdOrName 100 | Get-PveNodesQemuSnapshot

# Create a snapshot
New-PveNodesQemuSnapshot -Node pve1 -Vmid 100 -Snapname "backup-2024-01-15"
# Output: snapshot created successfully

# Rollback to a snapshot
New-PveNodesQemuSnapshotRollback -Node pve1 -Vmid 100 -Snapname "backup-2024-01-15"

# Delete a snapshot
Remove-PveNodesQemuSnapshot -Node pve1 -Vmid 100 -Snapname "backup-2024-01-15"
```

### Working with Indexed Parameters

When working with indexed parameters (e.g., `-ScsiN`, `-IdeN`, `-NetN`), use hashtables:

```powershell
# Define configurations using hashtables
$networkConfig = @{
    1 = [uri]::EscapeDataString("model=virtio,bridge=vmbr0")
}
$storageConfig = @{
    1 = 'ssdpool:32'
}
$bootableIso = @{
    1 = 'local:iso/ubuntu-22.04.iso'
}

# Create a new VM with indexed parameters
New-PveNodesQemu -Node pve1 `
                 -Vmid 105 `
                 -Memory 2048 `
                 -ScsiN $storageConfig `
                 -IdeN $bootableIso `
                 -NetN $networkConfig
```

**Note:** Use `[uri]::EscapeDataString` to properly escape parameter values containing special characters.

### Monitoring Resources

```powershell
# Get node monitoring data (RRD data)
Get-PveNodeMonitoring -Node pve1 -Timeframe hour
# Output: cpu, memory, network, disk usage statistics

# Get QEMU VM monitoring data
Get-PveQemuMonitoring -Node pve1 -Vmid 100 -Timeframe day
# Output: CPU usage, disk I/O, network traffic over time

# Get LXC container monitoring data
Get-PveLxcMonitoring -Node pve1 -Vmid 200 -Timeframe week
```

### Task Management

```powershell
# Execute a long-running task
$result = New-PveNodesQemu -Node pve1 -Vmid 110 -Memory 4096 -Name "new-vm"
$taskId = $result.Response.data
# Output: UPID:pve1:00001F40:...

# Wait for task completion
Wait-PveTaskIsFinish -Node pve1 -Upid $taskId

# Check if a task is still running
$isRunning = Get-PveTaskIsRunning -Node pve1 -Upid $taskId
# Output: True/False
```

## 🔧 Advanced Features

### PveResponse Class

All cmdlets return a `PveResponse` object with rich information:

```powershell
class PveResponse {
    [PSCustomObject] $Response           # The actual API response
    [int] $StatusCode                    # HTTP status code
    [string] $ReasonPhrase              # HTTP reason phrase
    [bool] $IsSuccessStatusCode         # Success indicator
    [string] $RequestResource           # API endpoint called
    [hashtable] $Parameters             # Request parameters
    [string] $Method                    # HTTP method used
    [string] $ResponseType              # Response format

    # Helper methods
    [bool] ResponseInError()            # Check for errors
    [PSCustomObject] ToTable()          # Format as table
    [PSCustomObject] ToData()           # Extract data only
    [void] ToCsv([string] $filename)    # Export to CSV
    [void] ToGridView()                 # Display in grid view
}
```

### PveTicket Class

Connection information is stored in a `PveTicket` object:

```powershell
class PveTicket {
    [string] $HostName
    [int] $Port
    [bool] $SkipCertificateCheck
    [string] $Ticket
    [string] $CSRFPreventionToken
    [string] $ApiToken
}
```

### Direct API Access

For operations not covered by cmdlets, use `Invoke-PveRestApi`:

```powershell
# Make a custom API call
$result = Invoke-PveRestApi -Method Get `
                            -Resource "/api2/json/nodes/pve1/status" `
                            -PveTicket $Global:PveTicketLast

# Display results
$result.Response.data
```

### High Availability Connections

Connect to multiple hosts for HA failover:

```powershell
# Connect to multiple nodes
Connect-PveCluster -HostsAndPorts "192.168.1.100:8006,192.168.1.101:8006,192.168.1.102:8006" `
                   -SkipCertificateCheck
```

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. **Report Issues** - Found a bug? [Open an issue](https://github.com/Corsinvest/cv4pve-api-powershell/issues)
2. **Suggest Features** - Have an idea? Share it in the [discussions](https://github.com/Corsinvest/cv4pve-api-powershell/discussions)
3. **Submit Pull Requests** - Want to contribute code? Fork the repo and submit a PR
4. **Improve Documentation** - Help us make the docs better

## 🔗 Related Projects

Part of the **cv4pve** suite of tools for Proxmox VE:

* **[cv4pve-api-dotnet](https://github.com/Corsinvest/cv4pve-api-dotnet)** - .NET library for Proxmox VE API
* **[cv4pve-autosnap](https://github.com/Corsinvest/cv4pve-autosnap)** - Automatic snapshot tool
* **[cv4pve-barc](https://github.com/Corsinvest/cv4pve-barc)** - Backup and restore Ceph
* **[cv4pve-pepper](https://github.com/Corsinvest/cv4pve-pepper)** - Launching SPICE remote-viewer

Visit [cv4pve.com](https://www.corsinvest.it/cv4pve) for the complete suite.

## 📞 Support

### Community Support

* **GitHub Issues**: [Report bugs or request features](https://github.com/Corsinvest/cv4pve-api-powershell/issues)
* **GitHub Discussions**: [Ask questions and share ideas](https://github.com/Corsinvest/cv4pve-api-powershell/discussions)
* **Documentation**: [HTML](https://corsinvest.github.io/cv4pve-api-powershell) | [Markdown](https://github.com/Corsinvest/cv4pve-api-powershell/blob/master/doc/markdown/about_cv4pve-api-powershell.md)

### Commercial Support

For enterprise support, SLA, consulting, or custom development:
* Visit [Corsinvest](https://www.corsinvest.it/cv4pve)
* Email: [support@corsinvest.it](mailto:support@corsinvest.it)

## ⭐ Show Your Support

If you find this project useful, please consider:
* ⭐ Starring the repository on GitHub
* 📢 Sharing it with others
* 🐛 Reporting issues you encounter
* 💡 Contributing improvements

---

**Made with ❤️ in Italy by [Corsinvest Srl](https://www.corsinvest.it)**
