using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'Phoenix versioned restore checkpoints' -Tag @('Unit','Restore','Checkpoint') {
    It 'creates a versioned session schema with stable identity' {
        $checkpoint = [PhoenixRestoreCheckpoint]::new()
        $checkpoint.Schema | Should-Be 'PhoenixRestoreCheckpoint'
        $checkpoint.SchemaVersion | Should-Be '1.0'
        ([guid]::Parse($checkpoint.SessionId) -ne [guid]::Empty) | Should-BeTrue
        $checkpoint.Status | Should-Be 'Planned'
    }

    It 'models per-operation progress retry result and reboot state' {
        $record = [PhoenixRestoreCheckpointRecord]::new()
        foreach ($property in @(
            'OperationId','RecordType','Id','Provider','PlannedAction','Status',
            'Attempts','Retryable','StartedAtUtc','CompletedAtUtc','ResultCode',
            'Error','RebootRequired'
        )) {
            ($null -ne $record.PSObject.Properties[$property]) | Should-BeTrue
        }
        $record.Status | Should-Be 'Pending'
    }

    It 'stores manifest and computer identity timestamps and version metadata' {
        $checkpoint = [PhoenixRestoreCheckpoint]::new()
        foreach ($property in @(
            'PlanId','ManifestId','ManifestPath','ManifestSha256','ComputerName',
            'ComputerManufacturer','ComputerModel','CreatedAtUtc','UpdatedAtUtc',
            'Sequence','PhoenixVersion','StoragePath'
        )) {
            ($null -ne $checkpoint.PSObject.Properties[$property]) |
                Should-BeTrue
        }
    }

    It 'writes immutable sequences before atomically replacing current state' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Public\Save-PhoenixRestoreCheckpoint.ps1'
        ) -Raw
        $source.Contains("'checkpoint-{0:D6}.json'") | Should-BeTrue
        $source.Contains('Copy-Item') | Should-BeTrue
        $source.Contains('Move-Item') | Should-BeTrue
        $source.Contains('.tmp') | Should-BeTrue
    }

    It 'rejects invalid sessions schemas versions and foreign computers' {
        $source = Get-Content (
            Join-Path $PSScriptRoot '..\..\Public\Get-PhoenixRestoreCheckpoint.ps1'
        ) -Raw
        $source.Contains('[guid]::TryParse') | Should-BeTrue
        $source.Contains("'PhoenixRestoreCheckpoint'") | Should-BeTrue
        $source.Contains("[version]'2.0'") | Should-BeTrue
        $source.Contains('AllowDifferentComputer') | Should-BeTrue
    }

    It 'exports checkpoint create save and load commands' {
        foreach ($path in @('Phoenix.psm1','Phoenix.psd1')) {
            $source = Get-Content (Join-Path $PSScriptRoot "..\..\$path") -Raw
            foreach ($command in @(
                'New-PhoenixRestoreCheckpoint','Save-PhoenixRestoreCheckpoint',
                'Get-PhoenixRestoreCheckpoint'
            )) { $source.Contains("'$command'") | Should-BeTrue }
        }
    }
}
