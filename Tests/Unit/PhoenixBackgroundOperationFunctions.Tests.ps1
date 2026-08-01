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

    $phoenixModule =
        Get-Module `
            -Name Phoenix `
            -ErrorAction Stop
}

Describe 'Phoenix background-operation functions' -Tag @(
    'Unit'
    'BackgroundOperation'
) {
    It 'allocates one isolated operation directory and file contract' {
        $operation =
            & $phoenixModule {
                param($Root)

                New-PhoenixBackgroundOperation `
                    -Action 'Inventory' `
                    -Parameters ([pscustomobject]@{}) `
                    -Component 'ControlCenter' `
                    -Description 'Collecting inventory...' `
                    -Completion {} `
                    -ProjectRoot $Root
            } $projectRoot

        try {
            $operation.State.ToString() |
                Should-Be 'Created'

            Test-Path `
                -LiteralPath $operation.JobDirectory `
                -PathType Container |
                Should-BeTrue

            Split-Path `
                -Leaf `
                $operation.JobDirectory |
                Should-Be $operation.OperationId

            Split-Path `
                -Leaf `
                $operation.RequestPath |
                Should-Be 'request.json'

            Split-Path `
                -Leaf `
                $operation.ProgressPath |
                Should-Be 'progress.json'

            Split-Path `
                -Leaf `
                $operation.ResultPath |
                Should-Be 'result.json'
        }
        finally {
            $null =
                & $phoenixModule {
                    param($Operation)

                    Remove-PhoenixBackgroundOperation `
                        -Operation $Operation
                } $operation
        }
    }


    It 'constructs an operation through a module-bound adapter closure' {
        $operation =
            & $phoenixModule {
                param($Root)

                $module =
                    $ExecutionContext.SessionState.Module

                $boundCommand =
                    $module.NewBoundScriptBlock({
                        [CmdletBinding()]
                        param(
                            [string]$Action,
                            [object]$Parameters,
                            [string]$Component,
                            [string]$Description,
                            [scriptblock]$Completion,
                            [string]$ProjectRoot
                        )

                        New-PhoenixBackgroundOperation `
                            @PSBoundParameters
                    })

                $callback = {
                    & $boundCommand `
                        -Action 'ClosureTest' `
                        -Parameters ([pscustomobject]@{}) `
                        -Component 'Tests' `
                        -Description 'Testing module adapter closure...' `
                        -Completion {} `
                        -ProjectRoot $Root
                }.GetNewClosure()

                & $callback
            } $projectRoot

        try {
            $operation.GetType().Name |
                Should-Be 'PhoenixBackgroundOperation'

            $operation.State.ToString() |
                Should-Be 'Created'

            Test-Path `
                -LiteralPath $operation.JobDirectory `
                -PathType Container |
                Should-BeTrue
        }
        finally {
            $null =
                & $phoenixModule {
                    param($Operation)

                    Remove-PhoenixBackgroundOperation `
                        -Operation $Operation
                } $operation
        }
    }

    It 'starts a queued worker and receives its atomic result' {
        [string]$workerPath =
            Join-Path `
                $TestDrive `
                'SuccessfulWorker.ps1'

        @'
[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$RequestPath,
    [string]$ProgressPath,
    [string]$ResultPath
)

[pscustomobject]@{
    Percent = 65
    Message = 'Worker progress'
} |
    ConvertTo-Json |
    Set-Content `
        -LiteralPath $ProgressPath `
        -Encoding UTF8

[pscustomobject]@{
    Success = $true
    Data = [pscustomobject]@{
        Value = 'Worker result'
    }
    Error = ''
} |
    ConvertTo-Json -Depth 5 |
    Set-Content `
        -LiteralPath $ResultPath `
        -Encoding UTF8
'@ |
            Set-Content `
                -LiteralPath $workerPath `
                -Encoding UTF8

        $operation =
            & $phoenixModule {
                param($Root)

                New-PhoenixBackgroundOperation `
                    -Action 'TestAction' `
                    -Parameters ([pscustomobject]@{}) `
                    -Component 'Tests' `
                    -Description 'Running test worker...' `
                    -Completion {} `
                    -ProjectRoot $Root
            } $projectRoot

        $operation.MarkQueued()

        $operation.State.ToString() |
            Should-Be 'Queued'

        try {
            $null =
                & $phoenixModule {
                    param(
                        $Operation,
                        $Root,
                        $Worker
                    )

                    Start-PhoenixBackgroundOperation `
                        -Operation $Operation `
                        -ProjectRoot $Root `
                        -WorkerPath $Worker
                } `
                    $operation `
                    $projectRoot `
                    $workerPath

            $received = $null

            for (
                [int]$attempt = 0;
                $attempt -lt 50;
                $attempt++
            ) {
                Start-Sleep `
                    -Milliseconds 100

                $received =
                    & $phoenixModule {
                        param($Operation)

                        Receive-PhoenixBackgroundOperation `
                            -Operation $Operation
                    } $operation

                if ($received.IsCompleted) {
                    break
                }
            }

            $received.IsCompleted |
                Should-BeTrue

            $received.Success |
                Should-BeTrue

            $received.Data.Value |
                Should-Be 'Worker result'

            $operation.State.ToString() |
                Should-Be 'Completed'
        }
        finally {
            $null =
                & $phoenixModule {
                    param($Operation)

                    Remove-PhoenixBackgroundOperation `
                        -Operation $Operation
                } $operation
        }
    }

    It 'receives progress only when its value changes' {
        $operation =
            & $phoenixModule {
                param($Root)

                New-PhoenixBackgroundOperation `
                    -Action 'Progress' `
                    -Parameters ([pscustomobject]@{}) `
                    -Component 'Tests' `
                    -Description 'Testing progress...' `
                    -Completion {} `
                    -ProjectRoot $Root
            } $projectRoot

        try {
            $operation.MarkStarting()
            $operation.Process =
                Get-Process -Id $PID
            $operation.MarkRunning()

            [pscustomobject]@{
                Percent = 42
                Message = 'Testing progress update'
            } |
                ConvertTo-Json |
                Set-Content `
                    -LiteralPath $operation.ProgressPath `
                    -Encoding UTF8

            $first =
                & $phoenixModule {
                    param($Operation)

                    Receive-PhoenixBackgroundOperation `
                        -Operation $Operation
                } $operation

            $second =
                & $phoenixModule {
                    param($Operation)

                    Receive-PhoenixBackgroundOperation `
                        -Operation $Operation
                } $operation

            $first.ProgressChanged |
                Should-BeTrue

            $first.Percent |
                Should-Be 42

            $second.ProgressChanged |
                Should-BeFalse
        }
        finally {
            if (-not $operation.IsTerminal()) {
                $operation.MarkFailed(
                    'Unit-test cleanup'
                )
            }

            $null =
                & $phoenixModule {
                    param($Operation)

                    Remove-PhoenixBackgroundOperation `
                        -Operation $Operation
                } $operation
        }
    }

    It 'fails a worker that exits without publishing a result' {
        $operation =
            & $phoenixModule {
                param($Root)

                New-PhoenixBackgroundOperation `
                    -Action 'MissingResult' `
                    -Parameters ([pscustomobject]@{}) `
                    -Component 'Tests' `
                    -Description 'Testing missing result...' `
                    -Completion {} `
                    -ProjectRoot $Root
            } $projectRoot

        $startInfo =
            [System.Diagnostics.ProcessStartInfo]::new()

        $startInfo.FileName =
            (Get-Process -Id $PID).Path

        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.ArgumentList.Add('-NoLogo')
        $startInfo.ArgumentList.Add('-NoProfile')
        $startInfo.ArgumentList.Add('-Command')
        $startInfo.ArgumentList.Add('exit 7')

        $process =
            [System.Diagnostics.Process]::Start(
                $startInfo
            )

        try {
            $operation.MarkStarting()
            $operation.Process = $process
            $operation.MarkRunning()

            $process.WaitForExit()

            $received =
                & $phoenixModule {
                    param($Operation)

                    Receive-PhoenixBackgroundOperation `
                        -Operation $Operation
                } $operation

            $received.IsCompleted |
                Should-BeTrue

            $received.Success |
                Should-BeFalse

            $received.Error |
                Should-MatchString (
                    'exited without publishing a result'
                )

            $operation.State.ToString() |
                Should-Be 'Failed'
        }
        finally {
            $null =
                & $phoenixModule {
                    param($Operation)

                    Remove-PhoenixBackgroundOperation `
                        -Operation $Operation
                } $operation
        }
    }

    It 'cancels and cleans up an active worker process' {
        $operation =
            & $phoenixModule {
                param($Root)

                New-PhoenixBackgroundOperation `
                    -Action 'Cancellation' `
                    -Parameters ([pscustomobject]@{}) `
                    -Component 'Tests' `
                    -Description 'Testing cancellation...' `
                    -Completion {} `
                    -ProjectRoot $Root
            } $projectRoot

        $startInfo =
            [System.Diagnostics.ProcessStartInfo]::new()

        $startInfo.FileName =
            (Get-Process -Id $PID).Path

        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.ArgumentList.Add('-NoLogo')
        $startInfo.ArgumentList.Add('-NoProfile')
        $startInfo.ArgumentList.Add('-Command')
        $startInfo.ArgumentList.Add(
            'Start-Sleep -Seconds 30'
        )

        $process =
            [System.Diagnostics.Process]::Start(
                $startInfo
            )

        $operation.MarkStarting()
        $operation.Process = $process
        $operation.MarkRunning()

        $null =
            & $phoenixModule {
                param($Operation)

                Stop-PhoenixBackgroundOperation `
                    -Operation $Operation
            } $operation

        $cleanup =
            & $phoenixModule {
                param($Operation)

                Remove-PhoenixBackgroundOperation `
                    -Operation $Operation
            } $operation

        $operation.State.ToString() |
            Should-Be 'Cancelled'

        $operation.CancellationRequested |
            Should-BeTrue

        $cleanup.Success |
            Should-BeTrue

        Test-Path `
            -LiteralPath $operation.JobDirectory |
            Should-BeFalse
    }
}
