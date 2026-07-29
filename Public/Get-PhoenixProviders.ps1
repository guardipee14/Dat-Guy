function Get-PhoenixProviders {

    [CmdletBinding()]
    param()

    (Get-PhoenixContext).Providers
}