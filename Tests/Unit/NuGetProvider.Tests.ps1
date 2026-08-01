using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'NuGetProvider' -Tag @('Unit','Provider','NuGet') {
    BeforeAll {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\20-Providers\NuGetProvider.ps1'
        ) -Raw
    }

    It 'publishes search inventory mutation export and restore capabilities' {
        $provider = [NuGetProvider]::new()
        foreach ($property in @(
            'SupportsSearch','SupportsInventory','SupportsInstall',
            'SupportsUpdate','SupportsRemove','SupportsExport','SupportsRestore'
        )) {
            $provider.$property | Should-BeTrue
        }
    }

    It 'discovers v3 search and package base resources from configured feeds' {
        $source.Contains('PHOENIX_NUGET_FEEDS') | Should-BeTrue
        $source.Contains('SearchQueryService') | Should-BeTrue
        $source.Contains('PackageBaseAddress') | Should-BeTrue
        $source.Contains('https://api.nuget.org/v3/index.json') |
            Should-BeTrue
    }

    It 'uses a Phoenix-owned current-user package store' {
        $source.Contains('Join-Path $env:LOCALAPPDATA ''Phoenix\NuGet''') |
            Should-BeTrue
        $source.Contains('Phoenix NuGet Store') | Should-BeTrue
    }

    It 'rejects invalid identities without downloading or deleting data' {
        $provider = [NuGetProvider]::new()
        $package = [NuGetPackageDefinition]::new()
        $package.Id = '..\unsafe'
        $package.Version = '1.0.0'

        $provider.InstallPackageSilent($package).Code |
            Should-Be 'PHX_INVALID_PACKAGE'
        $provider.RemovePackage($package).Code |
            Should-Be 'PHX_INVALID_PACKAGE'
    }

    It 'guards archive extraction against path traversal' {
        $source.Contains('GetFullPath') | Should-BeTrue
        $source.Contains('unsafe archive path') | Should-BeTrue
        $source.Contains('ZipFileExtensions]::ExtractToFile') |
            Should-BeTrue
    }

    It 'implements export restore and UI registration' {
        $initialize = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Core\Initialize-PhoenixProviders.ps1'
        ) -Raw
        $search = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Search-PhoenixControlCenterPackage.ps1'
        ) -Raw

        $source.Contains('[Result] ExportPackages()') | Should-BeTrue
        $source.Contains('[Result[]] RestorePackages(') | Should-BeTrue
        $initialize.Contains('[NuGetProvider]::new()') | Should-BeTrue
        $search.Contains("'NuGet'") | Should-BeTrue
    }
}
