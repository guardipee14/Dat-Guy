function Get-PhoenixPackage {

    [CmdletBinding()]
    param(
        [string]$Name
    )

    $context = $script:PhoenixContext

    # Safe to use here because this function only runs
    # after Start-Phoenix.

}