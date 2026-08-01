using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'Dell and HP OEM driver adapters' -Tag @('Unit','Driver','OEM') {
    It 'registers Dell and HP adapters in deterministic order' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\Drivers\Invoke-PhoenixOemDriver.ps1'
        ) -Raw
        $dellIndex = $source.IndexOf('[DellOemDriverAdapter]::new()')
        $hpIndex = $source.IndexOf('[HpOemDriverAdapter]::new()')
        ($dellIndex -ge 0) | Should-BeTrue
        ($hpIndex -gt $dellIndex) | Should-BeTrue
    }

    It 'gates Dell operations to Dell hardware' {
        $adapter = [DellOemDriverAdapter]::new()
        $adapter.TestApplicable('Dell Inc.', @()) | Should-BeTrue
        $adapter.TestApplicable('HP', @()) | Should-BeFalse
    }

    It 'gates HP operations to HP hardware' {
        $adapter = [HpOemDriverAdapter]::new()
        $adapter.TestApplicable('Hewlett-Packard', @()) | Should-BeTrue
        $adapter.TestApplicable('Dell Inc.', @()) | Should-BeFalse
    }

    It 'publishes approval and official utility metadata' {
        $dell = [DellOemDriverAdapter]::new()
        $hp = [HpOemDriverAdapter]::new()
        $dell.RequiresUtilityApproval | Should-BeTrue
        $hp.RequiresUtilityApproval | Should-BeTrue
        $dell.UtilityName | Should-Be 'Dell Command | Update'
        $hp.UtilityName | Should-Be 'HP Image Assistant'
        ($dell.UtilityUri -match '^https://www\.dell\.com/') | Should-BeTrue
        ($hp.UtilityUri -match '^https://ftp\.ext\.hp\.com/') | Should-BeTrue
    }

    It 'uses isolated vendor scan and install command paths' {
        $dell = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\00-Base\DellOemDriverAdapter.ps1'
        ) -Raw
        $hp = Get-Content (
            Join-Path $PSScriptRoot '..\..\Classes\00-Base\HpOemDriverAdapter.ps1'
        ) -Raw
        $dell.Contains("'/scan','-silent'") | Should-BeTrue
        $dell.Contains("'/applyUpdates','-silent','-reboot=disable'") |
            Should-BeTrue
        $hp.Contains("'/Operation:Analyze','/Action:List','/Silent'") |
            Should-BeTrue
        $hp.Contains("'/Operation:Analyze','/Action:Install','/Silent'") |
            Should-BeTrue
    }

    It 'returns normalized approval results when utilities are unavailable' {
        foreach ($adapter in @(
            [DellOemDriverAdapter]::new(),
            [HpOemDriverAdapter]::new()
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
