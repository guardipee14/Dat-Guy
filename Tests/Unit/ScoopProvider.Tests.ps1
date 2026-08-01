using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'ScoopProvider' -Tag @('Unit','Provider','Scoop') {
    It 'publishes Scoop capabilities without requiring elevation' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\20-Providers\ScoopProvider.ps1'
        ) -Raw

        $source.Contains('class ScoopProvider : PhoenixProvider') |
            Should-BeTrue
        $source.Contains('[PhoenixPrivilegeLevel]::User') |
            Should-BeTrue
        $source.Contains('$this.SupportsExport = $true') |
            Should-BeTrue
        $source.Contains('$this.SupportsRestore = $true') |
            Should-BeTrue
    }

    It 'implements search inventory mutation export and restore paths' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\20-Providers\ScoopProvider.ps1'
        ) -Raw

        foreach ($signature in @(
            'GetInstalledPackages()'
            'SearchPackage([string]$Name)'
            'InstallPackage([Package]$Package)'
            'UpdatePackage([Package]$Package)'
            'RemovePackage([Package]$Package)'
            'ExportPackages()'
            'RestorePackages([Package[]]$Packages)'
        )) {
            $source.Contains($signature) | Should-BeTrue
        }
    }

    It 'registers Scoop with runtime search and restore eligibility' {
        $initialize = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Core\Initialize-PhoenixProviders.ps1'
        ) -Raw
        $search = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Search-PhoenixControlCenterPackage.ps1'
        ) -Raw
        $eligibility = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Packages\Test-PhoenixRestorePackage.ps1'
        ) -Raw

        $initialize.Contains('[ScoopProvider]::new()') | Should-BeTrue
        $search.Contains("'Scoop'") | Should-BeTrue
        $eligibility.Contains("@('Chocolatey', 'Scoop')") |
            Should-BeTrue
    }
}
