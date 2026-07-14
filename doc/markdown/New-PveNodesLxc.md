---
external help file: Corsinvest.ProxmoxVE.Api-help.xml
Module Name: Corsinvest.ProxmoxVE.Api
online version:
schema: 2.0.0
---

# New-PveNodesLxc

## SYNOPSIS

## SYNTAX

```
New-PveNodesLxc [[-PveTicket] <PveTicket>] [[-Arch] <String>] [[-Bwlimit] <Single>] [[-Cmode] <String>]
 [[-Console] <Boolean>] [[-Cores] <Int32>] [[-Cpulimit] <Single>] [[-Cpuunits] <Int32>] [[-Debug_] <Boolean>]
 [[-Description] <String>] [[-DevN] <Hashtable>] [[-Entrypoint] <String>] [[-Env] <String>]
 [[-Features] <String>] [[-Force] <Boolean>] [[-HaManaged] <Boolean>] [[-Hookscript] <String>]
 [[-Hostname] <String>] [[-IgnoreUnpackErrors] <Boolean>] [[-Lock] <String>] [[-Memory] <Int32>]
 [[-MpN] <Hashtable>] [[-Nameserver] <String>] [[-NetN] <Hashtable>] [-Node] <String> [[-Onboot] <Boolean>]
 [-Ostemplate] <String> [[-Ostype] <String>] [[-Password] <SecureString>] [[-Pool] <String>]
 [[-Protection] <Boolean>] [[-Restore] <Boolean>] [[-Rootfs] <String>] [[-Searchdomain] <String>]
 [[-SshPublicKeys] <String>] [[-Start] <Boolean>] [[-Startup] <String>] [[-Storage] <String>] [[-Swap] <Int32>]
 [[-Tags] <String>] [[-Template] <Boolean>] [[-Timezone] <String>] [[-Tty] <Int32>] [[-Unique] <Boolean>]
 [[-Unprivileged] <Boolean>] [[-UnusedN] <Hashtable>] [-Vmid] <Int32> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Create or restore a container.

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

### -Arch
OS architecture type.
Enum: amd64,i386,arm64,armhf,riscv32,riscv64

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Bwlimit
Override I/O bandwidth limit (in KiB/s).

```yaml
Type: Single
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Cmode
Console mode.
By default, the console command tries to open a connection to one of the available tty devices.
By setting cmode to 'console' it tries to attach to /dev/console instead.
If you set cmode to 'shell', it simply invokes a shell inside the container (no login).
Enum: shell,console,tty

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

### -Console
Attach a console device (/dev/console) to the container.

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

### -Cores
The number of cores assigned to the container.
A container can use all available cores by default.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Cpulimit
Limit of CPU usage.NOTE':' If the computer has 2 CPUs, it has a total of '2' CPU time.
Value '0' indicates no CPU limit.

```yaml
Type: Single
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Cpuunits
CPU weight for a container, will be clamped to \\\[1, 10000\] in cgroup v2.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Debug_
Try to be more verbose.
For now this only enables debug log-level on start.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Description
Description for the Container.
Shown in the web-interface CT's summary.
This is saved as comment inside the configuration file.

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

### -DevN
Device to pass through to the container

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Entrypoint
Command to run as init, optionally with arguments; may start with an absolute path, relative path, or a binary in $PATH.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 12
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Env
The container runtime environment as NUL-separated list.
Replaces any lxc.environment.runtime entries in the config.

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

### -Features
Allow containers access to advanced features.

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

### -Force
Allow to overwrite existing container.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 15
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -HaManaged
Add the CT as a HA resource after it was created.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 16
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Hookscript
Script that will be executed during various steps in the containers lifetime.

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

### -Hostname
Set a host name for the container.

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

### -IgnoreUnpackErrors
Ignore errors when extracting the template.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 19
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Lock
Lock/unlock the container.
Enum: backup,create,destroyed,disk,fstrim,migrate,mounted,rollback,snapshot,snapshot-delete

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

### -Memory
Amount of RAM for the container in MB.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 21
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -MpN
Use volume as container mount point.
Use the special syntax STORAGE_ID':'SIZE_IN_GiB to allocate a new volume.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 22
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Nameserver
Sets DNS server IP address for a container.
Create will automatically use the setting from the host if you neither set searchdomain nor nameserver.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 23
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -NetN
Specifies network interfaces for the container.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 24
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
Position: 25
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Onboot
Specifies whether a container will be started during system bootup.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 26
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Ostemplate
The OS template or backup file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 27
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Ostype
OS type.
This is used to setup configuration inside the container, and corresponds to lxc setup scripts in /usr/share/lxc/config/\<ostype\>.common.conf.
Value 'unmanaged' can be used to skip and OS specific setup.
Enum: debian,devuan,ubuntu,centos,fedora,opensuse,archlinux,alpine,gentoo,nixos,unmanaged

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

### -Password
Sets root password inside container.

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: 29
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
Position: 30
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Protection
Sets the protection flag of the container.
This will prevent the CT or CT's disk remove/update operation.

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

### -Restore
Mark this as restore task.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 32
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Rootfs
Use volume as container root.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 33
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Searchdomain
Sets DNS search domains for a container.
Create will automatically use the setting from the host if you neither set searchdomain nor nameserver.

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

### -SshPublicKeys
Setup public SSH keys (one key per line, OpenSSH format).

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

### -Start
Start the CT after its creation finished successfully.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 36
Default value: False
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
Position: 37
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Storage
Default Storage.

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

### -Swap
Amount of SWAP for the container in MB.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 39
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Tags
Tags of the Container.
This is only meta information.

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

### -Template
Enable/disable Template.

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

### -Timezone
Time zone to use in the container.
If option isn't set, then nothing will be done.
Can be set to 'host' to match the host time zone, or an arbitrary time zone option from /usr/share/zoneinfo/zone.tab

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

### -Tty
Specify the number of tty available to the container

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 43
Default value: 0
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
Position: 44
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Unprivileged
Makes the container run as unprivileged user.
For creation, the default is 1.
For restore, the default is the value from the backup.
(Should not be modified manually.)

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

### -UnusedN
Reference to unused volumes.
This is used internally, and should not be modified manually.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 46
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
Position: 47
Default value: 0
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
