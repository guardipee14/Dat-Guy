function New-PhoenixBackgroundOperation {

    [CmdletBinding()]
    [OutputType([PhoenixBackgroundOperation])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Action,

        [Parameter()]
        [AllowNull()]
        [object]$Parameters,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Component,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [scriptblock]$Completion,

        [Parameter()]
        [ValidateRange(1, 86400)]
        [int]$TimeoutSeconds = 900,

        [Parameter()]
        [ValidateRange(0, 10)]
        [int]$RetryCount = 0,

        [Parameter()]
        [ValidateRange(0, 10)]
        [int]$MaxRetries = 1,

        [Parameter()]
        [AllowEmptyString()]
        [string]$ConcurrencyKey = '',

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectRoot
    )

    [string]$resolvedProjectRoot = (
        Resolve-Path `
            -LiteralPath $ProjectRoot `
            -ErrorAction Stop
    ).Path

    if (-not (
        Test-Path `
            -LiteralPath $resolvedProjectRoot `
            -PathType Container
    )) {
        throw (
            "Phoenix project root was not found: " +
            $resolvedProjectRoot
        )
    }

    $operation =
        [PhoenixBackgroundOperation]::new(
            $Action,
            $Parameters,
            $Component,
            $Description,
            $Completion
        )

    if ($RetryCount -gt $MaxRetries) {
        throw 'RetryCount cannot be greater than MaxRetries.'
    }

    if ([string]::IsNullOrWhiteSpace($ConcurrencyKey)) {
        $ConcurrencyKey = switch -Regex ($Action) {
            '^PackageAction$' { 'Installer'; break }
            '^(DriverAction|OemDriverAction)$' { 'Driver'; break }
            '^Restore' { 'Restore'; break }
            '^Reboot' { 'Reboot'; break }
            default { $Component }
        }
    }

    $operation.TimeoutSeconds = $TimeoutSeconds
    $operation.RetryCount = $RetryCount
    $operation.MaxRetries = $MaxRetries
    $operation.ConcurrencyKey = $ConcurrencyKey

    [string]$operationRoot =
        Join-Path `
            ([IO.Path]::GetTempPath()) `
            'PhoenixControlCenter'

    [string]$jobDirectory =
        Join-Path `
            $operationRoot `
            $operation.OperationId

    try {
        $null =
            New-Item `
                -ItemType Directory `
                -Path $jobDirectory `
                -Force `
                -ErrorAction Stop

        $operation.JobDirectory =
            $jobDirectory

        $operation.RequestPath =
            Join-Path `
                $jobDirectory `
                'request.json'

        $operation.ProgressPath =
            Join-Path `
                $jobDirectory `
                'progress.json'

        $operation.ResultPath =
            Join-Path `
                $jobDirectory `
                'result.json'

        return $operation
    }
    catch {
        Remove-Item `
            -LiteralPath $jobDirectory `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue

        throw
    }
}
