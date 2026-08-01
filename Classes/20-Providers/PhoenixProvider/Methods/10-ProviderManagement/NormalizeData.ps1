##########################################################
## Method: NormalizeData
##########################################################

[PhoenixProviderResult] NormalizeData(
    [object]$Data,
    [PhoenixProviderOperation]$Operation,
    [string]$Target
) {

    $sourceResult = [Result]::Success($Data)

    return $this.NormalizeResult(
        $sourceResult,
        $Operation,
        $Target
    )
}
