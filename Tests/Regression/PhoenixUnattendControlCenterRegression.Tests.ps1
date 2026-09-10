BeforeAll {
    $root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $xaml=Get-Content (Join-Path $root 'Private\ControlCenter\PhoenixControlCenter.xaml') -Raw
    $desktop=Get-Content (Join-Path $root 'Private\ControlCenter\Show-PhoenixDesktop.ps1') -Raw
    $worker=Get-Content (Join-Path $root 'Tools\Invoke-PhoenixControlCenterWorker.ps1') -Raw
}
Describe 'Unattended Setup Control Center integration' -Tag @('Regression','ControlCenter','Unattend') {
    It 'binds every unattended setup control' {
        foreach ($name in @('UnattendedSetupNavButton','UnattendedSetupPage','UnattendComputerNameText','UnattendLocaleText','UnattendTimeZoneText','UnattendLocalAccountText','UnattendOutputPathText','GenerateUnattendButton','UnattendStatusText')) {
            $xaml.Contains(('x:Name="{0}"' -f $name)) | Should-BeTrue
            $desktop.Contains("'$name'") | Should-BeTrue
        }
    }
    It 'keeps answer-file background work secret-free and serialized' {
        $desktop.Contains("-Action 'UnattendGenerate'") | Should-BeTrue
        $desktop.Contains("-ConcurrencyKey 'AnswerFile'") | Should-BeTrue
        $worker.Contains('New-PhoenixUnattendFile') | Should-BeTrue
        $worker.Contains('-IncludeSecrets') | Should-BeFalse
        $worker.Contains('-LocalAccountPassword') | Should-BeFalse
    }
}
