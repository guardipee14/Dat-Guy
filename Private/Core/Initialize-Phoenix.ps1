function Initialize-Phoenix {

    [CmdletBinding()]
    param()

    $ProjectRoot = Split-Path $PSScriptRoot -Parent
    $ProjectRoot = Split-Path $ProjectRoot -Parent

    $script:PhoenixContext = [PhoenixContext]::new($ProjectRoot)

    $script:PhoenixContext.Configuration.Load()

    Initialize-PhoenixProviders

    Install-MissingProviders

}