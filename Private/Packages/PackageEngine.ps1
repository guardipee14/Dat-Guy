function Get-PhoenixPackage {

    [CmdletBinding()]
    param(
        [string]$Name
    )

    $context =
        Resolve-PhoenixContext

    # Safe to use here because this function only runs
    # after Start-Phoenix.

}
