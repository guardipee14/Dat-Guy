using module '..\Classes\Phoenix.Classes.psm1'

function New-PhoenixRestoreCheckpoint {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PhoenixRestoreCheckpoint])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PhoenixRestorePlan]$Plan,

        [Parameter()]
        [AllowEmptyString()]
        [string]$CheckpointRoot = ''
    )

    process {
        $checkpoint = [PhoenixRestoreCheckpoint]::new()
        $checkpoint.PlanId = $Plan.PlanId
        $checkpoint.ManifestId = $Plan.ManifestId
        $checkpoint.ManifestPath = $Plan.ManifestPath
        if (Test-Path -LiteralPath $Plan.ManifestPath -PathType Leaf) {
            $checkpoint.ManifestSha256 = (
                Get-FileHash -LiteralPath $Plan.ManifestPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()
        }
        $checkpoint.ComputerName = $env:COMPUTERNAME
        try {
            $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
            $checkpoint.ComputerManufacturer = [string]$computer.Manufacturer
            $checkpoint.ComputerModel = [string]$computer.Model
        }
        catch { }
        $module = Get-Module Phoenix | Select-Object -First 1
        if ($null -ne $module) { $checkpoint.PhoenixVersion = $module.Version.ToString() }
        $records = [Collections.Generic.List[PhoenixRestoreCheckpointRecord]]::new()
        foreach ($planRecord in @($Plan.Records)) {
            $record = [PhoenixRestoreCheckpointRecord]::new()
            $record.OperationId = $planRecord.OperationId
            $record.RecordType = $planRecord.RecordType
            $record.Id = $planRecord.Id
            $record.Provider = $planRecord.Provider
            $record.PlannedAction = $planRecord.PlannedAction
            $record.Status = if ($planRecord.Selected) { 'Pending' } else { 'Skipped' }
            $record.RebootRequired = $planRecord.RebootRequired
            $records.Add($record)
        }
        $checkpoint.Records = $records.ToArray()
        return Save-PhoenixRestoreCheckpoint `
            -Checkpoint $checkpoint `
            -CheckpointRoot $CheckpointRoot `
            -Confirm:$false `
            -WhatIf:$WhatIfPreference
    }
}
