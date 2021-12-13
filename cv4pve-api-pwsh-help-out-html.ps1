# This file is part of the cv4pve-api-powershell https://github.com/Corsinvest/cv4pve-api-powershell,
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
 This file is part of the cv4pve-api-powershell https://github.com/Corsinvest/cv4pve-api-powershell,

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

    <title>cv4pve-api-powershell PowerShell for Proxmox VE</title>
    <meta name='generator' content='cv4pve-api-powershell - Build-PveDocumentation'>
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
        <a class='navbar-brand col-md-3 col-lg-2 mr-0 px-3' href='#'>Documentation cv4pve-api-powershell</a>
        <ul class='navbar-nav px-1'> </ul>
        <div class='input-group'>
            <div class='input-group-prepend'>
                <div class='input-group-text'>
                  <input id='searchAll' type='checkbox' aria-label='Checkbox for following text input'>&nbsp;Full text
                </div>
            </div>

            <input class='form-control form-control-dark w-1001' type='text' id='navSearch' placeholder='Search'
                aria-label='Search'>
        </div>
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
            </div>
'@
            (ConvertFrom-Markdown -InputObject (Invoke-WebRequest "https://raw.githubusercontent.com/Corsinvest/cv4pve-api-powershell/master/README.md").Content ).Html
@'
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
                <p class='searchable'>$(FixString(($_.Description | Out-String).Trim()) $true)</p>"
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
                    $_.alias | ForEach-Object { "<li class='searchable'>$($_.Name)</li>" }
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
                        <code class='powershell'>$syntax</code>
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
                            <td class='searchable'><nobr>-$(FixString($_.Name))</nobr></td>
                            <td class='visible-lg visible-md searchable'>$(FixString($_.Aliases))</td>
                            <td class='searchable'>$(FixString(($_.Description  | out-string).Trim()) $true)</td>
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
                        <code class='powershell'>$(FixString($_.code | Out-String).Trim())</code>
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
                <a href='https://github.com/Corsinvest/cv4pve-api-powershell' target='_blank'>cv4pve-api-powershell</a> - Proxmox VE Client API PowerShell Module by Corsinvest Srl <br>
                This is a part of suite <a href='https://www.cv4pve-tools.com' target='_blank'>cv4pve-tools</a>
'@
                " - Version $((Get-Module Corsinvest.ProxmoxVE.Api).Version.ToString())"
@'
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
            document.querySelectorAll('code').forEach((block) => {
                hljs.highlightBlock(block);
            });

            $('.toggle_container').hide();
            $('#GettingStarted').toggle('fast');
            $('#main-data').removeClass('main-data-hidden');
        });

        $(document).ready(function () {
            $('#navSearch').on('keyup', function () {
                var value = $(this).val().toLowerCase();
                $('#lstNav li').filter(function () {
                    $(this).toggle($(this).text().toLowerCase().indexOf(value) > -1)
                });

                if ($('#searchAll:checked').val() == 'on') {
                    $('.searchable').filter(function () {
                        if ($(this).text().toLowerCase().indexOf(value) > -1) {
                            var id = $(this).parents().closest(".toggle_container")[0].id;
                            $($($('a[href="#' + id + '"]')[0]).parent()[0]).toggle(true)
                        }
                    });
                }
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
