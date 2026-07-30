function Get-PhoenixPackages {

    [CmdletBinding()]
    param()

    $context =
        Resolve-PhoenixContext

    foreach ($provider in $context.Providers) {

        if ($provider.PSObject.Methods.Name -contains 'GetInstalledPackages') {

            $provider.GetInstalledPackages()
        }
    }
}
