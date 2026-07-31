function Stop-PhoenixBackgroundOperation {

    [CmdletBinding()]
    [OutputType([PhoenixBackgroundOperation])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PhoenixBackgroundOperation]$Operation,

        [Parameter()]
        [bool]$KillTree = $true
    )

    if ($Operation.IsTerminal()) {
        return $Operation
    }

    if (-not $Operation.CanCancel()) {
        throw (
            "Operation '$($Operation.OperationId)' cannot be " +
            "cancelled from state '$($Operation.State)'."
        )
    }

    $Operation.RequestCancellation()

    if ($null -ne $Operation.Timer) {
        try {
            $Operation.Timer.Stop()
        }
        catch {
            Write-Verbose (
                'The background-operation timer could not be stopped: {0}' -f
                $_.Exception.Message
            )
        }
    }

    try {
        if ($null -ne $Operation.Process) {
            $Operation.Process.Refresh()

            if (-not $Operation.Process.HasExited) {
                $Operation.Process.Kill(
                    $KillTree
                )

                [void]$Operation.Process.WaitForExit(
                    5000
                )
            }
        }

        $Operation.MarkCancelled()

        return $Operation
    }
    catch {
        [string]$message = (
            'The background worker could not be stopped: {0}' -f
            $_.Exception.Message
        )

        if (-not $Operation.IsTerminal()) {
            $Operation.MarkFailed(
                $message
            )
        }

        throw $message
    }
}
