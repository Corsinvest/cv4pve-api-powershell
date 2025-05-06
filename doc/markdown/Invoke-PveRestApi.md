---
external help file: Corsinvest.ProxmoxVE.Api-help.xml
Module Name: Corsinvest.ProxmoxVE.Api
online version:
schema: 2.0.0
---

# Invoke-PveRestApi

## SYNOPSIS

## SYNTAX

```
Invoke-PveRestApi [[-PveTicket] <PveTicket>] [-Resource] <String> [[-Method] <String>]
 [[-ResponseType] <String>] [[-Parameters] <Hashtable>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Invoke Proxmox VE Rest API

## EXAMPLES

### EXAMPLE 1
```
$PveTicket = Connect-PveCluster -HostsAndPorts '192.168.128.115' -Credentials (Get-Credential -Username 'root').
(Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource '/version').Resonse.data
```

data
----
@{version=5.4; release=15; repoid=d0ec33c6; keyboard=it}

## PARAMETERS

### -PveTicket
Ticket data

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

### -Resource
Resource Request

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Method
Method request

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Get
Accept pipeline input: False
Accept wildcard characters: False
```

### -ResponseType
Type request

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: Json
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameters
Parameters request

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
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

### Return object request
## NOTES
This must be used before any other cmdlets are used

## RELATED LINKS
