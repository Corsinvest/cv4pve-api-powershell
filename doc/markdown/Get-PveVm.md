---
external help file: Corsinvest.ProxmoxVE.Api-help.xml
Module Name: Corsinvest.ProxmoxVE.Api
online version:
schema: 2.0.0
---

# Get-PveVm

## SYNOPSIS

## SYNTAX

```
Get-PveVm [[-PveTicket] <PveTicket>] [[-VmIdOrName] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Get VMs/CTs from id or name.

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
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -VmIdOrName
The id or name VM/CT comma separated (eg.
100,101,102,TestDebian)
-vmid or -name exclude (e.g.
-200,-TestUbuntu)
range 100:107,-105,200:204
'@pool-???' for all VM/CT in specific pool (e.g.
@pool-customer1),
'@tag-???' for all VM/CT in specific tags (e.g.
@tag-customerA),
'@node-???' for all VM/CT in specific node (e.g.
@node-pve1, @node-\$(hostname)),
'@all-???' for all VM/CT in specific host (e.g.
@all-pve1, @all-\$(hostname)),
'@all' for all VM/CT in cluster";

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
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

### PSCustomObject. Return Vm/s data.
## NOTES

## RELATED LINKS
