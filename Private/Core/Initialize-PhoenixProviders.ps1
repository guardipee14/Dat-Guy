function Initialize-PhoenixProviders {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PhoenixContext]$Context
    )

    $Context.Providers.Clear()

    foreach ($provider in @(
        [WinGetProvider]::new()
        [ChocolateyProvider]::new()
    )) {

        Write-Host "Adding $($provider.GetType().Name)..."

        $Context.Providers.Add($provider)

    }

}
