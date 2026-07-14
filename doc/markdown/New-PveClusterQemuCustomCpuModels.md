---
external help file: Corsinvest.ProxmoxVE.Api-help.xml
Module Name: Corsinvest.ProxmoxVE.Api
online version:
schema: 2.0.0
---

# New-PveClusterQemuCustomCpuModels

## SYNOPSIS

## SYNTAX

```
New-PveClusterQemuCustomCpuModels [[-PveTicket] <PveTicket>] [-Cputype] <String> [[-Flags] <String>]
 [[-GuestPhysBits] <Int32>] [[-Hidden] <Boolean>] [[-HvVendorId] <String>] [[-Level] <Int32>]
 [[-PhysBits] <String>] [-ReportedModel] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Add a custom CPU model definition.

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

### -Cputype
Name for the custom CPU model.
The 'custom-' prefix is optional.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Flags
List of additional CPU flags separated by ';'.
Use '+FLAG' to enable, '-FLAG' to disable a flag.
There is a special 'nested-virt' shorthand which controls nested virtualization for the current CPU ('svm' for AMD and 'vmx' for Intel).
Custom CPU models can specify any flag supported by QEMU/KVM, VM-specific flags must be from the following set for security reasons':' aes, amd-no-ssb, amd-ssbd, hv-evmcs, hv-tlbflush, ibpb, md-clear, nested-virt, pcid, pdpe1gb, spec-ctrl, ssbd, virt-ssbd

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

### -GuestPhysBits
Number of physical address bits available to the guest.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Hidden
Do not identify as a KVM virtual machine.
Only affects vCPUs with x86-64 architecture.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -HvVendorId
The Hyper-V vendor ID.
Some drivers or programs inside Windows guests need a specific ID.

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

### -Level
Maximum input value for the basic CPUID leaves the guest can query - that is the vendor (leaf 0), family/model/stepping and feature bits (leaf 1), cache and topology info (leaves 4 and B), and so on.
Higher-numbered leaves are hidden.
Setting '30' is a common workaround for Hyper-V boot failures on Windows guests running on recent Intel hosts.
Only applies when the vCPU architecture is x86_64.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -PhysBits
The physical memory address bits that are reported to the guest OS.
Should be smaller or equal to the host's.
Set to 'host' to use value from host CPU, but note that doing so will break live migration to CPUs with other values.

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

### -ReportedModel
CPU model and vendor to report to the guest.
Must be a QEMU/KVM supported model.
Only valid for custom CPU model definitions, default models will always report themselves to the guest OS.
Enum: 486,a64fx,athlon,Broadwell,Broadwell-IBRS,Broadwell-noTSX,Broadwell-noTSX-IBRS,Cascadelake-Server,Cascadelake-Server-noTSX,Cascadelake-Server-v2,Cascadelake-Server-v4,Cascadelake-Server-v5,ClearwaterForest,ClearwaterForest-v2,ClearwaterForest-v3,Conroe,Cooperlake,Cooperlake-v2,core2duo,coreduo,cortex-a35,cortex-a53,cortex-a55,cortex-a57,cortex-a710,cortex-a72,cortex-a76,cortex-a78ae,DiamondRapids,EPYC,EPYC-Genoa,EPYC-Genoa-v2,EPYC-IBPB,EPYC-Milan,EPYC-Milan-v2,EPYC-Milan-v3,EPYC-Rome,EPYC-Rome-v2,EPYC-Rome-v3,EPYC-Rome-v4,EPYC-Rome-v5,EPYC-Turin,EPYC-v3,EPYC-v4,EPYC-v5,GraniteRapids,GraniteRapids-v2,GraniteRapids-v3,GraniteRapids-v4,GraniteRapids-v5,Haswell,Haswell-IBRS,Haswell-noTSX,Haswell-noTSX-IBRS,host,Icelake-Client,Icelake-Client-noTSX,Icelake-Server,Icelake-Server-noTSX,Icelake-Server-v3,Icelake-Server-v4,Icelake-Server-v5,Icelake-Server-v6,Icelake-Server-v7,IvyBridge,IvyBridge-IBRS,KnightsMill,kvm32,kvm64,max,Nehalem,Nehalem-IBRS,neoverse-n1,neoverse-n2,neoverse-v1,Opteron_G1,Opteron_G2,Opteron_G3,Opteron_G4,Opteron_G5,Penryn,pentium,pentium2,pentium3,phenom,qemu32,qemu64,SandyBridge,SandyBridge-IBRS,SapphireRapids,SapphireRapids-v2,SapphireRapids-v3,SapphireRapids-v4,SapphireRapids-v5,SapphireRapids-v6,SierraForest,SierraForest-v2,SierraForest-v3,SierraForest-v4,SierraForest-v5,Skylake-Client,Skylake-Client-IBRS,Skylake-Client-noTSX-IBRS,Skylake-Client-v4,Skylake-Server,Skylake-Server-IBRS,Skylake-Server-noTSX-IBRS,Skylake-Server-v4,Skylake-Server-v5,Westmere,Westmere-IBRS

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 9
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
