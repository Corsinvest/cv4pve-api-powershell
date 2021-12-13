# This file is part of the cv4pve-api-powershell https://github.com/Corsinvest/cv4pve-api-powershell,
#
# This source file is available under two different licenses:
# - GNU General Public License version 3 (GPLv3)
# - Corsinvest Enterprise License (CEL)
# Full copyright and license information is available in
# LICENSE.md which is distributed with this source code.
#
# Copyright (C) 2020 Corsinvest Srl	GPLv3 and CEL

remove-Module Corsinvest.ProxmoxVE.Api -Force
Import-Module .\Corsinvest.ProxmoxVE.Api\Corsinvest.ProxmoxVE.Api.psm1 -Verbose
