using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'PowerShellGalleryProvider' -Tag @('Unit','Provider','PSGallery') {
    BeforeAll {
        $providerSource = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\20-Providers\PowerShellGalleryProvider.ps1'
        ) -Raw
        $definitionSource = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\00-Base\PowerShellGalleryPackageDefinition.ps1'
        ) -Raw
    }

    It 'defines module and script repository and version metadata' {
        foreach ($propertyName in @(
            'ResourceType'
            'Repository'
            'InstalledVersion'
            'Description'
        )) {
            $definitionSource.Contains("`$$propertyName") | Should-BeTrue
        }
    }

    It 'publishes the complete Gallery provider capability set' {
        $provider = [PowerShellGalleryProvider]::new()

        $provider.Name | Should-Be 'PowerShell Gallery'
        $provider.SupportsSearch | Should-BeTrue
        $provider.SupportsInventory | Should-BeTrue
        $provider.SupportsInstall | Should-BeTrue
        $provider.SupportsUpdate | Should-BeTrue
        $provider.SupportsRemove | Should-BeTrue
        $provider.SupportsExport | Should-BeTrue
        $provider.SupportsRestore | Should-BeTrue
    }

    It 'prefers PSResourceGet with PowerShellGet module and script fallback' {
        foreach ($commandName in @(
            'Find-PSResource'
            'Get-InstalledPSResource'
            'Install-PSResource'
            'Update-PSResource'
            'Uninstall-PSResource'
            'Find-Module'
            'Find-Script'
        )) {
            $providerSource.Contains($commandName) | Should-BeTrue
        }
    }

    It 'rejects invalid package requests without changing resources' {
        $provider = [PowerShellGalleryProvider]::new()
        $package = [PowerShellGalleryPackageDefinition]::new()

        $result = $provider.InstallPackageSilent($package)

        $result.Success | Should-BeFalse
        $result.Code | Should-Be 'PHX_INVALID_PACKAGE'
    }

    It 'exports typed inventory and restores selected resources' {
        $providerSource.Contains('[Result] ExportPackages()') |
            Should-BeTrue
        $providerSource.Contains('[Result[]] RestorePackages(') |
            Should-BeTrue
        $providerSource.Contains('$this.InstallPackageSilent($package)') |
            Should-BeTrue
    }

    It 'registers Gallery search inventory and restore paths in the UI' {
        $initialize = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Core\Initialize-PhoenixProviders.ps1'
        ) -Raw
        $search = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Search-PhoenixControlCenterPackage.ps1'
        ) -Raw
        $eligibility = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Packages\Test-PhoenixRestorePackage.ps1'
        ) -Raw

        $initialize.Contains('[PowerShellGalleryProvider]::new()') |
            Should-BeTrue
        $search.Contains("'PowerShell Gallery'") | Should-BeTrue
        $search.Contains('InstalledVersion') | Should-BeTrue
        $eligibility.Contains("'PowerShell Gallery'") | Should-BeTrue
    }
}
