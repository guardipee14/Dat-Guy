enum PhoenixBackgroundOperationState {
    Created
    Queued
    Starting
    Running
    CancellationRequested
    Cancelled
    Completed
    Failed
}

class PhoenixBackgroundOperation {

    [string]$OperationId
    [string]$Action
    [object]$Parameters
    [string]$Component
    [string]$Description

    [PhoenixBackgroundOperationState]$State

    [datetime]$CreatedAtUtc
    [datetime]$StartedAtUtc
    [datetime]$CompletedAtUtc

    [object]$Process
    [object]$Timer

    [string]$JobDirectory
    [string]$RequestPath
    [string]$ProgressPath
    [string]$ResultPath

    [scriptblock]$Completion

    [int]$ProgressPercent
    [string]$ProgressMessage
    [string]$LastProgressKey

    [bool]$CancellationRequested
    [string]$ErrorMessage

    PhoenixBackgroundOperation(
        [string]$Action,
        [object]$Parameters,
        [string]$Component,
        [string]$Description,
        [scriptblock]$Completion
    ) {
        if ([string]::IsNullOrWhiteSpace($Action)) {
            throw 'A background operation action is required.'
        }

        if ([string]::IsNullOrWhiteSpace($Component)) {
            throw 'A background operation component is required.'
        }

        if ([string]::IsNullOrWhiteSpace($Description)) {
            throw 'A background operation description is required.'
        }

        if ($null -eq $Completion) {
            throw 'A background operation completion callback is required.'
        }

        $this.OperationId =
            [guid]::NewGuid().ToString('N')

        $this.Action = $Action
        $this.Parameters = $Parameters
        $this.Component = $Component
        $this.Description = $Description
        $this.Completion = $Completion

        $this.State =
            [PhoenixBackgroundOperationState]::Created

        $this.CreatedAtUtc =
            [datetime]::UtcNow

        $this.StartedAtUtc =
            [datetime]::MinValue

        $this.CompletedAtUtc =
            [datetime]::MinValue

        $this.Process = $null
        $this.Timer = $null

        $this.JobDirectory = ''
        $this.RequestPath = ''
        $this.ProgressPath = ''
        $this.ResultPath = ''

        $this.ProgressPercent = 0
        $this.ProgressMessage = $Description
        $this.LastProgressKey = ''

        $this.CancellationRequested = $false
        $this.ErrorMessage = ''
    }

    [void] MarkQueued() {
        $this.AssertState(
            [PhoenixBackgroundOperationState]::Created
        )

        $this.State =
            [PhoenixBackgroundOperationState]::Queued
    }

    [void] MarkStarting() {
        if (
            $this.State -ne
                [PhoenixBackgroundOperationState]::Created -and
            $this.State -ne
                [PhoenixBackgroundOperationState]::Queued
        ) {
            throw (
                "Operation '$($this.OperationId)' cannot start " +
                "from state '$($this.State)'."
            )
        }

        $this.State =
            [PhoenixBackgroundOperationState]::Starting

        $this.StartedAtUtc =
            [datetime]::UtcNow
    }

    [void] MarkRunning() {
        $this.AssertState(
            [PhoenixBackgroundOperationState]::Starting
        )

        $this.State =
            [PhoenixBackgroundOperationState]::Running
    }

    [void] UpdateProgress(
        [int]$Percent,
        [string]$Message
    ) {
        if (
            $this.State -ne
            [PhoenixBackgroundOperationState]::Running
        ) {
            throw (
                'Progress can only be updated while an operation ' +
                'is running.'
            )
        }

        if ($Percent -lt 0) {
            $Percent = 0
        }

        if ($Percent -gt 100) {
            $Percent = 100
        }

        $this.ProgressPercent = $Percent
        $this.ProgressMessage = $Message

        $this.LastProgressKey = (
            '{0}|{1}' -f
            $Percent,
            $Message
        )
    }

    [void] RequestCancellation() {
        if (-not $this.CanCancel()) {
            return
        }

        $this.CancellationRequested = $true

        $this.State =
            [PhoenixBackgroundOperationState]::CancellationRequested
    }

    [void] MarkCancelled() {
        if (
            $this.State -ne
                [PhoenixBackgroundOperationState]::Queued -and
            $this.State -ne
                [PhoenixBackgroundOperationState]::Running -and
            $this.State -ne
                [PhoenixBackgroundOperationState]::Starting -and
            $this.State -ne
                [PhoenixBackgroundOperationState]::CancellationRequested
        ) {
            throw (
                "Operation '$($this.OperationId)' cannot be " +
                "cancelled from state '$($this.State)'."
            )
        }

        $this.CancellationRequested = $true

        $this.State =
            [PhoenixBackgroundOperationState]::Cancelled

        $this.CompletedAtUtc =
            [datetime]::UtcNow
    }

    [void] MarkCompleted() {
        if (
            $this.State -ne
            [PhoenixBackgroundOperationState]::Running
        ) {
            throw (
                "Operation '$($this.OperationId)' cannot complete " +
                "from state '$($this.State)'."
            )
        }

        $this.ProgressPercent = 100

        $this.State =
            [PhoenixBackgroundOperationState]::Completed

        $this.CompletedAtUtc =
            [datetime]::UtcNow
    }

    [void] MarkFailed(
        [string]$Message
    ) {
        if ($this.IsTerminal()) {
            throw (
                "Operation '$($this.OperationId)' is already in " +
                "terminal state '$($this.State)'."
            )
        }

        $this.ErrorMessage = $Message

        $this.State =
            [PhoenixBackgroundOperationState]::Failed

        $this.CompletedAtUtc =
            [datetime]::UtcNow
    }

    [bool] CanCancel() {
        return (
            $this.State -eq
                [PhoenixBackgroundOperationState]::Queued -or
            $this.State -eq
                [PhoenixBackgroundOperationState]::Starting -or
            $this.State -eq
                [PhoenixBackgroundOperationState]::Running
        )
    }

    [bool] IsTerminal() {
        return (
            $this.State -eq
                [PhoenixBackgroundOperationState]::Cancelled -or
            $this.State -eq
                [PhoenixBackgroundOperationState]::Completed -or
            $this.State -eq
                [PhoenixBackgroundOperationState]::Failed
        )
    }

    hidden [void] AssertState(
        [PhoenixBackgroundOperationState]$ExpectedState
    ) {
        if ($this.State -ne $ExpectedState) {
            throw (
                "Operation '$($this.OperationId)' expected state " +
                "'$ExpectedState' but is '$($this.State)'."
            )
        }
    }
}
