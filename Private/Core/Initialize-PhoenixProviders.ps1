function Initialize-PhoenixProviders {

    $ctx = Get-PhoenixContext

    $ctx.Providers.Clear()

    foreach ($provider in @(
        [WinGetProvider]::new()
        [ChocolateyProvider]::new()
    )) {

        Write-Host "Adding $($provider.GetType().Name)..."

        $ctx.Providers.Add($provider)

    }

}