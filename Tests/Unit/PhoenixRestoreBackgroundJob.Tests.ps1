using module ..\..\Classes\Phoenix.Classes.psm1

BeforeAll {
    $projectRoot = (
        Resolve-Path (
            Join-Path `
                $PSScriptRoot `
                '..\..'
        )
    ).Path

    $modulePath =
        Join-Path `
            $projectRoot `
            'Phoenix.psd1'

    Import-Module `
        -Name $modulePath `
        -Force `
        -ErrorAction Stop
}

Describe 'Phoenix restore background jobs' -Tag @(
    'Unit'
    'BackgroundOperation'
    'Restore'
) {
    It 'runs a restore request through the public background-job facade' {
        [string]$manifestPath =
            Join-Path `
                $TestDrive `
                'restore.json'

        '{}' |
            Set-Content `
                -LiteralPath $manifestPath `
                -Encoding UTF8

        [string]$workerPath =
            Join-Path `
                $TestDrive `
                'RestoreWorker.ps1'

        @'
[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$RequestPath,
    [string]$ProgressPath,
    [string]$ResultPath
)

$request =
    Get-Content -LiteralPath $RequestPath -Raw |
    ConvertFrom-Json

[pscustomobject]@{
    Success = $true
    Data = [pscustomobject]@{
        Action = $request.Action
        ManifestPath = $request.Parameters.ManifestPath
        SkipDrivers = $request.Parameters.SkipDrivers
    }
    Error = ''
} |
    ConvertTo-Json -Depth 8 |
    Set-Content -LiteralPath $ResultPath -Encoding UTF8
'@ |
            Set-Content `
                -LiteralPath $workerPath `
                -Encoding UTF8

        $operation =
            Start-PhoenixRestoreJob `
                -ManifestPath $manifestPath `
                -SkipDrivers `
                -ProjectRoot $projectRoot `
                -WorkerPath $workerPath `
                -Confirm:$false

        [string]$jobDirectory =
            $operation.JobDirectory

        $received =
            Receive-PhoenixJob `
                -Operation $operation `
                -Wait `
                -PollIntervalMilliseconds 50

        $received.IsCompleted |
            Should-BeTrue

        $received.Success |
            Should-BeTrue

        $received.Data.Action |
            Should-Be 'RestoreAction'

        $received.Data.ManifestPath |
            Should-Be $manifestPath

        $received.Data.SkipDrivers |
            Should-BeTrue

        $operation.State.ToString() |
            Should-Be 'Completed'

        Test-Path -LiteralPath $jobDirectory |
            Should-BeFalse
    }

    It 'cancels and cleans up a restore background job' {
        [string]$manifestPath =
            Join-Path `
                $TestDrive `
                'cancel-restore.json'

        '{}' |
            Set-Content `
                -LiteralPath $manifestPath `
                -Encoding UTF8

        [string]$workerPath =
            Join-Path `
                $TestDrive `
                'SlowRestoreWorker.ps1'

        @'
[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$RequestPath,
    [string]$ProgressPath,
    [string]$ResultPath
)

Start-Sleep -Seconds 30
'@ |
            Set-Content `
                -LiteralPath $workerPath `
                -Encoding UTF8

        $operation =
            Start-PhoenixRestoreJob `
                -ManifestPath $manifestPath `
                -SkipDrivers `
                -ProjectRoot $projectRoot `
                -WorkerPath $workerPath `
                -Confirm:$false

        [string]$jobDirectory =
            $operation.JobDirectory

        $stopped =
            Stop-PhoenixJob `
                -Operation $operation `
                -Confirm:$false

        $stopped.State.ToString() |
            Should-Be 'Cancelled'

        $stopped.IsTerminal() |
            Should-BeTrue

        Test-Path -LiteralPath $jobDirectory |
            Should-BeFalse
    }

    It 'rejects a restore job with no selected workload' {
        [string]$manifestPath =
            Join-Path `
                $TestDrive `
                'empty-restore.json'

        '{}' |
            Set-Content `
                -LiteralPath $manifestPath `
                -Encoding UTF8

        {
            Start-PhoenixRestoreJob `
                -ManifestPath $manifestPath `
                -SkipDrivers `
                -SkipPackages `
                -Confirm:$false
        } |
            Should-Throw
    }
}
