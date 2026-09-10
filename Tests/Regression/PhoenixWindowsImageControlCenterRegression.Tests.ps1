BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $xaml = Get-Content (Join-Path $root 'Private\ControlCenter\PhoenixControlCenter.xaml') -Raw
    $desktop = Get-Content (Join-Path $root 'Private\ControlCenter\Show-PhoenixDesktop.ps1') -Raw
    $worker = Get-Content (Join-Path $root 'Tools\Invoke-PhoenixControlCenterWorker.ps1') -Raw
}
Describe 'Windows Image Control Center integration' -Tag @('Regression', 'WindowsImage', 'ControlCenter') {
    It 'binds the image page and every named input and action' {
        foreach ($name in @('WindowsImageNavButton','WindowsImagePage','WindowsImageSourceText','WindowsImageIndexText','WindowsImagePathText','WindowsImageSummaryText','ImageCreateButton','ImageInspectButton','ImageMountReadOnlyButton','ImageMountButton','ImageCommitButton','ImageDiscardButton','ImageRemoveButton')) {
            $xaml.Contains(('x:Name="{0}"' -f $name)) | Should-BeTrue
            $desktop.Contains("'$name'") | Should-BeTrue
        }
    }
    It 'queues image actions through a bounded serialized worker' {
        $desktop.Contains("-Action 'WindowsImage'") | Should-BeTrue
        $desktop.Contains("-ConcurrencyKey 'WindowsImageServicing'") | Should-BeTrue
        $desktop.Contains('-TimeoutSeconds 3600') | Should-BeTrue
        foreach ($name in @('New-PhoenixWindowsImageWorkspace','Get-PhoenixWindowsImageWorkspace','Mount-PhoenixWindowsImage','Dismount-PhoenixWindowsImage','Remove-PhoenixWindowsImageWorkspace')) {
            $worker.Contains($name) | Should-BeTrue
        }
    }
}
