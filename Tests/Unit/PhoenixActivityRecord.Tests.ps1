using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'PhoenixActivityRecord' -Tag @(
    'Unit'
    'Activity'
    'BackgroundOperation'
) {
    It 'tracks queued and running lifecycle details' {
        $operation =
            [PhoenixBackgroundOperation]::new(
                'PackageAction',
                [pscustomobject]@{},
                'ControlCenter',
                'Installing applications...',
                {}
            )

        $record =
            [PhoenixActivityRecord]::new(
                $operation,
                'PowerShell',
                'WinGet'
            )

        $record.State |
            Should-Be 'Created'

        $record.Target |
            Should-Be 'PowerShell'

        $record.Provider |
            Should-Be 'WinGet'

        $operation.MarkQueued()
        $record.UpdateLifecycle()

        $record.State |
            Should-Be 'Queued'

        $operation.MarkStarting()
        $operation.MarkRunning()
        $operation.UpdateProgress(
            45,
            'Installing PowerShell...'
        )
        $record.UpdateLifecycle()

        $record.State |
            Should-Be 'Running'

        $record.ProgressPercent |
            Should-Be 45

        $record.ProgressText |
            Should-Be '45% - Installing PowerShell...'

        [string]::IsNullOrWhiteSpace(
            $record.StartedText
        ) |
            Should-BeFalse

        $record.IsTerminal |
            Should-BeFalse

        $record.CanCancel |
            Should-BeTrue

        $record.CanRetry |
            Should-BeFalse
    }

    It 'retains completed result details' {
        $operation =
            [PhoenixBackgroundOperation]::new(
                'DriverAction',
                [pscustomobject]@{},
                'ControlCenter',
                'Scanning drivers...',
                {}
            )

        $operation.MarkStarting()
        $operation.MarkRunning()
        $operation.MarkCompleted()

        $record =
            [PhoenixActivityRecord]::new(
                $operation,
                'ScanUpdates',
                'Windows Update'
            )

        $resultData =
            [pscustomobject]@{
                Code = 'PHX_DRIVER_SCAN_COMPLETE'
                Warnings = @(
                    'A driver catalog was unavailable.'
                )
                Data = [pscustomobject]@{
                    RebootRequired = $true
                }
            }

        $record.SetResult(
            $resultData,
            ''
        )

        $record.State |
            Should-Be 'Completed'

        $record.IsTerminal |
            Should-BeTrue

        $record.ResultData.Code |
            Should-Be 'PHX_DRIVER_SCAN_COMPLETE'

        $record.ResultCode |
            Should-Be 'PHX_DRIVER_SCAN_COMPLETE'

        $record.Warnings.Count |
            Should-Be 1

        $record.RequiresRestart |
            Should-BeTrue

        $record.CanCancel |
            Should-BeFalse

        $record.CanRetry |
            Should-BeTrue

        (
            $record.ElapsedText -match
            '^\d{2}:\d{2}:\d{2}$'
        ) |
            Should-BeTrue
    }
}
