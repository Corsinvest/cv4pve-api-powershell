---
external help file: Corsinvest.ProxmoxVE.Api-help.xml
Module Name: Corsinvest.ProxmoxVE.Api
online version:
schema: 2.0.0
---

# Set-PveClusterOptions

## SYNOPSIS

## SYNTAX

```
Set-PveClusterOptions [[-PveTicket] <PveTicket>] [[-Bwlimit] <String>] [[-ConsentText] <String>]
 [[-Console] <String>] [[-Crs] <String>] [[-Delete] <String>] [[-Description] <String>] [[-EmailFrom] <String>]
 [[-Fencing] <String>] [[-Ha] <String>] [[-HttpProxy] <String>] [[-Keyboard] <String>] [[-Language] <String>]
 [[-MacPrefix] <String>] [[-MaxWorkers] <Int32>] [[-Migration] <String>] [[-MigrationUnsecure] <Boolean>]
 [[-NextId] <String>] [[-Notify] <String>] [[-RegisteredTags] <String>] [[-TagStyle] <String>]
 [[-U2f] <String>] [[-UserTagAccess] <String>] [[-Webauthn] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Set datacenter options.

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

### -Bwlimit
Set I/O bandwidth limit for various operations (in KiB/s).

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

### -ConsentText
Consent text that is displayed before logging in.

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

### -Console
Select the default Console viewer.
You can either use the builtin java applet (VNC; deprecated and maps to html5), an external virt-viewer comtatible application (SPICE), an HTML5 based vnc viewer (noVNC), or an HTML5 based console client (xtermjs).
If the selected viewer is not available (e.g.
SPICE not activated for the VM), the fallback is noVNC.
Enum: applet,vv,html5,xtermjs

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

### -Crs
Cluster resource scheduling settings.

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

### -Delete
A list of settings you want to delete.

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

### -Description
Datacenter description.
Shown in the web-interface datacenter notes panel.
This is saved as comment inside the configuration file.

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

### -EmailFrom
Specify email address to send notification from (default is root@$hostname)

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

### -Fencing
Set the fencing mode of the HA cluster.
Hardware mode needs a valid configuration of fence devices in /etc/pve/ha/fence.cfg.
With both all two modes are used.WARNING':' 'hardware' and 'both' are EXPERIMENTAL & WIP Enum: watchdog,hardware,both

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

### -Ha
Cluster wide HA settings.

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

### -HttpProxy
Specify external http proxy which is used for downloads (example':' 'http':'//username':'password@host':'port/')

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Keyboard
Default keybord layout for vnc server.
Enum: de,de-ch,da,en-gb,en-us,es,fi,fr,fr-be,fr-ca,fr-ch,hu,is,it,ja,lt,mk,nl,no,pl,pt,pt-br,sv,sl,tr

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

### -Language
Default GUI language.
Enum: ar,ca,da,de,en,es,eu,fa,fr,hr,he,it,ja,ka,kr,nb,nl,nn,pl,pt_BR,ru,sl,sv,tr,ukr,zh_CN,zh_TW

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

### -MacPrefix
Prefix for the auto-generated MAC addresses of virtual guests.
The default 'BC':'24':'11' is the OUI assigned by the IEEE to Proxmox Server Solutions GmbH for a 24-bit large MAC block.
You're allowed to use this in local networks, i.e., those not directly reachable by the public (e.g., in a LAN or behind NAT).

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

### -MaxWorkers
Defines how many workers (per node) are maximal started  on actions like 'stopall VMs' or task from the ha-manager.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 15
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Migration
For cluster wide migration settings.

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

### -MigrationUnsecure
Migration is secure using SSH tunnel by default.
For secure private networks you can disable it to speed up migration.
Deprecated, use the 'migration' property instead!

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 17
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -NextId
Control the range for the free VMID auto-selection pool.

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

### -Notify
Cluster-wide notification settings.

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

### -RegisteredTags
A list of tags that require a \`Sys.Modify\` on '/' to set and delete.
Tags set here that are also in 'user-tag-access' also require \`Sys.Modify\`.

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

### -TagStyle
Tag style options.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 21
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -U2f
u2f

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

### -UserTagAccess
Privilege options for user-settable tags

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

### -Webauthn
webauthn configuration

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
