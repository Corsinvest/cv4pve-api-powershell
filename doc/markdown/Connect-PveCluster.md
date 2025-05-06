---
external help file: Corsinvest.ProxmoxVE.Api-help.xml
Module Name: Corsinvest.ProxmoxVE.Api
online version:
schema: 2.0.0
---

# Connect-PveCluster

## SYNOPSIS

## SYNTAX

```
Connect-PveCluster [-HostsAndPorts] <String[]> [[-Credentials] <PSCredential>] [[-ApiToken] <String>]
 [[-Otp] <String>] [-SkipCertificateCheck] [-SkipRefreshPveTicketLast] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Connect to Proxmox VE Cluster.

## EXAMPLES

### EXAMPLE 1
```
$PveTicket = Connect-PveCluster -HostsAndPorts 192.168.128.115 -Credentials (Get-Credential -Username 'root').
```

## PARAMETERS

### -HostsAndPorts
Host and ports
Format 10.1.1.90:8006,10.1.1.91:8006,10.1.1.92:8006.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Credentials
Username and password, username formatted as user@pam, user@pve, user@yourdomain or user (default domain pam).

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiToken
Api Token format USER@REALM!TOKENID=UUID

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Otp
One-time password for Two-factor authentication.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipCertificateCheck
Skips certificate validation checks.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipRefreshPveTicketLast
Skip refresh PveTicket Last global variable

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
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

### PveTicket. Return ticket connection.
## NOTES

## RELATED LINKS
