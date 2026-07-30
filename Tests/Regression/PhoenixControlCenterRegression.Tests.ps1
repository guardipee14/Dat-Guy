BeforeAll {

    $projectRoot = (
        Resolve-Path (
            Join-Path `
                $PSScriptRoot `
                '..\..'
        )
    ).Path

    $controlCenterPowerShellFiles = @(
        Get-ChildItem `
            -LiteralPath (
                Join-Path `
                    $projectRoot `
                    'Private\ControlCenter'
            ) `
            -Filter '*.ps1' `
            -File

        Get-Item `
            -LiteralPath @(
                (
                    Join-Path `
                        $projectRoot `
                        'Private\Drivers\Invoke-PhoenixWindowsUpdateDriver.ps1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Private\Drivers\Repair-PhoenixDriver.ps1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Private\Drivers\Remove-PhoenixDriver.ps1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Private\Drivers\Update-PhoenixDriver.ps1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Public\Open-Phoenix.ps1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Tools\Start-PhoenixControlCenter.ps1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Tools\Invoke-PhoenixControlCenterWorker.ps1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Tools\Open-PhoenixThemeStudio.ps1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Public\Get-PhoenixTheme.ps1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Public\Install-PhoenixTheme.ps1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Public\Export-PhoenixTheme.ps1'
                )
            )
    )
}

Describe 'Phoenix Control Center regressions' -Tag @(
    'Regression'
    'ControlCenter'
) {

    It 'keeps all control-center PowerShell files syntactically valid' {

        $allErrors =
            [System.Collections.Generic.List[object]]::new()

        foreach ($file in $controlCenterPowerShellFiles) {

            $tokens = $null
            $parseErrors = $null

            [System.Management.Automation.Language.Parser]::ParseFile(
                $file.FullName,
                [ref]$tokens,
                [ref]$parseErrors
            ) |
                Out-Null

            foreach ($parseError in @($parseErrors)) {
                $allErrors.Add($parseError)
            }
        }

        $allErrors.Count |
            Should-Be 0
    }

    It 'loads and exports Open-Phoenix' {

        $moduleSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Phoenix.psm1'
                ) `
                -Raw

        $manifest =
            Import-PowerShellDataFile `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Phoenix.psd1'
                )

        $moduleSource |
            Should-MatchString (
                [regex]::Escape(
                    "'Private\ControlCenter'"
                )
            )

        $moduleSource |
            Should-MatchString (
                [regex]::Escape(
                    "'Open-Phoenix'"
                )
            )

        @($manifest.FunctionsToExport) |
            Should-ContainCollection 'Open-Phoenix'
    }

    It 'provides automatic, desktop, and console launch modes' {

        $launcherSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Phoenix.cmd'
                ) `
                -Raw

        $desktopLauncher =
            Join-Path `
                $projectRoot `
                'Phoenix-Desktop.cmd'

        $consoleLauncher =
            Join-Path `
                $projectRoot `
                'Phoenix-Console.cmd'

        $launcherSource |
            Should-MatchString 'Desktop'

        $launcherSource |
            Should-MatchString 'Console'

        $launcherSource |
            Should-MatchString 'Auto'

        $launcherSource |
            Should-MatchString '\-STA'

        Test-Path `
            -LiteralPath $desktopLauncher |
            Should-BeTrue

        Test-Path `
            -LiteralPath $consoleLauncher |
            Should-BeTrue
    }

    It 'keeps the desktop layout valid and exposes every required grid' {

        [xml]$xaml =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\PhoenixControlCenter.xaml'
                ) `
                -Raw

        $xaml.DocumentElement.GetAttribute(
            'Title'
        ) |
            Should-Be 'Phoenix Control Center'

        $xaml.OuterXml |
            Should-MatchString 'ApplicationGrid'

        $xaml.OuterXml |
            Should-MatchString 'SearchResultGrid'

        $xaml.OuterXml |
            Should-MatchString 'DriverGrid'

        $xaml.OuterXml |
            Should-MatchString 'DriverUpdateGrid'
    }

    It 'provides a modern customizable shell and editable dashboard' {

        [string]$xamlSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\PhoenixControlCenter.xaml'
                ) `
                -Raw

        [string]$desktopSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Show-PhoenixDesktop.ps1'
                ) `
                -Raw

        $xamlSource.Contains(
            'NavigationColumn'
        ) |
            Should-BeTrue

        $xamlSource.Contains(
            'CustomizePage'
        ) |
            Should-BeTrue

        $xamlSource.Contains(
            'DashboardCanvas'
        ) |
            Should-BeTrue

        $xamlSource.Contains(
            'TileResizeThumbStyle'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            'Add_DragDelta'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            'Save-PhoenixUiConfiguration'
        ) |
            Should-BeTrue
    }

    It 'ships a persistent user-editable appearance and tile configuration' {

        [string]$uiConfigurationPath =
            Join-Path `
                $projectRoot `
                'Config\Phoenix.UI.json'

        Test-Path `
            -LiteralPath $uiConfigurationPath |
            Should-BeTrue

        $uiConfiguration =
            Get-Content `
                -LiteralPath $uiConfigurationPath `
                -Raw |
                ConvertFrom-Json

        (
            [string]$uiConfiguration.Appearance.Accent -match
            '^#[0-9A-Fa-f]{6}$'
        ) |
            Should-BeTrue

        (
            @($uiConfiguration.Dashboard.Tiles).Count -ge
            5
        ) |
            Should-BeTrue
    }

    It 'falls back to total physical memory when module rows are unavailable' {

        [string]$inventorySource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Get-PhoenixControlCenterInventory.ps1'
                ) `
                -Raw

        $inventorySource.Contains(
            'TotalPhysicalMemory'
        ) |
            Should-BeTrue
    }

    It 'keeps long operations off the WPF interface thread' {

        [string]$desktopSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Show-PhoenixDesktop.ps1'
                ) `
                -Raw

        [string]$workerSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Tools\Invoke-PhoenixControlCenterWorker.ps1'
                ) `
                -Raw

        $desktopSource.Contains(
            '[System.Diagnostics.ProcessStartInfo]::new()'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            '[System.Windows.Threading.DispatcherTimer]::new()'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            'CancelOperationButton'
        ) |
            Should-BeTrue

        $workerSource.Contains(
            "'PackageAction'"
        ) |
            Should-BeTrue

        $workerSource.Contains(
            "'DriverAction'"
        ) |
            Should-BeTrue
    }

    It 'does not synchronously invoke the dispatcher from timer callbacks' {

        [string]$desktopSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Show-PhoenixDesktop.ps1'
                ) `
                -Raw

        $desktopSource.Contains(
            '$window.Dispatcher.Invoke'
        ) |
            Should-BeFalse

        $desktopSource.Contains(
            '[System.Windows.Threading.DispatcherTimer]::new()'
        ) |
            Should-BeTrue
    }

    It 'uses the atomic worker result instead of polling process state' {

        [string]$desktopSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Show-PhoenixDesktop.ps1'
                ) `
                -Raw

        $desktopSource.Contains(
            '$operation.Process.HasExited'
        ) |
            Should-BeFalse

        $desktopSource.Contains(
            '-LiteralPath $operation.ResultPath'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            'Control Center operation callback failed:'
        ) |
            Should-BeTrue
    }

    It 'pins timer dependencies into the operation invocation scope' {

        [string]$desktopSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Show-PhoenixDesktop.ps1'
                ) `
                -Raw

        $desktopSource.Contains(
            '$timerState = $state'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            '$timerSetOperationUi = $setOperationUi'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            '& $timerSetOperationUi'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            '$timerState.ActiveOperation'
        ) |
            Should-BeTrue
    }

    It 'invokes the application-update callback as a script block' {

        [string]$desktopSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Show-PhoenixDesktop.ps1'
                ) `
                -Raw

        $desktopSource.Contains(
            '& $state['
        ) |
            Should-BeFalse

        $desktopSource.Contains(
            '$refreshUpdatesCommand -is [scriptblock]'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            '& $refreshUpdatesCommand'
        ) |
            Should-BeTrue
    }

    It 'shows application update versions and publisher metadata' {

        [string]$xamlSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\PhoenixControlCenter.xaml'
                ) `
                -Raw

        [string]$updateSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Get-PhoenixControlCenterApplicationUpdate.ps1'
                ) `
                -Raw

        $xamlSource.Contains(
            'AvailableVersion'
        ) |
            Should-BeTrue

        $xamlSource.Contains(
            'ApplicationDetailsText'
        ) |
            Should-BeTrue

        $updateSource.Contains(
            '--upgrade-available'
        ) |
            Should-BeTrue

        $updateSource.Contains(
            'outdated'
        ) |
            Should-BeTrue
    }

    It 'includes driver descriptions release notes and support links' {

        [string]$driverSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\Drivers\Invoke-PhoenixWindowsUpdateDriver.ps1'
                ) `
                -Raw

        foreach (
            $metadataName in @(
                'Description'
                'ReleaseNotes'
                'SupportUrl'
                'MoreInfoUrls'
                'KBArticleIds'
                'PublishedAtUtc'
            )
        ) {
            $driverSource.Contains(
                $metadataName
            ) |
                Should-BeTrue
        }
    }

    It 'provides selected application and driver uninstall actions' {

        [string]$xamlSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\PhoenixControlCenter.xaml'
                ) `
                -Raw

        [string]$desktopSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Show-PhoenixDesktop.ps1'
                ) `
                -Raw

        [string]$packageActionSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Invoke-PhoenixControlCenterPackageAction.ps1'
                ) `
                -Raw

        [string]$driverActionSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Invoke-PhoenixControlCenterDriverAction.ps1'
                ) `
                -Raw

        $xamlSource.Contains(
            'UninstallSelectedAppsButton'
        ) |
            Should-BeTrue

        $xamlSource.Contains(
            'UninstallSelectedDriversButton'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            "& `$runApplicationAction 'Uninstall' `$false"
        ) |
            Should-BeTrue

        $packageActionSource.Contains(
            'Remove-PhoenixPackage'
        ) |
            Should-BeTrue

        $packageActionSource.Contains(
            'PHX_CONTROL_CENTER_PACKAGE_PROTECTED'
        ) |
            Should-BeTrue

        $driverActionSource.Contains(
            "'RemoveSelected'"
        ) |
            Should-BeTrue

        $driverActionSource.Contains(
            'Remove-PhoenixDriver'
        ) |
            Should-BeTrue
    }

    It 'registers every statically referenced desktop control' {

        [string]$desktopSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Show-PhoenixDesktop.ps1'
                ) `
                -Raw

        [int]$registryEnd =
            $desktopSource.IndexOf(
                '$getUiConfigurationCommand'
            )

        ($registryEnd -gt 0) |
            Should-BeTrue

        [string]$registrySource =
            $desktopSource.Substring(
                0,
                $registryEnd
            )

        $referencedControlNames = @(
            [regex]::Matches(
                $desktopSource,
                '\$controls\.([A-Za-z][A-Za-z0-9_]*)'
            ) |
                ForEach-Object {
                    $_.Groups[1].Value
                } |
                Sort-Object -Unique
        )

        $unregisteredControlNames = @(
            $referencedControlNames |
                Where-Object {
                    $registrySource -notmatch (
                        "'{0}'" -f
                        [regex]::Escape($_)
                    )
                }
        )

        $unregisteredControlNames.Count |
            Should-Be 0
    }

    It 'keeps selected driver removal constrained and non-forced' {

        [string]$removeDriverSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\Drivers\Remove-PhoenixDriver.ps1'
                ) `
                -Raw

        $removeDriverSource.Contains(
            '/delete-driver'
        ) |
            Should-BeTrue

        $removeDriverSource.Contains(
            '/uninstall'
        ) |
            Should-BeTrue

        $removeDriverSource.Contains(
            '^(?i:oem\d+\.inf)$'
        ) |
            Should-BeTrue

        $removeDriverSource.Contains(
            '/force'
        ) |
            Should-BeFalse

        $removeDriverSource.Contains(
            "[PhoenixPrivilegeLevel]::Administrator"
        ) |
            Should-BeTrue
    }

    It 'ships presets graphical color controls and Theme Studio' {

        $themeFiles = @(
            Get-ChildItem `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Themes\BuiltIn'
                ) `
                -Filter '*.json' `
                -File
        )

        $themeFiles.Count |
            Should-Be 4

        [string]$xamlSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\PhoenixControlCenter.xaml'
                ) `
                -Raw

        $xamlSource.Contains(
            'ThemePresetCombo'
        ) |
            Should-BeTrue

        $xamlSource.Contains(
            'RedColorSlider'
        ) |
            Should-BeTrue

        Test-Path `
            -LiteralPath (
                Join-Path `
                    $projectRoot `
                    'Phoenix-Theme-Studio.cmd'
            ) |
            Should-BeTrue
    }

    It 'keeps color preview conversion independent of module scope' {

        [string]$desktopSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Show-PhoenixDesktop.ps1'
                ) `
                -Raw

        $desktopSource.Contains(
            'ConvertTo-PhoenixUiBrush'
        ) |
            Should-BeFalse

        $desktopSource.Contains(
            '[System.Windows.Media.SolidColorBrush]::new'
        ) |
            Should-BeTrue
    }

    It 'keeps installable themes declarative and size limited' {

        [string]$validationSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Test-PhoenixThemePackage.ps1'
                ) `
                -Raw

        $validationSource.Contains(
            '25MB'
        ) |
            Should-BeTrue

        $validationSource.Contains(
            '128 files'
        ) |
            Should-BeTrue

        $validationSource.Contains(
            "'.ps1'"
        ) |
            Should-BeFalse
    }

    It 'filters Windows Update installation by selected update IDs' {

        $driverSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\Drivers\Invoke-PhoenixWindowsUpdateDriver.ps1'
                ) `
                -Raw

        $driverSource |
            Should-MatchString (
                [regex]::Escape(
                    '[string[]]$UpdateId'
                )
            )

        $driverSource |
            Should-MatchString (
                [regex]::Escape(
                    "'NotSelected'"
                )
            )
    }

    It 'limits bulk driver repair to problem devices' {

        $repairSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\Drivers\Repair-PhoenixDriver.ps1'
                ) `
                -Raw

        $repairSource |
            Should-MatchString 'ConfigManagerErrorCode'

        $repairSource |
            Should-MatchString (
                [regex]::Escape(
                    '[switch]$ProblemOnly'
                )
            )

        $repairSource |
            Should-MatchString (
                [regex]::Escape(
                    "ConfirmImpact = 'High'"
                )
            )
    }
}
