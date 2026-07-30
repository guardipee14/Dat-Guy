function Get-PhoenixPackage {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $context =
        Resolve-PhoenixContext

    foreach ($provider in $context.Providers) {

        Write-Host "Querying $($provider.Name)..."

        $packages = $provider.GetInstalledPackages()

}

    return $null
}
