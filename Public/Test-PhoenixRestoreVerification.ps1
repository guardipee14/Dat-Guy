using module '..\Classes\Phoenix.Classes.psm1'

function Test-PhoenixRestoreVerification {
    [CmdletBinding(DefaultParameterSetName = 'Session')]
    [OutputType([PhoenixRestoreVerification])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Session')]
        [string]$SessionId,

        [Parameter(Mandatory, ParameterSetName = 'Checkpoint', ValueFromPipeline)]
        [object]$Checkpoint,

        [Parameter()]
        [AllowEmptyString()]
        [string]$CheckpointRoot = ''
    )

    if ($PSCmdlet.ParameterSetName -eq 'Session') {
        $Checkpoint = Get-PhoenixRestoreCheckpoint `
            -SessionId $SessionId `
            -CheckpointRoot $CheckpointRoot
    }
    $plan = $Checkpoint.PlanSnapshot
    if ($null -eq $plan) {
        throw 'The checkpoint does not contain a restore plan snapshot.'
    }
    $report = [PhoenixRestoreVerification]::new()
    $report.SessionId = [string]$Checkpoint.SessionId
    $context = Resolve-PhoenixContext -SkipProviderBootstrap -ErrorAction Stop
    $installedByProvider = @{}
    $providerErrors = @{}
    $drivers = @()
    try { $drivers = @(Get-PhoenixDriver) } catch { }
    $records = [Collections.Generic.List[PhoenixRestoreVerificationRecord]]::new()

    foreach ($checkpointRecord in @($Checkpoint.Records)) {
        $planRecord = @(
            $plan.Records | Where-Object OperationId -EQ $checkpointRecord.OperationId
        ) | Select-Object -First 1
        $record = [PhoenixRestoreVerificationRecord]::new()
        $record.OperationId = [string]$checkpointRecord.OperationId
        $record.RecordType = [string]$checkpointRecord.RecordType
        $record.Id = [string]$checkpointRecord.Id
        $record.Provider = [string]$checkpointRecord.Provider
        $record.ResultCode = [string]$checkpointRecord.ResultCode
        $record.RebootRequired = [bool]$checkpointRecord.RebootRequired
        if ($null -ne $planRecord) {
            $record.ExpectedVersion = [string]$planRecord.RequestedVersion
        }

        if ([string]$checkpointRecord.Status -eq 'Skipped') {
            $record.Status = if (
                $null -ne $planRecord -and -not [bool]$planRecord.Eligible
            ) { 'NoLongerApplicable' } else { 'Skipped' }
            $record.Details = 'The restore plan did not select this record.'
        }
        elseif ([string]$checkpointRecord.Status -eq 'Failed') {
            $record.Status = 'Failed'
            $record.Details = [string]$checkpointRecord.Error
        }
        elseif (
            [bool]$checkpointRecord.RebootRequired -or
            [string]$Checkpoint.Status -eq 'RestartPending'
        ) {
            $record.Status = 'RestartPending'
            $record.Details = 'Verification will be final after Windows restarts.'
        }
        elseif ($null -eq $planRecord) {
            $record.Status = 'UnableToVerify'
            $record.Details = 'The operation is missing from the plan snapshot.'
        }
        elseif ([string]$planRecord.RecordType -eq 'Application') {
            [string]$providerName = [string]$planRecord.Provider
            if (-not $installedByProvider.ContainsKey($providerName)) {
                $provider = @(
                    $context.Providers | Where-Object Name -IEQ $providerName
                ) | Select-Object -First 1
                if ($null -eq $provider -or -not $provider.Available) {
                    $providerErrors[$providerName] = 'Provider is unavailable.'
                    $installedByProvider[$providerName] = @()
                }
                else {
                    try {
                        $installedByProvider[$providerName] = @(
                            $provider.GetInstalledPackages()
                        )
                    }
                    catch {
                        $providerErrors[$providerName] = $_.Exception.Message
                        $installedByProvider[$providerName] = @()
                    }
                }
            }
            if ($providerErrors.ContainsKey($providerName)) {
                $record.Status = 'UnableToVerify'
                $record.Details = [string]$providerErrors[$providerName]
            }
            else {
                $installed = @(
                    $installedByProvider[$providerName] |
                        Where-Object Id -IEQ ([string]$planRecord.Id)
                ) | Select-Object -First 1
                if ($null -eq $installed) {
                    $record.Status = 'Missing'
                    $record.Details = 'The application was not found after restoration.'
                }
                else {
                    $record.ActualVersion = [string]$installed.Version
                    if (
                        [string]::IsNullOrWhiteSpace($record.ExpectedVersion) -or
                        $record.ActualVersion -eq $record.ExpectedVersion
                    ) {
                        $record.Status = 'Verified'
                        $record.Details = 'The application is installed at the requested version.'
                    }
                    else {
                        [bool]$newer = $false
                        try {
                            $newer = [version]$record.ActualVersion -gt [version]$record.ExpectedVersion
                        }
                        catch { }
                        $record.Status = if ($newer) { 'AlreadySatisfied' } else { 'VersionMismatch' }
                        $record.Details = "Expected $($record.ExpectedVersion); found $($record.ActualVersion)."
                    }
                }
            }
        }
        elseif ([string]$planRecord.RecordType -eq 'Driver') {
            $installed = @(
                $drivers | Where-Object {
                    (-not [string]::IsNullOrWhiteSpace([string]$planRecord.Id) -and
                        $_.InfName -ieq [string]$planRecord.Id) -or
                    $_.Name -ieq [string]$planRecord.Name
                }
            ) | Select-Object -First 1
            if ($null -eq $installed) {
                $record.Status = 'Missing'
                $record.Details = 'The driver was not found after restoration.'
            }
            else {
                $record.ActualVersion = [string]$installed.Version
                $record.Status = if (
                    [string]::IsNullOrWhiteSpace($record.ExpectedVersion) -or
                    $record.ActualVersion -eq $record.ExpectedVersion
                ) { 'Verified' } else { 'VersionMismatch' }
                $record.Details = if ($record.Status -eq 'Verified') {
                    'The driver is present at the requested version.'
                }
                else { "Expected $($record.ExpectedVersion); found $($record.ActualVersion)." }
            }
        }
        else {
            $record.Status = 'UnableToVerify'
            $record.Details = "Unsupported record type '$($planRecord.RecordType)'."
        }
        if ($null -ne $planRecord) {
            $planRecord.VerificationStatus = $record.Status
            $planRecord.VerificationDetails = $record.Details
        }
        $records.Add($record)
    }

    $report.Records = $records.ToArray()
    $problemStatuses = @('VersionMismatch','Missing','Failed','UnableToVerify')
    $report.VerifiedCount = @(
        $report.Records | Where-Object Status -In @('Verified','AlreadySatisfied')
    ).Count
    $report.ProblemCount = @(
        $report.Records | Where-Object Status -In $problemStatuses
    ).Count
    $report.SkippedCount = @(
        $report.Records | Where-Object Status -In @('Skipped','NoLongerApplicable')
    ).Count
    $report.RebootRequired = @(
        $report.Records | Where-Object Status -EQ 'RestartPending'
    ).Count -gt 0
    $report.Status = if ($report.RebootRequired) { 'RestartPending' }
        elseif ($report.ProblemCount -eq 0) { 'Complete' }
        elseif ($report.ProblemCount -eq $report.Records.Count) { 'Failed' }
        else { 'Partial' }
    $report.CompletedAtUtc = [datetime]::UtcNow
    return $report
}
