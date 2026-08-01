using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'Chocolatey provider completion' -Tag @(
    'Unit'
    'Provider'
    'Chocolatey'
) {
    It 'normalizes Chocolatey reboot results through the common contract' {
        $provider = [PhoenixProvider]::new()
        $provider.Name = 'Chocolatey'
        $provider.RequiredPrivilege =
            [PhoenixPrivilegeLevel]::Administrator

        $result = [Result]::Success()
        $result.Provider = 'Chocolatey'
        $result.Operation = 'Update'
        $result.Target = 'powershell-core'
        $result.Code = 'PHX_UPDATED_REBOOT_REQUIRED'
        $result.HasExitCode = $true
        $result.ExitCode = 1641
        $result.RebootRequired = $true

        $normalized = $provider.NormalizeResult(
            $result,
            [PhoenixProviderOperation]::Update,
            'powershell-core'
        )

        $normalized.Success | Should-BeTrue
        $normalized.ExitCode | Should-Be 1641
        $normalized.RequiresRestart | Should-BeTrue
        $normalized.RequiredPrivilege.ToString() |
            Should-Be 'Administrator'
    }

    It 'decorates every Chocolatey mutation result' {
        $providerRoot = Join-Path $PSScriptRoot '..\..\Classes\20-Providers\ChocolateyProvider\Methods'

        foreach ($method in @(
            'InstallPackageSilent.ps1'
            'InstallPackageInteractive.ps1'
            'UpdatePackage.ps1'
            'RepairPackageSilent.ps1'
            'RepairPackageInteractive.ps1'
            'RemovePackage.ps1'
        )) {
            $source = Get-Content (Join-Path $providerRoot $method) -Raw
            $source.Contains('CompleteChocolateyResult') |
                Should-BeTrue
        }

        $helper = Get-Content (
            Join-Path $providerRoot 'Helpers\CompleteChocolateyResult.ps1'
        ) -Raw
        $helper.Contains('$Result.RebootRequired') | Should-BeTrue
        $helper.Contains('$Result.ExitCode') | Should-BeTrue
    }

    It 'keeps Chocolatey actions capability-aware in the UI inventory' {
        $inventorySource = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Get-PhoenixControlCenterInventory.ps1'
        ) -Raw
        $desktopSource = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Show-PhoenixDesktop.ps1'
        ) -Raw

        $inventorySource.Contains('SupportsRepair') | Should-BeTrue
        $inventorySource.Contains('SupportsRemove') | Should-BeTrue
        $desktopSource.Contains('Provider health:') | Should-BeTrue
    }
}
