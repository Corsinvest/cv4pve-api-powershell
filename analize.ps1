# SPDX-FileCopyrightText: Copyright Corsinvest Srl
# SPDX-License-Identifier: GPL-3.0-only

Import-Module PSScriptAnalyzer

Get-ChildItem -Path Corsinvest.ProxmoxVE.Api -Filter "*.psm1" -Recurse | Invoke-ScriptAnalyzer -ExcludeRule PSUseSingularNouns
