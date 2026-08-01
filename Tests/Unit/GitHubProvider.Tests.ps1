using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'GitHubProvider' -Tag @('Unit','Provider','GitHub') {
    BeforeAll {
        $providerSource = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\20-Providers\GitHubProvider.ps1'
        ) -Raw
        $definitionSource = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\00-Base\GitHubReleasePackageDefinition.ps1'
        ) -Raw
    }

    It 'defines repository release asset checksum and publisher metadata' {
        foreach ($propertyName in @(
            'Repository'
            'ReleaseTag'
            'AssetName'
            'AssetPattern'
            'DownloadUri'
            'ChecksumUri'
            'SHA256'
            'InstalledVersion'
            'ReleaseNotes'
            'ReleaseNotesUrl'
        )) {
            $definitionSource.Contains("`$$propertyName") | Should-BeTrue
        }
    }

    It 'publishes discovery installation and update capabilities' {
        $provider = [GitHubProvider]::new()

        $provider.Name | Should-Be 'GitHub Releases'
        $provider.SupportsSearch | Should-BeTrue
        $provider.SupportsInstall | Should-BeTrue
        $provider.SupportsUpdate | Should-BeTrue
        $provider.SupportsRemove | Should-BeFalse
    }

    It 'uses supported GitHub REST endpoints and authenticated headers' {
        $providerSource.Contains('/search/repositories') | Should-BeTrue
        $providerSource.Contains('/releases/latest') | Should-BeTrue
        $providerSource.Contains('application/vnd.github+json') |
            Should-BeTrue
        $providerSource.Contains('GITHUB_TOKEN') | Should-BeTrue
    }

    It 'selects Windows installer assets and delegates to package engines' {
        $providerSource.Contains("'arm64' { '(?i)(arm64|aarch64)' }") |
            Should-BeTrue
        $providerSource.Contains("[MSIProvider]::new()") | Should-BeTrue
        $providerSource.Contains("[EXEProvider]::new()") | Should-BeTrue
        $providerSource.Contains("'PHX_INSTALLER_TYPE_UNSUPPORTED'") |
            Should-BeTrue
    }

    It 'rejects incomplete release definitions without downloading' {
        $provider = [GitHubProvider]::new()
        $package = [GitHubReleasePackageDefinition]::new()
        $package.Id = 'owner/repository'

        $result = $provider.InstallPackageSilent($package)

        $result.Success | Should-BeFalse
        $result.Code | Should-Be 'PHX_RELEASE_ASSET_REQUIRED'
    }

    It 'verifies publisher SHA-256 metadata when available' {
        $providerSource.Contains('Get-FileHash') | Should-BeTrue
        $providerSource.Contains("'PHX_HASH_MISMATCH'") | Should-BeTrue
        $providerSource.Contains('ChecksumUri') | Should-BeTrue
    }

    It 'registers GitHub search and release metadata in the UI' {
        $initialize = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Core\Initialize-PhoenixProviders.ps1'
        ) -Raw
        $search = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Search-PhoenixControlCenterPackage.ps1'
        ) -Raw
        $release = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Get-PhoenixControlCenterPackageRelease.ps1'
        ) -Raw

        $initialize.Contains('[GitHubProvider]::new()') | Should-BeTrue
        $search.Contains("'GitHub Releases'") | Should-BeTrue
        $release.Contains("'GitHub Releases'") | Should-BeTrue
        $release.Contains('[string]$release.html_url') | Should-BeTrue
    }
}
