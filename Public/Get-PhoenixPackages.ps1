function Get-PhoenixPackages {

    [CmdletBinding()]
    param()

    foreach ($provider in (Get-PhoenixContext).Providers) {

        if ($provider.PSObject.Methods.Name -contains 'GetInstalledPackages') {

            $provider.GetInstalledPackages()
        }
    }
}