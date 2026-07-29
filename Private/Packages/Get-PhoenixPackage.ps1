function Get-PhoenixPackage {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $providers = Get-PhoenixProviders

    foreach ($provider in (Get-PhoenixContext).Providers) {

        Write-Host "Querying $($provider.Name)..."

        $packages = $provider.GetInstalledPackages()

}

    return $null
}