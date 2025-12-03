---
external help file: Corsinvest.ProxmoxVE.Api-help.xml
Module Name: Corsinvest.ProxmoxVE.Api
online version:
schema: 2.0.0
---

# New-PveNodesQemu

## SYNOPSIS

## SYNTAX

```
New-PveNodesQemu [[-PveTicket] <PveTicket>] [[-Acpi] <Boolean>] [[-Affinity] <String>] [[-Agent] <String>]
 [[-AllowKsm] <Boolean>] [[-AmdSev] <String>] [[-Arch] <String>] [[-Archive] <String>] [[-Args_] <String>]
 [[-Audio0] <String>] [[-Autostart] <Boolean>] [[-Balloon] <Int32>] [[-Bios] <String>] [[-Boot] <String>]
 [[-Bootdisk] <String>] [[-Bwlimit] <Int32>] [[-Cdrom] <String>] [[-Cicustom] <String>]
 [[-Cipassword] <SecureString>] [[-Citype] <String>] [[-Ciupgrade] <Boolean>] [[-Ciuser] <String>]
 [[-Cores] <Int32>] [[-Cpu] <String>] [[-Cpulimit] <Single>] [[-Cpuunits] <Int32>] [[-Description] <String>]
 [[-Efidisk0] <String>] [[-Force] <Boolean>] [[-Freeze] <Boolean>] [[-HaManaged] <Boolean>]
 [[-Hookscript] <String>] [[-HostpciN] <Hashtable>] [[-Hotplug] <String>] [[-Hugepages] <String>]
 [[-IdeN] <Hashtable>] [[-ImportWorkingStorage] <String>] [[-IntelTdx] <String>] [[-IpconfigN] <Hashtable>]
 [[-Ivshmem] <String>] [[-Keephugepages] <Boolean>] [[-Keyboard] <String>] [[-Kvm] <Boolean>]
 [[-LiveRestore] <Boolean>] [[-Localtime] <Boolean>] [[-Lock] <String>] [[-Machine] <String>]
 [[-Memory] <String>] [[-MigrateDowntime] <Single>] [[-MigrateSpeed] <Int32>] [[-Name] <String>]
 [[-Nameserver] <String>] [[-NetN] <Hashtable>] [-Node] <String> [[-Numa] <Boolean>] [[-NumaN] <Hashtable>]
 [[-Onboot] <Boolean>] [[-Ostype] <String>] [[-ParallelN] <Hashtable>] [[-Pool] <String>]
 [[-Protection] <Boolean>] [[-Reboot] <Boolean>] [[-Rng0] <String>] [[-SataN] <Hashtable>]
 [[-ScsiN] <Hashtable>] [[-Scsihw] <String>] [[-Searchdomain] <String>] [[-SerialN] <Hashtable>]
 [[-Shares] <Int32>] [[-Smbios1] <String>] [[-Smp] <Int32>] [[-Sockets] <Int32>]
 [[-SpiceEnhancements] <String>] [[-Sshkeys] <String>] [[-Start] <Boolean>] [[-Startdate] <String>]
 [[-Startup] <String>] [[-Storage] <String>] [[-Tablet] <Boolean>] [[-Tags] <String>] [[-Tdf] <Boolean>]
 [[-Template] <Boolean>] [[-Tpmstate0] <String>] [[-Unique] <Boolean>] [[-UnusedN] <Hashtable>]
 [[-UsbN] <Hashtable>] [[-Vcpus] <Int32>] [[-Vga] <String>] [[-VirtioN] <Hashtable>] [[-VirtiofsN] <Hashtable>]
 [[-Vmgenid] <String>] [-Vmid] <Int32> [[-Vmstatestorage] <String>] [[-Watchdog] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Create or restore a virtual machine.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -PveTicket
Ticket data connection.

```yaml
Type: PveTicket
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Acpi
Enable/disable ACPI.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Affinity
List of host cores used to execute guest processes, for example':' 0,5,8-11

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Agent
Enable/disable communication with the QEMU Guest Agent and its properties.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -AllowKsm
Allow memory pages of this guest to be merged via KSM (Kernel Samepage Merging).

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -AmdSev
Secure Encrypted Virtualization (SEV) features by AMD CPUs

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Arch
Virtual processor architecture.
Defaults to the host.
Enum: x86_64,aarch64

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Archive
The backup archive.
Either the file system path to a .tar or .vma file (use '-' to pipe data from stdin) or a proxmox storage backup volume identifier.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Args_
Arbitrary arguments passed to kvm.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Audio0
Configure a audio device, useful in combination with QXL/Spice.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Autostart
Automatic restart after crash (currently ignored).

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Balloon
Amount of target RAM for the VM in MiB.
Using zero disables the ballon driver.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 12
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Bios
Select BIOS implementation.
Enum: seabios,ovmf

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 13
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Boot
Specify guest boot order.
Use the 'order=' sub-property as usage with no key or 'legacy=' is deprecated.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 14
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Bootdisk
Enable booting from specified disk.
Deprecated':' Use 'boot':' order=foo;bar' instead.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 15
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Bwlimit
Override I/O bandwidth limit (in KiB/s).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 16
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Cdrom
This is an alias for option -ide2

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 17
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Cicustom
cloud-init':' Specify custom files to replace the automatically generated ones at start.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 18
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Cipassword
cloud-init':' Password to assign the user.
Using this is generally not recommended.
Use ssh keys instead.
Also note that older cloud-init versions do not support hashed passwords.

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: 19
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Citype
Specifies the cloud-init configuration format.
The default depends on the configured operating system type (\`ostype\`.
We use the \`nocloud\` format for Linux, and \`configdrive2\` for windows.
Enum: configdrive2,nocloud,opennebula

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 20
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Ciupgrade
cloud-init':' do an automatic package upgrade after the first boot.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 21
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Ciuser
cloud-init':' User name to change ssh keys and password for instead of the image's configured default user.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 22
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Cores
The number of cores per socket.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 23
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Cpu
Emulated CPU type.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 24
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Cpulimit
Limit of CPU usage.

```yaml
Type: Single
Parameter Sets: (All)
Aliases:

Required: False
Position: 25
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Cpuunits
CPU weight for a VM, will be clamped to \\\[1, 10000\] in cgroup v2.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 26
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Description
Description for the VM.
Shown in the web-interface VM's summary.
This is saved as comment inside the configuration file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 27
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Efidisk0
Configure a disk for storing EFI vars.
Use the special syntax STORAGE_ID':'SIZE_IN_GiB to allocate a new volume.
Note that SIZE_IN_GiB is ignored here and that the default EFI vars are copied to the volume instead.
Use STORAGE_ID':'0 and the 'import-from' parameter to import from an existing volume.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 28
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Force
Allow to overwrite existing VM.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 29
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Freeze
Freeze CPU at startup (use 'c' monitor command to start execution).

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 30
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -HaManaged
Add the VM as a HA resource after it was created.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 31
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Hookscript
Script that will be executed during various steps in the vms lifetime.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 32
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -HostpciN
Map host PCI devices into guest.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 33
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Hotplug
Selectively enable hotplug features.
This is a comma separated list of hotplug features':' 'network', 'disk', 'cpu', 'memory', 'usb' and 'cloudinit'.
Use '0' to disable hotplug completely.
Using '1' as value is an alias for the default \`network,disk,usb\`.
USB hotplugging is possible for guests with machine version \>= 7.1 and ostype l26 or windows \> 7.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 34
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Hugepages
Enables hugepages memory.Sets the size of hugepages in MiB.
If the value is set to 'any' then 1 GiB hugepages will be used if possible, otherwise the size will fall back to 2 MiB.
Enum: any,2,1024

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 35
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -IdeN
Use volume as IDE hard disk or CD-ROM (n is 0 to 3).
Use the special syntax STORAGE_ID':'SIZE_IN_GiB to allocate a new volume.
Use STORAGE_ID':'0 and the 'import-from' parameter to import from an existing volume.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 36
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ImportWorkingStorage
A file-based storage with 'images' content-type enabled, which is used as an intermediary extraction storage during import.
Defaults to the source storage.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 37
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -IntelTdx
Trusted Domain Extension (TDX) features by Intel CPUs

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 38
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -IpconfigN
cloud-init':' Specify IP addresses and gateways for the corresponding interface.IP addresses use CIDR notation, gateways are optional but need an IP of the same type specified.The special string 'dhcp' can be used for IP addresses to use DHCP, in which case no explicitgateway should be provided.For IPv6 the special string 'auto' can be used to use stateless autoconfiguration.
This requirescloud-init 19.4 or newer.If cloud-init is enabled and neither an IPv4 nor an IPv6 address is specified, it defaults to usingdhcp on IPv4.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 39
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Ivshmem
Inter-VM shared memory.
Useful for direct communication between VMs, or to the host.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 40
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Keephugepages
Use together with hugepages.
If enabled, hugepages will not not be deleted after VM shutdown and can be used for subsequent starts.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 41
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Keyboard
Keyboard layout for VNC server.
This option is generally not required and is often better handled from within the guest OS.
Enum: de,de-ch,da,en-gb,en-us,es,fi,fr,fr-be,fr-ca,fr-ch,hu,is,it,ja,lt,mk,nl,no,pl,pt,pt-br,sv,sl,tr

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 42
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Kvm
Enable/disable KVM hardware virtualization.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 43
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -LiveRestore
Start the VM immediately while importing or restoring in the background.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 44
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Localtime
Set the real time clock (RTC) to local time.
This is enabled by default if the \`ostype\` indicates a Microsoft Windows OS.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 45
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Lock
Lock/unlock the VM.
Enum: backup,clone,create,migrate,rollback,snapshot,snapshot-delete,suspending,suspended

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 46
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Machine
Specify the QEMU machine.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 47
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Memory
Memory properties.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 48
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -MigrateDowntime
Set maximum tolerated downtime (in seconds) for migrations.
Should the migration not be able to converge in the very end, because too much newly dirtied RAM needs to be transferred, the limit will be increased automatically step-by-step until migration can converge.

```yaml
Type: Single
Parameter Sets: (All)
Aliases:

Required: False
Position: 49
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -MigrateSpeed
Set maximum speed (in MB/s) for migrations.
Value 0 is no limit.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 50
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Name
Set a name for the VM.
Only used on the configuration web interface.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 51
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Nameserver
cloud-init':' Sets DNS server IP address for a container.
Create will automatically use the setting from the host if neither searchdomain nor nameserver are set.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 52
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -NetN
Specify network devices.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 53
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Node
The cluster node name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 54
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Numa
Enable/disable NUMA.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 55
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -NumaN
NUMA topology.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 56
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Onboot
Specifies whether a VM will be started during system bootup.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 57
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Ostype
Specify guest operating system.
Enum: other,wxp,w2k,w2k3,w2k8,wvista,win7,win8,win10,win11,l24,l26,solaris

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 58
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ParallelN
Map host parallel devices (n is 0 to 2).

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 59
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Pool
Add the VM to the specified pool.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 60
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Protection
Sets the protection flag of the VM.
This will disable the remove VM and remove disk operations.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 61
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Reboot
Allow reboot.
If set to '0' the VM exit on reboot.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 62
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Rng0
Configure a VirtIO-based Random Number Generator.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 63
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -SataN
Use volume as SATA hard disk or CD-ROM (n is 0 to 5).
Use the special syntax STORAGE_ID':'SIZE_IN_GiB to allocate a new volume.
Use STORAGE_ID':'0 and the 'import-from' parameter to import from an existing volume.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 64
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ScsiN
Use volume as SCSI hard disk or CD-ROM (n is 0 to 30).
Use the special syntax STORAGE_ID':'SIZE_IN_GiB to allocate a new volume.
Use STORAGE_ID':'0 and the 'import-from' parameter to import from an existing volume.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 65
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Scsihw
SCSI controller model Enum: lsi,lsi53c810,virtio-scsi-pci,virtio-scsi-single,megasas,pvscsi

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 66
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Searchdomain
cloud-init':' Sets DNS search domains for a container.
Create will automatically use the setting from the host if neither searchdomain nor nameserver are set.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 67
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -SerialN
Create a serial device inside the VM (n is 0 to 3)

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 68
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Shares
Amount of memory shares for auto-ballooning.
The larger the number is, the more memory this VM gets.
Number is relative to weights of all other running VMs.
Using zero disables auto-ballooning.
Auto-ballooning is done by pvestatd.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 69
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Smbios1
Specify SMBIOS type 1 fields.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 70
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Smp
The number of CPUs.
Please use option -sockets instead.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 71
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Sockets
The number of CPU sockets.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 72
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -SpiceEnhancements
Configure additional enhancements for SPICE.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 73
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Sshkeys
cloud-init':' Setup public SSH keys (one key per line, OpenSSH format).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 74
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Start
Start VM after it was created successfully.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 75
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Startdate
Set the initial date of the real time clock.
Valid format for date are':''now' or '2006-06-17T16':'01':'21' or '2006-06-17'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 76
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Startup
Startup and shutdown behavior.
Order is a non-negative number defining the general startup order.
Shutdown in done with reverse ordering.
Additionally you can set the 'up' or 'down' delay in seconds, which specifies a delay to wait before the next VM is started or stopped.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 77
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Storage
Default storage.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 78
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Tablet
Enable/disable the USB tablet device.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 79
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Tags
Tags of the VM.
This is only meta information.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 80
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Tdf
Enable/disable time drift fix.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 81
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Template
Enable/disable Template.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 82
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Tpmstate0
Configure a Disk for storing TPM state.
The format is fixed to 'raw'.
Use the special syntax STORAGE_ID':'SIZE_IN_GiB to allocate a new volume.
Note that SIZE_IN_GiB is ignored here and 4 MiB will be used instead.
Use STORAGE_ID':'0 and the 'import-from' parameter to import from an existing volume.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 83
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Unique
Assign a unique random ethernet address.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 84
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -UnusedN
Reference to unused volumes.
This is used internally, and should not be modified manually.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 85
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -UsbN
Configure an USB device (n is 0 to 4, for machine version \>= 7.1 and ostype l26 or windows \> 7, n can be up to 14).

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 86
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Vcpus
Number of hotplugged vcpus.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 87
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Vga
Configure the VGA hardware.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 88
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -VirtioN
Use volume as VIRTIO hard disk (n is 0 to 15).
Use the special syntax STORAGE_ID':'SIZE_IN_GiB to allocate a new volume.
Use STORAGE_ID':'0 and the 'import-from' parameter to import from an existing volume.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 89
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -VirtiofsN
Configuration for sharing a directory between host and guest using Virtio-fs.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 90
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Vmgenid
Set VM Generation ID.
Use '1' to autogenerate on create or update, pass '0' to disable explicitly.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 91
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Vmid
The (unique) ID of the VM.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: True
Position: 92
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Vmstatestorage
Default storage for VM state volumes/files.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 93
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Watchdog
Create a virtual hardware watchdog device.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 94
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PveResponse. Return response.
## NOTES

## RELATED LINKS
