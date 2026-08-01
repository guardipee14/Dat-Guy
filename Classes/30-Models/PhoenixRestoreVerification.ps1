class PhoenixRestoreVerificationRecord {
    [string]$OperationId
    [string]$RecordType
    [string]$Id
    [string]$Provider
    [string]$ExpectedVersion
    [string]$ActualVersion
    [string]$Status
    [string]$ResultCode
    [string]$Details
    [bool]$RebootRequired
}

class PhoenixRestoreVerification {
    [string]$Schema
    [string]$SchemaVersion
    [string]$SessionId
    [datetime]$StartedAtUtc
    [datetime]$CompletedAtUtc
    [string]$Status
    [PhoenixRestoreVerificationRecord[]]$Records
    [int]$VerifiedCount
    [int]$ProblemCount
    [int]$SkippedCount
    [bool]$RebootRequired

    PhoenixRestoreVerification() {
        $this.Schema = 'PhoenixRestoreVerification'
        $this.SchemaVersion = '1.0'
        $this.StartedAtUtc = [datetime]::UtcNow
        $this.Status = 'Running'
        $this.Records = @()
    }
}
