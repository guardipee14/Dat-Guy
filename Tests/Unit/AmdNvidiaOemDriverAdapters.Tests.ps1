using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'AMD and NVIDIA OEM driver adapters' -Tag @('Unit','Driver','OEM') {
    It 'registers AMD and NVIDIA after platform adapters' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Drivers\Invoke-PhoenixOemDriver.ps1'
        ) -Raw
        $intel = $source.IndexOf('[IntelOemDriverAdapter]::new()')
        $amd = $source.IndexOf('[AmdOemDriverAdapter]::new()')
        $nvidia = $source.IndexOf('[NvidiaOemDriverAdapter]::new()')
        ($amd -gt $intel) | Should-BeTrue
        ($nvidia -gt $amd) | Should-BeTrue
    }

    It 'gates AMD by PCI vendor ID on any computer brand' {
        $adapter = [AmdOemDriverAdapter]::new()
        $adapter.TestApplicable('Contoso', @('PCI\VEN_1002&DEV_73BF')) |
            Should-BeTrue
        $adapter.TestApplicable('AMD', @('PCI\VEN_10DE&DEV_1234')) |
            Should-BeFalse
    }

    It 'gates NVIDIA by PCI vendor ID on any computer brand' {
        $adapter = [NvidiaOemDriverAdapter]::new()
        $adapter.TestApplicable('Contoso', @('PCI\VEN_10DE&DEV_2684')) |
            Should-BeTrue
        $adapter.TestApplicable('NVIDIA', @('PCI\VEN_1002&DEV_1234')) |
            Should-BeFalse
    }

    It 'publishes official utility and support metadata' {
        $amd = [AmdOemDriverAdapter]::new()
        $nvidia = [NvidiaOemDriverAdapter]::new()
        $amd.UtilityName | Should-Be 'AMD Software: Adrenalin Edition'
        $nvidia.UtilityName | Should-Be 'NVIDIA App'
        ($amd.UtilityUri -match '^https://www\.amd\.com/') | Should-BeTrue
        ($nvidia.UtilityUri -match '^https://www\.nvidia\.com/') | Should-BeTrue
    }

    It 'uses non-restarting vendor scan and install command paths' {
        $amd = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\00-Base\AmdOemDriverAdapter.ps1'
        ) -Raw
        $nvidia = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\00-Base\NvidiaOemDriverAdapter.ps1'
        ) -Raw
        $amd.Contains("@('-CheckForUpdates','-Silent')") | Should-BeTrue
        $amd.Contains("'-NoRestart'") | Should-BeTrue
        $nvidia.Contains("@('--check-for-updates','--silent')") | Should-BeTrue
        $nvidia.Contains("'--no-restart'") | Should-BeTrue
    }

    It 'normalizes unavailable utility approval results' {
        foreach ($adapter in @(
            [AmdOemDriverAdapter]::new(),
            [NvidiaOemDriverAdapter]::new()
        )) {
            $adapter.UtilityAvailable = $false
            $update = [PhoenixOemDriverUpdate]::new()
            $update.Id = "$($adapter.Name)-Recommended"
            $result = $adapter.Install($update)
            $result.Success | Should-BeFalse
            $result.Code | Should-Be 'PHX_OEM_UTILITY_APPROVAL_REQUIRED'
            $result.Provider | Should-Be $adapter.Name
        }
    }
}
