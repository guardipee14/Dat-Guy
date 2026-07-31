function Remove-PhoenixBackgroundOperation {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PhoenixBackgroundOperation]$Operation
    )

    $cleanupErrors =
        [System.Collections.Generic.List[string]]::new()

    [bool]$timerStopped = $false
    [bool]$processDisposed = $false
    [bool]$directoryRemoved = $false

    if ($null -ne $Operation.Timer) {
        try {
            $Operation.Timer.Stop()
            $timerStopped = $true
        }
        catch {
            $cleanupErrors.Add(
                (
                    'Timer cleanup failed: {0}' -f
                    $_.Exception.Message
                )
            )
        }
        finally {
            $Operation.Timer = $null
        }
    }

    if ($null -ne $Operation.Process) {
        try {
            $Operation.Process.Dispose()
            $processDisposed = $true
        }
        catch {
            $cleanupErrors.Add(
                (
                    'Process cleanup failed: {0}' -f
                    $_.Exception.Message
                )
            )
        }
        finally {
            $Operation.Process = $null
        }
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            $Operation.JobDirectory
        )
    ) {
        try {
            if (
                Test-Path `
                    -LiteralPath $Operation.JobDirectory
            ) {
                Remove-Item `
                    -LiteralPath $Operation.JobDirectory `
                    -Recurse `
                    -Force `
                    -ErrorAction Stop
            }

            $directoryRemoved = $true
        }
        catch {
            $cleanupErrors.Add(
                (
                    'Job-directory cleanup failed: {0}' -f
                    $_.Exception.Message
                )
            )
        }
    }

    return [pscustomobject][ordered]@{
        OperationId      = $Operation.OperationId
        TimerStopped     = $timerStopped
        ProcessDisposed  = $processDisposed
        DirectoryRemoved = $directoryRemoved
        Errors           = $cleanupErrors.ToArray()
        Success          = $cleanupErrors.Count -eq 0
    }
}
