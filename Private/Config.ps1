function Get-PhoenixConfiguration {

    [CmdletBinding()]
    param()

    $context =
        Resolve-PhoenixContext

    $configPath =
        Join-Path `
            $context.ProjectRoot `
            'Config\Phoenix.json'

    if (-not (Test-Path $configPath)) {
        return [PhoenixConfiguration]::new(
            $context.ProjectRoot
        )
    }

    $config =
        [PhoenixConfiguration]::new(
            $context.ProjectRoot
        )

    $jsonObject = Get-Content $configPath -Raw |
    ConvertFrom-Json

$settings = @{}

foreach ($property in $jsonObject.PSObject.Properties) {
    $settings[$property.Name] = $property.Value
}

$config.Settings = $settings
}

function Save-PhoenixConfiguration {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PhoenixConfiguration]$Configuration
    )

    $Configuration.Settings |
        ConvertTo-Json -Depth 10 |
        Set-Content $Configuration.ConfigFile
}
