using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'Phoenix restore planning engine' -Tag @('Unit','Restore','Plan') {
    It 'creates a versioned plan with stable identity and timestamp' {
        $plan = [PhoenixRestorePlan]::new()
        $plan.Schema | Should-Be 'PhoenixRestorePlan'
        $plan.SchemaVersion | Should-Be '1.0'
        [string]::IsNullOrWhiteSpace($plan.PlanId) | Should-BeFalse
        ($plan.CreatedAtUtc -le [datetime]::UtcNow) | Should-BeTrue
    }

    It 'summarizes selected blocked and already-satisfied records' {
        $selected = [PhoenixRestorePlanRecord]::new()
        $selected.Selected = $true
        $selected.Eligible = $true
        $selected.PlannedAction = 'Install'
        $blocked = [PhoenixRestorePlanRecord]::new()
        $blocked.Eligible = $false
        $satisfied = [PhoenixRestorePlanRecord]::new()
        $satisfied.Eligible = $true
        $satisfied.PlannedAction = 'AlreadySatisfied'
        $plan = [PhoenixRestorePlan]::new()
        $plan.Records = @($selected, $blocked, $satisfied)
        $plan.RefreshSummary()
        $plan.TotalCount | Should-Be 3
        $plan.SelectedCount | Should-Be 1
        $plan.BlockedCount | Should-Be 1
        $plan.SatisfiedCount | Should-Be 1
    }

    It 'models action provider version safety dependency and restart details' {
        $record = [PhoenixRestorePlanRecord]::new()
        foreach ($property in @(
            'RecordType','RequestedVersion','InstalledVersion','AvailableVersion',
            'Provider','ProviderAlternatives','PlannedAction','RequiresElevation',
            'Protected','RebootRequired','DependencyIds','Safety','Reason'
        )) {
            ($null -ne $record.PSObject.Properties[$property]) | Should-BeTrue
        }
    }

    It 'builds the plan before Restore-Phoenix asks to make changes' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Public\Restore-Phoenix.ps1'
        ) -Raw
        $planIndex = $source.IndexOf('New-PhoenixRestorePlan')
        $processIndex = $source.IndexOf('$PSCmdlet.ShouldProcess')
        ($planIndex -ge 0) | Should-BeTrue
        ($processIndex -gt $planIndex) | Should-BeTrue
        $source.Contains("'PHX_RESTORE_PLAN_FAILED'") | Should-BeTrue
    }

    It 'never bootstraps or installs providers during planning' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Public\New-PhoenixRestorePlan.ps1'
        ) -Raw
        $source.Contains('-SkipProviderBootstrap') | Should-BeTrue
        $source.Contains('Install-MissingProviders') | Should-BeFalse
        $source.Contains('InstallProvider(') | Should-BeFalse
    }

    It 'exports the public planning command' {
        $moduleSource = Get-Content (
            Join-Path $PSScriptRoot '..\..\Phoenix.psm1'
        ) -Raw
        $manifestSource = Get-Content (
            Join-Path $PSScriptRoot '..\..\Phoenix.psd1'
        ) -Raw
        $moduleSource.Contains("'New-PhoenixRestorePlan'") | Should-BeTrue
        $manifestSource.Contains("'New-PhoenixRestorePlan'") | Should-BeTrue
    }
}
