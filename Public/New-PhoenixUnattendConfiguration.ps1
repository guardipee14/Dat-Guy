using module '..\Classes\Phoenix.Classes.psm1'

function New-PhoenixUnattendConfiguration {

    [CmdletBinding()]
    [OutputType([PhoenixUnattendConfiguration])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = '*',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Locale = 'en-US',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TimeZone = 'Mountain Standard Time',

        [Parameter()]
        [ValidateSet('Prompt', 'Firmware', 'ProvidedAtDeployment')]
        [string]$ProductKeyPolicy = 'Prompt',

        [Parameter()]
        [AllowEmptyString()]
        [string]$LocalAccountName = '',

        [Parameter()]
        [ValidateSet('Administrators', 'Users')]
        [string]$LocalAccountGroup = 'Users'
    )

    $configuration = New-Object -TypeName PhoenixUnattendConfiguration
    $configuration.ComputerName = $ComputerName.Trim()
    $configuration.InputLocale = $Locale.Trim()
    $configuration.SystemLocale = $Locale.Trim()
    $configuration.UiLanguage = $Locale.Trim()
    $configuration.UserLocale = $Locale.Trim()
    $configuration.TimeZone = $TimeZone.Trim()
    $configuration.ProductKeyPolicy = $ProductKeyPolicy

    if (-not [string]::IsNullOrWhiteSpace($LocalAccountName)) {
        $configuration.AddLocalAccount($LocalAccountName.Trim(), $LocalAccountName.Trim(), $LocalAccountGroup)
    }

    if (-not $configuration.IsValid()) {
        throw 'The unattended setup configuration is invalid.'
    }

    try {
        $null = [Globalization.CultureInfo]::GetCultureInfo($configuration.UiLanguage)
        $null = [TimeZoneInfo]::FindSystemTimeZoneById($configuration.TimeZone)
    }
    catch { throw 'Choose a recognized Windows locale and time-zone identifier.' }

    return $configuration
}
