---
external help file: Corsinvest.ProxmoxVE.Api-help.xml
Module Name: Corsinvest.ProxmoxVE.Api
online version:
schema: 2.0.0
---

# New-PveClusterSdnZones

## SYNOPSIS

## SYNTAX

```
New-PveClusterSdnZones [[-PveTicket] <PveTicket>] [[-AdvertiseSubnets] <Boolean>] [[-Bridge] <String>]
 [[-BridgeDisableMacLearning] <Boolean>] [[-Controller] <String>] [[-Dhcp] <String>]
 [[-DisableArpNdSuppression] <Boolean>] [[-Dns] <String>] [[-Dnszone] <String>] [[-DpId] <Int32>]
 [[-Exitnodes] <String>] [[-ExitnodesLocalRouting] <Boolean>] [[-ExitnodesPrimary] <String>]
 [[-Fabric] <String>] [[-Ipam] <String>] [[-LockToken] <String>] [[-Mac] <String>] [[-Mtu] <Int32>]
 [[-Nodes] <String>] [[-Peers] <String>] [[-Reversedns] <String>] [[-RtImport] <String>] [[-Tag] <Int32>]
 [-Type] <String> [[-VlanProtocol] <String>] [[-VrfVxlan] <Int32>] [[-VxlanPort] <Int32>] [-Zone] <String>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Create a new sdn zone object.

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

### -AdvertiseSubnets
Advertise IP prefixes (Type-5 routes) instead of MAC/IP pairs (Type-2 routes).

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Bridge
The bridge for which VLANs should be managed.

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

### -BridgeDisableMacLearning
Disable auto mac learning.

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

### -Controller
Controller for this zone.

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

### -Dhcp
Type of the DHCP backend for this zone Enum: dnsmasq

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

### -DisableArpNdSuppression
Suppress IPv4 ARP && IPv6 Neighbour Discovery messages.

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

### -Dns
dns api server

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

### -Dnszone
dns domain zone  ex':' mydomain.com

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

### -DpId
Faucet dataplane id

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

### -Exitnodes
List of cluster node names.

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

### -ExitnodesLocalRouting
Allow exitnodes to connect to EVPN guests.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 12
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ExitnodesPrimary
Force traffic through this exitnode first.

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

### -Fabric
SDN fabric to use as underlay for this VXLAN zone.

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

### -Ipam
use a specific ipam

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

### -LockToken
the token for unlocking the global SDN configuration

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

### -Mac
Anycast logical router mac address.

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

### -Mtu
MTU of the zone, will be used for the created VNet bridges.

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

### -Nodes
List of cluster node names.

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

### -Peers
Comma-separated list of peers, that are part of the VXLAN zone.
Usually the IPs of the nodes.

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

### -Reversedns
reverse dns api server

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

### -RtImport
List of Route Targets that should be imported into the VRF of the zone.

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

### -Tag
Service-VLAN Tag (outer VLAN)

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 23
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Type
Plugin type.
Enum: evpn,faucet,qinq,simple,vlan,vxlan

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 24
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -VlanProtocol
Which VLAN protocol should be used for the creation of the QinQ zone.
Enum: 802.1q,802.1ad

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

### -VrfVxlan
VNI for the zone VRF.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 26
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -VxlanPort
UDP port that should be used for the VXLAN tunnel (default 4789).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 27
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Zone
The SDN zone object identifier.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 28
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
