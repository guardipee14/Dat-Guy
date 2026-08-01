class PhoenixRestorePlanRecord {
    [string]$OperationId
    [string]$RecordType
    [string]$Id
    [string]$Name
    [string]$RequestedVersion
    [string]$InstalledVersion
    [string]$AvailableVersion
    [string]$Provider
    [string[]]$ProviderAlternatives
    [string]$PlannedAction
    [bool]$Selected
    [bool]$Eligible
    [bool]$RequiresElevation
    [bool]$Protected
    [bool]$RebootRequired
    [string[]]$DependencyIds
    [string]$Safety
    [string]$Reason
    [string]$VerificationStatus
    [string]$VerificationDetails
    [object]$ManifestRecord

    PhoenixRestorePlanRecord() {
        $this.OperationId = [guid]::NewGuid().ToString()
        $this.ProviderAlternatives = @()
        $this.DependencyIds = @()
        $this.PlannedAction = 'Blocked'
        $this.Safety = 'Not evaluated.'
    }
}

class PhoenixRestorePlan {
    [string]$PlanId
    [string]$Schema
    [string]$SchemaVersion
    [string]$ManifestId
    [string]$ManifestPath
    [datetime]$CreatedAtUtc
    [string]$ComputerName
    [PhoenixRestorePlanRecord[]]$Records
    [int]$TotalCount
    [int]$SelectedCount
    [int]$BlockedCount
    [int]$SatisfiedCount

    PhoenixRestorePlan() {
        $this.PlanId = [guid]::NewGuid().ToString()
        $this.Schema = 'PhoenixRestorePlan'
        $this.SchemaVersion = '1.0'
        $this.CreatedAtUtc = [datetime]::UtcNow
        $this.ComputerName = $env:COMPUTERNAME
        $this.Records = @()
    }

    [void] RefreshSummary() {
        $this.TotalCount = $this.Records.Count
        $this.SelectedCount = @($this.Records | Where-Object Selected).Count
        $this.BlockedCount = @(
            $this.Records | Where-Object { -not $_.Eligible }
        ).Count
        $this.SatisfiedCount = @(
            $this.Records | Where-Object PlannedAction -EQ 'AlreadySatisfied'
        ).Count
    }
}
