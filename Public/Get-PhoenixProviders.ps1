function Get-PhoenixProviders {

    [CmdletBinding()]
    param()

    $context =
        Resolve-PhoenixContext

    $context.Providers
}
