using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'WinGet provider completion' -Tag @(
    'Unit'
    'Provider'
    'WinGet'
) {
    It 'publishes every supported application capability' {
        $provider = [PhoenixProvider]::new()
        $provider.Name = 'WinGet'
        $provider.Available = $true
        $provider.SupportsSilentInstall = $true
        $provider.SupportsInteractiveInstall = $true
        $provider.SupportsRepair = $true

        $capability = $provider.GetCapability()

        foreach ($operation in @('Search','Inventory','Install','Update','Repair','Remove','Restore')) {
            ($capability.SupportedOperations -contains $operation) |
                Should-BeTrue
        }
    }

    It 'normalizes WinGet exit and restart metadata' {
        $provider = [PhoenixProvider]::new()
        $provider.Name = 'WinGet'

        $result = [Result]::Success()
        $result.Provider = 'WinGet'
        $result.Operation = 'Install'
        $result.Target = 'Microsoft.PowerShell'
        $result.Code = 'PHX_INSTALLED_RESTART_REQUIRED'
        $result.HasExitCode = $true
        $result.ExitCode = 3010
        $result.RebootRequired = $true

        $normalized = $provider.NormalizeResult(
            $result,
            [PhoenixProviderOperation]::Install,
            'Microsoft.PowerShell'
        )

        $normalized.Success | Should-BeTrue
        $normalized.HasExitCode | Should-BeTrue
        $normalized.ExitCode | Should-Be 3010
        $normalized.RequiresRestart | Should-BeTrue
    }

    It 'implements every advertised WinGet application action' {
        $providerRoot = Join-Path $PSScriptRoot '..\..\Classes\20-Providers\WinGetProvider'

        foreach ($method in @(
            'SearchPackage.ps1'
            'GetInstalledPackages.ps1'
            'InstallPackageSilent.ps1'
            'InstallPackageInteractive.ps1'
            'UpdatePackage.ps1'
            'RepairPackageSilent.ps1'
            'RepairPackageInteractive.ps1'
            'RemovePackage.ps1'
        )) {
            $matches = @(
                Get-ChildItem $providerRoot -Recurse -Filter $method
            )
            $matches.Count | Should-Be 1
        }

        $interactiveSource = Get-Content (
            Join-Path $providerRoot 'Methods\InstallPackageInteractive.ps1'
        ) -Raw
        $interactiveSource.Contains('--interactive') | Should-BeTrue
        $interactiveSource.Contains('$result.ExitCode = $exitCode') | Should-BeTrue
    }
}
