# This file is part of the cv4pve-api-pwsh https://github.com/Corsinvest/cv4pve-api-pwsh,
#
# This source file is available under two different licenses:
# - GNU General Public License version 3 (GPLv3)
# - Corsinvest Enterprise License (CEL)
# Full copyright and license information is available in
# LICENSE.md which is distributed with this source code.
#
# Copyright (C) 2020 Corsinvest Srl	GPLv3 and CEL

function Progress([string]$text)
{
    Write-Progress -Activity $text -CurrentOperation "Completed $($progress) of $totProgress." -PercentComplete $(($progress / $totProgress) * 100)
}

function FixString ([string]$string) {
    if ($null -eq $string) { return $string}
    return $string.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace([Environment]::NewLine, '').Trim()
}

@'
<!--
 This file is part of the cv4pve-api-pwsh https://github.com/Corsinvest/cv4pve-api-pwsh,

 This source file is available under two different licenses:
 - GNU General Public License version 3 (GPLv3)
 - Corsinvest Enterprise License (CEL)
 Full copyright and license information is available in
 LICENSE.md which is distributed with this source code.

 Copyright (C) 2020 Corsinvest Srl	GPLv3 and CEL
-->

<head>
    <meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1, shrink-to-fit=no'>

    <link rel='stylesheet'
          href='https://stackpath.bootstrapcdn.com/bootstrap/4.5.0/css/bootstrap.min.css'
          integrity='sha384-9aIt2nRpC12Uk9gS9baDl411NQApFmC26EwAOH8WgZl5MYYxFfc+NcPb1dKGj7Sk'
          crossorigin='anonymous'>
    <link rel="stylesheet"
          href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.1.1/styles/default.min.css" />

    <title>cv4pve-api-pwsh PowerShell for Proxmox VE</title>
    <meta name='generator' content='cv4pve-api-pwsh - Build-PveDocumentation'>
    <style>
        body { font-size: .875rem; }

        .feather {
            width: 16px;
            height: 16px;
            vertical-align: text-bottom;
        }

        /* Sidebar */

        .sidebar {
            position: fixed;
            top: 0;
            bottom: 0;
            left: 0;
            z-index: 100;
            /* Behind the navbar */
            padding: 48px 0 0;
            /* Height of navbar */
            box-shadow: inset -1px 0 0 rgba(0, 0, 0, .1);
        }

        @media (max-width: 767.98px) {
            .sidebar { top: 5rem; }
        }

        .sidebar-sticky {
            position: relative;
            top: 0;
            height: calc(100vh - 48px - 50px);
            padding-top: .5rem;
            overflow-x: hidden;
            overflow-y: auto;
            /* Scrollable contents if viewport is shorter than content. */
        }

        .sidebar .nav-link {
            font-weight: 500;
            color: #333;
        }

        .sidebar .nav-link .feather {
            margin-right: 4px;
            color: #999;
        }

        .sidebar .nav-link.active { color: #007bff; }

        .sidebar .nav-link:hover .feather,
        .sidebar .nav-link.active .feather { color: inherit; }

        .sidebar-heading {
            font-size: .75rem;
            text-transform: uppercase;
        }

        /*  Navbar */

        .navbar-brand {
            padding-top: .75rem;
            padding-bottom: .75rem;
            font-size: 1rem;
            background-color: rgba(0, 0, 0, .25);
            box-shadow: inset -1px 0 0 rgba(0, 0, 0, .25);
        }

        .container-fluid { padding-bottom: 50px; }

        .main-data-hidden { visibility: hidden; }
    </style>
</head>

<body>
    <nav class='navbar navbar-dark sticky-top bg-primary flex-md-nowrap p-0 shadow'>
        <a class='navbar-brand col-md-3 col-lg-2 mr-0 px-3' href='#'>Documentation cv4pve-api-pwsh</a>
        <ul class='navbar-nav px-1'> </ul>
        <input class='form-control form-control-dark w-100' type='text' id='navSearch' placeholder='Search'
            aria-label='Search'>
        <ul class='navbar-nav px-1'> </ul>
    </nav>

    <div class='container-fluid'>
        <div class='row'>
            <nav id='sidebarMenu' class='col-md-3 col-lg-2 d-md-block bg-light sidebar collapse'>
                <div class='sidebar-sticky pt-3'>
                    <ul class='nav flex-column' id='lstNav'>
                        <li class='nav-item'><a class='nav-link' href='#GettingStarted'>Getting Started</a></li>
'@
                    $progress = 0
                    $data | ForEach-Object {
                        $progress++
                        Progress "Create html link $($_.Name)"
                        "<li class='nav-item'><a class='nav-link' href='#$($_.Name)'>$($_.Name)</a></li>"
                    }
@'
                    </ul>
                </div>
            </nav>

            <main role='main' id='main-data' class='col-md-9 ml-sm-auto col-lg-10 px-md-4 main-data-hidden'>
            <div id='GettingStarted' class="toggle_container">
            <div class="page-header">
                <h2> Getting Started </h2>
            </div>

            <p>
                This module allows to manage Proxmox VE using the <a
                    href='https://pve.proxmox.com/wiki/Proxmox_VE_API' target='_blank'>API</a>.
                </p>

            <p>
                For more information about project on <a href='https://github.com/Corsinvest/cv4pve-api-pwsh' target='_blank'>cv4pve-api-pwsh</a> <br>
                For more information about suite <a href='https://www.cv4pve-tools.com' target='_blank'>cv4pve-tools</a>
            </p>

            <div>
                <h3>Connect to cluster</h3>
            </div>
            <div class="panel panel-default">
                <div class='panel-body'>
                    <p>
                        For connection use the function <a href="#Connect-PveCluster">Connect-PveCluster</a>.
                        This function generate a Ticket object that refer a PveTicket class.<br>
                        The first connection saved ticket data in the variable <strong>$Global:PveTicketLast</strong>.
                        In the various functions, the <strong>-PveTicket</strong> parameter is the connection reference
                        ticket.
                        If not specified will be used <strong>$Global:PveTicketLast</strong>.
                    </p>
                </div>
            </div>

            <div>
                <h3>PveTicket Class</h3>
            </div>
            <div class="panel panel-default">
                <div class='panel-body'>
                    <p>
                        This class contain data after connection and login <a href="#Connect-PveCluster">Connect-PveCluster</a>
                    </p>

                    <pre>
                        <code class="powershell">
class PveTicket {
    [string] $HostName = ''
    [int] $Port = 8006
    [bool] $SkipCertificateCheck = $true
    [string] $Ticket = ''
    [string] $CSRFPreventionToken = ''
    [string] $ApiToken = ''
}
                        </code>
                    </pre>

                </div>
            </div>

            <div>
                <h3>PveResponse Class</h3>
            </div>
            <div class="panel panel-default">
                <div class='panel-body'>
                    <p>
                        This class contain data after execution any command
                    </p>

                    <pre>
                        <code class="powershell">
class PveResponse {
    #Contain real response of Proxmox VE
    #Is converted in object Json response
    [PSCustomObject] $Response
    [int] $StatusCode = 200
    [string] $ReasonPhrase
    [bool] $IsSuccessStatusCode = $true
    [string] $RequestResource
    [hashtable] $Parameters
    [string] $Method
    [string] $ResponseType

    [bool] ResponseInError() { return $null -ne $this.Response.error }
    [PSCustomObject] ToTable() { return $this.Response.data | Format-Table }
    [PSCustomObject] GetData() { return $this.Response.data }
    [void] ToCsv([string] $filename) { $this.Response.data | Export-Csv $filename }
}
                        </code>
                    </pre>
                </div>
            </div>

            <div>
                <h3>Usage</h3>
            </div>
            <div class="panel panel-default">
                <div class='panel-body'>
                    <p>
                        Example Connect and get version
                    </p>

                    <pre>
                        <code class="powershell">
#Connection to cluster user and password
PS /home/frank> Connect-PveCluster -HostsAndPorts 192.168.190.191:8006,192.168.190.192 -SkipCertificateCheck
PowerShell credential request
Proxmox VE Username and password, username formatted as user@pam, user@pve, user@yourdomain or user (default domain pam).
User: test
Password for user test: ****

#return Ticket, default set $Global:PveTicketLast
#this is useful when connections to multiple clusters are needed use parameter -SkipRefreshPveTicketLast
HostName             : 192.168.190.191
Port                 : 8006
SkipCertificateCheck : True
Ticket               : PVE:test@pam:5EFF3CCA::iXhSNb5NTgNUYznf93mBOhj8pqYvAXoecKBHCXa3coYwBWjsWO/x8TO1gIDX0yz9nfHuvY3alJ0+Ew5AouOTZlZl3NODO9Cp4Hl87qnzhsz4wvoYEzvS1NUOTBekt+yAa68jdbhP
                        OzhOd8ozEEQIK7Fw2lOSa0qBFUTZRoMtnCnlsjk/Nn3kNEnZrkHXRGm46fA+asprvr0nslLxJgPGh94Xxd6jpNDj+xJnp9u6W3PxiAojM9g7IRurbp7ZCJvAgHbA9FqxibpgjaVm4NCd8LdkLDgCROxgYCjI3eR
                        gjkDvu1P7lLjK9JxSzqnCWWD739DT3P3bW+Ac3SyVqTf8sw==
CSRFPreventionToken  : 5EFF3CCA:Cu0NuFiL6CkhFdha2V+HHigMQPk

#Connection to cluster using Api Token
PS /home/frank> Connect-PveCluster -HostsAndPorts 192.168.190.191:8006,192.168.190.192 -SkipCertificateCheck -ApiToken root@pam!qqqqqq=8a8c1cd4-d373-43f1-b366-05ce4cb8061f
HostName             : 192.168.190.191
Port                 : 8006
SkipCertificateCheck : True
Ticket               :
CSRFPreventionToken  :
ApiToken             : root@pam!qqqqqq=8a8c1cd4-d373-43f1-b366-05ce4cb8061f

#For disable output call Connect-PveCluster > $null

#Get version
PS /home/frank> $ret = Get-PveVersion

#$ret return a class PveResponse

#Show data
PS /home/frank> $ret.Response.data
repoid   release keyboard version
------   ------- -------- -------
d0ec33c6 15      it       5.4

#Show data 2
PS /home/frank> $ret.ToTable()
repoid   release keyboard version
------   ------- -------- -------
d0ec33c6 15      it       5.4

# Get snapshots of vm
PS /home/frank> (Get-PveNodesQemuSnapshot -Node pve1 -Vmid 100).ToTable()

vmstate name                         parent                       description       snaptime
------- ----                         ------                       -----------       --------
      0 autowin10service200221183059 autowin10service200220183012 cv4pve-autosnap 1582306261
      0 autowin10service200220183012 autowin10service200219183012 cv4pve-autosnap 1582219813
      0 autowin10service200224183012 autowin10service200223183014 cv4pve-autosnap 1582565413
      0 autowin10service200223183014 autowin10service200222183019 cv4pve-autosnap 1582479015
      0 autowin10service200215183012 autowin10service200214183012 cv4pve-autosnap 1581787814
      0 autowin10service200216183017 autowin10service200215183012 cv4pve-autosnap 1581874219
      0 autowin10service200218183010 autowin10service200216183017 cv4pve-autosnap 1582047011
      0 autowin10service200219183012 autowin10service200218183010 cv4pve-autosnap 1582133413
      0 autowin10service200214183012                              cv4pve-autosnap 1581701413
      0 autowin10service200222183019 autowin10service200221183059 cv4pve-autosnap 1582392621
        current                      autowin10service200224183012 You are here!
```

#Other method
PS /home/frank> (Find-PveVM -VmIdOrName 100 | Get-PveNodesQemuSnapshot).ToTable()

vmstate name                         parent                       description       snaptime
------- ----                         ------                       -----------       --------
      0 autowin10service200221183059 autowin10service200220183012 cv4pve-autosnap 1582306261
      0 autowin10service200220183012 autowin10service200219183012 cv4pve-autosnap 1582219813
      0 autowin10service200224183012 autowin10service200223183014 cv4pve-autosnap 1582565413
      0 autowin10service200223183014 autowin10service200222183019 cv4pve-autosnap 1582479015
      0 autowin10service200215183012 autowin10service200214183012 cv4pve-autosnap 1581787814
      0 autowin10service200216183017 autowin10service200215183012 cv4pve-autosnap 1581874219
      0 autowin10service200218183010 autowin10service200216183017 cv4pve-autosnap 1582047011
      0 autowin10service200219183012 autowin10service200218183010 cv4pve-autosnap 1582133413
      0 autowin10service200214183012                              cv4pve-autosnap 1581701413
      0 autowin10service200222183019 autowin10service200221183059 cv4pve-autosnap 1582392621
        current                      autowin10service200224183012 You are here!
                        </code>
                    </pre>
                </div>
            </div>
        </div>
'@
        $progress = 0
        $data | ForEach-Object {
            $progress++
            Progress "Create html data $($_.Name)"
@"
        <div id=`"$(FixString($_.Name))`" class="toggle_container">
            <div class="page-header">
                <h2> $(FixString($_.Name)) </h2>
"@
            $synopsis = FixString($_.synopsis)
            if(!($synopsis).StartsWith($(FixString($_.Name)))){
                "<p>$synopsis</p>
                <p>$(FixString(($_.Description | Out-String).Trim()) $true)</p>"
            }
@'
            </div>
'@
            if (!($_.alias.Length -eq 0)) {
@'
            <div class='panel panel-default'>
                <div class='panel-heading'>
                    <h3 class='panel-title'> Aliases </h3>
                </div>
                <div class='panel-body'>
                    <ul>
'@
                    $_.alias | ForEach-Object { "<li>$($_.Name)</li>" }
@'
                    </ul>
                </div>
            </div>
'@
            }

            $syntax = FixString($_.syntax | Out-String).Trim()
            if (!$syntax.Contains('syntaxItem')) {
                "<div>
                    <h3> Syntax </h3>
                </div>
                <div class='panel panel-default'>
                    <div class='panel-body'>
                        <pre>
                            <code class='powershell'>$syntax</code>
                        </pre>
                    </div>
                </div>"
            }

            if($_.parameters){
@'
            <div>
                <h3> Parameters </h3>
                <table class="table table-striped table-bordered table-condensed visible-on">
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th class="visible-lg visible-md">Alias</th>
                            <th>Description</th>
                            <th class="visible-lg visible-md">Required?</th>
                            <th class="visible-lg">Pipeline Input</th>
                            <th class="visible-lg">Default Value</th>
                        </tr>
                    </thead>
                    <tbody>
'@
                $_.parameters.parameter | ForEach-Object {
                        "<tr>
                            <td><nobr>-$(FixString($_.Name))</nobr></td>
                            <td class='visible-lg visible-md'>$(FixString($_.Aliases))</td>
                            <td>$(FixString(($_.Description  | out-string).Trim()) $true)</td>
                            <td class='visible-lg visible-md'>$(FixString($_.Required))</td>
                            <td class='visible-lg'>$(FixString($_.PipelineInput))</td>
                            <td class='visible-lg'>$(FixString($_.DefaultValue))</td>
                        </tr>"
                }
@'
                    </tbody>
                </table>
            </div>
'@
            }

            $inputTypes = $(FixString($_.inputTypes  | out-string))
            if ($inputTypes.Length -gt 0 -and -not $inputTypes.Contains('inputType')) {
                "<div>
                    <h3> Inputs </h3>
                    <p>The input type is the type of the objects that you can pipe to the cmdlet.</p>
                    <ul><li>$inputTypes</li></ul>
                </div>"
            }

            $returnValues = $(FixString($_.returnValues  | out-string))
            if ($returnValues.Length -gt 0 -and -not $returnValues.StartsWith("returnValue")) {
                "<div>
                    <h3> Outputs </h3>
                    <p>The output type is the type of the objects that the cmdlet emits.</p>
                    <ul><li>$returnValues</li></ul>
                </div>"
            }

            $notes = $(FixString($_.alertSet  | out-string))
            if ($notes.Trim().Length -gt 0) {
                "<div class='panel panel-default'>
                    <div class='panel-heading'>
                        <h3 class='panel-title'> Note </h3>
                    </div>
                    <div class='panel-body'>$notes</div>
                </div>"
            }

            if(($_.examples | Out-String).Trim().Length -gt 0) {
@'
            <div>
                <h3> Examples </h3>
            </div>
            <div class='panel panel-default'>
                <div class='panel-body'>
'@
                $_.examples.example | ForEach-Object {
                    "<strong>$(FixString($_.title.Trim(('-',' '))))</strong>
                        <pre>
                            <code class='powershell'>$(FixString($_.code | Out-String).Trim())</code>
                        </pre>
                        <div>$(FixString($_.remarks | Out-String).Trim())</div>"
                }
@'
                </div>
            </div>
'@
            }

            if(($_.relatedLinks | Out-String).Trim().Length -gt 0) {
@'
            <div>
                <h3> Links </h3>
                <div>
                    <ul>
'@
                    $_.links | ForEach-Object {
                        "<li class='$($_.cssClass)'><a href='$($_.link)' target='$($_.target)'>$($_.name)</a></li>"
                    }
@'
                    </ul>
                </div>
            </div>
'@
            }
@'
    </div>
'@
        }
@'
            </main>
        </div>

        <div class='fixed-bottom text-white bg-dark'>
                <a href='https://github.com/Corsinvest/cv4pve-api-pwsh' target='_blank'>cv4pve-api-pwsh</a> - PowerShell for Proxmox VE by Corsinvest Srl <br>
                This is a part of suite <a href='https://www.cv4pve-tools.com' target='_blank'>cv4pve-tools</a>
        </div>
    </div>

    <script src='https://code.jquery.com/jquery-3.5.1.slim.min.js'
        integrity='sha384-DfXdz2htPH0lsSSs5nCTpuj/zy4C+OGpamoFVy38MVBnE+IbbVYUew+OrCXaRkfj'
        crossorigin='anonymous'></script>
    <script src='https://cdn.jsdelivr.net/npm/popper.js@1.16.0/dist/umd/popper.min.js'
        integrity='sha384-Q6E9RHvbIyZFJoft+2mJbHaEWldlvI9IOYy5n3zV9zzTtmI3UksdQRVvoxMfooAo'
        crossorigin='anonymous'></script>
    <script src='https://stackpath.bootstrapcdn.com/bootstrap/4.5.0/js/bootstrap.min.js'
        integrity='sha384-OgVRvuATP1z7JjHLkuOU7Xw704+h835Lr+6QL9UvYjZE3Ipu6Tp75j7Bh/kR0JKI'
        crossorigin='anonymous'></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.1.1/highlight.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.1.1/languages/powershell.min.js"></script>

    <script>
        document.addEventListener('DOMContentLoaded', (event) => {
            document.querySelectorAll('pre code').forEach((block) => {
                $('.toggle_container').hide();
                $('#GettingStarted').toggle('fast');

                hljs.highlightBlock(block);

                $('#main-data').removeClass('main-data-hidden');
            });
        });

        $(document).ready(function () {
            $('#navSearch').on('keyup', function () {
                var value = $(this).val().toLowerCase();
                $('#lstNav li').filter(function () {
                    $(this).toggle($(this).text().toLowerCase().indexOf(value) > -1)
                });
            });

            $('.nav-item a').click(function () {
                $('.toggle_container').hide();
                var elem = $(this).prop('hash');
                $(elem).toggle('fast');
                window.scrollTo(0, 0);
            });
        });
    </script>
</body>
</html>
'@
