##########################################################
## Method: CompleteChocolateyResult
##########################################################

hidden [Result] CompleteChocolateyResult(
    [Result]$Result,
    [Package]$Package,
    [string]$Operation,
    [int]$ExitCode
) {

    $Result.Provider = $this.Name
    $Result.Operation = $Operation
    $Result.Target = if ($null -ne $Package) {
        $Package.Id
    }
    else {
        ''
    }
    $Result.HasExitCode = $true
    $Result.ExitCode = $ExitCode
    $Result.RebootRequired =
        $ExitCode -in @(1641, 3010)

    if ($null -ne $Package) {
        $Result.Data = $Package
    }

    return $Result
}
