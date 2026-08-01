using module '..\Classes\Phoenix.Classes.psm1'

function Import-PhoenixRestorePlan {
    [CmdletBinding()]
    [OutputType([PhoenixRestorePlan])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [string]$LiteralPath
    )

    [string]$resolvedPath = (Resolve-Path -LiteralPath $LiteralPath -ErrorAction Stop).Path
    $raw = Get-Content -LiteralPath $resolvedPath -Raw -ErrorAction Stop |
        ConvertFrom-Json -ErrorAction Stop
    if ([string]$raw.Schema -ne 'PhoenixRestorePlan') {
        throw "Unsupported restore plan schema '$($raw.Schema)'."
    }
    if ([version]$raw.SchemaVersion -ge [version]'2.0') {
        throw "Unsupported restore plan version '$($raw.SchemaVersion)'."
    }
    $plan = [PhoenixRestorePlan]::new()
    foreach ($property in @(
        'PlanId','SchemaVersion','ManifestId','ManifestPath','ComputerName'
    )) {
        if ($null -ne $raw.PSObject.Properties[$property]) {
            $plan.$property = $raw.$property
        }
    }
    if ($null -ne $raw.PSObject.Properties['CreatedAtUtc']) {
        $plan.CreatedAtUtc = [datetime]$raw.CreatedAtUtc
    }
    $records = [Collections.Generic.List[PhoenixRestorePlanRecord]]::new()
    foreach ($rawRecord in @($raw.Records)) {
        $record = [PhoenixRestorePlanRecord]::new()
        foreach ($property in @(
            'OperationId','RecordType','Id','Name','RequestedVersion',
            'InstalledVersion','AvailableVersion','Provider','PlannedAction',
            'Selected','Eligible','RequiresElevation','Protected',
            'RebootRequired','Safety','Reason','ManifestRecord'
        )) {
            if ($null -ne $rawRecord.PSObject.Properties[$property]) {
                $record.$property = $rawRecord.$property
            }
        }
        $record.ProviderAlternatives = @($rawRecord.ProviderAlternatives)
        $record.DependencyIds = @($rawRecord.DependencyIds)
        $records.Add($record)
    }
    $plan.Records = $records.ToArray()
    $plan.RefreshSummary()
    return $plan
}
