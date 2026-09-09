function Invoke-PhoenixExternalTool {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter()][string[]]$ArgumentList = @()
    )
    $LASTEXITCODE = 0
    $output = @(& $FilePath @ArgumentList 2>&1)
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}
