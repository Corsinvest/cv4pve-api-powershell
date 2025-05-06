---
external help file: Corsinvest.ProxmoxVE.Api-help.xml
Module Name: Corsinvest.ProxmoxVE.Api
online version:
schema: 2.0.0
---

# Set-PveNodesLxcResize

## SYNOPSIS

## SYNTAX

```
Set-PveNodesLxcResize [[-PveTicket] <PveTicket>] [[-Digest] <String>] [-Disk] <String> [-Node] <String>
 [-Size] <String> [-Vmid] <Int32> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Resize a container mount point.

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

### -Digest
Prevent changes if current configuration file has different SHA1 digest.
This can be used to prevent concurrent modifications.

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

### -Disk
The disk you want to resize.
Enum: rootfs,mp0,mp1,mp2,mp3,mp4,mp5,mp6,mp7,mp8,mp9,mp10,mp11,mp12,mp13,mp14,mp15,mp16,mp17,mp18,mp19,mp20,mp21,mp22,mp23,mp24,mp25,mp26,mp27,mp28,mp29,mp30,mp31,mp32,mp33,mp34,mp35,mp36,mp37,mp38,mp39,mp40,mp41,mp42,mp43,mp44,mp45,mp46,mp47,mp48,mp49,mp50,mp51,mp52,mp53,mp54,mp55,mp56,mp57,mp58,mp59,mp60,mp61,mp62,mp63,mp64,mp65,mp66,mp67,mp68,mp69,mp70,mp71,mp72,mp73,mp74,mp75,mp76,mp77,mp78,mp79,mp80,mp81,mp82,mp83,mp84,mp85,mp86,mp87,mp88,mp89,mp90,mp91,mp92,mp93,mp94,mp95,mp96,mp97,mp98,mp99,mp100,mp101,mp102,mp103,mp104,mp105,mp106,mp107,mp108,mp109,mp110,mp111,mp112,mp113,mp114,mp115,mp116,mp117,mp118,mp119,mp120,mp121,mp122,mp123,mp124,mp125,mp126,mp127,mp128,mp129,mp130,mp131,mp132,mp133,mp134,mp135,mp136,mp137,mp138,mp139,mp140,mp141,mp142,mp143,mp144,mp145,mp146,mp147,mp148,mp149,mp150,mp151,mp152,mp153,mp154,mp155,mp156,mp157,mp158,mp159,mp160,mp161,mp162,mp163,mp164,mp165,mp166,mp167,mp168,mp169,mp170,mp171,mp172,mp173,mp174,mp175,mp176,mp177,mp178,mp179,mp180,mp181,mp182,mp183,mp184,mp185,mp186,mp187,mp188,mp189,mp190,mp191,mp192,mp193,mp194,mp195,mp196,mp197,mp198,mp199,mp200,mp201,mp202,mp203,mp204,mp205,mp206,mp207,mp208,mp209,mp210,mp211,mp212,mp213,mp214,mp215,mp216,mp217,mp218,mp219,mp220,mp221,mp222,mp223,mp224,mp225,mp226,mp227,mp228,mp229,mp230,mp231,mp232,mp233,mp234,mp235,mp236,mp237,mp238,mp239,mp240,mp241,mp242,mp243,mp244,mp245,mp246,mp247,mp248,mp249,mp250,mp251,mp252,mp253,mp254,mp255

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
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
Position: 4
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Size
The new size.
With the '+' sign the value is added to the actual size of the volume and without it, the value is taken as an absolute one.
Shrinking disk size is not supported.

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

### -Vmid
The (unique) ID of the VM.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: True
Position: 6
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
