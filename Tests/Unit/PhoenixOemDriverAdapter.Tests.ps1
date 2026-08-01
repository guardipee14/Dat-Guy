using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'Phoenix OEM driver adapter framework' -Tag @('Unit','Driver','OEM') {
    It 'matches manufacturer and applicable hardware prefixes' {
        $adapter = [PhoenixOemDriverAdapter]::new(
            'Example',
            @('Contoso'),
            @('PCI\VEN_1234')
        )

        $adapter.TestApplicable('Contoso Computer', @('PCI\VEN_1234&DEV_1')) |
            Should-BeTrue
        $adapter.TestApplicable('Fabrikam', @('PCI\VEN_1234&DEV_1')) |
            Should-BeFalse
        $adapter.TestApplicable('Contoso Computer', @('PCI\VEN_9999')) |
            Should-BeFalse
    }

    It 'publishes the common installed available source and release contract' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\00-Base\PhoenixOemDriverUpdate.ps1'
        ) -Raw
        foreach ($property in @(
            'InstalledVersion','AvailableVersion','Source','ReleaseDate',
            'ReleaseNotes','SupportUrl','DownloadUri','RebootRequired'
        )) { $source.Contains("`$$property") | Should-BeTrue }
    }

    It 'requires approval before unavailable OEM utilities' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Drivers\Invoke-PhoenixOemDriver.ps1'
        ) -Raw
        $source.Contains('RequiresUtilityApproval') | Should-BeTrue
        $source.Contains('PHX_OEM_UTILITY_APPROVAL_REQUIRED') |
            Should-BeTrue
        $source.Contains('ApproveUtility') | Should-BeTrue
    }

    It 'uses Windows Update when no applicable OEM adapter exists' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Drivers\Invoke-PhoenixOemDriver.ps1'
        ) -Raw
        $source.Contains('Invoke-PhoenixControlCenterDriverAction') |
            Should-BeTrue
        $source.Contains('-Action ScanUpdates') | Should-BeTrue
    }

    It 'routes OEM work through the isolated background operation system' {
        $manager = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Drivers\Invoke-PhoenixOemDriver.ps1'
        ) -Raw
        $worker = Get-Content (
            Join-Path $PSScriptRoot '..\..\Tools\Invoke-PhoenixControlCenterWorker.ps1'
        ) -Raw
        $manager.Contains('New-PhoenixBackgroundOperation') | Should-BeTrue
        $manager.Contains('Start-PhoenixBackgroundOperation') | Should-BeTrue
        $worker.Contains("'OemDriverAction'") | Should-BeTrue
    }

    It 'exposes adapter status to Drivers and Activity UI consumers' {
        $inventory = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Get-PhoenixControlCenterInventory.ps1'
        ) -Raw
        $inventory.Contains('OemAdapters') | Should-BeTrue
        $inventory.Contains('Get-PhoenixOemAdapterStatus') | Should-BeTrue
    }
}
