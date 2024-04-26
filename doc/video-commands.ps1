# SPDX-FileCopyrightText: Copyright Corsinvest Srl
# SPDX-License-Identifier: GPL-3.0-only

#TP-START,SM0
#    ______                _                      __
#   / ____/___  __________(_)___ _   _____  _____/ /_
#  / /   / __ \/ ___/ ___/ / __ \ | / / _ \/ ___/ __/
# / /___/ /_/ / /  (__  ) / / / / |/ /  __(__  ) /_
# \____/\____/_/  /____/_/_/ /_/|___/\___/____/\__/
#
# PowerShell for Proxmox VE         (Made in Italy)
#
# cv4pve-api-powershell is a part of suite cv4pve.
# For more information visit https://www.corsinvest.it/cv4pve

#TP-END

#TP-START
# Today we will see how to use PowerShell commands for Proxmox VE

# Github https://github.com/Corsinvest/cv4pve-api-powershell
# Documentation https://raw.githack.com/Corsinvest/cv4pve-api-powershell/master/doc/index.html

# Install module from gallery https://www.powershellgallery.com/packages/Corsinvest.ProxmoxVE.Api

Install-Module -Name Corsinvest.ProxmoxVE.Api -Force
#TP-END

#TP-START

# Connect to node/cluster using Credential or ApiToken
$ticket = Connect-PveCluster -HostsAndPorts 192.168.0.1:8006,192.168.0.1 -SkipCertificateCheck -ApiToken $ENV:PveApiToken
#TP-END

#TP-START

# The global ticker are saved in $Global:PveTicketLast
# For commands if the -PveTicket parameter is not specified, $Global:PveTicketLast will be used

$ret = Get-PveVersion

# $ret is a class of type PveResponse
#TP-END

Start-Sleep -Milliseconds 500

#TP-START
$ret
#TP-END

Start-Sleep -Milliseconds 500

#TP-START
$ret.ToData()
#TP-END

Start-Sleep -Milliseconds 500

#TP-START
$ret.ToTable()
#TP-END

Start-Sleep -Milliseconds 1000

#TP-START
# Get nodes of cluster
(Get-PveNodes).ToData() | Select-Object -Property type,node,uptime,status,maxcpu,maxdisk | Out-Default
#TP-END

Start-Sleep -Milliseconds 500

#TP-START
# Special command get vm from id or name
Get-PveVm -VmIdOrName 100
#TP-END

#TP-START
# Special command get vm from id or name
Get-PveVm -VmIdOrName 100
#TP-END

#TP-START
# Get snapshots from Vm 102
(Get-PveNodesQemuSnapshot -Node cc02 -Vmid 102).ToTable()
#TP-END

#TP-START
# Get snapshots from Vm 102
(Get-PveVm -VmIdOrName 102 | Get-PveNodesQemuSnapshot).ToTable()
#TP-END

#TP-START
# For build documentation use command Build-PveDocumentation
#TP-END
