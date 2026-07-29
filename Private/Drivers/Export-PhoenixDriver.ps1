function Export-PhoenixDriver {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    Get-PhoenixDriver |
        ConvertTo-Json -Depth 10 |
        Set-Content $Path

}