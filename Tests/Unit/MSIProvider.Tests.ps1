using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'MSIProvider' -Tag @('Unit','Provider','MSI') {
    BeforeAll {
        $providerSource = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\20-Providers\MSIProvider.ps1'
        ) -Raw
    }

    It 'publishes native installer capabilities and privilege requirements' {
        $provider = [MSIProvider]::new()

        $provider.Name | Should-Be 'MSI'
        $provider.SupportsInventory | Should-BeTrue
        $provider.SupportsInstall | Should-BeTrue
        $provider.SupportsRepair | Should-BeTrue
        $provider.SupportsRemove | Should-BeTrue
        $provider.SupportsUpdate | Should-BeFalse
        $provider.RequiredPrivilege.ToString() | Should-Be 'Administrator'
    }

    It 'uses registry inventory without invoking Win32_Product' {
        $providerSource.Contains('CurrentVersion\Uninstall\*') |
            Should-BeTrue
        $providerSource.Contains('WOW6432Node') | Should-BeTrue
        $providerSource.Contains('Win32_Product') | Should-BeFalse
        $providerSource.Contains('$package.InstallerType = ''MSI''') |
            Should-BeTrue
    }

    It 'implements silent interactive repair and removal paths' {
        foreach ($signature in @(
            'InstallPackageSilent([Package]$Package)'
            'InstallPackageInteractive([Package]$Package)'
            'RepairPackageSilent([Package]$Package)'
            'RepairPackageInteractive([Package]$Package)'
            'RemovePackage([Package]$Package)'
        )) {
            $providerSource.Contains($signature) | Should-BeTrue
        }
    }

    It 'normalizes Windows Installer success and restart exit codes' {
        $providerSource.Contains('@(0, 1605, 1614, 1641, 3010)') |
            Should-BeTrue
        $providerSource.Contains('@(1641, 3010)') | Should-BeTrue
        $providerSource.Contains('$result.HasExitCode = $true') |
            Should-BeTrue
        $providerSource.Contains('$result.RebootRequired') |
            Should-BeTrue
    }

    It 'registers MSI and routes Control Center actions by capability' {
        $initialize = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Core\Initialize-PhoenixProviders.ps1'
        ) -Raw
        $action = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Invoke-PhoenixControlCenterPackageAction.ps1'
        ) -Raw

        $initialize.Contains('[MSIProvider]::new()') | Should-BeTrue
        $action.Contains('$actionProvider.SupportsRepair') | Should-BeTrue
        $action.Contains('$actionProvider.SupportsRemove') | Should-BeTrue
        $action.Contains('Test-PhoenixRestorePackage') | Should-BeFalse
    }
}
