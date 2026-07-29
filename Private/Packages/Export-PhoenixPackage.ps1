function Export-PhoenixPackage {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    Get-PhoenixPackage |
        ConvertTo-Json -Depth 10 |
        Set-Content $Path
}