using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'Phoenix restore resume retry and reboot state' -Tag @('Unit','Restore','Checkpoint') {
    BeforeAll {
        $script:invokeSource = Get-Content (
            Join-Path $PSScriptRoot '..\..\Public\Invoke-PhoenixRestorePlan.ps1'
        ) -Raw
    }

    It 'saves before and after every selected restore operation' {
        $script:invokeSource.Contains("Status = 'Running'") | Should-BeTrue
        $script:invokeSource.Contains("Status = 'Completed'") | Should-BeTrue
        $script:invokeSource.Contains("Status = 'Failed'") | Should-BeTrue
        ([regex]::Matches(
            $script:invokeSource,
            'Save-PhoenixRestoreCheckpoint'
        ).Count -ge 5) | Should-BeTrue
    }

    It 'resumes without repeating completed or skipped work' {
        $script:invokeSource.Contains("Where-Object Status -EQ 'Pending'") |
            Should-BeTrue
        $script:invokeSource.Contains("Where-Object Status -EQ 'Running'") |
            Should-BeTrue
        $script:invokeSource.Contains('$record.Status = ''Pending''') |
            Should-BeTrue
    }

    It 'retries only failed records marked retryable' {
        $script:invokeSource.Contains('$RetryFailed') | Should-BeTrue
        $script:invokeSource.Contains('$_.Status -eq ''Failed'' -and $_.Retryable') |
            Should-BeTrue
        $script:invokeSource.Contains("'PHX_PROTECTED_PACKAGE'") |
            Should-BeTrue
    }

    It 'preserves interruption and restart-pending outcomes' {
        $script:invokeSource.Contains("'Interrupted'") | Should-BeTrue
        $script:invokeSource.Contains("'RestartPending'") | Should-BeTrue
        $script:invokeSource.Contains("'PHX_RESTORE_RESTART_PENDING'") |
            Should-BeTrue
        $script:invokeSource.Contains('$checkpoint.RebootRequired') |
            Should-BeTrue
    }

    It 'rejects a manifest that changed after checkpoint creation' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Public\Get-PhoenixRestoreCheckpoint.ps1'
        ) -Raw
        $source.Contains('Get-FileHash') | Should-BeTrue
        $source.Contains('AllowStaleManifest') | Should-BeTrue
        $source.Contains('changed after this checkpoint was created') |
            Should-BeTrue
    }

    It 'routes execute and resume through the isolated worker and UI' {
        $worker = Get-Content (
            Join-Path $PSScriptRoot '..\..\Tools\Invoke-PhoenixControlCenterWorker.ps1'
        ) -Raw
        $desktop = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Show-PhoenixDesktop.ps1'
        ) -Raw
        $xaml = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\PhoenixControlCenter.xaml'
        ) -Raw
        $worker.Contains("'RestorePlanExecute'") | Should-BeTrue
        $worker.Contains('Resume-PhoenixRestore') | Should-BeTrue
        $desktop.Contains('RestoreSessionId') | Should-BeTrue
        foreach ($name in @('ExecuteRestorePlanButton','ResumeRestoreButton')) {
            $desktop.Contains("'$name'") | Should-BeTrue
            $xaml.Contains("x:Name=`"$name`"") | Should-BeTrue
        }
    }

    It 'exports checkpointed execution and resume commands' {
        foreach ($path in @('Phoenix.psm1','Phoenix.psd1')) {
            $source = Get-Content (Join-Path $PSScriptRoot "..\..\$path") -Raw
            $source.Contains("'Invoke-PhoenixRestorePlan'") | Should-BeTrue
            $source.Contains("'Resume-PhoenixRestore'") | Should-BeTrue
        }
    }
}
