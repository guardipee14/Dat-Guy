using module '..\Classes\Phoenix.Classes.psm1'

function Invoke-PhoenixRestorePlan {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([Result])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Plan', ValueFromPipeline)]
        [object]$Plan,

        [Parameter(Mandatory, ParameterSetName = 'Resume')]
        [ValidateNotNullOrEmpty()]
        [string]$SessionId,

        [Parameter()]
        [AllowEmptyString()]
        [string]$CheckpointRoot = '',

        [Parameter()]
        [switch]$RetryFailed,

        [Parameter()]
        [switch]$StopOnError,

        [Parameter()]
        [switch]$Unattended,

        [Parameter(DontShow)]
        [ValidateRange(0, 2147483647)]
        [int]$StopAfterOperations = 0
    )

    if ($PSCmdlet.ParameterSetName -eq 'Resume') {
        $checkpoint = Get-PhoenixRestoreCheckpoint `
            -SessionId $SessionId `
            -CheckpointRoot $CheckpointRoot
        $Plan = $checkpoint.PlanSnapshot
        if ($null -eq $Plan) {
            throw 'The checkpoint does not contain its restore plan snapshot.'
        }
    }
    else {
        $checkpoint = $null
    }

    [int]$selectedCount = @($Plan.Records | Where-Object Selected).Count
    if (-not $PSCmdlet.ShouldProcess(
        $env:COMPUTERNAME,
        "Execute $selectedCount selected restore-plan operations"
    )) {
        $preview = [Result]::Success($Plan)
        $preview.Code = 'PHX_RESTORE_PLAN_PREVIEW'
        $preview.Message = 'Restore plan preview completed; no checkpoint or system change was made.'
        return $preview
    }

    if ($null -eq $checkpoint) {
        $checkpoint = New-PhoenixRestoreCheckpoint `
            -Plan $Plan `
            -CheckpointRoot $CheckpointRoot `
            -Confirm:$false
    }

    foreach ($record in @($checkpoint.Records | Where-Object Status -EQ 'Running')) {
        $record.Status = 'Pending'
        $record.Retryable = $true
        $record.Error = 'The previous process ended while this operation was running.'
    }
    if ($RetryFailed) {
        foreach ($record in @(
            $checkpoint.Records | Where-Object {
                $_.Status -eq 'Failed' -and $_.Retryable
            }
        )) {
            $record.Status = 'Pending'
            $record.Error = ''
            $record.ResultCode = ''
        }
    }

    $operationResults = [Collections.Generic.List[Result]]::new()
    [int]$processed = 0
    $checkpoint.Status = 'Running'
    $checkpoint = Save-PhoenixRestoreCheckpoint `
        -Checkpoint $checkpoint `
        -CheckpointRoot $CheckpointRoot `
        -Confirm:$false

    foreach ($checkpointRecord in @(
        $checkpoint.Records | Where-Object Status -EQ 'Pending'
    )) {
        if ($StopAfterOperations -gt 0 -and $processed -ge $StopAfterOperations) {
            break
        }
        $planRecord = @(
            $Plan.Records | Where-Object OperationId -EQ $checkpointRecord.OperationId
        ) | Select-Object -First 1
        if ($null -eq $planRecord) {
            $checkpointRecord.Status = 'Failed'
            $checkpointRecord.Error = 'Plan operation was not found in the checkpoint snapshot.'
            $checkpointRecord.ResultCode = 'PHX_RESTORE_PLAN_RECORD_MISSING'
            $checkpointRecord.Retryable = $false
            $checkpoint = Save-PhoenixRestoreCheckpoint `
                -Checkpoint $checkpoint -CheckpointRoot $CheckpointRoot -Confirm:$false
            if ($StopOnError) { break }
            continue
        }

        $checkpointRecord.Status = 'Running'
        $checkpointRecord.Attempts++
        $checkpointRecord.StartedAtUtc = [datetime]::UtcNow
        $checkpoint = Save-PhoenixRestoreCheckpoint `
            -Checkpoint $checkpoint -CheckpointRoot $CheckpointRoot -Confirm:$false

        try {
            [Result]$operationResult = $null
            if ([string]$planRecord.RecordType -eq 'Application') {
                [Package]$package = ConvertTo-PhoenixRestorePackage `
                    -InputObject $planRecord.ManifestRecord
                if ($null -eq $package) {
                    $operationResult = [Result]::Failure('Restore plan package is invalid.')
                    $operationResult.Code = 'PHX_RESTORE_INVALID_PACKAGE'
                }
                else {
                    $package.Provider = [string]$planRecord.Provider
                    $operationResult = Install-PhoenixPackage `
                        -Package $package `
                        -Provider $package.Provider `
                        -Confirm:$false
                }
            }
            elseif ([string]$planRecord.RecordType -eq 'Driver') {
                $operationResult = Update-PhoenixDriver -Unattended:$Unattended
            }
            else {
                $operationResult = [Result]::Failure(
                    "Unsupported restore record type '$($planRecord.RecordType)'."
                )
                $operationResult.Code = 'PHX_RESTORE_RECORD_TYPE_UNSUPPORTED'
            }
            if ($null -eq $operationResult) {
                $operationResult = [Result]::Failure('Restore operation returned no result.')
                $operationResult.Code = 'PHX_RESTORE_NO_RESULT'
            }
        }
        catch {
            $operationResult = [Result]::Failure($_.Exception.Message)
            $operationResult.Code = 'PHX_RESTORE_OPERATION_FAILED'
            $operationResult.Errors = @($_.Exception.Message)
        }

        $operationResults.Add($operationResult)
        $checkpointRecord.CompletedAtUtc = [datetime]::UtcNow
        $checkpointRecord.ResultCode = [string]$operationResult.Code
        $checkpointRecord.RebootRequired = [bool]$operationResult.RebootRequired
        $checkpoint.RebootRequired = (
            $checkpoint.RebootRequired -or $operationResult.RebootRequired
        )
        if ($operationResult.Success) {
            $checkpointRecord.Status = 'Completed'
            $checkpointRecord.Error = ''
            $checkpointRecord.Retryable = $false
        }
        else {
            $checkpointRecord.Status = 'Failed'
            $checkpointRecord.Error = [string]$operationResult.Message
            $checkpointRecord.Retryable = $operationResult.Code -notin @(
                'PHX_RESTORE_INVALID_PACKAGE',
                'PHX_RESTORE_RECORD_TYPE_UNSUPPORTED',
                'PHX_PROTECTED_PACKAGE'
            )
        }
        $processed++
        $checkpoint = Save-PhoenixRestoreCheckpoint `
            -Checkpoint $checkpoint -CheckpointRoot $CheckpointRoot -Confirm:$false
        if ($StopOnError -and -not $operationResult.Success) { break }
    }

    [int]$pendingCount = @($checkpoint.Records | Where-Object Status -EQ 'Pending').Count
    [int]$failedCount = @($checkpoint.Records | Where-Object Status -EQ 'Failed').Count
    $checkpoint.Status = if ($pendingCount -gt 0) { 'Interrupted' }
        elseif ($failedCount -gt 0) { 'Partial' }
        elseif ($checkpoint.RebootRequired) { 'RestartPending' }
        else { 'Complete' }
    $checkpoint = Save-PhoenixRestoreCheckpoint `
        -Checkpoint $checkpoint -CheckpointRoot $CheckpointRoot -Confirm:$false

    $verification = $null
    $verificationError = ''
    if ($checkpoint.Status -ne 'Interrupted') {
        try {
            $verification = Test-PhoenixRestoreVerification `
                -Checkpoint $checkpoint `
                -CheckpointRoot $CheckpointRoot
            $checkpoint.VerificationSnapshot = $verification
            $checkpoint = Save-PhoenixRestoreCheckpoint `
                -Checkpoint $checkpoint -CheckpointRoot $CheckpointRoot -Confirm:$false
        }
        catch {
            $verificationError = $_.Exception.Message
        }
    }

    $result = if ($failedCount -eq 0) { [Result]::Success() }
        else { [Result]::Failure("$failedCount restore operations failed.") }
    $result.Code = switch ($checkpoint.Status) {
        'Complete' { 'PHX_RESTORE_COMPLETE' }
        'RestartPending' { 'PHX_RESTORE_RESTART_PENDING' }
        'Interrupted' { 'PHX_RESTORE_INTERRUPTED' }
        default { 'PHX_RESTORE_PARTIAL' }
    }
    $result.Message = "Restore session $($checkpoint.SessionId) is $($checkpoint.Status)."
    $result.RebootRequired = $checkpoint.RebootRequired
    $result.Data = [pscustomobject]@{
        Checkpoint = $checkpoint
        Results = $operationResults.ToArray()
        ProcessedCount = $processed
        PendingCount = $pendingCount
        FailedCount = $failedCount
        Verification = $verification
        VerificationError = $verificationError
    }
    return $result
}
