# Common Issues and Examples

This guide covers the most common issues users encounter and provides practical examples for typical use cases.

## Table of Contents

- [Hashtable Parameters (NetN, SataN, ScsiN, etc.)](#hashtable-parameters)
- [Boolean vs Switch Parameters](#boolean-vs-switch-parameters)
- [Working with Result Objects](#working-with-result-objects)
- [Disk Configuration Syntax](#disk-configuration-syntax)
- [Password with Special Characters](#password-with-special-characters)
- [Creating VMs with Disks and Network](#creating-vms-with-disks-and-network)
- [Guest Agent Commands](#guest-agent-commands)

---

## Hashtable Parameters

Many cmdlets use parameters with a suffix `N` (like `-NetN`, `-SataN`, `-ScsiN`, `-IdeN`, `-VirtioN`, `-HostpciN`, etc.) to configure multiple devices. These parameters accept a **Hashtable** where:

- **Key** = Device number (0, 1, 2, etc.)
- **Value** = Configuration string

### Network Configuration

```powershell
# Single network interface
$net = @{0 = "model=e1000,bridge=vmbr0,firewall=1"}
New-PveNodesQemu -Node "pve" -Vmid 100 -NetN $net

# Multiple network interfaces
$net = @{
    0 = "model=virtio,bridge=vmbr0,firewall=1"
    1 = "model=e1000,bridge=vmbr1"
}
New-PveNodesQemu -Node "pve" -Vmid 100 -NetN $net
```

### SATA Disk Configuration

```powershell
# Single SATA disk (100GB on storage "local-lvm")
$sata = @{0 = "local-lvm:100"}
Set-PveNodesQemuConfig -Node "pve" -Vmid 100 -SataN $sata

# Multiple SATA disks
$sata = @{
    0 = "local-lvm:100"
    1 = "local-lvm:50"
}
Set-PveNodesQemuConfig -Node "pve" -Vmid 100 -SataN $sata
```

### SCSI Disk Configuration

```powershell
# SCSI disk with additional parameters
$scsi = @{0 = "local-lvm:100,cache=writethrough,iothread=1"}
New-PveNodesQemu -Node "pve" -Vmid 100 -ScsiN $scsi
```

### IDE Disk Configuration

```powershell
# IDE disk (typically for CD-ROM)
$ide = @{2 = "local:iso/ubuntu-22.04.iso,media=cdrom"}
New-PveNodesQemu -Node "pve" -Vmid 100 -IdeN $ide
```

### VirtIO Disk Configuration

```powershell
# VirtIO disk (best performance for Linux VMs)
$virtio = @{0 = "local-lvm:100,cache=writeback,discard=on"}
New-PveNodesQemu -Node "pve" -Vmid 100 -VirtioN $virtio
```

### LXC Network Configuration

```powershell
# LXC container with network
$net = @{0 = "name=eth0,bridge=vmbr0,ip=dhcp"}
New-PveNodesLxc -Node "pve" -Vmid 200 -Ostemplate "local:vztmpl/ubuntu-22.04.tar.gz" -NetN $net

# LXC with static IP
$net = @{0 = "name=eth0,bridge=vmbr0,ip=192.168.1.100/24,gw=192.168.1.1"}
New-PveNodesLxc -Node "pve" -Vmid 200 -Ostemplate "local:vztmpl/ubuntu-22.04.tar.gz" -NetN $net
```

---

## Boolean vs Switch Parameters

Some cmdlets use `[Boolean]` parameters instead of `[Switch]`. This can cause "Parameter verification failed" errors if not handled correctly.

### The Problem

```powershell
# ❌ This may fail with "Parameter verification failed"
Remove-PveNodesQemu -Node "pve" -Vmid 100 -Purge -DestroyUnreferencedDisks
```

### The Solution

Use explicit boolean values:

```powershell
#  Correct way with explicit boolean
Remove-PveNodesQemu -Node "pve" -Vmid 100 -Purge $true -DestroyUnreferencedDisks $true

#  Alternative syntax with colon
Remove-PveNodesQemu -Node "pve" -Vmid 100 -Purge:$true -DestroyUnreferencedDisks:$true

#  To disable (false)
Remove-PveNodesQemu -Node "pve" -Vmid 100 -Purge $false -DestroyUnreferencedDisks $false
```

### Common Boolean Parameters

- `-Purge` - Remove VM from configuration
- `-DestroyUnreferencedDisks` - Delete unused disks
- `-Force` - Force operation
- `-Start` - Start VM after creation
- `-Acpi` - Enable/disable ACPI

---

## Working with Result Objects

Cmdlets return `PveResponse` objects. To access the actual data, use the `.ToData()` method or access the `Response` property.

### The Problem

```powershell
# This seems to return nothing
$config = Get-PveNodesQemuConfig -Node "pve" -Vmid 100
Write-Host $config  # Outputs object type, not data
```

### The Solution

```powershell
#  Method 1: Use .ToData()
$config = (Get-PveNodesQemuConfig -Node "pve" -Vmid 100).ToData()
Write-Host $config.memory  # Access properties directly

#  Method 2: Access Response property
$result = Get-PveNodesQemuConfig -Node "pve" -Vmid 100
$config = $result.Response.data
Write-Host $config.memory

#  Method 3: Pipeline
Get-PveNodesQemuConfig -Node "pve" -Vmid 100 | ForEach-Object { $_.ToData() }
```

### PveResponse Class Properties

```powershell
$result = Get-PveNodesQemu -Node "pve"

# Properties
$result.Response                # The actual API response (PSCustomObject with 'data' property)
$result.StatusCode              # HTTP status code (200, 400, 500, etc.)
$result.ReasonPhrase            # Error message if request failed
$result.IsSuccessStatusCode     # Boolean - true if StatusCode is 2xx
$result.RequestResource         # API endpoint that was called
$result.Parameters              # Hashtable of parameters sent
$result.Method                  # HTTP method used (GET, POST, PUT, DELETE)
$result.ResponseType            # Response content type (usually 'json')
```

### PveResponse Class Methods

```powershell
# Get data from response
$data = $result.ToData()        # Returns $result.Response.data

# Check for errors
$hasError = $result.ResponseInError()  # Returns true if response contains an error

# Export/display data
$result.ToTable()               # Display as formatted table
$result.ToGridView()            # Open in grid view window (Windows only)
$result.ToCsv("output.csv")     # Export data to CSV file
```

### Example: Error Handling

```powershell
$result = Get-PveNodesQemuConfig -Node "pve" -Vmid 999

if ($result.IsSuccessStatusCode) {
    $config = $result.ToData()
    Write-Host "VM Memory: $($config.memory)"
} else {
    Write-Error "Request failed: $($result.StatusCode) - $($result.ReasonPhrase)"
}

# Or check for API-level errors
if ($result.ResponseInError()) {
    Write-Error "API returned an error: $($result.Response.error)"
}
```

---

## Disk Configuration Syntax

Disk parameters use a special syntax: `STORAGE_ID:SIZE_IN_GiB[,parameter=value,...]`

### Basic Disk Syntax

```powershell
# Format: "storage:size"
"local-lvm:100"           # 100GB disk on local-lvm storage
"ceph-storage:50"         # 50GB disk on ceph-storage
```

### EFI Disk Configuration

```powershell
# EFI disk for UEFI boot (size is ignored, typically 4M)
$efidisk = "local-lvm:4,efitype=4m"
New-PveNodesQemu -Node "pve" -Vmid 100 -Efidisk0 $efidisk -Bios "ovmf"

# Alternative format
$efidisk = "local-lvm:0,efitype=4m,size=4M"
Set-PveNodesQemuConfig -Node "pve" -Vmid 100 -Efidisk0 $efidisk
```

### Disk with Additional Parameters

```powershell
# SCSI disk with cache and SSD emulation
$scsi = @{0 = "local-lvm:100,cache=writethrough,ssd=1,discard=on"}
New-PveNodesQemu -Node "pve" -Vmid 100 -ScsiN $scsi

# VirtIO disk with backup disabled
$virtio = @{0 = "local-lvm:100,backup=0"}
New-PveNodesQemu -Node "pve" -Vmid 100 -VirtioN $virtio
```

### Import Existing Disk

```powershell
# Import disk from storage (size=0 + import-from parameter)
$scsi = @{0 = "local-lvm:0,import-from=/mnt/pve/nfs/images/100/vm-100-disk-0.raw"}
New-PveNodesQemu -Node "pve" -Vmid 100 -ScsiN $scsi
```

### Common Disk Parameters

- `cache=` - Cache mode: `none`, `writethrough`, `writeback`, `directsync`, `unsafe`
- `ssd=1` - Emulate SSD
- `discard=on` - Enable TRIM/discard
- `iothread=1` - Enable IO thread (SCSI/VirtIO only)
- `backup=0` - Exclude from backup
- `replicate=0` - Exclude from replication
- `size=` - Disk size (e.g., `size=100G`)

---

## Password with Special Characters

Passwords containing special characters like `+`, `#`, `&`, `=` may cause authentication failures.

### The Problem

```powershell
# ❌ This may fail with "authentication failure"
$password = "MyP@ss+Word#123"
Connect-PveCluster -HostsAndPorts "pve.example.com" -Username "root@pam" -Password $password
```

### The Solution

Use `SecureString` (recommended):

```powershell
#  Method 1: Use SecureString (most secure)
$securePassword = ConvertTo-SecureString "MyP@ss+Word#123" -AsPlainText -Force
Connect-PveCluster -HostsAndPorts "pve.example.com" -Username "root@pam" -Password $securePassword
```

Alternatively, URL encoding (for API tokens):

```powershell
#  Method 2: URL encode (if SecureString doesn't work)
$password = [uri]::EscapeDataString("MyP@ss+Word#123")
Connect-PveCluster -HostsAndPorts "pve.example.com" -Username "root@pam" -Password $password
```

---

## Creating VMs with Disks and Network

Complete examples for creating VMs with proper configuration.

### Example 1: Windows VM with EFI, Disks, and Network

```powershell
# Connect to Proxmox
$ticket = Connect-PveCluster -HostsAndPorts "pve.example.com" -SkipCertificateCheck

# Define configuration
$vmid = 100
$node = "pve"
$name = "windows-server"

# Network configuration
$net = @{0 = "model=e1000,bridge=vmbr0,firewall=1"}

# Create VM with EFI disk
$efidisk = "local-lvm:4,efitype=4m"

# SATA disk for OS (100GB)
$sata = @{0 = "local-lvm:100"}

# Create the VM
New-PveNodesQemu -PveTicket $ticket `
    -Node $node `
    -Vmid $vmid `
    -Name $name `
    -Memory 4096 `
    -Cores 4 `
    -Sockets 1 `
    -Cpu "host" `
    -Bios "ovmf" `
    -Machine "q35" `
    -Ostype "win10" `
    -Scsihw "virtio-scsi-pci" `
    -Efidisk0 $efidisk `
    -SataN $sata `
    -NetN $net `
    -Vga "qxl" `
    -Balloon 2048 `
    -Start $true

Write-Host "VM $vmid created and started successfully"
```

### Example 2: Linux VM with VirtIO Disks

```powershell
# Connect
$ticket = Connect-PveCluster -HostsAndPorts "pve.example.com" -SkipCertificateCheck

# Configuration
$vmid = 101
$node = "pve"

# Network
$net = @{0 = "model=virtio,bridge=vmbr0"}

# VirtIO disks (best performance for Linux)
$virtio = @{
    0 = "local-lvm:50,cache=writeback,discard=on"  # OS disk
    1 = "local-lvm:100,cache=writeback,discard=on" # Data disk
}

# ISO for installation
$ide = @{2 = "local:iso/ubuntu-22.04.iso,media=cdrom"}

# Create VM
New-PveNodesQemu -PveTicket $ticket `
    -Node $node `
    -Vmid $vmid `
    -Name "ubuntu-server" `
    -Memory 2048 `
    -Cores 2 `
    -Cpu "host" `
    -Ostype "l26" `
    -Scsihw "virtio-scsi-pci" `
    -VirtioN $virtio `
    -IdeN $ide `
    -NetN $net `
    -Vga "virtio" `
    -Start $false
```

### Example 3: LXC Container with Network

```powershell
# Connect
$ticket = Connect-PveCluster -HostsAndPorts "pve.example.com" -SkipCertificateCheck

# Configuration
$vmid = 200
$node = "pve"
$hostname = "ubuntu-container"
$ostemplate = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"

# Network with static IP
$net = @{0 = "name=eth0,bridge=vmbr0,ip=192.168.1.100/24,gw=192.168.1.1"}

# Create LXC container
New-PveNodesLxc -PveTicket $ticket `
    -Node $node `
    -Vmid $vmid `
    -Hostname $hostname `
    -Ostemplate $ostemplate `
    -Storage "local-lvm" `
    -Memory 1024 `
    -Swap 512 `
    -Cores 2 `
    -NetN $net `
    -Nameserver "8.8.8.8" `
    -Searchdomain "example.com" `
    -Start $true
```

---

## Guest Agent Commands

Execute commands inside VMs using QEMU Guest Agent.

### Prerequisites

1. QEMU Guest Agent must be installed in the VM
   - **Windows**: Install from VirtIO driver ISO
   - **Linux**: `apt install qemu-guest-agent` or `yum install qemu-guest-agent`

2. Enable agent in VM configuration:
   ```powershell
   Set-PveNodesQemuConfig -Node "pve" -Vmid 100 -Agent "enabled=1"
   ```

### Execute Commands

```powershell
# Connect
$ticket = Connect-PveCluster -HostsAndPorts "pve.example.com" -SkipCertificateCheck

# Execute command (Linux example)
$result = New-PveNodesQemuAgentExec -PveTicket $ticket `
    -Node "pve" `
    -Vmid 100 `
    -Command @('/usr/bin/apt', 'update')

# Get PID
$pid = ($result.ToData()).pid

# Wait for command to complete and get output
Start-Sleep -Seconds 5
$output = Get-PveNodesQemuAgentExecStatus -PveTicket $ticket `
    -Node "pve" `
    -Vmid 100 `
    -Pid $pid

$outputData = $output.ToData()
Write-Host "Exit Code: $($outputData.'exit-code')"
Write-Host "Output: $($outputData.'out-data')"
```

### Windows Example

```powershell
# Execute PowerShell command on Windows VM
$result = New-PveNodesQemuAgentExec -PveTicket $ticket `
    -Node "pve" `
    -Vmid 100 `
    -Command @('C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe', '-Command', 'Get-Service')

$pid = ($result.ToData()).pid

# Get output
Start-Sleep -Seconds 3
$output = Get-PveNodesQemuAgentExecStatus -PveTicket $ticket -Node "pve" -Vmid 100 -Pid $pid
```

### Common Guest Agent Operations

```powershell
# Get VM IP addresses
$ips = Get-PveNodesQemuAgentNetworkGetInterfaces -PveTicket $ticket -Node "pve" -Vmid 100
$ips.ToData()

# Get OS information
$osinfo = Get-PveNodesQemuAgentGetOsinfo -PveTicket $ticket -Node "pve" -Vmid 100
$osinfo.ToData()

# Ping VM (check if agent is responsive)
$ping = New-PveNodesQemuAgentPing -PveTicket $ticket -Node "pve" -Vmid 100
$ping.ToData()

# Shutdown VM gracefully via agent
New-PveNodesQemuAgentShutdown -PveTicket $ticket -Node "pve" -Vmid 100
```

---

## Additional Resources

- [Proxmox VE API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
- [Cmdlet Reference](cmdlets-index.md)
- [GitHub Issues](https://github.com/Corsinvest/cv4pve-api-powershell/issues)
- [Proxmox VE Wiki](https://pve.proxmox.com/wiki/)

---

## Need Help?

If you encounter issues not covered here:

1. Check the [Cmdlet Reference](cmdlets-index.md) for parameter details
2. Search [existing issues](https://github.com/Corsinvest/cv4pve-api-powershell/issues)
3. Create a [new issue](https://github.com/Corsinvest/cv4pve-api-powershell/issues/new) with:
   - PowerShell version (`$PSVersionTable`)
   - Module version (`Get-Module Corsinvest.ProxmoxVE.Api`)
   - Proxmox VE version
   - Complete error message and command used
