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

    It 'isolates desktop exceptions behind an in-app recovery surface' {

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

        foreach (
            $controlName in @(
                'RecoveryPanel'
                'RecoveryTitleText'
                'RecoveryMessageText'
                'RecoveryRetryButton'
                'RecoveryDetailsButton'
                'RecoveryDismissButton'
            )
        ) {
            $xamlSource.Contains($controlName) |
                Should-BeTrue
        }

        $desktopSource.Contains(
            'DispatcherUnhandledExceptionEventHandler'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            'Invoke-PhoenixControlCenterBoundary'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            '$eventArgs.Handled = $true'
        ) |
            Should-BeTrue
    }

    It 'offers desktop startup retry safe-layout and console recovery' {

        [string]$openSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Public\Open-Phoenix.ps1'
                ) `
                -Raw

        [string]$recoverySource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Show-PhoenixDesktopRecovery.ps1'
                ) `
                -Raw

        $openSource.Contains(
            'Show-PhoenixDesktopRecovery'
        ) |
            Should-BeTrue

        $openSource.Contains(
            'Reset-PhoenixControlCenterUiConfiguration'
        ) |
            Should-BeTrue

        foreach (
            $recoveryAction in @(
                'Retry desktop'
                'Use safe layout'
                'Open console'
                'Close'
            )
        ) {
            $recoverySource.Contains($recoveryAction) |
                Should-BeTrue
        }
    }

    It 'records structured Control Center failures with bounded history' {

        [string]$boundarySource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Invoke-PhoenixControlCenterBoundary.ps1'
                ) `
                -Raw

        $boundarySource.Contains(
            'PHX_UI_COMPONENT_FAILED'
        ) |
            Should-BeTrue

        $boundarySource.Contains(
            'PHX_DESKTOP_STARTUP_FAILED'
        ) |
            Should-BeTrue

        $boundarySource.Contains(
            'Cache\ControlCenter\LastFailure.json'
        ) |
            Should-BeTrue

        $boundarySource.Contains(
            '[int]$RetentionCount = 20'
        ) |
            Should-BeTrue
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

    It 'shows the active Phoenix context lifecycle on the dashboard' {

        [string]$inventorySource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Get-PhoenixControlCenterInventory.ps1'
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

        $inventorySource.Contains(
            'LifecycleState'
        ) |
            Should-BeTrue

        $inventorySource.Contains(
            'InitializationWarnings'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            'Phoenix state'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            'Context generation'
        ) |
            Should-BeTrue
    }

    It 'shows runtime recovery state and last repair details' {

        [string]$inventorySource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Get-PhoenixControlCenterInventory.ps1'
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

        $inventorySource.Contains(
            'RuntimeRecovery'
        ) |
            Should-BeTrue

        $inventorySource.Contains(
            'LastRecoveryAtUtc'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            'Runtime recovery'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            'Last repair (UTC)'
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

        [string]$startSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Start-PhoenixBackgroundOperation.ps1'
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

        $startSource.Contains(
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

    It 'queues application operations in FIFO order' {

        [string]$desktopSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Show-PhoenixDesktop.ps1'
                ) `
                -Raw

        [string]$operationSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Classes\10-Core\PhoenixBackgroundOperation.ps1'
                ) `
                -Raw

        $operationSource.Contains('Queued') |
            Should-BeTrue

        $desktopSource.Contains(
            '[System.Collections.Generic.Queue[PhoenixBackgroundOperation]]::new()'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            '$state.OperationQueue.Enqueue('
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            '$state.OperationQueue.Dequeue()'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            'Queued application operation {0}: {1}'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            'Starting queued application operation: {0}'
        ) |
            Should-BeTrue

        [regex]::Matches(
            $desktopSource,
            '(?s)-Action ''PackageAction''.{0,80}-QueueIfBusy'
        ).Count |
            Should-Be 2

        [regex]::Matches(
            $desktopSource,
            '(?s)-Action ''DriverAction''.{0,80}-QueueIfBusy'
        ).Count |
            Should-Be 0

        $desktopSource.Contains(
            'while ($state.OperationQueue.Count -gt 0)'
        ) |
            Should-BeTrue
    }

    It 'binds live background operations to the Activity Center' {
        [xml]$xaml =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\PhoenixControlCenter.xaml'
                ) `
                -Raw

        [string]$xamlSource = $xaml.OuterXml

        [string]$desktopSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Show-PhoenixDesktop.ps1'
                ) `
                -Raw

        foreach (
            $bindingName in @(
                'State'
                'Action'
                'Target'
                'Provider'
                'ProgressText'
                'StartedText'
                'ElapsedText'
            )
        ) {
            $xamlSource.Contains(
                "Binding $bindingName"
            ) |
                Should-BeTrue
        }

        $xamlSource.Contains('ActivityGrid') |
            Should-BeTrue

        $desktopSource.Contains(
            '[System.Collections.Generic.List[PhoenixActivityRecord]]::new()'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            '$timerUpdateActivityOperation'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            '$state.ActivityOperations.ToArray()'
        ) |
            Should-BeTrue
    }

    It 'defers provider bootstrap from desktop startup to a worker' {

        [string]$openSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Public\Open-Phoenix.ps1'
                ) `
                -Raw

        [string]$resolveSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\Core\Resolve-PhoenixContext.ps1'
                ) `
                -Raw

        [string]$startSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Public\Start-Phoenix.ps1'
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

        $openSource.Contains(
            '-SkipProviderBootstrap:('
        ) |
            Should-BeTrue

        $openSource.Contains(
            '-EnsureProviderBootstrap'
        ) |
            Should-BeTrue

        $resolveSource.Contains(
            '-SkipProviderBootstrap:$SkipProviderBootstrap'
        ) |
            Should-BeTrue

        $startSource.Contains(
            'if (-not $SkipProviderBootstrap)'
        ) |
            Should-BeTrue

        $workerSource.Contains(
            'Start-Phoenix `'
        ) |
            Should-BeTrue

        $workerSource.Contains(
            "'Inventory'"
        ) |
            Should-BeTrue

        $workerSource.Contains(
            "'SearchPackages'"
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

    It 'uses the atomic worker result with an unexpected-exit fallback' {

        [string]$desktopSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Show-PhoenixDesktop.ps1'
                ) `
                -Raw

        [string]$receiveSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Private\ControlCenter\Receive-PhoenixBackgroundOperation.ps1'
                ) `
                -Raw

        $desktopSource.Contains(
            '$operation.Process.HasExited'
        ) |
            Should-BeFalse

        $receiveSource.Contains(
            '-LiteralPath $Operation.ResultPath'
        ) |
            Should-BeTrue

        $receiveSource.Contains(
            '$Operation.Process.HasExited'
        ) |
            Should-BeTrue

        $receiveSource.Contains(
            'The background worker exited without publishing '
        ) |
            Should-BeTrue

        $receiveSource.Contains(
            "'a result.'"
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

    It 'uses module-bound adapters for shared background operations' {

        [string]$desktopPath =
            Join-Path `
                $projectRoot `
                'Private\ControlCenter\Show-PhoenixDesktop.ps1'

        [string]$desktopSource =
            Get-Content `
                -LiteralPath $desktopPath `
                -Raw

        $tokens = $null
        $parseErrors = $null

        $null =
            [Management.Automation.Language.Parser]::ParseFile(
                $desktopPath,
                [ref]$tokens,
                [ref]$parseErrors
            )

        @($parseErrors).Count |
            Should-Be 0

        $desktopSource.Contains(
            '$ExecutionContext.SessionState.Module'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            '.NewBoundScriptBlock({'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            'NewBoundScriptBlock(' +
            [Environment]::NewLine +
            '            ${function:'
        ) |
            Should-BeFalse

        $desktopSource.Contains(
            '[PhoenixBackgroundOperationState]::Cancelled'
        ) |
            Should-BeFalse

        foreach (
            $functionName in @(
                'New-PhoenixBackgroundOperation'
                'Start-PhoenixBackgroundOperation'
                'Receive-PhoenixBackgroundOperation'
                'Stop-PhoenixBackgroundOperation'
                'Remove-PhoenixBackgroundOperation'
            )
        ) {
            [string]$functionPath =
                Join-Path `
                    $projectRoot `
                    (
                        'Private\ControlCenter\{0}.ps1' -f
                        $functionName
                    )

            Test-Path `
                -LiteralPath $functionPath `
                -PathType Leaf |
                Should-BeTrue

            $desktopSource.Contains(
                $functionName
            ) |
                Should-BeTrue
        }

        $desktopSource.Contains(
            'New-PhoenixBackgroundOperation `' +
            [Environment]::NewLine +
            '                @PSBoundParameters'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            'Start-PhoenixBackgroundOperation `' +
            [Environment]::NewLine +
            '                @PSBoundParameters'
        ) |
            Should-BeTrue

        $desktopSource.Contains(
            '$operation = [pscustomobject]@{'
        ) |
            Should-BeFalse

        $desktopSource.Contains(
            '$operation.Cancelled = $true'
        ) |
            Should-BeFalse
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
