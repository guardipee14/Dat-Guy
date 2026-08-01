##########################################################
## Method: NormalizeResult
##########################################################

[PhoenixProviderResult] NormalizeResult(
    [Result]$Result,
    [PhoenixProviderOperation]$Operation,
    [string]$Target
) {

    $normalized = [PhoenixProviderResult]::new()
    $normalized.ProviderName = $this.Name
    $normalized.Operation = $Operation
    $normalized.Target = $Target
    $normalized.RequiredPrivilege = $this.RequiredPrivilege

    if ($null -eq $Result) {
        $normalized.Success = $false
        $normalized.Code = 'PHX_PROVIDER_RESULT_MISSING'
        $normalized.Message =
            'The provider returned no result.'
        $normalized.Errors = @($normalized.Message)

        return $normalized
    }

    $normalized.Success = $Result.Success
    $normalized.Code = $Result.Code
    $normalized.Message = $Result.Message
    $normalized.Data = $Result.Data

    if ($Result.Timestamp -gt [datetime]::MinValue) {
        $normalized.Timestamp =
            $Result.Timestamp.ToUniversalTime()
    }

    $warningItems =
        [System.Collections.Generic.List[string]]::new()

    foreach ($warning in @($Result.Warnings)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$warning)) {
            $warningItems.Add([string]$warning)
        }
    }

    $errorItems =
        [System.Collections.Generic.List[string]]::new()

    foreach ($resultError in @($Result.Errors)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$resultError)) {
            $errorItems.Add([string]$resultError)
        }
    }

    if (
        -not $Result.Success -and
        $errorItems.Count -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($Result.Message)
    ) {
        $errorItems.Add($Result.Message)
    }

    $metadataCandidates =
        [System.Collections.Generic.List[object]]::new()

    $metadataCandidates.Add($Result)

    if ($null -ne $Result.Data) {
        foreach ($dataItem in @($Result.Data)) {
            if ($null -ne $dataItem) {
                $metadataCandidates.Add($dataItem)
            }
        }
    }

    foreach ($candidate in $metadataCandidates) {
        $exitCodeProperty =
            $candidate.PSObject.Properties['ExitCode']

        if (
            $null -ne $exitCodeProperty -and
            $null -ne $exitCodeProperty.Value
        ) {
            $normalized.ExitCode =
                [int]$exitCodeProperty.Value
            $normalized.HasExitCode = $true
        }

        foreach (
            $restartPropertyName in @(
                'RequiresRestart'
                'RebootRequired'
                'RestartRequired'
            )
        ) {
            $restartProperty =
                $candidate.PSObject.Properties[
                    $restartPropertyName
                ]

            if (
                $null -ne $restartProperty -and
                [bool]$restartProperty.Value
            ) {
                $normalized.RequiresRestart = $true
            }
        }

        foreach (
            $timeoutPropertyName in @(
                'TimedOut'
                'Timeout'
            )
        ) {
            $timeoutProperty =
                $candidate.PSObject.Properties[
                    $timeoutPropertyName
                ]

            if (
                $null -ne $timeoutProperty -and
                [bool]$timeoutProperty.Value
            ) {
                $normalized.TimedOut = $true
            }
        }

        foreach (
            $cancelPropertyName in @(
                'Cancelled'
                'Canceled'
            )
        ) {
            $cancelProperty =
                $candidate.PSObject.Properties[
                    $cancelPropertyName
                ]

            if (
                $null -ne $cancelProperty -and
                [bool]$cancelProperty.Value
            ) {
                $normalized.Cancelled = $true
            }
        }
    }

    $normalized.Warnings = $warningItems.ToArray()
    $normalized.Errors = $errorItems.ToArray()

    if ([string]::IsNullOrWhiteSpace($normalized.Code)) {
        [string]$operationName =
            $Operation.ToString().ToUpperInvariant()

        $normalized.Code = if ($normalized.Success) {
            "PHX_PROVIDER_$($operationName)_SUCCEEDED"
        }
        else {
            "PHX_PROVIDER_$($operationName)_FAILED"
        }
    }

    return $normalized
}
