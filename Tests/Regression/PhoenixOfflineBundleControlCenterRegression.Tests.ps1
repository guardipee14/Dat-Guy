BeforeAll {

    $projectRoot = (
        Resolve-Path (
            Join-Path $PSScriptRoot '..\..'
        )
    ).Path

    [string]$xaml =
        Get-Content `
            -LiteralPath (Join-Path $projectRoot 'Private\ControlCenter\PhoenixControlCenter.xaml') `
            -Raw

    [string]$desktopSource =
        Get-Content `
            -LiteralPath (Join-Path $projectRoot 'Private\ControlCenter\Show-PhoenixDesktop.ps1') `
            -Raw

    [string]$workerSource =
        Get-Content `
            -LiteralPath (Join-Path $projectRoot 'Tools\Invoke-PhoenixControlCenterWorker.ps1') `
            -Raw
}

Describe 'Phoenix offline-bundle Control Center workflow' -Tag @(
    'Regression'
    'OfflineBundle'
    'ControlCenter'
) {

    It 'binds every recovery-bundle page control in the desktop runtime' {

        foreach (
            $controlName in @(
                'RecoveryBundleNavButton'
                'RecoveryBundlePage'
                'RecoveryBundleNameText'
                'RecoveryBundlePathText'
                'RecoveryBundleInputText'
                'RecoveryBundleSummaryText'
                'BuildRecoveryBundleButton'
                'InspectRecoveryBundleButton'
                'VerifyRecoveryBundleButton'
                'RemoveRecoveryBundleButton'
            )
        ) {
            $xaml.Contains(('x:Name="{0}"' -f $controlName)) |
                Should-BeTrue

            $desktopSource.Contains(("'$controlName'")) |
                Should-BeTrue
        }
    }

    It 'routes every recovery-bundle action through the isolated worker' {

        foreach (
            $action in @(
                'OfflineBundleBuild'
                'OfflineBundleInspect'
                'OfflineBundleVerify'
                'OfflineBundleRemove'
            )
        ) {
            $workerSource.Contains(("'$action'")) |
                Should-BeTrue

            $desktopSource.Contains(("-Action '$action'")) |
                Should-BeTrue
        }
    }

    It 'serializes long bundle work and supports resumable incremental builds' {

        $desktopSource.Contains("-ConcurrencyKey 'OfflineBundle'") |
            Should-BeTrue

        $desktopSource.Contains('-TimeoutSeconds 3600') |
            Should-BeTrue

        $workerSource.Contains('Update-PhoenixOfflineBundle') |
            Should-BeTrue

        $workerSource.Contains('New-PhoenixOfflineBundle') |
            Should-BeTrue
    }

    It 'does not expose later Windows deployment controls or worker actions' {

        $xaml.Contains('x:Name="DeploymentNavButton"') |
            Should-BeFalse

        $xaml.Contains('x:Name="DeploymentPage"') |
            Should-BeFalse

        $workerSource.Contains("'DeploymentPrerequisite'") |
            Should-BeFalse

        $workerSource.Contains("'WinPEWorkspaceBuild'") |
            Should-BeFalse
    }
}
