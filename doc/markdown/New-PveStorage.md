---
external help file: Corsinvest.ProxmoxVE.Api-help.xml
Module Name: Corsinvest.ProxmoxVE.Api
online version:
schema: 2.0.0
---

# New-PveStorage

## SYNOPSIS

## SYNTAX

```
New-PveStorage [[-PveTicket] <PveTicket>] [[-Authsupported] <String>] [[-Base] <String>]
 [[-Blocksize] <String>] [[-Bwlimit] <String>] [[-ComstarHg] <String>] [[-ComstarTg] <String>]
 [[-Content] <String>] [[-ContentDirs] <String>] [[-CreateBasePath] <Boolean>] [[-CreateSubdirs] <Boolean>]
 [[-DataPool] <String>] [[-Datastore] <String>] [[-Disable] <Boolean>] [[-Domain] <String>]
 [[-EncryptionKey] <String>] [[-Export] <String>] [[-Fingerprint] <String>] [[-Format] <String>]
 [[-FsName] <String>] [[-Fuse] <Boolean>] [[-IsMountpoint] <String>] [[-Iscsiprovider] <String>]
 [[-Keyring] <String>] [[-Krbd] <Boolean>] [[-LioTpg] <String>] [[-MasterPubkey] <String>]
 [[-MaxProtectedBackups] <Int32>] [[-Maxfiles] <Int32>] [[-Mkdir] <Boolean>] [[-Monhost] <String>]
 [[-Mountpoint] <String>] [[-Namespace] <String>] [[-Nocow] <Boolean>] [[-Nodes] <String>]
 [[-Nowritecache] <Boolean>] [[-Options] <String>] [[-Password] <SecureString>] [[-Path] <String>]
 [[-Pool] <String>] [[-Port] <Int32>] [[-Portal] <String>] [[-Preallocation] <String>]
 [[-PruneBackups] <String>] [[-Saferemove] <Boolean>] [[-SaferemoveThroughput] <String>] [[-Server] <String>]
 [[-Server2] <String>] [[-Share] <String>] [[-Shared] <Boolean>] [[-SkipCertVerification] <Boolean>]
 [[-Smbversion] <String>] [[-Sparse] <Boolean>] [-Storage] <String> [[-Subdir] <String>]
 [[-TaggedOnly] <Boolean>] [[-Target] <String>] [[-Thinpool] <String>] [[-Transport] <String>] [-Type] <String>
 [[-Username] <String>] [[-Vgname] <String>] [[-Volume] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Create a new storage.

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

### -Authsupported
Authsupported.

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

### -Base
Base volume.
This volume is automatically activated.

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

### -Blocksize
block size

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

### -Bwlimit
Set I/O bandwidth limit for various operations (in KiB/s).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ComstarHg
host group for comstar views

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

### -ComstarTg
target group for comstar views

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

### -Content
Allowed content types.NOTE':' the value 'rootdir' is used for Containers, and value 'images' for VMs.

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

### -ContentDirs
Overrides for default content type directories.

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

### -CreateBasePath
Create the base directory if it doesn't exist.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -CreateSubdirs
Populate the directory with the default structure.

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

### -DataPool
Data Pool (for erasure coding only)

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

### -Datastore
Proxmox Backup Server datastore name.

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

### -Disable
Flag to disable the storage.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 14
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Domain
CIFS domain.

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

### -EncryptionKey
Encryption key.
Use 'autogen' to generate one automatically without passphrase.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 16
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Export
NFS export path.

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

### -Fingerprint
Certificate SHA 256 fingerprint.

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

### -Format
Default image format.
Enum: raw,qcow2,subvol,vmdk

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 19
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -FsName
The Ceph filesystem name.

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

### -Fuse
Mount CephFS through FUSE.

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

### -IsMountpoint
Assume the given path is an externally managed mountpoint and consider the storage offline if it is not mounted.
Using a boolean (yes/no) value serves as a shortcut to using the target path in this field.

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

### -Iscsiprovider
iscsi provider

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

### -Keyring
Client keyring contents (for external clusters).

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

### -Krbd
Always access rbd through krbd kernel module.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 25
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -LioTpg
target portal group for Linux LIO targets

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 26
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -MasterPubkey
Base64-encoded, PEM-formatted public RSA key.
Used to encrypt a copy of the encryption-key which will be added to each encrypted backup.

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

### -MaxProtectedBackups
Maximal number of protected backups per guest.
Use '-1' for unlimited.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 28
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Maxfiles
Deprecated':' use 'prune-backups' instead.
Maximal number of backup files per VM.
Use '0' for unlimited.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 29
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Mkdir
Create the directory if it doesn't exist and populate it with default sub-dirs.
NOTE':' Deprecated, use the 'create-base-path' and 'create-subdirs' options instead.

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

### -Monhost
IP addresses of monitors (for external clusters).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 31
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Mountpoint
mount point

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

### -Namespace
Namespace.

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

### -Nocow
Set the NOCOW flag on files.
Disables data checksumming and causes data errors to be unrecoverable from while allowing direct I/O.
Only use this if data does not need to be any more safe than on a single ext4 formatted disk with no underlying raid system.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 34
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Nodes
List of nodes for which the storage configuration applies.

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

### -Nowritecache
disable write caching on the target

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

### -Options
NFS/CIFS mount options (see 'man nfs' or 'man mount.cifs')

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

### -Password
Password for accessing the share/datastore.

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: 38
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Path
File system path.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 39
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Pool
Pool.

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

### -Port
Use this port to connect to the storage instead of the default one (for example, with PBS or ESXi).
For NFS and CIFS, use the 'options' option to configure the port via the mount options.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 41
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Portal
iSCSI portal (IP or DNS name with optional port).

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

### -Preallocation
Preallocation mode for raw and qcow2 images.
Using 'metadata' on raw images results in preallocation=off.
Enum: off,metadata,falloc,full

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 43
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -PruneBackups
The retention options with shorter intervals are processed first with --keep-last being the very first one.
Each option covers a specific period of time.
We say that backups within this period are covered by this option.
The next option does not take care of already covered backups and only considers older backups.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 44
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Saferemove
Zero-out data when removing LVs.

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

### -SaferemoveThroughput
Wipe throughput (cstream -t parameter value).

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

### -Server
Server IP or DNS name.

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

### -Server2
Backup volfile server IP or DNS name.

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

### -Share
CIFS share.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 49
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Shared
Indicate that this is a single storage with the same contents on all nodes (or all listed in the 'nodes' option).
It will not make the contents of a local storage automatically accessible to other nodes, it just marks an already shared storage as such!

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 50
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -SkipCertVerification
Disable TLS certificate verification, only enable on fully trusted networks!

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 51
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Smbversion
SMB protocol version.
'default' if not set, negotiates the highest SMB2+ version supported by both the client and server.
Enum: default,2.0,2.1,3,3.0,3.11

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

### -Sparse
use sparse volumes

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 53
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Storage
The storage identifier.

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

### -Subdir
Subdir to mount.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 55
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -TaggedOnly
Only use logical volumes tagged with 'pve-vm-ID'.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 56
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Target
iSCSI target.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 57
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Thinpool
LVM thin pool LV name.

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

### -Transport
Gluster transport':' tcp or rdma Enum: tcp,rdma,unix

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 59
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Type
Storage type.
Enum: btrfs,cephfs,cifs,dir,esxi,glusterfs,iscsi,iscsidirect,lvm,lvmthin,nfs,pbs,rbd,zfs,zfspool

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 60
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Username
RBD Id.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 61
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Vgname
Volume group name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 62
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Volume
Glusterfs Volume.

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
