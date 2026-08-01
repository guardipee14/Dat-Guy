class PhoenixRestoreCheckpointRecord {
    [string]$OperationId
    [string]$RecordType
    [string]$Id
    [string]$Provider
    [string]$PlannedAction
    [string]$Status
    [int]$Attempts
    [bool]$Retryable
    [datetime]$StartedAtUtc
    [datetime]$CompletedAtUtc
    [string]$ResultCode
    [string]$Error
    [bool]$RebootRequired

    PhoenixRestoreCheckpointRecord() {
        $this.Status = 'Pending'
    }
}

class PhoenixRestoreCheckpoint {
    [string]$Schema
    [string]$SchemaVersion
    [string]$SessionId
    [string]$PlanId
    [string]$ManifestId
    [string]$ManifestPath
    [string]$ManifestSha256
    [string]$ComputerName
    [string]$ComputerManufacturer
    [string]$ComputerModel
    [datetime]$CreatedAtUtc
    [datetime]$UpdatedAtUtc
    [int]$Sequence
    [string]$Status
    [bool]$RebootRequired
    [string]$PhoenixVersion
    [object]$PlanSnapshot
    [object]$VerificationSnapshot
    [PhoenixRestoreCheckpointRecord[]]$Records
    [string]$StoragePath

    PhoenixRestoreCheckpoint() {
        $this.Schema = 'PhoenixRestoreCheckpoint'
        $this.SchemaVersion = '1.0'
        $this.SessionId = [guid]::NewGuid().ToString()
        $this.CreatedAtUtc = [datetime]::UtcNow
        $this.UpdatedAtUtc = $this.CreatedAtUtc
        $this.Status = 'Planned'
        $this.Records = @()
    }
}
