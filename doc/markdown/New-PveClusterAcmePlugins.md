---
external help file: Corsinvest.ProxmoxVE.Api-help.xml
Module Name: Corsinvest.ProxmoxVE.Api
online version:
schema: 2.0.0
---

# New-PveClusterAcmePlugins

## SYNOPSIS

## SYNTAX

```
New-PveClusterAcmePlugins [[-PveTicket] <PveTicket>] [[-Api] <String>] [[-Data] <String>]
 [[-Disable] <Boolean>] [-Id] <String> [[-Nodes] <String>] [-Type] <String> [[-ValidationDelay] <Int32>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Add ACME plugin configuration.

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

### -Api
API plugin name Enum: 1984hosting,acmedns,acmeproxy,active24,ad,ali,alviy,anx,artfiles,arvan,aurora,autodns,aws,azion,azure,bookmyname,bunny,cf,clouddns,cloudns,cn,conoha,constellix,cpanel,curanet,cyon,da,ddnss,desec,df,dgon,dnsexit,dnshome,dnsimple,dnsservices,doapi,domeneshop,dp,dpi,dreamhost,duckdns,durabledns,dyn,dynu,dynv6,easydns,edgedns,euserv,exoscale,fornex,freedns,gandi_livedns,gcloud,gcore,gd,geoscaling,googledomains,he,hetzner,hexonet,hostingde,huaweicloud,infoblox,infomaniak,internetbs,inwx,ionos,ionos_cloud,ipv64,ispconfig,jd,joker,kappernet,kas,kinghost,knot,la,leaseweb,lexicon,limacity,linode,linode_v4,loopia,lua,maradns,me,miab,misaka,myapi,mydevil,mydnsjp,mythic_beasts,namecheap,namecom,namesilo,nanelo,nederhost,neodigit,netcup,netlify,nic,njalla,nm,nsd,nsone,nsupdate,nw,oci,omglol,one,online,openprovider,openstack,opnsense,ovh,pdns,pleskxml,pointhq,porkbun,rackcorp,rackspace,rage4,rcode0,regru,scaleway,schlundtech,selectel,selfhost,servercow,simply,technitium,tele3,tencent,timeweb,transip,udr,ultra,unoeuro,variomedia,veesp,vercel,vscale,vultr,websupport,west_cn,world4you,yandex360,yc,zilore,zone,zoneedit,zonomi

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

### -Data
DNS plugin data.
(base64 encoded)

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

### -Disable
Flag to disable the config.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Id
ACME Plugin ID name

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

### -Nodes
List of cluster node names.

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

### -Type
ACME challenge type.
Enum: dns,standalone

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

### -ValidationDelay
Extra delay in seconds to wait before requesting validation.
Allows to cope with a long TTL of DNS records.

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
