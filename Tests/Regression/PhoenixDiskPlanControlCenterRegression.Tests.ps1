BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $xaml = Get-Content (Join-Path $root 'Private\ControlCenter\PhoenixControlCenter.xaml') -Raw
    $desktop = Get-Content (Join-Path $root 'Private\ControlCenter\Show-PhoenixDesktop.ps1') -Raw
    $worker = Get-Content (Join-Path $root 'Tools\Invoke-PhoenixControlCenterWorker.ps1') -Raw
}
Describe 'Read-only disk preview Control Center integration' -Tag @('Regression','ControlCenter','DiskPlan') {
    It 'binds every disk preview control and requires an explicit target' {
        foreach ($name in @('DiskPlanNavButton','DiskPlanPage','DiskPlanNumberText','PreviewDiskPlanButton','DiskPlanSummaryText')) {
            $xaml.Contains(('x:Name="{0}"' -f $name)) | Should-BeTrue
            $desktop.Contains("'$name'") | Should-BeTrue
        }
        $xaml.Contains('x:Name="DiskPlanNumberText" />') | Should-BeTrue
        $desktop.Contains('[int]::TryParse') | Should-BeTrue
    }
    It 'uses a background read-only action with no deployment command exported' {
        $desktop.Contains("-Action 'DiskPlanPreview'") | Should-BeTrue
        $desktop.Contains("-ConcurrencyKey 'DiskPreview'") | Should-BeTrue
        $worker.Contains('New-PhoenixDiskPlan -DiskNumber') | Should-BeTrue
        $worker.Contains('Show-PhoenixDiskPlan -Plan') | Should-BeTrue
        (Test-Path (Join-Path $root 'Public\Invoke-PhoenixDeployment.ps1')) | Should-BeFalse
        foreach ($source in @('Public\New-PhoenixDiskPlan.ps1','Public\Show-PhoenixDiskPlan.ps1')) {
            $text = Get-Content (Join-Path $root $source) -Raw
            foreach ($mutation in @('Clear-Disk','Initialize-Disk','New-Partition','Format-Volume','diskpart.exe','Invoke-PhoenixDeployment')) {
                $text.Contains($mutation) | Should-BeFalse
            }
        }
    }
}
