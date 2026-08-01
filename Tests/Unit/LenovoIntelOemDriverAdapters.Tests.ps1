using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'Lenovo and Intel OEM driver adapters' -Tag @('Unit','Driver','OEM') {
    It 'registers Lenovo and Intel after manufacturer adapters' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Drivers\Invoke-PhoenixOemDriver.ps1'
        ) -Raw
        $hp = $source.IndexOf('[HpOemDriverAdapter]::new()')
        $lenovo = $source.IndexOf('[LenovoOemDriverAdapter]::new()')
        $intel = $source.IndexOf('[IntelOemDriverAdapter]::new()')
        ($lenovo -gt $hp) | Should-BeTrue
        ($intel -gt $lenovo) | Should-BeTrue
    }

    It 'gates Lenovo by computer manufacturer' {
        $adapter = [LenovoOemDriverAdapter]::new()
        $adapter.TestApplicable('LENOVO', @()) | Should-BeTrue
        $adapter.TestApplicable('Dell Inc.', @()) | Should-BeFalse
    }

    It 'gates Intel across computer brands by PCI vendor ID' {
        $adapter = [IntelOemDriverAdapter]::new()
        $adapter.TestApplicable('Contoso', @('PCI\VEN_8086&DEV_1234')) |
            Should-BeTrue
        $adapter.TestApplicable('Intel Corporation', @('PCI\VEN_10DE&DEV_1234')) |
            Should-BeFalse
    }

    It 'publishes official utility and support metadata' {
        $lenovo = [LenovoOemDriverAdapter]::new()
        $intel = [IntelOemDriverAdapter]::new()
        $lenovo.UtilityName | Should-Be 'Lenovo System Update'
        $intel.UtilityName | Should-Be 'Intel Driver & Support Assistant'
        ($lenovo.UtilityUri -match '^https://support\.lenovo\.com/') |
            Should-BeTrue
        ($intel.UtilityUri -match '^https://www\.intel\.com/') |
            Should-BeTrue
    }

    It 'uses unattended vendor scan and install command paths' {
        $lenovo = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\00-Base\LenovoOemDriverAdapter.ps1'
        ) -Raw
        $intel = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\00-Base\IntelOemDriverAdapter.ps1'
        ) -Raw
        $lenovo.Contains("'-action','LIST'") | Should-BeTrue
        $lenovo.Contains("'-action','INSTALL'") | Should-BeTrue
        $intel.Contains("@('/scan','/silent')") | Should-BeTrue
        $intel.Contains("@('/install','/silent','/norestart')") | Should-BeTrue
    }

    It 'normalizes unavailable utility approval results' {
        foreach ($adapter in @(
            [LenovoOemDriverAdapter]::new(),
            [IntelOemDriverAdapter]::new()
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
