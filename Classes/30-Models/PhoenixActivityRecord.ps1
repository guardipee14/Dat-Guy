class PhoenixActivityRecord {

    [string]$OperationId
    [string]$State
    [string]$Action
    [string]$Target
    [string]$Provider
    [string]$Description

    [int]$ProgressPercent
    [string]$ProgressMessage
    [string]$ProgressText

    [datetime]$CreatedAtUtc
    [datetime]$StartedAtUtc
    [datetime]$CompletedAtUtc
    [string]$StartedText
    [string]$ElapsedText

    [bool]$IsTerminal
    [PhoenixBackgroundOperation]$Operation

    [object]$ResultData
    [string]$ResultCode
    [string]$ErrorMessage
    [string[]]$Warnings
    [bool]$RequiresRestart

    PhoenixActivityRecord(
        [PhoenixBackgroundOperation]$Operation,
        [string]$Target,
        [string]$Provider
    ) {
        if ($null -eq $Operation) {
            throw 'An activity operation is required.'
        }

        $this.Operation = $Operation
        $this.OperationId = $Operation.OperationId
        $this.Action = $Operation.Action
        $this.Target = $Target
        $this.Provider = $Provider
        $this.Description = $Operation.Description
        $this.Warnings = @()

        $this.UpdateLifecycle()
    }

    [void] UpdateLifecycle() {
        $this.State = $this.Operation.State.ToString()
        $this.ProgressPercent =
            $this.Operation.ProgressPercent
        $this.ProgressMessage =
            $this.Operation.ProgressMessage
        $this.ProgressText = (
            '{0}% - {1}' -f
            $this.ProgressPercent,
            $this.ProgressMessage
        )

        $this.CreatedAtUtc =
            $this.Operation.CreatedAtUtc
        $this.StartedAtUtc =
            $this.Operation.StartedAtUtc
        $this.CompletedAtUtc =
            $this.Operation.CompletedAtUtc
        $this.IsTerminal =
            $this.Operation.IsTerminal()

        [datetime]$effectiveStart = if (
            $this.StartedAtUtc -gt [datetime]::MinValue
        ) {
            $this.StartedAtUtc
        }
        else {
            $this.CreatedAtUtc
        }

        $this.StartedText =
            $effectiveStart.ToLocalTime().ToString(
                'HH:mm:ss'
            )

        [datetime]$effectiveEnd = if (
            $this.CompletedAtUtc -gt [datetime]::MinValue
        ) {
            $this.CompletedAtUtc
        }
        else {
            [datetime]::UtcNow
        }

        [timespan]$elapsed =
            $effectiveEnd - $effectiveStart

        if ($elapsed -lt [timespan]::Zero) {
            $elapsed = [timespan]::Zero
        }

        $this.ElapsedText = (
            '{0:00}:{1:00}:{2:00}' -f
            [Math]::Floor($elapsed.TotalHours),
            $elapsed.Minutes,
            $elapsed.Seconds
        )

        $this.ErrorMessage =
            $this.Operation.ErrorMessage
    }

    [void] SetResult(
        [object]$Data,
        [string]$Error
    ) {
        $this.ResultData = $Data
        $this.ErrorMessage = $Error
    }
}
