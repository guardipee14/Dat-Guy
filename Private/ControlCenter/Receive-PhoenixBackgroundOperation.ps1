function Receive-PhoenixBackgroundOperation {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PhoenixBackgroundOperation]$Operation
    )

    [bool]$progressChanged = $false
    [bool]$isCompleted =
        $Operation.IsTerminal()

    [object]$data = $null
    [object]$success = $null
    [string]$errorMessage =
        $Operation.ErrorMessage

    if (
        -not $isCompleted -and
        $Operation.State -eq
            [PhoenixBackgroundOperationState]::Running -and
        $Operation.TimeoutSeconds -gt 0 -and
        $Operation.StartedAtUtc -gt [datetime]::MinValue -and
        (
            [datetime]::UtcNow - $Operation.StartedAtUtc
        ).TotalSeconds -ge $Operation.TimeoutSeconds
    ) {
        $errorMessage = (
            'The background operation exceeded its {0}-second timeout.' -f
            $Operation.TimeoutSeconds
        )

        if ($null -ne $Operation.Process) {
            try {
                $Operation.Process.Refresh()

                if (-not $Operation.Process.HasExited) {
                    try {
                        $Operation.Process.Kill($true)
                    }
                    catch {
                        $Operation.Process.Kill()
                    }

                    $null = $Operation.Process.WaitForExit(5000)
                }
            }
            catch {
                $errorMessage += (
                    ' The worker could not be stopped cleanly: {0}' -f
                    $_.Exception.Message
                )
            }
        }

        $Operation.MarkTimedOut($errorMessage)
        $success = $false
        $isCompleted = $true
    }

    if (
        -not $isCompleted -and
        $Operation.State -eq
            [PhoenixBackgroundOperationState]::Running -and
        (
            Test-Path `
                -LiteralPath $Operation.ProgressPath `
                -PathType Leaf
        )
    ) {
        try {
            $progress =
                Get-Content `
                    -LiteralPath $Operation.ProgressPath `
                    -Raw `
                    -ErrorAction Stop |
                ConvertFrom-Json `
                    -ErrorAction Stop

            [int]$percent =
                [Math]::Max(
                    0,
                    [Math]::Min(
                        100,
                        [int]$progress.Percent
                    )
                )

            [string]$message =
                [string]$progress.Message

            [string]$progressKey = (
                '{0}|{1}' -f
                $percent,
                $message
            )

            if (
                $progressKey -ne
                $Operation.LastProgressKey
            ) {
                $Operation.UpdateProgress(
                    $percent,
                    $message
                )

                $progressChanged = $true
            }
        }
        catch {
            # The worker publishes progress through an atomic replacement.
            # A transient read failure is retried on the next polling tick.
        }
    }

    if (
        -not $isCompleted -and
        (
            Test-Path `
                -LiteralPath $Operation.ResultPath `
                -PathType Leaf
        )
    ) {
        try {
            $envelope =
                Get-Content `
                    -LiteralPath $Operation.ResultPath `
                    -Raw `
                    -ErrorAction Stop |
                ConvertFrom-Json `
                    -ErrorAction Stop

            if ([bool]$envelope.Success) {
                $data =
                    $envelope.Data

                $Operation.MarkCompleted()

                $success = $true
            }
            else {
                $errorMessage =
                    [string]$envelope.Error

                if (
                    [string]::IsNullOrWhiteSpace(
                        $errorMessage
                    )
                ) {
                    $errorMessage =
                        'The background worker reported an unspecified failure.'
                }

                $Operation.MarkFailed(
                    $errorMessage
                )

                $success = $false
            }
        }
        catch {
            $errorMessage = (
                'The background worker result could not be read: {0}' -f
                $_.Exception.Message
            )

            $Operation.MarkFailed(
                $errorMessage
            )

            $success = $false
        }

        $isCompleted = $true
    }

    if (-not $isCompleted) {
        if ($null -eq $Operation.Process) {
            $errorMessage =
                'The running background operation does not have a worker process.'

            $Operation.MarkFailed(
                $errorMessage
            )

            $success = $false
            $isCompleted = $true
        }
        else {
            try {
                $Operation.Process.Refresh()

                if ($Operation.Process.HasExited) {
                    [string]$exitDetail = ''

                    try {
                        $exitDetail = (
                            ' Exit code: {0}.' -f
                            $Operation.Process.ExitCode
                        )
                    }
                    catch {
                        $exitDetail = ''
                    }

                    $errorMessage = (
                        'The background worker exited without publishing ' +
                        'a result.' +
                        $exitDetail
                    )

                    $Operation.MarkFailed(
                        $errorMessage
                    )

                    $success = $false
                    $isCompleted = $true
                }
            }
            catch {
                $errorMessage = (
                    'The background worker state could not be read: {0}' -f
                    $_.Exception.Message
                )

                $Operation.MarkFailed(
                    $errorMessage
                )

                $success = $false
                $isCompleted = $true
            }
        }
    }

    if (
        $isCompleted -and
        $null -eq $success
    ) {
        $success = (
            $Operation.State -eq
            [PhoenixBackgroundOperationState]::Completed
        )
    }

    return [pscustomobject][ordered]@{
        OperationId     = $Operation.OperationId
        State           = $Operation.State.ToString()
        ProgressChanged = $progressChanged
        Percent         = $Operation.ProgressPercent
        Message         = $Operation.ProgressMessage
        IsCompleted     = $isCompleted
        Success         = $success
        TimedOut        = $Operation.TimedOut
        RetryCount      = $Operation.RetryCount
        Data            = $data
        Error           = $errorMessage
    }
}
