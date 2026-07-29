function Invoke-PhoenixDriverEngine {

    [CmdletBinding()]
    param()

    Write-PhoenixLog -Level Info -Message "Starting Driver Engine."

    return Get-PhoenixDriver

}