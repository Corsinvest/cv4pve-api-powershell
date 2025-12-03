---
external help file: Corsinvest.ProxmoxVE.Api-help.xml
Module Name: Corsinvest.ProxmoxVE.Api
online version:
schema: 2.0.0
---

# Set-PveClusterMetricsServer

## SYNOPSIS

## SYNTAX

```
Set-PveClusterMetricsServer [[-PveTicket] <PveTicket>] [[-ApiPathPrefix] <String>] [[-Bucket] <String>]
 [[-Delete] <String>] [[-Digest] <String>] [[-Disable] <Boolean>] [-Id] <String> [[-Influxdbproto] <String>]
 [[-MaxBodySize] <Int32>] [[-Mtu] <Int32>] [[-Organization] <String>] [[-OtelCompression] <String>]
 [[-OtelHeaders] <String>] [[-OtelMaxBodySize] <Int32>] [[-OtelPath] <String>] [[-OtelProtocol] <String>]
 [[-OtelResourceAttributes] <String>] [[-OtelTimeout] <Int32>] [[-OtelVerifySsl] <Boolean>] [[-Path] <String>]
 [-Port] <Int32> [[-Proto] <String>] [-Server] <String> [[-Timeout] <Int32>] [[-Token] <String>]
 [[-VerifyCertificate] <Boolean>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Update metric server configuration.

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

### -ApiPathPrefix
An API path prefix inserted between '\<host\>':'\<port\>/' and '/api2/'.
Can be useful if the InfluxDB service runs behind a reverse proxy.

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

### -Bucket
The InfluxDB bucket/db.
Only necessary when using the http v2 api.

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

### -Delete
A list of settings you want to delete.

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

### -Digest
Prevent changes if current configuration file has a different digest.
This can be used to prevent concurrent modifications.

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

### -Disable
Flag to disable the plugin.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Id
The ID of the entry.

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

### -Influxdbproto
-- Enum: udp,http,https

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

### -MaxBodySize
InfluxDB max-body-size in bytes.
Requests are batched up to this size.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Mtu
MTU for metrics transmission over UDP

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Organization
The InfluxDB organization.
Only necessary when using the http v2 api.
Has no meaning when using v2 compatibility api.

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

### -OtelCompression
Compression algorithm for requests Enum: none,gzip

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

### -OtelHeaders
Custom HTTP headers (JSON format, base64 encoded)

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

### -OtelMaxBodySize
Maximum request body size in bytes

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 14
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -OtelPath
OTLP endpoint path

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

### -OtelProtocol
HTTP protocol Enum: http,https

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

### -OtelResourceAttributes
Additional resource attributes as JSON, base64 encoded

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

### -OtelTimeout
HTTP request timeout in seconds

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 18
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -OtelVerifySsl
Verify SSL certificates

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

### -Path
root graphite path (ex':' proxmox.mycluster.mykey)

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

### -Port
server network port

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: True
Position: 21
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Proto
Protocol to send graphite data.
TCP or UDP (default) Enum: udp,tcp

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

### -Server
server dns name or IP address

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 23
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Timeout
graphite TCP socket timeout (default=1)

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 24
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Token
The InfluxDB access token.
Only necessary when using the http v2 api.
If the v2 compatibility api is used, use 'user':'password' instead.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 25
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -VerifyCertificate
Set to 0 to disable certificate verification for https endpoints.

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
