using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'DISMProvider' -Tag @('Unit','Provider','DISM') {
    BeforeAll {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\20-Providers\DISMProvider.ps1'
        ) -Raw
    }

    It 'publishes online servicing capabilities with elevation' {
        $provider = [DISMProvider]::new()
        $provider.SupportsSearch | Should-BeTrue
        $provider.SupportsInventory | Should-BeTrue
        $provider.SupportsInstall | Should-BeTrue
        $provider.SupportsRemove | Should-BeTrue
        $provider.RequiredPrivilege.ToString() | Should-Be 'Administrator'
    }

    It 'detects capabilities optional features and packages online only' {
        foreach ($command in @(
            'Get-WindowsCapability','Get-WindowsOptionalFeature','Get-WindowsPackage'
        )) { $source.Contains($command) | Should-BeTrue }
        $source.Contains('-Online') | Should-BeTrue
        $source.Contains('-ImagePath') | Should-BeFalse
    }

    It 'implements type-specific enable install disable and removal' {
        foreach ($command in @(
            'Add-WindowsCapability','Remove-WindowsCapability',
            'Enable-WindowsOptionalFeature','Disable-WindowsOptionalFeature',
            'Add-WindowsPackage','Remove-WindowsPackage'
        )) { $source.Contains($command) | Should-BeTrue }
    }

    It 'normalizes restart and DISM result codes' {
        $source.Contains('RestartNeeded') | Should-BeTrue
        $source.Contains('$result.RebootRequired') | Should-BeTrue
        $source.Contains('$result.HasExitCode = $true') | Should-BeTrue
        $source.Contains('$_.Exception.HResult') | Should-BeTrue
    }

    It 'rejects untyped servicing records without mutation' {
        $provider = [DISMProvider]::new()
        $package = [Package]::new()
        $package.Id = 'Example'
        $provider.InstallPackageSilent($package).Code |
            Should-Be 'PHX_SERVICING_TYPE_UNSUPPORTED'
    }

    It 'registers DISM search and provider health in the UI' {
        $initialize = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Core\Initialize-PhoenixProviders.ps1'
        ) -Raw
        $search = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Search-PhoenixControlCenterPackage.ps1'
        ) -Raw
        $initialize.Contains('[DISMProvider]::new()') | Should-BeTrue
        $search.Contains("'DISM'") | Should-BeTrue
    }
}
