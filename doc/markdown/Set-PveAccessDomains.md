---
external help file: Corsinvest.ProxmoxVE.Api-help.xml
Module Name: Corsinvest.ProxmoxVE.Api
online version:
schema: 2.0.0
---

# Set-PveAccessDomains

## SYNOPSIS

## SYNTAX

```
Set-PveAccessDomains [[-PveTicket] <PveTicket>] [[-AcrValues] <String>] [[-Autocreate] <Boolean>]
 [[-BaseDn] <String>] [[-BindDn] <String>] [[-Capath] <String>] [[-CaseSensitive] <Boolean>] [[-Cert] <String>]
 [[-Certkey] <String>] [[-CheckConnection] <Boolean>] [[-ClientId] <String>] [[-ClientKey] <String>]
 [[-Comment] <String>] [[-Default] <Boolean>] [[-Delete] <String>] [[-Digest] <String>] [[-Domain] <String>]
 [[-Filter] <String>] [[-GroupClasses] <String>] [[-GroupDn] <String>] [[-GroupFilter] <String>]
 [[-GroupNameAttr] <String>] [[-GroupsAutocreate] <Boolean>] [[-GroupsClaim] <String>]
 [[-GroupsOverwrite] <Boolean>] [[-IssuerUrl] <String>] [[-Mode] <String>] [[-Password] <SecureString>]
 [[-Port] <Int32>] [[-Prompt] <String>] [[-QueryUserinfo] <Boolean>] [-Realm] <String> [[-Scopes] <String>]
 [[-Secure] <Boolean>] [[-Server1] <String>] [[-Server2] <String>] [[-Sslversion] <String>]
 [[-SyncDefaultsOptions] <String>] [[-SyncAttributes] <String>] [[-Tfa] <String>] [[-UserAttr] <String>]
 [[-UserClasses] <String>] [[-Verify] <Boolean>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Update authentication server settings.

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

### -AcrValues
Specifies the Authentication Context Class Reference values that theAuthorization Server is being requested to use for the Auth Request.

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

### -Autocreate
Automatically create users if they do not exist.

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

### -BaseDn
LDAP base domain name

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

### -BindDn
LDAP bind domain name

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

### -Capath
Path to the CA certificate store

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

### -CaseSensitive
username is case-sensitive

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Cert
Path to the client certificate

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

### -Certkey
Path to the client certificate key

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

### -CheckConnection
Check bind connection to the server.

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

### -ClientId
OpenID Client ID

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

### -ClientKey
OpenID Client Key

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

### -Comment
Description.

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

### -Default
Use this as default realm

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

### -Delete
A list of settings you want to delete.

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

### -Digest
Prevent changes if current configuration file has a different digest.
This can be used to prevent concurrent modifications.

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

### -Domain
AD domain name

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

### -Filter
LDAP filter for user sync.

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

### -GroupClasses
The objectclasses for groups.

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

### -GroupDn
LDAP base domain name for group sync.
If not set, the base_dn will be used.

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

### -GroupFilter
LDAP filter for group sync.

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

### -GroupNameAttr
LDAP attribute representing a groups name.
If not set or found, the first value of the DN will be used as name.

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

### -GroupsAutocreate
Automatically create groups if they do not exist.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 23
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -GroupsClaim
OpenID claim used to retrieve groups with.

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

### -GroupsOverwrite
All groups will be overwritten for the user on login.

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

### -IssuerUrl
OpenID Issuer Url

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

### -Mode
LDAP protocol mode.
Enum: ldap,ldaps,ldap+starttls

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

### -Password
LDAP bind password.
Will be stored in '/etc/pve/priv/realm/\<REALM\>.pw'.

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: 28
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Port
Server port.

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

### -Prompt
Specifies whether the Authorization Server prompts the End-User for reauthentication and consent.

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

### -QueryUserinfo
Enables querying the userinfo endpoint for claims values.

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

### -Realm
Authentication domain ID

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 32
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Scopes
Specifies the scopes (user details) that should be authorized and returned, for example 'email' or 'profile'.

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

### -Secure
Use secure LDAPS protocol.
DEPRECATED':' use 'mode' instead.

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

### -Server1
Server IP address (or DNS name)

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

### -Server2
Fallback Server IP address (or DNS name)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 36
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Sslversion
LDAPS TLS/SSL version.
It's not recommended to use version older than 1.2!
Enum: tlsv1,tlsv1_1,tlsv1_2,tlsv1_3

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

### -SyncDefaultsOptions
The default options for behavior of synchronizations.

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

### -SyncAttributes
Comma separated list of key=value pairs for specifying which LDAP attributes map to which PVE user field.
For example, to map the LDAP attribute 'mail' to PVEs 'email', write  'email=mail'.
By default, each PVE user field is represented  by an LDAP attribute of the same name.

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

### -Tfa
Use Two-factor authentication.

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

### -UserAttr
LDAP user attribute name

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 41
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -UserClasses
The objectclasses for users.

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

### -Verify
Verify the server's SSL certificate

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
