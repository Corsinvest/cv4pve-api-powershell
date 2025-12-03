---
external help file: Corsinvest.ProxmoxVE.Api-help.xml
Module Name: Corsinvest.ProxmoxVE.Api
online version:
schema: 2.0.0
---

# New-PveNodesQemuMoveDisk

## SYNOPSIS

## SYNTAX

```
New-PveNodesQemuMoveDisk [[-PveTicket] <PveTicket>] [[-Bwlimit] <Int32>] [[-Delete] <Boolean>]
 [[-Digest] <String>] [-Disk] <String> [[-Format] <String>] [-Node] <String> [[-Storage] <String>]
 [[-TargetDigest] <String>] [[-TargetDisk] <String>] [[-TargetVmid] <Int32>] [-Vmid] <Int32>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Move volume to different storage or to a different VM.

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
Override I/O bandwidth limit (in KiB/s).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Delete
Delete the original disk after successful copy.
By default the original disk is kept as unused disk.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Digest
Prevent changes if current configuration file has different SHA1 digest.
This can be used to prevent concurrent modifications.

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

### -Disk
The disk you want to move.
Enum: ide0,ide1,ide2,ide3,scsi0,scsi1,scsi2,scsi3,scsi4,scsi5,scsi6,scsi7,scsi8,scsi9,scsi10,scsi11,scsi12,scsi13,scsi14,scsi15,scsi16,scsi17,scsi18,scsi19,scsi20,scsi21,scsi22,scsi23,scsi24,scsi25,scsi26,scsi27,scsi28,scsi29,scsi30,virtio0,virtio1,virtio2,virtio3,virtio4,virtio5,virtio6,virtio7,virtio8,virtio9,virtio10,virtio11,virtio12,virtio13,virtio14,virtio15,sata0,sata1,sata2,sata3,sata4,sata5,efidisk0,tpmstate0,unused0,unused1,unused2,unused3,unused4,unused5,unused6,unused7,unused8,unused9,unused10,unused11,unused12,unused13,unused14,unused15,unused16,unused17,unused18,unused19,unused20,unused21,unused22,unused23,unused24,unused25,unused26,unused27,unused28,unused29,unused30,unused31,unused32,unused33,unused34,unused35,unused36,unused37,unused38,unused39,unused40,unused41,unused42,unused43,unused44,unused45,unused46,unused47,unused48,unused49,unused50,unused51,unused52,unused53,unused54,unused55,unused56,unused57,unused58,unused59,unused60,unused61,unused62,unused63,unused64,unused65,unused66,unused67,unused68,unused69,unused70,unused71,unused72,unused73,unused74,unused75,unused76,unused77,unused78,unused79,unused80,unused81,unused82,unused83,unused84,unused85,unused86,unused87,unused88,unused89,unused90,unused91,unused92,unused93,unused94,unused95,unused96,unused97,unused98,unused99,unused100,unused101,unused102,unused103,unused104,unused105,unused106,unused107,unused108,unused109,unused110,unused111,unused112,unused113,unused114,unused115,unused116,unused117,unused118,unused119,unused120,unused121,unused122,unused123,unused124,unused125,unused126,unused127,unused128,unused129,unused130,unused131,unused132,unused133,unused134,unused135,unused136,unused137,unused138,unused139,unused140,unused141,unused142,unused143,unused144,unused145,unused146,unused147,unused148,unused149,unused150,unused151,unused152,unused153,unused154,unused155,unused156,unused157,unused158,unused159,unused160,unused161,unused162,unused163,unused164,unused165,unused166,unused167,unused168,unused169,unused170,unused171,unused172,unused173,unused174,unused175,unused176,unused177,unused178,unused179,unused180,unused181,unused182,unused183,unused184,unused185,unused186,unused187,unused188,unused189,unused190,unused191,unused192,unused193,unused194,unused195,unused196,unused197,unused198,unused199,unused200,unused201,unused202,unused203,unused204,unused205,unused206,unused207,unused208,unused209,unused210,unused211,unused212,unused213,unused214,unused215,unused216,unused217,unused218,unused219,unused220,unused221,unused222,unused223,unused224,unused225,unused226,unused227,unused228,unused229,unused230,unused231,unused232,unused233,unused234,unused235,unused236,unused237,unused238,unused239,unused240,unused241,unused242,unused243,unused244,unused245,unused246,unused247,unused248,unused249,unused250,unused251,unused252,unused253,unused254,unused255

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 5
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Format
Target Format.
Enum: raw,qcow2,vmdk

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

### -Node
The cluster node name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 7
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Storage
Target storage.

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

### -TargetDigest
Prevent changes if the current config file of the target VM has a different SHA1 digest.
This can be used to detect concurrent modifications.

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

### -TargetDisk
The config key the disk will be moved to on the target VM (for example, ide0 or scsi1).
Default is the source disk key.
Enum: ide0,ide1,ide2,ide3,scsi0,scsi1,scsi2,scsi3,scsi4,scsi5,scsi6,scsi7,scsi8,scsi9,scsi10,scsi11,scsi12,scsi13,scsi14,scsi15,scsi16,scsi17,scsi18,scsi19,scsi20,scsi21,scsi22,scsi23,scsi24,scsi25,scsi26,scsi27,scsi28,scsi29,scsi30,virtio0,virtio1,virtio2,virtio3,virtio4,virtio5,virtio6,virtio7,virtio8,virtio9,virtio10,virtio11,virtio12,virtio13,virtio14,virtio15,sata0,sata1,sata2,sata3,sata4,sata5,efidisk0,tpmstate0,unused0,unused1,unused2,unused3,unused4,unused5,unused6,unused7,unused8,unused9,unused10,unused11,unused12,unused13,unused14,unused15,unused16,unused17,unused18,unused19,unused20,unused21,unused22,unused23,unused24,unused25,unused26,unused27,unused28,unused29,unused30,unused31,unused32,unused33,unused34,unused35,unused36,unused37,unused38,unused39,unused40,unused41,unused42,unused43,unused44,unused45,unused46,unused47,unused48,unused49,unused50,unused51,unused52,unused53,unused54,unused55,unused56,unused57,unused58,unused59,unused60,unused61,unused62,unused63,unused64,unused65,unused66,unused67,unused68,unused69,unused70,unused71,unused72,unused73,unused74,unused75,unused76,unused77,unused78,unused79,unused80,unused81,unused82,unused83,unused84,unused85,unused86,unused87,unused88,unused89,unused90,unused91,unused92,unused93,unused94,unused95,unused96,unused97,unused98,unused99,unused100,unused101,unused102,unused103,unused104,unused105,unused106,unused107,unused108,unused109,unused110,unused111,unused112,unused113,unused114,unused115,unused116,unused117,unused118,unused119,unused120,unused121,unused122,unused123,unused124,unused125,unused126,unused127,unused128,unused129,unused130,unused131,unused132,unused133,unused134,unused135,unused136,unused137,unused138,unused139,unused140,unused141,unused142,unused143,unused144,unused145,unused146,unused147,unused148,unused149,unused150,unused151,unused152,unused153,unused154,unused155,unused156,unused157,unused158,unused159,unused160,unused161,unused162,unused163,unused164,unused165,unused166,unused167,unused168,unused169,unused170,unused171,unused172,unused173,unused174,unused175,unused176,unused177,unused178,unused179,unused180,unused181,unused182,unused183,unused184,unused185,unused186,unused187,unused188,unused189,unused190,unused191,unused192,unused193,unused194,unused195,unused196,unused197,unused198,unused199,unused200,unused201,unused202,unused203,unused204,unused205,unused206,unused207,unused208,unused209,unused210,unused211,unused212,unused213,unused214,unused215,unused216,unused217,unused218,unused219,unused220,unused221,unused222,unused223,unused224,unused225,unused226,unused227,unused228,unused229,unused230,unused231,unused232,unused233,unused234,unused235,unused236,unused237,unused238,unused239,unused240,unused241,unused242,unused243,unused244,unused245,unused246,unused247,unused248,unused249,unused250,unused251,unused252,unused253,unused254,unused255

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

### -TargetVmid
The (unique) ID of the VM.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: 0
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
Position: 12
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
