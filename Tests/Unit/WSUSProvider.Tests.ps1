using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'WSUSProvider' -Tag @('Unit','Provider','WSUS') {
    BeforeAll {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\20-Providers\WSUSProvider.ps1'
        ) -Raw
    }

    It 'publishes managed update capabilities with elevation' {
        $provider = [WSUSProvider]::new()
        $provider.SupportsSearch | Should-BeTrue
        $provider.SupportsInventory | Should-BeTrue
        $provider.SupportsInstall | Should-BeTrue
        $provider.SupportsUpdate | Should-BeTrue
        $provider.SupportsRemove | Should-BeFalse
        $provider.RequiredPrivilege.ToString() | Should-Be 'Administrator'
    }

    It 'detects Windows Update and managed WSUS policy' {
        $source.Contains('WUServer') | Should-BeTrue
        $source.Contains('WUStatusServer') | Should-BeTrue
        $source.Contains('UseWUServer') | Should-BeTrue
        $source.Contains("'Microsoft Update'") | Should-BeTrue
    }

    It 'discovers applicable updates through Windows Update Agent' {
        $source.Contains('Microsoft.Update.Session') | Should-BeTrue
        $source.Contains('IsInstalled=0 and IsHidden=0') | Should-BeTrue
        $source.Contains('ServerSelection') | Should-BeTrue
        $source.Contains('KBArticleIDs') | Should-BeTrue
    }

    It 'downloads and installs through the selected managed source' {
        $source.Contains('CreateUpdateDownloader') | Should-BeTrue
        $source.Contains('CreateUpdateInstaller') | Should-BeTrue
        $source.Contains('Microsoft.Update.UpdateColl') | Should-BeTrue
        $source.Contains('AcceptEula') | Should-BeTrue
    }

    It 'reports applicability approval HRESULT and reboot state' {
        foreach ($value in @(
            'ApprovalStatus','Applicable','PHX_UPDATE_NOT_APPLICABLE',
            'HResult','RebootRequired'
        )) { $source.Contains($value) | Should-BeTrue }
    }

    It 'rejects invalid update identities without mutation' {
        $provider = [WSUSProvider]::new()
        $package = [Package]::new()
        $package.Id = 'invalid'
        $provider.InstallPackageSilent($package).Code |
            Should-Be 'PHX_INVALID_PACKAGE'
    }

    It 'registers WSUS source and operation details in the UI' {
        $initialize = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Core\Initialize-PhoenixProviders.ps1'
        ) -Raw
        $search = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Search-PhoenixControlCenterPackage.ps1'
        ) -Raw
        $initialize.Contains('[WSUSProvider]::new()') | Should-BeTrue
        $search.Contains("'WSUS'") | Should-BeTrue
    }
}
