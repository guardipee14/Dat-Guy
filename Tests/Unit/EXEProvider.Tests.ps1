using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'EXEProvider' -Tag @('Unit','Provider','EXE') {
    BeforeAll {
        $providerSource = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\20-Providers\EXEProvider.ps1'
        ) -Raw
        $definitionSource = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\00-Base\EXEPackageDefinition.ps1'
        ) -Raw
    }

    It 'defines declarative installer uninstall repair and exit metadata' {
        foreach ($propertyName in @(
            'InstallCommand'
            'UninstallCommand'
            'QuietUninstallCommand'
            'RepairCommand'
            'SuccessExitCodes'
            'RebootExitCodes'
        )) {
            $definitionSource.Contains("`$$propertyName") | Should-BeTrue
        }
    }

    It 'publishes executable package capabilities' {
        $provider = [EXEProvider]::new()

        $provider.Name | Should-Be 'EXE'
        $provider.SupportsInventory | Should-BeTrue
        $provider.SupportsInstall | Should-BeTrue
        $provider.SupportsRepair | Should-BeTrue
        $provider.SupportsRemove | Should-BeTrue
        $provider.SupportsUpdate | Should-BeFalse
    }

    It 'discovers registered uninstall and version information' {
        $providerSource.Contains('CurrentVersion\Uninstall\*') |
            Should-BeTrue
        $providerSource.Contains('DisplayVersion') | Should-BeTrue
        $providerSource.Contains('QuietUninstallString') | Should-BeTrue
        $providerSource.Contains('ModifyPath') | Should-BeTrue
        $providerSource.Contains("WindowsInstaller -eq 1") |
            Should-BeTrue
    }

    It 'keeps missing installer definitions non-destructive' {
        $provider = [EXEProvider]::new()
        $package = [EXEPackageDefinition]::new()
        $package.Id = 'C:\missing-phoenix-installer.exe'
        $package.Provider = 'EXE'

        $result = $provider.InstallPackageSilent($package)

        $result.Success | Should-BeFalse
        $result.Code | Should-Be 'PHX_INSTALLER_NOT_FOUND'
    }

    It 'normalizes vendor exit and reboot codes' {
        $providerSource.Contains("'SuccessExitCodes'") | Should-BeTrue
        $providerSource.Contains("'RebootExitCodes'") | Should-BeTrue
        $providerSource.Contains('$result.HasExitCode = $true') |
            Should-BeTrue
        $providerSource.Contains('$result.RebootRequired') |
            Should-BeTrue
    }

    It 'registers EXE and exposes per-package UI actions' {
        $initialize = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Core\Initialize-PhoenixProviders.ps1'
        ) -Raw
        $inventory = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Get-PhoenixControlCenterInventory.ps1'
        ) -Raw

        $initialize.Contains('[EXEProvider]::new()') | Should-BeTrue
        $inventory.Contains('$_.Provider -eq ''EXE''') | Should-BeTrue
        $inventory.Contains("PSObject.Properties['RepairCommand']") |
            Should-BeTrue
        $inventory.Contains("PSObject.Properties['UninstallCommand']") |
            Should-BeTrue
    }
}
