using module '..\Classes\Phoenix.Classes.psm1'

function Get-PhoenixRestoreCheckpoint {
    [CmdletBinding()]
    [OutputType([PhoenixRestoreCheckpoint])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$SessionId,

        [Parameter()]
        [AllowEmptyString()]
        [string]$CheckpointRoot = '',

        [Parameter()]
        [switch]$AllowDifferentComputer
    )

    [guid]$sessionGuid = [guid]::Empty
    if (-not [guid]::TryParse($SessionId, [ref]$sessionGuid)) {
        throw 'Checkpoint SessionId must be a GUID.'
    }
    if ([string]::IsNullOrWhiteSpace($CheckpointRoot)) {
        $context = Resolve-PhoenixContext -SkipProviderBootstrap -ErrorAction Stop
        $CheckpointRoot = $context.CheckpointRoot
    }
    [string]$path = Join-Path `
        (Join-Path ([IO.Path]::GetFullPath($CheckpointRoot)) $sessionGuid.ToString()) `
        'checkpoint.json'
    $raw = Get-Content -LiteralPath $path -Raw -ErrorAction Stop |
        ConvertFrom-Json -ErrorAction Stop
    if ([string]$raw.Schema -ne 'PhoenixRestoreCheckpoint') {
        throw "Unsupported checkpoint schema '$($raw.Schema)'."
    }
    if ([version]$raw.SchemaVersion -ge [version]'2.0') {
        throw "Unsupported checkpoint version '$($raw.SchemaVersion)'."
    }
    if (
        -not $AllowDifferentComputer -and
        -not [string]::IsNullOrWhiteSpace([string]$raw.ComputerName) -and
        [string]$raw.ComputerName -ine $env:COMPUTERNAME
    ) {
        throw 'The checkpoint belongs to a different computer.'
    }
    $checkpoint = [PhoenixRestoreCheckpoint]::new()
    foreach ($property in @(
        'SchemaVersion','SessionId','PlanId','ManifestId','ManifestPath',
        'ManifestSha256','ComputerName','ComputerManufacturer','ComputerModel',
        'Sequence','Status','RebootRequired','PhoenixVersion'
    )) { $checkpoint.$property = $raw.$property }
    $checkpoint.CreatedAtUtc = [datetime]$raw.CreatedAtUtc
    $checkpoint.UpdatedAtUtc = [datetime]$raw.UpdatedAtUtc
    $checkpoint.StoragePath = $path
    $records = [Collections.Generic.List[PhoenixRestoreCheckpointRecord]]::new()
    foreach ($rawRecord in @($raw.Records)) {
        $record = [PhoenixRestoreCheckpointRecord]::new()
        foreach ($property in @(
            'OperationId','RecordType','Id','Provider','PlannedAction','Status',
            'Attempts','Retryable','ResultCode','Error','RebootRequired'
        )) { $record.$property = $rawRecord.$property }
        if ($rawRecord.StartedAtUtc) { $record.StartedAtUtc = [datetime]$rawRecord.StartedAtUtc }
        if ($rawRecord.CompletedAtUtc) { $record.CompletedAtUtc = [datetime]$rawRecord.CompletedAtUtc }
        $records.Add($record)
    }
    $checkpoint.Records = $records.ToArray()
    return $checkpoint
}
