using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'Phoenix Restore Plan UI and persistence' -Tag @('Unit','Restore','UI') {
    BeforeAll {
        $script:desktopSource = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\Show-PhoenixDesktop.ps1'
        ) -Raw
        $script:xamlSource = Get-Content (
            Join-Path $PSScriptRoot '..\..\Private\ControlCenter\PhoenixControlCenter.xaml'
        ) -Raw
    }

    It 'ships a dedicated Restore Plan page and navigation entry' {
        foreach ($name in @(
            'RestorePlanNavButton','RestorePlanPage','RestoreManifestPathText',
            'CreateRestoreManifestButton','RestorePlanGrid',
            'RestorePlanSummaryText'
        )) {
            $script:xamlSource.Contains("x:Name=`"$name`"") | Should-BeTrue
            $script:desktopSource.Contains("'$name'") | Should-BeTrue
        }
    }

    It 'supports individual grouped and filtered selection' {
        $script:xamlSource.Contains('Binding="{Binding Selected, Mode=TwoWay}"') |
            Should-BeTrue
        foreach ($name in @(
            'RestoreRecordTypeFilter','RestoreProviderFilter',
            'RestoreActionFilter','SelectVisibleRestoreButton',
            'ClearRestoreSelectionButton'
        )) { $script:desktopSource.Contains($name) | Should-BeTrue }
    }

    It 'allows eligible applications to change to provider alternatives' {
        $script:desktopSource.Contains('ProviderAlternatives') | Should-BeTrue
        $script:desktopSource.Contains('ApplyRestoreProviderButton') |
            Should-BeTrue
        $script:desktopSource.Contains("RecordType -eq 'Application'") |
            Should-BeTrue
    }

    It 'builds plans in the isolated background worker' {
        $worker = Get-Content (
            Join-Path $PSScriptRoot '..\..\Tools\Invoke-PhoenixControlCenterWorker.ps1'
        ) -Raw
        $worker.Contains("'RestorePlan'") | Should-BeTrue
        $worker.Contains('New-PhoenixRestorePlan') | Should-BeTrue
        $script:desktopSource.Contains("-Action 'RestorePlan'") | Should-BeTrue
    }

    It 'creates restore manifests in the isolated background worker' {
        $worker = Get-Content (
            Join-Path $PSScriptRoot '..\..\Tools\Invoke-PhoenixControlCenterWorker.ps1'
        ) -Raw
        $script:xamlSource.Contains(
            'x:Name="CreateRestoreManifestButton"'
        ) | Should-BeTrue
        $worker.Contains("'Backup'") | Should-BeTrue
        $worker.Contains('Backup-Phoenix') | Should-BeTrue
        $script:desktopSource.Contains("-Action 'Backup'") | Should-BeTrue
        $script:desktopSource.Contains(
            'RestoreManifestPathText.Text ='
        ) | Should-BeTrue
    }

    It 'captures delayed inventory filter callbacks explicitly' {
        $script:desktopSource.Contains(
            '$inventoryPopulateProviderFilters ='
        ) | Should-BeTrue
        $script:desktopSource.Contains(
            '$inventoryApplyApplicationFilter ='
        ) | Should-BeTrue
        $script:desktopSource.Contains(
            '& $inventoryPopulateProviderFilters'
        ) | Should-BeTrue
        $script:desktopSource.Contains(
            '& $inventoryApplyApplicationFilter'
        ) | Should-BeTrue
    }

    It 'saves atomically and validates saved plan schema versions' {
        $save = Get-Content (
            Join-Path $PSScriptRoot '..\..\Public\Save-PhoenixRestorePlan.ps1'
        ) -Raw
        $load = Get-Content (
            Join-Path $PSScriptRoot '..\..\Public\Import-PhoenixRestorePlan.ps1'
        ) -Raw
        $save.Contains('.tmp') | Should-BeTrue
        $save.Contains('Move-Item') | Should-BeTrue
        $load.Contains("'PhoenixRestorePlan'") | Should-BeTrue
        $load.Contains("[version]'2.0'") | Should-BeTrue
    }

    It 'exports save and reload commands through both module layers' {
        foreach ($path in @('Phoenix.psm1','Phoenix.psd1')) {
            $source = Get-Content (Join-Path $PSScriptRoot "..\..\$path") -Raw
            $source.Contains("'Save-PhoenixRestorePlan'") | Should-BeTrue
            $source.Contains("'Import-PhoenixRestorePlan'") | Should-BeTrue
        }
    }
}
