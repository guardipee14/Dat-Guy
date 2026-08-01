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
    [string[]]$Errors
    [bool]$RequiresRestart
    [bool]$CanCancel
    [bool]$CanRetry

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
        $this.Errors = @()

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
        $this.CanCancel =
            $this.Operation.CanCancel()
        $this.CanRetry =
            $this.IsTerminal

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

        $codes =
            [System.Collections.Generic.List[string]]::new()

        $warningItems =
            [System.Collections.Generic.List[string]]::new()

        $errorItems =
            [System.Collections.Generic.List[string]]::new()

        $candidates =
            [System.Collections.Generic.List[object]]::new()

        foreach ($item in @($Data)) {
            if ($null -eq $item) {
                continue
            }

            $candidates.Add($item)

            if ($null -ne $item.PSObject.Properties['Data']) {
                foreach ($nestedItem in @($item.Data)) {
                    if ($null -ne $nestedItem) {
                        $candidates.Add($nestedItem)
                    }
                }
            }
        }

        foreach ($candidate in $candidates) {
            if (
                $null -ne $candidate.PSObject.Properties['Code'] -and
                -not [string]::IsNullOrWhiteSpace(
                    [string]$candidate.Code
                )
            ) {
                [string]$code = [string]$candidate.Code

                if (-not $codes.Contains($code)) {
                    $codes.Add($code)
                }
            }

            if ($null -ne $candidate.PSObject.Properties['Warnings']) {
                foreach ($warning in @($candidate.Warnings)) {
                    if (-not [string]::IsNullOrWhiteSpace(
                        [string]$warning
                    )) {
                        $warningItems.Add([string]$warning)
                    }
                }
            }

            if ($null -ne $candidate.PSObject.Properties['Errors']) {
                foreach ($resultError in @($candidate.Errors)) {
                    if (-not [string]::IsNullOrWhiteSpace(
                        [string]$resultError
                    )) {
                        $errorItems.Add([string]$resultError)
                    }
                }
            }

            foreach (
                $restartProperty in @(
                    'RequiresRestart'
                    'RebootRequired'
                    'RestartRequired'
                )
            ) {
                if (
                    $null -ne $candidate.PSObject.Properties[
                        $restartProperty
                    ] -and
                    [bool]$candidate.$restartProperty
                ) {
                    $this.RequiresRestart = $true
                }
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($Error)) {
            $errorItems.Insert(0, $Error)
        }

        $this.ResultCode = $codes -join ', '
        $this.Warnings = $warningItems.ToArray()
        $this.Errors = $errorItems.ToArray()

        if ($errorItems.Count -gt 0) {
            $this.ErrorMessage = $errorItems -join [Environment]::NewLine
        }
    }
}
