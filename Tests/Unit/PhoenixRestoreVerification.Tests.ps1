using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'Phoenix restore verification engine and UI' -Tag @('Unit','Restore','Verification') {
    It 'creates typed versioned verification reports' {
        $report = [PhoenixRestoreVerification]::new()
        $report.Schema | Should-Be 'PhoenixRestoreVerification'
        $report.SchemaVersion | Should-Be '1.0'
        $report.Status | Should-Be 'Running'
        ($report.StartedAtUtc -le [datetime]::UtcNow) | Should-BeTrue
    }

    It 'publishes the complete verification classification set' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Public\Test-PhoenixRestoreVerification.ps1'
        ) -Raw
        foreach ($status in @(
            'Verified','VersionMismatch','AlreadySatisfied','Skipped',
            'RestartPending','Missing','Failed','NoLongerApplicable',
            'UnableToVerify'
        )) { $source.Contains("'$status'") | Should-BeTrue }
    }

    It 'rescans applications and drivers with provider and version detail' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Public\Test-PhoenixRestoreVerification.ps1'
        ) -Raw
        $source.Contains('GetInstalledPackages()') | Should-BeTrue
        $source.Contains('Get-PhoenixDriver') | Should-BeTrue
        foreach ($property in @(
            'Provider','ExpectedVersion','ActualVersion','ResultCode','Details'
        )) {
            ([PhoenixRestoreVerificationRecord]::new().PSObject.Properties.Name -contains $property) |
                Should-BeTrue
        }
    }

    It 'summarizes complete partial failed and restart-pending outcomes' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Public\Test-PhoenixRestoreVerification.ps1'
        ) -Raw
        foreach ($status in @('Complete','Partial','Failed','RestartPending')) {
            $source.Contains("'$status'") | Should-BeTrue
        }
        foreach ($property in @(
            'VerifiedCount','ProblemCount','SkippedCount','RebootRequired'
        )) {
            ([PhoenixRestoreVerification]::new().PSObject.Properties.Name -contains $property) |
                Should-BeTrue
        }
    }

    It 'runs automatically after non-interrupted restore execution' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Public\Invoke-PhoenixRestorePlan.ps1'
        ) -Raw
        $source.Contains('$checkpoint.Status -ne ''Interrupted''') | Should-BeTrue
        $source.Contains('Test-PhoenixRestoreVerification') | Should-BeTrue
        $source.Contains('VerificationSnapshot') | Should-BeTrue
    }

    It 'shows and persists verification through the worker and Control Center' {
        $worker = Get-Content (
            Join-Path $PSScriptRoot '..\..\Tools\Invoke-PhoenixControlCenterWorker.ps1'
        ) -Raw
        $desktop = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Show-PhoenixDesktop.ps1'
        ) -Raw
        $xaml = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\PhoenixControlCenter.xaml'
        ) -Raw
        $worker.Contains("'RestoreVerify'") | Should-BeTrue
        $worker.Contains('VerificationSnapshot') | Should-BeTrue
        $desktop.Contains('VerificationStatus') | Should-BeTrue
        $xaml.Contains('Binding="{Binding VerificationStatus}"') | Should-BeTrue
        $xaml.Contains('x:Name="VerifyRestoreButton"') | Should-BeTrue
    }

    It 'exports structured verification to PowerShell' {
        foreach ($path in @('Phoenix.psm1','Phoenix.psd1')) {
            $source = Get-Content (Join-Path $PSScriptRoot "..\..\$path") -Raw
            $source.Contains("'Test-PhoenixRestoreVerification'") |
                Should-BeTrue
        }
    }
}
