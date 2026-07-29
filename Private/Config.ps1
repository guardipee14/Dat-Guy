function Get-PhoenixConfiguration {

    [CmdletBinding()]
    param()

    $configPath = Join-Path $script:PhoenixContext.ProjectRoot 'Config\Phoenix.json'

    if (-not (Test-Path $configPath)) {
        return [PhoenixConfiguration]::new($script:PhoenixContext.ProjectRoot)
    }

    $config = [PhoenixConfiguration]::new($script:PhoenixContext.ProjectRoot)

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